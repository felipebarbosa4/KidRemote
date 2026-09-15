begin;
-- OD-49: authenticated own-device observations, not server assertions of physical truth.
create or replace function public.accept_device_report(p_digest bytea,p_report jsonb) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare
 d public.devices%rowtype; c private.device_credentials%rowtype; h public.households%rowtype;
 p public.device_policies%rowtype; prior public.device_state%rowtype;
 seq bigint; ver bigint; used bigint; bonus bigint; remaining bigint; period text;
 manual boolean; required boolean; lim integer; hash bytea; received timestamptz;
begin
 if octet_length(p_digest)<>32 or p_digest is null then return jsonb_build_object('code','UNAUTHORIZED'); end if;
 select * into c from private.device_credentials where secret_digest=p_digest;
 if not found then return jsonb_build_object('code','UNAUTHORIZED'); end if;
 select * into d from public.devices where id=c.device_id for update;
 select * into c from private.device_credentials where secret_digest=p_digest for share;
 select * into h from public.households where id=d.household_id and deletion_state='active' for share;
 if not found or c.expires_at<=clock_timestamp() or c.revoked_at is not null or d.revoked_at is not null then
  return jsonb_build_object('code','UNAUTHORIZED'); end if;
 if p_report is null or jsonb_typeof(p_report)<>'object' or not p_report ?& array['protocol_version','device_id','policy_epoch','applied_version','report_sequence','period_key','used_ms','bonus_seconds','remaining_ms','manual_lock','restriction_required','restriction_applied','health','accounting_status','observed_at'] or
 p_report-array['protocol_version','device_id','policy_epoch','applied_version','report_sequence','period_key','used_ms','bonus_seconds','remaining_ms','manual_lock','restriction_required','restriction_applied','health','accounting_status','observed_at']<>'{}'::jsonb or
 p_report->'protocol_version'<>'1'::jsonb or p_report->>'device_id'<>d.id::text or p_report->>'policy_epoch'<>d.policy_epoch::text then return jsonb_build_object('code','REPORT_REJECTED'); end if;
 if exists(select 1 from unnest(array['device_id','policy_epoch','period_key','health','accounting_status','observed_at']) k where jsonb_typeof(p_report->k)<>'string') or exists(select 1 from unnest(array['applied_version','report_sequence','used_ms','bonus_seconds','remaining_ms']) k
 where jsonb_typeof(p_report->k)<>'number' or (p_report->>k)!~'^[0-9]+$' or (p_report->>k)::numeric>9007199254740991) or
 exists(select 1 from unnest(array['manual_lock','restriction_required','restriction_applied']) k where jsonb_typeof(p_report->k)<>'boolean') or
 p_report->>'health' not in ('ENFORCEMENT_UNAVAILABLE','SERVICE_DISCONNECTED','PERMISSION_REQUIRED','ADAPTER_PENDING','ADAPTER_FAILED','RESTRICTED_OBSERVED','UNRESTRICTED_OBSERVED','SAFE_SURFACE_AVAILABLE','UNKNOWN_SURFACE_FAIL_OPEN') or
 (p_report->>'restriction_applied')::boolean <> (p_report->>'health'='RESTRICTED_OBSERVED') or
 (p_report->>'health'='RESTRICTED_OBSERVED' and not (p_report->>'restriction_required')::boolean) or
 (p_report->>'health'='UNRESTRICTED_OBSERVED' and (p_report->>'restriction_required')::boolean) or
 p_report->>'accounting_status' not in ('NONE','HISTORY','CLOCK','STORAGE') then return jsonb_build_object('code','REPORT_REJECTED'); end if;
 seq:=(p_report->>'report_sequence')::bigint;ver:=(p_report->>'applied_version')::bigint;
 used:=(p_report->>'used_ms')::bigint;bonus:=(p_report->>'bonus_seconds')::bigint;remaining:=(p_report->>'remaining_ms')::bigint;
 manual:=(p_report->>'manual_lock')::boolean;required:=(p_report->>'restriction_required')::boolean;period:=p_report->>'period_key';
 received:=clock_timestamp();
 if seq<1 or period!~'^[0-9]+:[0-9]{4}-[0-9]{2}-[0-9]{2}$' or split_part(period,':',1)<>h.timezone_revision::text or
 split_part(period,':',2)<>to_char(to_date(split_part(period,':',2),'YYYY-MM-DD'),'YYYY-MM-DD') or
 split_part(period,':',2)>to_char(received at time zone h.timezone_name,'YYYY-MM-DD') or
 jsonb_typeof(p_report->'observed_at')<>'string' or length(p_report->>'observed_at')>40 then return jsonb_build_object('code','REPORT_REJECTED');end if;
 perform (p_report->>'observed_at')::timestamptz;
 select * into p from public.device_policies where device_id=d.id for share;
 if ver>p.version or ver<1 then return jsonb_build_object('code','VERSION_CONFLICT');end if;
 hash:=extensions.digest(convert_to(p_report::text,'UTF8'),'sha256');
 select * into prior from public.device_state where device_id=d.id;
 if found then
  if seq=prior.report_sequence and hash=prior.report_digest then return jsonb_build_object('code','ACKNOWLEDGED','report_sequence',seq,'received_at',prior.received_at);end if;
  if seq<=prior.report_sequence or ver<prior.applied_version or period<prior.period_key or (period=prior.period_key and used<prior.used_ms) then return jsonb_build_object('code','REPORT_CONFLICT');end if;
 end if;
 select (payload->>'daily_limit_seconds')::integer into lim from public.commands
 where device_id=d.id and kind='SET_DAILY_LIMIT' and version<=ver order by version desc limit 1;
 if lim is null or manual<>coalesce((select kind='LOCK' from public.commands where device_id=d.id and kind in ('LOCK','UNLOCK') and version<=ver order by version desc limit 1),false) or
 bonus<>(select coalesce(sum(g.seconds),0) from public.daily_grants g join public.commands o on o.id=g.command_id where g.device_id=d.id and g.period_key=period and o.version<=ver) or
 bonus+lim>86400 or remaining<>greatest(0,(bonus+lim)*1000-used) or
 ((manual or remaining=0 or p_report->>'accounting_status'<>'NONE') and not required) then return jsonb_build_object('code','REPORT_REJECTED');end if;
 insert into public.device_state(device_id,household_id,policy_epoch,applied_version,report_sequence,period_key,used_ms,bonus_seconds,remaining_ms,manual_lock,restriction_required,restriction_applied,health,observed_at,received_at,report_digest)
 values(d.id,d.household_id,d.policy_epoch,ver,seq,period,used,bonus,remaining,manual,required,(p_report->>'restriction_applied')::boolean,(p_report->>'health')||':'||(p_report->>'accounting_status'),(p_report->>'observed_at')::timestamptz,received,hash)
 on conflict(device_id) do update set applied_version=excluded.applied_version,report_sequence=excluded.report_sequence,period_key=excluded.period_key,used_ms=excluded.used_ms,bonus_seconds=excluded.bonus_seconds,remaining_ms=excluded.remaining_ms,manual_lock=excluded.manual_lock,restriction_required=excluded.restriction_required,restriction_applied=excluded.restriction_applied,health=excluded.health,observed_at=excluded.observed_at,received_at=excluded.received_at,report_digest=excluded.report_digest;
 return jsonb_build_object('code','ACKNOWLEDGED','report_sequence',seq,'received_at',received);
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then return jsonb_build_object('code','REPORT_REJECTED');
end $fn$;
revoke all on function public.accept_device_report(bytea,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.accept_device_report(bytea,jsonb) to service_role;
-- RLS still executes as the reading parent. Delivery is never application evidence.
create or replace view public.operation_status with (security_invoker=true) as
 select o.id as operation_id,o.device_id,o.household_id,o.version,o.kind,o.accepted_at,
 case when r.outcome in ('failed','rejected') then r.outcome
 when s.applied_version is null or s.applied_version<o.version then 'pending'
 when o.kind='ADD_TIME' and o.period_key<s.period_key then 'expired_for_period'
 when o.kind='ADD_TIME' and o.period_key<>s.period_key then 'pending'
 when exists(select 1 from public.commands n where n.device_id=o.device_id and n.version>o.version and n.version<=s.applied_version and
 ((o.kind in ('LOCK','UNLOCK') and n.kind in ('LOCK','UNLOCK')) or (o.kind='SET_DAILY_LIMIT' and n.kind='SET_DAILY_LIMIT'))) then 'superseded'
 when (s.restriction_required and s.restriction_applied and s.health like 'RESTRICTED_OBSERVED:%') or
 (not s.restriction_required and not s.restriction_applied and s.health='UNRESTRICTED_OBSERVED:NONE') then 'applied'
 else 'persisted' end as status,s.received_at,s.health,s.restriction_required,s.restriction_applied
 from public.commands o left join public.device_state s on s.device_id=o.device_id left join public.command_receipts r on r.command_id=o.id;
grant select on public.operation_status to authenticated;
commit;
