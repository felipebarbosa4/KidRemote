-- Real PostgreSQL roles + Supabase auth.uid(); no Auth HTTP/JWT signature claim.
begin;
create extension if not exists pgtap with schema extensions;
-- Test-only assertion helpers; rolled back, never part of the app migration.
grant execute on all functions in schema extensions to anon, authenticated;
set search_path = public, extensions;
select no_plan();

insert into auth.users(id) values ('00000001-0000-4000-8000-000000000001');
insert into public.profiles(user_id) values ('00000001-0000-4000-8000-000000000001');
insert into public.households(id,timezone_name,timezone_revision,deletion_state) values ('00000002-0000-4000-8000-000000000001','Etc/UTC',1,'active');
insert into public.household_members values ('00000002-0000-4000-8000-000000000001','00000001-0000-4000-8000-000000000001','owner',true);
insert into public.devices(id,household_id,nickname,platform,os_major,agent_version,policy_epoch)
 values ('00000003-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001','synthetic-1','android',16,'synthetic','00000005-0000-4000-8000-000000000001');
insert into public.device_policies values ('00000003-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001',1,true,3600,false,'00000001-0000-4000-8000-000000000001',now());
insert into public.commands(id,device_id,household_id,actor_user_id,version,kind,payload,period_key)
 values ('00000004-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001','00000001-0000-4000-8000-000000000001',1,'ADD_TIME','{"seconds":600}','1:2026-09-11');
insert into public.daily_grants values ('00000004-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001','1:2026-09-11',600);
insert into public.command_receipts(command_id,device_id,snapshot_version,outcome,observed_enforcement)
 values ('00000004-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001',1,'applied',true);
insert into public.device_state values ('00000003-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001','00000005-0000-4000-8000-000000000001',1,1,'1:2026-09-11',0,600,4200000,false,false,false,'healthy',now(),now());

insert into auth.users(id) values ('00000001-0000-4000-8000-000000000002');
insert into public.profiles(user_id) values ('00000001-0000-4000-8000-000000000002');
insert into public.households(id,timezone_name,timezone_revision,deletion_state) values ('00000002-0000-4000-8000-000000000002','Etc/UTC',1,'active');
insert into public.household_members values ('00000002-0000-4000-8000-000000000002','00000001-0000-4000-8000-000000000002','owner',true);
insert into public.devices(id,household_id,nickname,platform,os_major,agent_version,policy_epoch)
 values ('00000003-0000-4000-8000-000000000002','00000002-0000-4000-8000-000000000002','synthetic-2','android',16,'synthetic','00000005-0000-4000-8000-000000000002');
insert into public.device_policies values ('00000003-0000-4000-8000-000000000002','00000002-0000-4000-8000-000000000002',1,true,3600,false,'00000001-0000-4000-8000-000000000002',now());
insert into public.commands(id,device_id,household_id,actor_user_id,version,kind,payload,period_key)
 values ('00000004-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000002','00000002-0000-4000-8000-000000000002','00000001-0000-4000-8000-000000000002',1,'ADD_TIME','{"seconds":600}','1:2026-09-11');
insert into public.daily_grants values ('00000004-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000002','00000002-0000-4000-8000-000000000002','1:2026-09-11',600);
insert into public.command_receipts(command_id,device_id,snapshot_version,outcome,observed_enforcement)
 values ('00000004-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000002',1,'applied',true);
insert into public.device_state values ('00000003-0000-4000-8000-000000000002','00000002-0000-4000-8000-000000000002','00000005-0000-4000-8000-000000000002',1,1,'1:2026-09-11',0,600,4200000,false,false,false,'healthy',now(),now());

select ok((select count(*) = 16 and bool_and(c.relrowsecurity)
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('public','private') and c.relkind='r'), 'all 16 app tables enable RLS');
select ok(not exists(select 1 from pg_roles where rolname in ('anon','authenticated')
 and (rolsuper or rolbypassrls)), 'client roles are neither superuser nor BYPASSRLS');
select ok(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 join pg_roles r on r.oid=c.relowner where n.nspname in ('public','private')
 and c.relkind='r' and r.rolname in ('anon','authenticated')), 'clients do not own app tables');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='private'), 'no private business RPC introduced');
select table_privs_are('public','profiles','authenticated',array['SELECT'], 'profiles: minimum SELECT grant');
select table_privs_are('public','households','authenticated',array['SELECT'], 'households: minimum SELECT grant');
select table_privs_are('public','household_members','authenticated',array['SELECT'], 'household_members: minimum SELECT grant');
select table_privs_are('public','devices','authenticated',array['SELECT'], 'devices: minimum SELECT grant');
select table_privs_are('public','device_policies','authenticated',array['SELECT'], 'device_policies: minimum SELECT grant');
select table_privs_are('public','commands','authenticated',array['SELECT'], 'commands: minimum SELECT grant');
select table_privs_are('public','daily_grants','authenticated',array['SELECT'], 'daily_grants: minimum SELECT grant');
select table_privs_are('public','command_receipts','authenticated',array['SELECT'], 'command_receipts: minimum SELECT grant');
select table_privs_are('public','device_state','authenticated',array['SELECT'], 'device_state: minimum SELECT grant');

set local role authenticated;
set local "request.jwt.claim.sub" = '00000001-0000-4000-8000-000000000001';
select is(current_user::text,'authenticated','1: actual client role');
select is(auth.uid(),'00000001-0000-4000-8000-000000000001'::uuid,'1: actual auth claim');
select is((select count(*) from public.profiles),1::bigint,'1: profiles own row only');
select throws_ok($q$insert into public.profiles default values$q$,'42501',null,'1: profiles insert denied');
select throws_ok($q$update public.profiles set display_name=display_name$q$,'42501',null,'1: profiles update denied');
select throws_ok($q$delete from public.profiles$q$,'42501',null,'1: profiles delete denied');
select is((select count(*) from public.households),1::bigint,'1: households own row only');
select is((select count(*) from public.households where id='00000002-0000-4000-8000-000000000001'),1::bigint,'1: households own guessed ID allowed');
select is((select count(*) from public.households where id='00000002-0000-4000-8000-000000000002'),0::bigint,'1: households foreign guessed ID denied');
select throws_ok($q$insert into public.households default values$q$,'42501',null,'1: households insert denied');
select throws_ok($q$update public.households set timezone_revision=timezone_revision$q$,'42501',null,'1: households update denied');
select throws_ok($q$delete from public.households$q$,'42501',null,'1: households delete denied');
select is((select count(*) from public.household_members),1::bigint,'1: household_members own row only');
select throws_ok($q$insert into public.household_members default values$q$,'42501',null,'1: household_members insert denied');
select throws_ok($q$update public.household_members set active=active$q$,'42501',null,'1: household_members update denied');
select throws_ok($q$delete from public.household_members$q$,'42501',null,'1: household_members delete denied');
select is((select count(*) from public.devices),1::bigint,'1: devices own row only');
select is((select count(*) from public.devices where household_id='00000002-0000-4000-8000-000000000001'),1::bigint,'1: devices own guessed ID allowed');
select is((select count(*) from public.devices where household_id='00000002-0000-4000-8000-000000000002'),0::bigint,'1: devices foreign guessed ID denied');
select throws_ok($q$insert into public.devices default values$q$,'42501',null,'1: devices insert denied');
select throws_ok($q$update public.devices set nickname=nickname$q$,'42501',null,'1: devices update denied');
select throws_ok($q$delete from public.devices$q$,'42501',null,'1: devices delete denied');
select is((select count(*) from public.device_policies),1::bigint,'1: device_policies own row only');
select is((select count(*) from public.device_policies where household_id='00000002-0000-4000-8000-000000000001'),1::bigint,'1: device_policies own guessed ID allowed');
select is((select count(*) from public.device_policies where household_id='00000002-0000-4000-8000-000000000002'),0::bigint,'1: device_policies foreign guessed ID denied');
select throws_ok($q$insert into public.device_policies default values$q$,'42501',null,'1: device_policies insert denied');
select throws_ok($q$update public.device_policies set version=version$q$,'42501',null,'1: device_policies update denied');
select throws_ok($q$delete from public.device_policies$q$,'42501',null,'1: device_policies delete denied');
select is((select count(*) from public.commands),1::bigint,'1: commands own row only');
select is((select count(*) from public.commands where household_id='00000002-0000-4000-8000-000000000001'),1::bigint,'1: commands own guessed ID allowed');
select is((select count(*) from public.commands where household_id='00000002-0000-4000-8000-000000000002'),0::bigint,'1: commands foreign guessed ID denied');
select throws_ok($q$insert into public.commands default values$q$,'42501',null,'1: commands insert denied');
select throws_ok($q$update public.commands set version=version$q$,'42501',null,'1: commands update denied');
select throws_ok($q$delete from public.commands$q$,'42501',null,'1: commands delete denied');
select is((select count(*) from public.daily_grants),1::bigint,'1: daily_grants own row only');
select is((select count(*) from public.daily_grants where household_id='00000002-0000-4000-8000-000000000001'),1::bigint,'1: daily_grants own guessed ID allowed');
select is((select count(*) from public.daily_grants where household_id='00000002-0000-4000-8000-000000000002'),0::bigint,'1: daily_grants foreign guessed ID denied');
select throws_ok($q$insert into public.daily_grants default values$q$,'42501',null,'1: daily_grants insert denied');
select throws_ok($q$update public.daily_grants set seconds=seconds$q$,'42501',null,'1: daily_grants update denied');
select throws_ok($q$delete from public.daily_grants$q$,'42501',null,'1: daily_grants delete denied');
select is((select count(*) from public.command_receipts),1::bigint,'1: command_receipts own row only');
select throws_ok($q$insert into public.command_receipts default values$q$,'42501',null,'1: command_receipts insert denied');
select throws_ok($q$update public.command_receipts set snapshot_version=snapshot_version$q$,'42501',null,'1: command_receipts update denied');
select throws_ok($q$delete from public.command_receipts$q$,'42501',null,'1: command_receipts delete denied');
select is((select count(*) from public.device_state),1::bigint,'1: device_state own row only');
select is((select count(*) from public.device_state where household_id='00000002-0000-4000-8000-000000000001'),1::bigint,'1: device_state own guessed ID allowed');
select is((select count(*) from public.device_state where household_id='00000002-0000-4000-8000-000000000002'),0::bigint,'1: device_state foreign guessed ID denied');
select throws_ok($q$insert into public.device_state default values$q$,'42501',null,'1: device_state insert denied');
select throws_ok($q$update public.device_state set used_ms=used_ms$q$,'42501',null,'1: device_state update denied');
select throws_ok($q$delete from public.device_state$q$,'42501',null,'1: device_state delete denied');
select is((select count(*) from public.devices d join public.commands c on c.device_id=d.id
 join public.daily_grants g on g.command_id=c.id join public.command_receipts r on r.command_id=c.id
 join public.device_policies p on p.device_id=d.id join public.device_state s on s.device_id=d.id),
 1::bigint,'1: joined graph only own household');
select is((select count(*) from public.devices a join public.devices b on a.household_id<>b.household_id),
 0::bigint,'1: cross-tenant join denied');
select throws_ok($q$update public.household_members set user_id='00000001-0000-4000-8000-000000000002', active=true$q$,
 '42501',null,'1: membership self-promotion denied');
select throws_ok($q$insert into public.household_members values ('00000002-0000-4000-8000-000000000002','00000001-0000-4000-8000-000000000001','owner',true)$q$,
 '42501',null,'1: foreign membership insertion denied');
select throws_ok($q$select public.accept_command()$q$,'42883',null,'1: absent control RPC is not an access path');
select throws_ok($q$select * from auth.users$q$,'42501',null,'1: no direct Auth table access');
select throws_ok($q$create table public.client_created(id int)$q$,'42501',null,'1: schema creation denied');
select throws_ok($q$select * from private.pairing_sessions$q$,'42501',null,'1: private pairing_sessions select denied');
select throws_ok($q$insert into private.pairing_sessions default values$q$,'42501',null,'1: private pairing_sessions insert denied');
select throws_ok($q$update private.pairing_sessions set id=id$q$,'42501',null,'1: private pairing_sessions update denied');
select throws_ok($q$delete from private.pairing_sessions$q$,'42501',null,'1: private pairing_sessions delete denied');
select throws_ok($q$select * from private.device_credentials$q$,'42501',null,'1: private device_credentials select denied');
select throws_ok($q$insert into private.device_credentials default values$q$,'42501',null,'1: private device_credentials insert denied');
select throws_ok($q$update private.device_credentials set generation=generation$q$,'42501',null,'1: private device_credentials update denied');
select throws_ok($q$delete from private.device_credentials$q$,'42501',null,'1: private device_credentials delete denied');
select throws_ok($q$select * from private.push_registrations$q$,'42501',null,'1: private push_registrations select denied');
select throws_ok($q$insert into private.push_registrations default values$q$,'42501',null,'1: private push_registrations insert denied');
select throws_ok($q$update private.push_registrations set id=id$q$,'42501',null,'1: private push_registrations update denied');
select throws_ok($q$delete from private.push_registrations$q$,'42501',null,'1: private push_registrations delete denied');
select throws_ok($q$select * from private.push_outbox$q$,'42501',null,'1: private push_outbox select denied');
select throws_ok($q$insert into private.push_outbox default values$q$,'42501',null,'1: private push_outbox insert denied');
select throws_ok($q$update private.push_outbox set id=id$q$,'42501',null,'1: private push_outbox update denied');
select throws_ok($q$delete from private.push_outbox$q$,'42501',null,'1: private push_outbox delete denied');
select throws_ok($q$select * from private.audit_events$q$,'42501',null,'1: private audit_events select denied');
select throws_ok($q$insert into private.audit_events default values$q$,'42501',null,'1: private audit_events insert denied');
select throws_ok($q$update private.audit_events set id=id$q$,'42501',null,'1: private audit_events update denied');
select throws_ok($q$delete from private.audit_events$q$,'42501',null,'1: private audit_events delete denied');
select throws_ok($q$select * from private.rate_limit_buckets$q$,'42501',null,'1: private rate_limit_buckets select denied');
select throws_ok($q$insert into private.rate_limit_buckets default values$q$,'42501',null,'1: private rate_limit_buckets insert denied');
select throws_ok($q$update private.rate_limit_buckets set count=count$q$,'42501',null,'1: private rate_limit_buckets update denied');
select throws_ok($q$delete from private.rate_limit_buckets$q$,'42501',null,'1: private rate_limit_buckets delete denied');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub" = '00000001-0000-4000-8000-000000000002';
select is(current_user::text,'authenticated','2: actual client role');
select is(auth.uid(),'00000001-0000-4000-8000-000000000002'::uuid,'2: actual auth claim');
select is((select count(*) from public.profiles),1::bigint,'2: profiles own row only');
select throws_ok($q$insert into public.profiles default values$q$,'42501',null,'2: profiles insert denied');
select throws_ok($q$update public.profiles set display_name=display_name$q$,'42501',null,'2: profiles update denied');
select throws_ok($q$delete from public.profiles$q$,'42501',null,'2: profiles delete denied');
select is((select count(*) from public.households),1::bigint,'2: households own row only');
select is((select count(*) from public.households where id='00000002-0000-4000-8000-000000000002'),1::bigint,'2: households own guessed ID allowed');
select is((select count(*) from public.households where id='00000002-0000-4000-8000-000000000001'),0::bigint,'2: households foreign guessed ID denied');
select throws_ok($q$insert into public.households default values$q$,'42501',null,'2: households insert denied');
select throws_ok($q$update public.households set timezone_revision=timezone_revision$q$,'42501',null,'2: households update denied');
select throws_ok($q$delete from public.households$q$,'42501',null,'2: households delete denied');
select is((select count(*) from public.household_members),1::bigint,'2: household_members own row only');
select throws_ok($q$insert into public.household_members default values$q$,'42501',null,'2: household_members insert denied');
select throws_ok($q$update public.household_members set active=active$q$,'42501',null,'2: household_members update denied');
select throws_ok($q$delete from public.household_members$q$,'42501',null,'2: household_members delete denied');
select is((select count(*) from public.devices),1::bigint,'2: devices own row only');
select is((select count(*) from public.devices where household_id='00000002-0000-4000-8000-000000000002'),1::bigint,'2: devices own guessed ID allowed');
select is((select count(*) from public.devices where household_id='00000002-0000-4000-8000-000000000001'),0::bigint,'2: devices foreign guessed ID denied');
select throws_ok($q$insert into public.devices default values$q$,'42501',null,'2: devices insert denied');
select throws_ok($q$update public.devices set nickname=nickname$q$,'42501',null,'2: devices update denied');
select throws_ok($q$delete from public.devices$q$,'42501',null,'2: devices delete denied');
select is((select count(*) from public.device_policies),1::bigint,'2: device_policies own row only');
select is((select count(*) from public.device_policies where household_id='00000002-0000-4000-8000-000000000002'),1::bigint,'2: device_policies own guessed ID allowed');
select is((select count(*) from public.device_policies where household_id='00000002-0000-4000-8000-000000000001'),0::bigint,'2: device_policies foreign guessed ID denied');
select throws_ok($q$insert into public.device_policies default values$q$,'42501',null,'2: device_policies insert denied');
select throws_ok($q$update public.device_policies set version=version$q$,'42501',null,'2: device_policies update denied');
select throws_ok($q$delete from public.device_policies$q$,'42501',null,'2: device_policies delete denied');
select is((select count(*) from public.commands),1::bigint,'2: commands own row only');
select is((select count(*) from public.commands where household_id='00000002-0000-4000-8000-000000000002'),1::bigint,'2: commands own guessed ID allowed');
select is((select count(*) from public.commands where household_id='00000002-0000-4000-8000-000000000001'),0::bigint,'2: commands foreign guessed ID denied');
select throws_ok($q$insert into public.commands default values$q$,'42501',null,'2: commands insert denied');
select throws_ok($q$update public.commands set version=version$q$,'42501',null,'2: commands update denied');
select throws_ok($q$delete from public.commands$q$,'42501',null,'2: commands delete denied');
select is((select count(*) from public.daily_grants),1::bigint,'2: daily_grants own row only');
select is((select count(*) from public.daily_grants where household_id='00000002-0000-4000-8000-000000000002'),1::bigint,'2: daily_grants own guessed ID allowed');
select is((select count(*) from public.daily_grants where household_id='00000002-0000-4000-8000-000000000001'),0::bigint,'2: daily_grants foreign guessed ID denied');
select throws_ok($q$insert into public.daily_grants default values$q$,'42501',null,'2: daily_grants insert denied');
select throws_ok($q$update public.daily_grants set seconds=seconds$q$,'42501',null,'2: daily_grants update denied');
select throws_ok($q$delete from public.daily_grants$q$,'42501',null,'2: daily_grants delete denied');
select is((select count(*) from public.command_receipts),1::bigint,'2: command_receipts own row only');
select throws_ok($q$insert into public.command_receipts default values$q$,'42501',null,'2: command_receipts insert denied');
select throws_ok($q$update public.command_receipts set snapshot_version=snapshot_version$q$,'42501',null,'2: command_receipts update denied');
select throws_ok($q$delete from public.command_receipts$q$,'42501',null,'2: command_receipts delete denied');
select is((select count(*) from public.device_state),1::bigint,'2: device_state own row only');
select is((select count(*) from public.device_state where household_id='00000002-0000-4000-8000-000000000002'),1::bigint,'2: device_state own guessed ID allowed');
select is((select count(*) from public.device_state where household_id='00000002-0000-4000-8000-000000000001'),0::bigint,'2: device_state foreign guessed ID denied');
select throws_ok($q$insert into public.device_state default values$q$,'42501',null,'2: device_state insert denied');
select throws_ok($q$update public.device_state set used_ms=used_ms$q$,'42501',null,'2: device_state update denied');
select throws_ok($q$delete from public.device_state$q$,'42501',null,'2: device_state delete denied');
select is((select count(*) from public.devices d join public.commands c on c.device_id=d.id
 join public.daily_grants g on g.command_id=c.id join public.command_receipts r on r.command_id=c.id
 join public.device_policies p on p.device_id=d.id join public.device_state s on s.device_id=d.id),
 1::bigint,'2: joined graph only own household');
select is((select count(*) from public.devices a join public.devices b on a.household_id<>b.household_id),
 0::bigint,'2: cross-tenant join denied');
select throws_ok($q$update public.household_members set user_id='00000001-0000-4000-8000-000000000001', active=true$q$,
 '42501',null,'2: membership self-promotion denied');
select throws_ok($q$insert into public.household_members values ('00000002-0000-4000-8000-000000000001','00000001-0000-4000-8000-000000000002','owner',true)$q$,
 '42501',null,'2: foreign membership insertion denied');
select throws_ok($q$select public.accept_command()$q$,'42883',null,'2: absent control RPC is not an access path');
select throws_ok($q$select * from auth.users$q$,'42501',null,'2: no direct Auth table access');
select throws_ok($q$create table public.client_created(id int)$q$,'42501',null,'2: schema creation denied');
select throws_ok($q$select * from private.pairing_sessions$q$,'42501',null,'2: private pairing_sessions select denied');
select throws_ok($q$insert into private.pairing_sessions default values$q$,'42501',null,'2: private pairing_sessions insert denied');
select throws_ok($q$update private.pairing_sessions set id=id$q$,'42501',null,'2: private pairing_sessions update denied');
select throws_ok($q$delete from private.pairing_sessions$q$,'42501',null,'2: private pairing_sessions delete denied');
select throws_ok($q$select * from private.device_credentials$q$,'42501',null,'2: private device_credentials select denied');
select throws_ok($q$insert into private.device_credentials default values$q$,'42501',null,'2: private device_credentials insert denied');
select throws_ok($q$update private.device_credentials set generation=generation$q$,'42501',null,'2: private device_credentials update denied');
select throws_ok($q$delete from private.device_credentials$q$,'42501',null,'2: private device_credentials delete denied');
select throws_ok($q$select * from private.push_registrations$q$,'42501',null,'2: private push_registrations select denied');
select throws_ok($q$insert into private.push_registrations default values$q$,'42501',null,'2: private push_registrations insert denied');
select throws_ok($q$update private.push_registrations set id=id$q$,'42501',null,'2: private push_registrations update denied');
select throws_ok($q$delete from private.push_registrations$q$,'42501',null,'2: private push_registrations delete denied');
select throws_ok($q$select * from private.push_outbox$q$,'42501',null,'2: private push_outbox select denied');
select throws_ok($q$insert into private.push_outbox default values$q$,'42501',null,'2: private push_outbox insert denied');
select throws_ok($q$update private.push_outbox set id=id$q$,'42501',null,'2: private push_outbox update denied');
select throws_ok($q$delete from private.push_outbox$q$,'42501',null,'2: private push_outbox delete denied');
select throws_ok($q$select * from private.audit_events$q$,'42501',null,'2: private audit_events select denied');
select throws_ok($q$insert into private.audit_events default values$q$,'42501',null,'2: private audit_events insert denied');
select throws_ok($q$update private.audit_events set id=id$q$,'42501',null,'2: private audit_events update denied');
select throws_ok($q$delete from private.audit_events$q$,'42501',null,'2: private audit_events delete denied');
select throws_ok($q$select * from private.rate_limit_buckets$q$,'42501',null,'2: private rate_limit_buckets select denied');
select throws_ok($q$insert into private.rate_limit_buckets default values$q$,'42501',null,'2: private rate_limit_buckets insert denied');
select throws_ok($q$update private.rate_limit_buckets set count=count$q$,'42501',null,'2: private rate_limit_buckets update denied');
select throws_ok($q$delete from private.rate_limit_buckets$q$,'42501',null,'2: private rate_limit_buckets delete denied');
reset role;

-- NULL auth with the real authenticated role: membership-derived reads fail closed.
set local role authenticated;
set local "request.jwt.claim.sub" = '';
set local "request.jwt.claims" = '{}';
select is(auth.uid(),null::uuid,'missing authentication is NULL');
select is((select count(*) from public.profiles),0::bigint,'null auth: profiles empty');
select is((select count(*) from public.households),0::bigint,'null auth: households empty');
select is((select count(*) from public.household_members),0::bigint,'null auth: household_members empty');
select is((select count(*) from public.devices),0::bigint,'null auth: devices empty');
select is((select count(*) from public.device_policies),0::bigint,'null auth: device_policies empty');
select is((select count(*) from public.commands),0::bigint,'null auth: commands empty');
select is((select count(*) from public.daily_grants),0::bigint,'null auth: daily_grants empty');
select is((select count(*) from public.command_receipts),0::bigint,'null auth: command_receipts empty');
select is((select count(*) from public.device_state),0::bigint,'null auth: device_state empty');
reset role;
set local role anon;
select throws_ok($q$select * from public.profiles$q$,'42501',null,'anon: profiles select denied');
select throws_ok($q$insert into public.profiles default values$q$,'42501',null,'anon: profiles insert denied');
select throws_ok($q$delete from public.profiles$q$,'42501',null,'anon: profiles delete denied');
select throws_ok($q$select * from public.households$q$,'42501',null,'anon: households select denied');
select throws_ok($q$insert into public.households default values$q$,'42501',null,'anon: households insert denied');
select throws_ok($q$delete from public.households$q$,'42501',null,'anon: households delete denied');
select throws_ok($q$select * from public.household_members$q$,'42501',null,'anon: household_members select denied');
select throws_ok($q$insert into public.household_members default values$q$,'42501',null,'anon: household_members insert denied');
select throws_ok($q$delete from public.household_members$q$,'42501',null,'anon: household_members delete denied');
select throws_ok($q$select * from public.devices$q$,'42501',null,'anon: devices select denied');
select throws_ok($q$insert into public.devices default values$q$,'42501',null,'anon: devices insert denied');
select throws_ok($q$delete from public.devices$q$,'42501',null,'anon: devices delete denied');
select throws_ok($q$select * from public.device_policies$q$,'42501',null,'anon: device_policies select denied');
select throws_ok($q$insert into public.device_policies default values$q$,'42501',null,'anon: device_policies insert denied');
select throws_ok($q$delete from public.device_policies$q$,'42501',null,'anon: device_policies delete denied');
select throws_ok($q$select * from public.commands$q$,'42501',null,'anon: commands select denied');
select throws_ok($q$insert into public.commands default values$q$,'42501',null,'anon: commands insert denied');
select throws_ok($q$delete from public.commands$q$,'42501',null,'anon: commands delete denied');
select throws_ok($q$select * from public.daily_grants$q$,'42501',null,'anon: daily_grants select denied');
select throws_ok($q$insert into public.daily_grants default values$q$,'42501',null,'anon: daily_grants insert denied');
select throws_ok($q$delete from public.daily_grants$q$,'42501',null,'anon: daily_grants delete denied');
select throws_ok($q$select * from public.command_receipts$q$,'42501',null,'anon: command_receipts select denied');
select throws_ok($q$insert into public.command_receipts default values$q$,'42501',null,'anon: command_receipts insert denied');
select throws_ok($q$delete from public.command_receipts$q$,'42501',null,'anon: command_receipts delete denied');
select throws_ok($q$select * from public.device_state$q$,'42501',null,'anon: device_state select denied');
select throws_ok($q$insert into public.device_state default values$q$,'42501',null,'anon: device_state insert denied');
select throws_ok($q$delete from public.device_state$q$,'42501',null,'anon: device_state delete denied');
select throws_ok($q$select * from private.pairing_sessions$q$,'42501',null,'anon: private pairing_sessions denied');
select throws_ok($q$select * from private.device_credentials$q$,'42501',null,'anon: private device_credentials denied');
select throws_ok($q$select * from private.push_registrations$q$,'42501',null,'anon: private push_registrations denied');
select throws_ok($q$select * from private.push_outbox$q$,'42501',null,'anon: private push_outbox denied');
select throws_ok($q$select * from private.audit_events$q$,'42501',null,'anon: private audit_events denied');
select throws_ok($q$select * from private.rate_limit_buckets$q$,'42501',null,'anon: private rate_limit_buckets denied');
reset role;
-- Deliberately grant verbs: prove RLS, not only GRANT, still denies mutations.
grant insert, update, delete on public.household_members, public.devices to authenticated;
set local role authenticated;
set local "request.jwt.claim.sub" = '00000001-0000-4000-8000-000000000001';
select throws_ok($q$insert into public.household_members values ('00000002-0000-4000-8000-000000000002','00000001-0000-4000-8000-000000000001','owner',true)$q$,
 '42501',null,'WITH CHECK absence denies self-promotion even with INSERT grant');
with changed as (update public.household_members set active=false returning *)
 select is((select count(*) from changed),0::bigint,'no UPDATE policy denies even own mutation with grant');
with changed as (delete from public.devices returning *)
 select is((select count(*) from changed),0::bigint,'no DELETE policy denies mutation with grant');
reset role;
revoke insert, update, delete on public.household_members, public.devices from authenticated;
-- Missing SELECT policy on an existing populated table, despite its SELECT grant.
drop policy own_household on public.devices;
set local role authenticated;
select is((select count(*) from public.devices),0::bigint,'removed/missing policy denies with grant');
select is((select count(*) from public.command_receipts),0::bigint,'join policy also fails closed');
reset role;
create policy own_household on public.devices for select to authenticated
 using (exists(select 1 from public.household_members m where m.household_id=devices.household_id));
-- Forgotten grant, even with a valid SELECT policy.
revoke select on public.devices from authenticated;
set local role authenticated;
select throws_ok($q$select * from public.devices$q$,'42501',null,'missing grant fails closed');
reset role;
grant select on public.devices to authenticated;
-- Test-only private invoker function, rolled back; default EXECUTE must not leak.
create function private.test_boundary() returns integer language sql set search_path='' as 'select 1';
set local role authenticated;
select throws_ok($q$select private.test_boundary()$q$,'42501',null,'private RPC denied');
reset role;
grant usage on schema private to authenticated;
set local role authenticated;
select throws_ok($q$select private.test_boundary()$q$,'42501',null,'private function EXECUTE denied even with schema usage');
reset role;
revoke usage on schema private from authenticated;
-- Still-valid subject claim cannot revive an inactive or removed membership.
update public.household_members set active=false where user_id='00000001-0000-4000-8000-000000000001';
set local role authenticated;
select is((select count(*) from public.households),0::bigint,'inactive member: households denied');
select is((select count(*) from public.household_members),0::bigint,'inactive member: household_members denied');
select is((select count(*) from public.devices),0::bigint,'inactive member: devices denied');
select is((select count(*) from public.device_policies),0::bigint,'inactive member: device_policies denied');
select is((select count(*) from public.commands),0::bigint,'inactive member: commands denied');
select is((select count(*) from public.daily_grants),0::bigint,'inactive member: daily_grants denied');
select is((select count(*) from public.command_receipts),0::bigint,'inactive member: command_receipts denied');
select is((select count(*) from public.device_state),0::bigint,'inactive member: device_state denied');
reset role;
delete from public.household_members where user_id='00000001-0000-4000-8000-000000000001';
set local role authenticated;
select is((select count(*) from public.households),0::bigint,'removed member with stale claim: households denied');
select is((select count(*) from public.household_members),0::bigint,'removed member with stale claim: household_members denied');
select is((select count(*) from public.devices),0::bigint,'removed member with stale claim: devices denied');
select is((select count(*) from public.device_policies),0::bigint,'removed member with stale claim: device_policies denied');
select is((select count(*) from public.commands),0::bigint,'removed member with stale claim: commands denied');
select is((select count(*) from public.daily_grants),0::bigint,'removed member with stale claim: daily_grants denied');
select is((select count(*) from public.command_receipts),0::bigint,'removed member with stale claim: command_receipts denied');
select is((select count(*) from public.device_state),0::bigint,'removed member with stale claim: device_state denied');
select is((select count(*) from public.profiles),1::bigint,'removed membership does not erase own profile identity');
reset role;
select * from finish();
rollback;
