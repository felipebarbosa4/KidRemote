-- OD-43 local pairing. Raw secrets never enter stored rows or SQL arguments.
-- Public, narrowly granted RPCs; private tables retain their existing deny-all RLS.
begin;
alter table private.pairing_sessions
 add column created_at timestamptz not null default clock_timestamp(),
 add column failed_attempts integer not null default 0 check (failed_attempts between 0 and 5);

create function public.create_pairing(p_token_digest bytea) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid := auth.uid(); household uuid; t timestamptz; n integer; sid uuid;
begin
 if actor is null then return jsonb_build_object('result','DENIED'); end if;
 if p_token_digest is null or octet_length(p_token_digest)<>32 then
  return jsonb_build_object('result','INVALID'); end if;
 select m.household_id into household from public.household_members m
 join public.households h on h.id=m.household_id
 where m.user_id=actor and m.active and m.role='owner' and h.deletion_state='active'
 for share of m,h;
 if not found then return jsonb_build_object('result','DENIED'); end if;
 -- Serializes create quota independently of challenge locks. Fixed windows are local baseline.
 perform pg_advisory_xact_lock(hashtextextended('pair-create:'||actor::text,0));
 t := clock_timestamp();
 insert into private.rate_limit_buckets(scope_hash,window_start,count,expires_at)
 values(extensions.digest('pair-create:'||actor::text,'sha256'),date_bin(interval '10 minutes',t,timestamptz '2000-01-01'),1,t+interval '24 hours')
 on conflict(scope_hash,window_start) do update set count=least(private.rate_limit_buckets.count+1,6)
 returning count into n;
 if n>5 then return jsonb_build_object('result','RATE_LIMITED','retry_after_seconds',600); end if;
 sid := gen_random_uuid();
 insert into private.pairing_sessions(id,household_id,created_by,token_digest,expires_at,created_at)
 values(sid,household,actor,p_token_digest,t+interval '5 minutes',t);
 return jsonb_build_object('result','CREATED','session_id',sid,'expires_at',t+interval '5 minutes');
end $$;

-- Called only by the bounded trusted gateway, never by anon/authenticated directly.
-- Source key is produced by trusted ingress, not a request-body/header identity.
create function public.redeem_pairing(p_session uuid,p_token_digest bytea,
 p_credential_digest bytea,p_source_hash bytea,p_metadata jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s private.pairing_sessions%rowtype; t timestamptz; n integer; did uuid; cid uuid; epoch uuid;
begin
 if p_source_hash is null or octet_length(p_source_hash)<>32 then return jsonb_build_object('result','INVALID'); end if;
 t := clock_timestamp();
 insert into private.rate_limit_buckets(scope_hash,window_start,count,expires_at)
 values(extensions.digest('pair-redeem:'||encode(p_source_hash,'hex'),'sha256'),date_trunc('minute',t),1,t+interval '24 hours')
 on conflict(scope_hash,window_start) do update set count=least(private.rate_limit_buckets.count+1,11)
 returning count into n;
 if n>10 then return jsonb_build_object('result','RATE_LIMITED','retry_after_seconds',60); end if;
 if p_session is null or p_token_digest is null or octet_length(p_token_digest)<>32
 or p_credential_digest is null or octet_length(p_credential_digest)<>32
 or p_metadata is null or jsonb_typeof(p_metadata)<>'object'
 or not (p_metadata ?& array['platform','os_major','agent_version','nickname'])
 or (p_metadata-array['platform','os_major','agent_version','nickname'])<>'{}'::jsonb
 or jsonb_typeof(p_metadata->'platform')<>'string' or p_metadata->>'platform'<>'android'
 or jsonb_typeof(p_metadata->'os_major')<>'number'
 or (p_metadata->>'os_major') !~ '^[1-9][0-9]{0,2}$'
 or jsonb_typeof(p_metadata->'agent_version')<>'string'
 or (p_metadata->>'agent_version') !~ '^[A-Za-z0-9._+-]{1,64}$'
 or jsonb_typeof(p_metadata->'nickname')<>'string'
 or length(btrim(p_metadata->>'nickname')) not between 1 and 80
 or octet_length(p_metadata::text)>1024 then return jsonb_build_object('result','INVALID'); end if;
 select * into s from private.pairing_sessions where id=p_session for update;
 t := clock_timestamp(); -- after contention, never transaction-start time for expiry
 if not found or s.consumed_at is not null or s.cancelled_at is not null
 or s.expires_at<=t or s.failed_attempts>=5 then return jsonb_build_object('result','DENIED'); end if;
 if s.token_digest<>p_token_digest then
  update private.pairing_sessions set failed_attempts=failed_attempts+1 where id=s.id;
  return jsonb_build_object('result','DENIED'); -- commit negative counters, do not throw/rollback
 end if;
 perform 1 from public.household_members m join public.households h on h.id=m.household_id
 where m.household_id=s.household_id and m.user_id=s.created_by and m.active and m.role='owner'
 and h.deletion_state='active' for share of m,h;
 if not found then return jsonb_build_object('result','DENIED'); end if;
 t:=clock_timestamp(); -- membership/household locks can also wait past expiry
 if s.expires_at<=t then return jsonb_build_object('result','DENIED'); end if;
 did:=gen_random_uuid(); cid:=gen_random_uuid(); epoch:=gen_random_uuid();
 insert into public.devices(id,household_id,nickname,platform,os_major,agent_version,policy_epoch)
 values(did,s.household_id,p_metadata->>'nickname','android',(p_metadata->>'os_major')::integer,p_metadata->>'agent_version',epoch);
 insert into public.device_policies(device_id,household_id,version,policy_configured,daily_limit_seconds,manual_lock,updated_by)
 values(did,s.household_id,0,false,null,false,s.created_by);
 insert into private.device_credentials(credential_id,device_id,secret_digest,created_at,expires_at,generation)
 values(cid,did,p_credential_digest,t,t+interval '90 days',1);
 update private.pairing_sessions set consumed_at=t,device_id=did where id=s.id;
 return jsonb_build_object('result','REDEEMED','device_id',did,'credential_id',cid,
  'policy_epoch',epoch,'expires_at',t+interval '90 days','rotate_after',t+interval '30 days');
end $$;

-- A cancel that loses to redemption never silently undoes identity creation.
-- Explicit recovery revokes an incomplete identity before requesting a fresh QR.
create function public.finish_pairing(p_session uuid,p_revoke_incomplete boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s private.pairing_sessions%rowtype; actor uuid:=auth.uid(); t timestamptz;
begin
 if actor is null or p_revoke_incomplete is null then return jsonb_build_object('result','DENIED'); end if;
 select * into s from private.pairing_sessions where id=p_session for update;
 if not found then return jsonb_build_object('result','DENIED'); end if;
 perform 1 from public.household_members m join public.households h on h.id=m.household_id
 where m.household_id=s.household_id and m.user_id=actor and m.active and m.role='owner'
 and h.deletion_state='active' for share of m,h;
 if not found then return jsonb_build_object('result','DENIED'); end if;
 t:=clock_timestamp();
 if s.consumed_at is not null then
  if not p_revoke_incomplete then return jsonb_build_object('result','ALREADY_REDEEMED','device_id',s.device_id); end if;
  perform 1 from public.devices where id=s.device_id for update;
  if exists(select 1 from public.device_state where device_id=s.device_id) then
   return jsonb_build_object('result','USE_DEVICE_REMOVAL'); end if;
  update public.devices set revoked_at=coalesce(revoked_at,t) where id=s.device_id;
  update private.device_credentials set revoked_at=coalesce(revoked_at,t) where device_id=s.device_id;
  update private.push_registrations set invalidated_at=coalesce(invalidated_at,t) where device_id=s.device_id;
  delete from private.push_outbox where device_id=s.device_id;
  return jsonb_build_object('result','REVOKED_FRESH_QR_REQUIRED');
 end if;
 update private.pairing_sessions set cancelled_at=coalesce(cancelled_at,t) where id=s.id;
 return jsonb_build_object('result','CANCELLED');
end $$;

revoke all on function public.create_pairing(bytea) from public,anon,authenticated,service_role;
revoke all on function public.redeem_pairing(uuid,bytea,bytea,bytea,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.finish_pairing(uuid,boolean) from public,anon,authenticated,service_role;
grant execute on function public.create_pairing(bytea),public.finish_pairing(uuid,boolean) to authenticated;
grant execute on function public.redeem_pairing(uuid,bytea,bytea,bytea,jsonb) to service_role;
commit;
