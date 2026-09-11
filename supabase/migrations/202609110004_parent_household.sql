-- OD-44. Verified Auth subject, confirmed server-side user; no caller actor/tenant.
begin;
create function public.bootstrap_household(p_timezone text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); existing uuid; created uuid; member public.household_members%rowtype;
begin
 if actor is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
 -- Also serializes retries from separate HTTP sessions. Never trust editable metadata.
 perform 1 from auth.users where id=actor and email_confirmed_at is not null and deleted_at is null for update;
 if not found then raise exception using errcode='42501',message='CONFIRMED_ACCOUNT_REQUIRED'; end if;
 if p_timezone is null or length(p_timezone)>80 or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then
  raise exception using errcode='22023',message='INVALID_TIMEZONE'; end if;
 select * into member from public.household_members where user_id=actor;
 if found then
  if not member.active or not exists(select 1 from public.households where id=member.household_id and deletion_state='active') then
   raise exception using errcode='42501',message='MEMBERSHIP_REMOVED'; end if;
  return jsonb_build_object('household_id',member.household_id,'created',false);
 end if;
 -- A retained profile is a bootstrap tombstone: removing membership cannot create a new owner.
 if exists(select 1 from public.profiles where user_id=actor) then
  raise exception using errcode='42501',message='MEMBERSHIP_REMOVED'; end if;
 insert into public.profiles(user_id) values(actor);
 created:=gen_random_uuid();
 insert into public.households(id,timezone_name,timezone_revision,deletion_state) values(created,p_timezone,1,'active');
 insert into public.household_members(household_id,user_id,role,active) values(created,actor,'owner',true);
 return jsonb_build_object('household_id',created,'created',true);
end $$;
revoke all on function public.bootstrap_household(text) from public,anon,authenticated,service_role;
grant execute on function public.bootstrap_household(text) to authenticated;
commit;
