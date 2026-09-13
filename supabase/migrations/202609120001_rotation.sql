-- OD-45 AC-6: digest-only two-phase rotation, no caller identity or test clock.
begin;
create table private.credential_rotations (
 device_id uuid not null references public.devices(id),
 operation_id uuid not null,
 old_credential_id uuid not null unique references private.device_credentials(credential_id),
 new_credential_id uuid not null unique references private.device_credentials(credential_id),
 created_at timestamptz not null,
 overlap_until timestamptz not null,
 confirmed_at timestamptz,
 primary key(device_id,operation_id),
 check(overlap_until>created_at and overlap_until<=created_at+interval '5 minutes')
);
alter table private.credential_rotations enable row level security;
revoke all on private.credential_rotations from public,anon,authenticated;

create function public.rotate_device_credential(p_digest bytea,p_operation uuid,p_phase text,p_new_digest bytea default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c private.device_credentials; d public.devices; r private.credential_rotations;
 n private.device_credentials; t timestamptz; deadline timestamptz;
begin
 if p_operation is null or p_digest is null or p_phase is null or octet_length(p_digest)<>32 or p_phase not in ('BEGIN','CONFIRM','STATUS')
 or (p_phase='BEGIN' and (p_new_digest is null or octet_length(p_new_digest)<>32 or p_new_digest=p_digest))
 or (p_phase<>'BEGIN' and p_new_digest is not null) then return jsonb_build_object('result','INVALID'); end if;
 select * into c from private.device_credentials where secret_digest=p_digest;
 if not found then return jsonb_build_object('result','UNAUTHORIZED'); end if;
 -- Serialize all generations for this verified device; recheck live authority after locking.
 select * into d from public.devices where id=c.device_id for update;
 perform 1 from public.households where id=d.household_id and deletion_state='active' for share;
 if not found then return jsonb_build_object('result','UNAUTHORIZED'); end if;
 select * into c from private.device_credentials where credential_id=c.credential_id for update;
 t:=clock_timestamp();
 if c.revoked_at is not null or d.revoked_at is not null then return jsonb_build_object('result','REVOKED'); end if;
 if c.expires_at<=t then return jsonb_build_object('result','UNAUTHORIZED'); end if;
 select * into r from private.credential_rotations where device_id=d.id and operation_id=p_operation;
 if p_phase='BEGIN' then
  if r.operation_id is not null then
   select * into n from private.device_credentials where credential_id=r.new_credential_id;
   if r.old_credential_id<>c.credential_id or n.secret_digest<>p_new_digest then return jsonb_build_object('result','CONFLICT'); end if;
  else
   if exists(select 1 from private.credential_rotations where old_credential_id=c.credential_id)
      or exists(select 1 from private.credential_rotations where new_credential_id=c.credential_id and confirmed_at is null)
      then return jsonb_build_object('result','CONFLICT'); end if;
   if t<c.created_at+interval '30 days' then return jsonb_build_object('result','NOT_DUE'); end if;
   if exists(select 1 from private.device_credentials where secret_digest=p_new_digest) then return jsonb_build_object('result','CONFLICT'); end if;
   deadline:=least(c.expires_at,t+interval '5 minutes');
   insert into private.device_credentials(credential_id,device_id,secret_digest,created_at,expires_at,generation)
    values(gen_random_uuid(),d.id,p_new_digest,t,t+interval '90 days',c.generation+1) returning * into n;
   update private.device_credentials set expires_at=deadline where credential_id=c.credential_id;
   insert into private.credential_rotations values(d.id,p_operation,c.credential_id,n.credential_id,t,deadline,null) returning * into r;
  end if;
 else
  if r.operation_id is null then return jsonb_build_object('result','NOT_FOUND'); end if;
  if c.credential_id not in (r.old_credential_id,r.new_credential_id) then return jsonb_build_object('result','CONFLICT'); end if;
  select * into n from private.device_credentials where credential_id=r.new_credential_id;
  if p_phase='CONFIRM' then
   if c.credential_id<>r.new_credential_id then return jsonb_build_object('result','NEW_POSSESSION_REQUIRED'); end if;
   if r.confirmed_at is null then
    update private.credential_rotations set confirmed_at=t where device_id=d.id and operation_id=p_operation returning * into r;
    update private.device_credentials set revoked_at=coalesce(revoked_at,t) where credential_id=r.old_credential_id;
   end if;
  end if;
 end if;
 if n.revoked_at is not null or n.expires_at<=t then return jsonb_build_object('result','UNAUTHORIZED'); end if;
 return jsonb_build_object('result',case when r.confirmed_at is null then 'PENDING' else 'CONFIRMED' end,
  'operation_id',r.operation_id,'device_id',d.id,'policy_epoch',d.policy_epoch,'generation',n.generation,
  'expires_at',n.expires_at,'rotate_after',n.created_at+interval '30 days','overlap_until',r.overlap_until);
end $$;
revoke all on function public.rotate_device_credential(bytea,uuid,text,bytea) from public,anon,authenticated;
grant execute on function public.rotate_device_credential(bytea,uuid,text,bytea) to service_role;
commit;
