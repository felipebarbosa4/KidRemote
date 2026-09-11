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

delete from public.command_receipts; delete from public.daily_grants; delete from public.commands;
update public.device_policies set version=0;
update public.device_state set used_ms=3000000;
select ok((select prosecdef and proconfig=array['search_path=""'] and pg_get_userbyid(proowner)='supabase_admin'
 from pg_proc where oid='public.accept_control(uuid,uuid,text,jsonb,bigint)'::regprocedure),
 'reviewed definer ownership and fixed empty search path');
select ok(not has_function_privilege('anon','public.accept_control(uuid,uuid,text,jsonb,bigint)','EXECUTE'),'anon has no control execute');
select ok(not has_function_privilege('service_role','public.accept_control(uuid,uuid,text,jsonb,bigint)','EXECUTE'),'generic device service role has no parent control execute');
set local role authenticated;
set local "request.jwt.claim.sub"='00000001-0000-4000-8000-000000000001';
select is((public.accept_control('00000020-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','LOCK','{}',0)->>'version')::bigint,1::bigint,'LOCK increments version');
select ok((select manual_lock from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),'LOCK persists');
select is((public.accept_control('00000020-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)->>'version')::bigint,2::bigint,'ADD_TIME increments version');
select ok((select manual_lock from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),'ADD_TIME does not unlock');
select is((select sum(seconds) from public.daily_grants where device_id='00000003-0000-4000-8000-000000000001'),600::bigint,'one grant');
select is((public.accept_control('00000020-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)->>'version')::bigint,2::bigint,'identical retry returns original version');
select is((select count(*) from public.commands),2::bigint,'retry adds no command');
select is((select sum(seconds) from public.daily_grants),600::bigint,'retry adds no grant');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',1800,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)$q$,'40001','OPERATION_CONFLICT','changed payload reuse conflicts');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','LOCK','{}',1)$q$,'40001','OPERATION_CONFLICT','changed expected version reuse conflicts');
select is((public.accept_control('00000020-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','LOCK','{}',0)->>'version')::bigint,1::bigint,'old identical retry bypasses new version precondition safely');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000003','00000003-0000-4000-8000-000000000001','UNLOCK','{}',0)$q$,'40001','VERSION_CONFLICT','stale desired state rejected');
select is((public.accept_control('00000020-0000-4000-8000-000000000003','00000003-0000-4000-8000-000000000001','UNLOCK','{}',2)->>'version')::bigint,3::bigint,'UNLOCK valid version');
select ok(not (select manual_lock from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),'manual flag cleared');
select is((public.accept_control('00000020-0000-4000-8000-000000000004','00000003-0000-4000-8000-000000000001','SET_DAILY_LIMIT','{"daily_limit_seconds":0}',3)->>'version')::bigint,4::bigint,'explicit zero limit allowed');
select is((select used_ms from public.device_state where device_id='00000003-0000-4000-8000-000000000001'),3000000::bigint,'control never rewrites local usage');
select is((select sum(seconds) from public.daily_grants),600::bigint,'SET limit retains bonus');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000005','00000003-0000-4000-8000-000000000001','SET_DAILY_LIMIT','{"daily_limit_seconds":86400}',4)$q$,'22023','ALLOWANCE_CAP','SET limit includes current bonus cap');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000006','00000003-0000-4000-8000-000000000001','ADD_TIME','{"seconds":600,"period_key":"0:1900-01-01"}',null)$q$,'40001','PERIOD_CONFLICT','old day cannot receive a new grant');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000030','00000003-0000-4000-8000-000000000001','LOCK','{"extra":1}',4)$q$,'22023','INVALID_OPERATION','invalid payload 1 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000031','00000003-0000-4000-8000-000000000001','LOCK','{}',null)$q$,'22023','INVALID_OPERATION','invalid payload 2 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000032','00000003-0000-4000-8000-000000000001','SET_DAILY_LIMIT','{"daily_limit_seconds":1.5}',4)$q$,'22023','INVALID_OPERATION','invalid payload 3 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000033','00000003-0000-4000-8000-000000000001','SET_DAILY_LIMIT','{"daily_limit_seconds":86401}',4)$q$,'22023','INVALID_OPERATION','invalid payload 4 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000034','00000003-0000-4000-8000-000000000001','SET_DAILY_LIMIT','{"daily_limit_seconds":-1}',4)$q$,'22023','INVALID_OPERATION','invalid payload 5 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000035','00000003-0000-4000-8000-000000000001','SET_DAILY_LIMIT','{"daily_limit_seconds":"600"}',4)$q$,'22023','INVALID_OPERATION','invalid payload 6 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000036','00000003-0000-4000-8000-000000000001','SET_DAILY_LIMIT','{"daily_limit_seconds":null}',4)$q$,'22023','INVALID_OPERATION','invalid payload 7 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000037','00000003-0000-4000-8000-000000000001','ADD_TIME','{"seconds":601,"period_key":"x"}',null)$q$,'22023','INVALID_OPERATION','invalid payload 8 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000038','00000003-0000-4000-8000-000000000001','ADD_TIME','{"seconds":600.5,"period_key":"x"}',null)$q$,'22023','INVALID_OPERATION','invalid payload 9 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000039','00000003-0000-4000-8000-000000000001','ADD_TIME','{"seconds":600,"period_key":null}',null)$q$,'22023','INVALID_OPERATION','invalid payload 10 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000040','00000003-0000-4000-8000-000000000001','ADD_TIME','{"seconds":600,"period_key":"x","actor_user_id":"x"}',null)$q$,'22023','INVALID_OPERATION','invalid payload 11 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000041','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),4)$q$,'22023','INVALID_OPERATION','invalid payload 12 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000042','00000003-0000-4000-8000-000000000001','OTHER','{}',4)$q$,'22023','INVALID_OPERATION','invalid payload 13 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000043','00000003-0000-4000-8000-000000000001','UNLOCK','null'::jsonb,4)$q$,'22023','INVALID_OPERATION','invalid payload 14 denied');
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000007','00000003-0000-4000-8000-000000000002','LOCK','{}',0)$q$,'42501','TARGET_DENIED','foreign target denied by transaction');
set local "request.jwt.claim.sub"='00000001-0000-4000-8000-000000000002';
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000002','LOCK','{}',0)$q$,'40001','OPERATION_CONFLICT','other actor/target operation ID reuse conflicts generically');
set local "request.jwt.claim.sub"='';
set local "request.jwt.claims"='{}';
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000008','00000003-0000-4000-8000-000000000001','LOCK','{}',0)$q$,'42501','AUTH_REQUIRED','null auth denied by transaction');
reset role;
update public.household_members set active=false where user_id='00000001-0000-4000-8000-000000000001';
set local role authenticated;
set local "request.jwt.claim.sub"='00000001-0000-4000-8000-000000000001';
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','LOCK','{}',0)$q$,'42501','TARGET_DENIED','retry after removal of authorization denied');
reset role;
update public.household_members set active=true where user_id='00000001-0000-4000-8000-000000000001';
update public.devices set revoked_at=now() where id='00000003-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','LOCK','{}',0)$q$,'42501','TARGET_DENIED','retry after device revocation denied');
reset role;
update public.devices set revoked_at=null where id='00000003-0000-4000-8000-000000000001';
update public.households set deletion_state='pending' where id='00000002-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000009','00000003-0000-4000-8000-000000000001','LOCK','{}',4)$q$,'42501','TARGET_DENIED','deleting household denied');
reset role;
update public.households set deletion_state='active' where id='00000002-0000-4000-8000-000000000001';
-- Idempotent retry after its original day must not credit the current day again.
update public.households set timezone_revision=2 where id='00000002-0000-4000-8000-000000000001';
set local role authenticated;
select is((public.accept_control('00000020-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)->>'version')::bigint,2::bigint,'identical retry after day revision retains original accepted operation');
reset role;
update public.households set timezone_revision=1 where id='00000002-0000-4000-8000-000000000001';
select is((select count(*) from private.push_outbox),4::bigint,'one outbox per accepted operation only');
select is((select count(*) from private.audit_events),4::bigint,'one minimal audit per accepted operation only');
select ok(not exists(select 1 from private.push_outbox o join public.commands c on o.id=c.id where o.newest_version<>c.version),'outbox versions match commands');

create function pg_temp.inject_failure() returns trigger language plpgsql as
 $$begin raise exception using errcode='P0001',message='INJECTED_FAILURE'; end$$;
create temp table baseline(snapshot jsonb);
truncate baseline; insert into baseline select jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a));
create trigger injected after update on public.device_policies for each row execute function pg_temp.inject_failure();
set local role authenticated;
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000090','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)$q$,'P0001','INJECTED_FAILURE','failure after public.device_policies is propagated');
reset role;
select is((jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a)))::text,(select snapshot::text from baseline),'public.device_policies: entire business state rolled back');
drop trigger injected on public.device_policies;
truncate baseline; insert into baseline select jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a));
create trigger injected after insert on public.commands for each row execute function pg_temp.inject_failure();
set local role authenticated;
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000090','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)$q$,'P0001','INJECTED_FAILURE','failure after public.commands is propagated');
reset role;
select is((jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a)))::text,(select snapshot::text from baseline),'public.commands: entire business state rolled back');
drop trigger injected on public.commands;
truncate baseline; insert into baseline select jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a));
create trigger injected after insert on public.daily_grants for each row execute function pg_temp.inject_failure();
set local role authenticated;
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000090','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)$q$,'P0001','INJECTED_FAILURE','failure after public.daily_grants is propagated');
reset role;
select is((jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a)))::text,(select snapshot::text from baseline),'public.daily_grants: entire business state rolled back');
drop trigger injected on public.daily_grants;
truncate baseline; insert into baseline select jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a));
create trigger injected after insert on private.audit_events for each row execute function pg_temp.inject_failure();
set local role authenticated;
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000090','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)$q$,'P0001','INJECTED_FAILURE','failure after private.audit_events is propagated');
reset role;
select is((jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a)))::text,(select snapshot::text from baseline),'private.audit_events: entire business state rolled back');
drop trigger injected on private.audit_events;
truncate baseline; insert into baseline select jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a));
create trigger injected after insert on private.push_outbox for each row execute function pg_temp.inject_failure();
set local role authenticated;
select throws_ok($q$select public.accept_control('00000020-0000-4000-8000-000000000090','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)$q$,'P0001','INJECTED_FAILURE','failure after private.push_outbox is propagated');
reset role;
select is((jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a)))::text,(select snapshot::text from baseline),'private.push_outbox: entire business state rolled back');
drop trigger injected on private.push_outbox;
-- Caller abort remains atomic even after a successful function return.
truncate baseline; insert into baseline select jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a));
savepoint caller_abort;
set local role authenticated;
select public.accept_control('00000020-0000-4000-8000-000000000091','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null);
reset role;
rollback to caller_abort;
select is((jsonb_build_object(
 'policy',(select jsonb_agg(to_jsonb(p) order by device_id) from public.device_policies p),
 'commands',(select jsonb_agg(to_jsonb(c) order by id) from public.commands c),
 'grants',(select jsonb_agg(to_jsonb(g) order by command_id) from public.daily_grants g),
 'outbox',(select jsonb_agg(to_jsonb(o) order by id) from private.push_outbox o),
 'audit',(select jsonb_agg(to_jsonb(a) order by id) from private.audit_events a)))::text,(select snapshot::text from baseline),'caller rollback removes successful operation entirely');
select * from finish();
rollback;
