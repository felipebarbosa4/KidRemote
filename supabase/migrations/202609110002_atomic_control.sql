-- OD-42 AC-6. Forward-only extension; preserve migration 001 and its fixtures.
begin;
create extension if not exists pgcrypto with schema extensions;
alter table public.commands add column expected_version bigint check (expected_version >= 0);
alter table public.commands add column request_digest bytea
  check (octet_length(request_digest) = 32);

-- Single parent entrypoint; caller identity is never a function argument.
create function public.accept_control(
  p_operation_id uuid, p_device_id uuid, p_kind text, p_payload jsonb,
  p_expected_version bigint default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $control$
declare
  actor uuid := auth.uid();
  dev public.devices%rowtype;
  household public.households%rowtype;
  policy public.device_policies%rowtype;
  prior public.commands%rowtype;
  digest bytea;
  period text;
  accepted timestamptz;
  bonus bigint;
  amount integer;
  limit_value integer;
begin
  if actor is null then raise exception using errcode='42501', message='AUTH_REQUIRED'; end if;
  if p_operation_id is null or p_device_id is null or p_kind is null or
     p_kind not in ('LOCK','UNLOCK','ADD_TIME','SET_DAILY_LIMIT') or
     p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode='22023', message='INVALID_OPERATION';
  end if;
  if p_kind in ('LOCK','UNLOCK') then
    if p_payload <> '{}'::jsonb or p_expected_version is null or p_expected_version < 0 then
      raise exception using errcode='22023', message='INVALID_OPERATION';
    end if;
  elsif p_kind = 'SET_DAILY_LIMIT' then
    if not (p_payload ? 'daily_limit_seconds') or
       p_payload - 'daily_limit_seconds' <> '{}'::jsonb or
       jsonb_typeof(p_payload->'daily_limit_seconds') <> 'number' then
      raise exception using errcode='22023', message='INVALID_OPERATION';
    end if;
    if (p_payload->>'daily_limit_seconds')::numeric not between 0 and 86400 or
       (p_payload->>'daily_limit_seconds')::numeric <> trunc((p_payload->>'daily_limit_seconds')::numeric) or
       p_expected_version is null or p_expected_version < 0 then
      raise exception using errcode='22023', message='INVALID_OPERATION';
    end if;
    limit_value := (p_payload->>'daily_limit_seconds')::integer;
  else
    if not (p_payload ?& array['seconds','period_key']) or
       p_payload - array['seconds','period_key'] <> '{}'::jsonb or
       jsonb_typeof(p_payload->'seconds') <> 'number' or
       p_payload->'seconds' not in ('600'::jsonb,'1800'::jsonb) or
       jsonb_typeof(p_payload->'period_key') <> 'string' or
       p_expected_version is not null then
      raise exception using errcode='22023', message='INVALID_OPERATION';
    end if;
    amount := (p_payload->>'seconds')::integer;
  end if;
  digest := extensions.digest(convert_to(jsonb_build_object(
    'device_id',p_device_id,'kind',p_kind,'payload',p_payload,'expected_version',p_expected_version)::text,'UTF8'),'sha256');
  -- Serialize a globally unique operation ID even if maliciously reused on two
  -- different devices. Hash collisions only add serialization, never authorization.
  perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,0));
  select * into dev from public.devices where id=p_device_id for update;
  if not found or dev.revoked_at is not null then
    raise exception using errcode='42501', message='TARGET_DENIED';
  end if;
  perform 1 from public.household_members
    where household_id=dev.household_id and user_id=actor and active and role='owner' for share;
  if not found then raise exception using errcode='42501', message='TARGET_DENIED'; end if;
  select * into household from public.households
    where id=dev.household_id and deletion_state='active' for share;
  if not found then raise exception using errcode='42501', message='TARGET_DENIED'; end if;
  select * into policy from public.device_policies
    where device_id=dev.id and household_id=dev.household_id for update;
  if not found then raise exception using errcode='55000', message='POLICY_NOT_READY'; end if;

  select * into prior from public.commands where id=p_operation_id;
  if found then
    if prior.actor_user_id <> actor or prior.device_id <> dev.id or prior.kind <> p_kind or
       prior.request_digest is distinct from digest then
      raise exception using errcode='40001', message='OPERATION_CONFLICT';
    end if;
    return jsonb_build_object('operation_id',prior.id,'device_id',dev.id,
      'policy_epoch',dev.policy_epoch,'version',prior.version,'status','accepted','accepted_at',prior.accepted_at);
  end if;

  -- After waiting for locks, use actual server time, not transaction-start time.
  accepted := clock_timestamp();
  period := household.timezone_revision::text || ':' ||
    to_char(accepted at time zone household.timezone_name,'YYYY-MM-DD');
  select coalesce(sum(seconds),0) into bonus from public.daily_grants
    where device_id=dev.id and period_key=period;
  if p_kind='ADD_TIME' then
    if not policy.policy_configured then
      raise exception using errcode='55000', message='POLICY_NOT_CONFIGURED';
    end if;
    if p_payload->>'period_key' <> period then
      raise exception using errcode='40001', message='PERIOD_CONFLICT';
    end if;
    if policy.daily_limit_seconds::bigint + bonus + amount > 86400 then
      raise exception using errcode='22023', message='ALLOWANCE_CAP';
    end if;
  else
    if p_expected_version <> policy.version then
      raise exception using errcode='40001', message='VERSION_CONFLICT';
    end if;
    if p_kind='SET_DAILY_LIMIT' and limit_value::bigint + bonus > 86400 then
      raise exception using errcode='22023', message='ALLOWANCE_CAP';
    end if;
  end if;

  update public.device_policies set
    version=version+1,
    manual_lock=case p_kind when 'LOCK' then true when 'UNLOCK' then false else manual_lock end,
    policy_configured=case when p_kind='SET_DAILY_LIMIT' then true else policy_configured end,
    daily_limit_seconds=case when p_kind='SET_DAILY_LIMIT' then limit_value else daily_limit_seconds end,
    updated_by=actor, updated_at=accepted
    where device_id=dev.id returning * into policy;
  insert into public.commands(id,device_id,household_id,actor_user_id,version,kind,payload,
    period_key,accepted_at,expected_version,request_digest)
    values(p_operation_id,dev.id,dev.household_id,actor,policy.version,p_kind,p_payload,
      case when p_kind='ADD_TIME' then period end,accepted,p_expected_version,digest);
  if p_kind='ADD_TIME' then
    insert into public.daily_grants values(p_operation_id,dev.id,dev.household_id,period,amount);
  end if;
  insert into private.audit_events(id,household_id,actor_type,actor_id,action,outcome,device_id,created_at)
    values(p_operation_id,dev.household_id,'parent',actor,p_kind,'accepted',dev.id,accepted);
  insert into private.push_outbox(id,device_id,newest_version,next_attempt_at,attempts,state)
    values(p_operation_id,dev.id,policy.version,accepted,0,'pending');
  return jsonb_build_object('operation_id',p_operation_id,'device_id',dev.id,
    'policy_epoch',dev.policy_epoch,'version',policy.version,'status','accepted','accepted_at',accepted);
end $control$;
revoke all on function public.accept_control(uuid,uuid,text,jsonb,bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.accept_control(uuid,uuid,text,jsonb,bigint) to authenticated;
comment on function public.accept_control(uuid,uuid,text,jsonb,bigint) is
  'KR-004 local parent transaction: trusted auth.uid context; no device gateway dispatch or production exposure authorized.';
commit;
