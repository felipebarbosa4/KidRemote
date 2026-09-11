-- Real PostgreSQL roles + Supabase auth.uid(); no Auth HTTP/JWT signature claim.
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


-- Deliberately committed synthetic fixtures for real independent DB sessions.
-- The task runner removes this entire exclusive DB after the suite.
delete from public.command_receipts; delete from public.daily_grants; delete from public.commands;
update public.device_policies set version=0;
insert into public.devices(id,household_id,nickname,platform,os_major,agent_version,policy_epoch)
 values ('00000003-0000-4000-8000-000000000003','00000002-0000-4000-8000-000000000001','synthetic-sibling','android',16,'synthetic','00000005-0000-4000-8000-000000000003');
insert into public.device_policies values ('00000003-0000-4000-8000-000000000003','00000002-0000-4000-8000-000000000001',0,true,3600,false,'00000001-0000-4000-8000-000000000001',now());
create extension if not exists dblink with schema extensions;
select dblink_connect('a','dbname=postgres user=supabase_admin host=/var/run/postgresql application_name=kr004_worker_a');
select dblink_connect('b','dbname=postgres user=supabase_admin host=/var/run/postgresql application_name=kr004_worker_b');
select dblink_exec('a','set role authenticated');
select dblink_exec('b','set role authenticated');
select dblink_exec('a',$remote$set "request.jwt.claim.sub"='00000001-0000-4000-8000-000000000001'$remote$);
select dblink_exec('b',$remote$set "request.jwt.claim.sub"='00000001-0000-4000-8000-000000000001'$remote$);
select dblink_exec('a',$remote$set statement_timeout='10s'$remote$);
select dblink_exec('b',$remote$set statement_timeout='10s'$remote$);
select is((select result from dblink('a','select current_user::text') as t(result text)),'authenticated','worker A actual client role');
select is((select result from dblink('b','select current_user::text') as t(result text)),'authenticated','worker B actual client role');
create temp table results(label text, result jsonb);
create function pg_temp.worker_waiting() returns boolean language plpgsql as $wait$
begin
 for i in 1..200 loop
  perform pg_stat_clear_snapshot();
  if exists(select 1 from pg_stat_activity where application_name='kr004_worker_b' and wait_event_type='Lock') then return true; end if;
  perform pg_sleep(0.01);
 end loop;
 return false;
end $wait$;

select dblink_exec('a','begin');
insert into results select 'identical retry-a',result::jsonb from dblink('a',$remote$select public.accept_control('00000021-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)::text$remote$) as t(result text);
select is(dblink_send_query('b',$remote$select public.accept_control('00000021-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)::text$remote$),1,'identical retry: worker B dispatched asynchronously');
select ok(pg_temp.worker_waiting(),'identical retry: overlapping session observed waiting on lock');
select dblink_exec('a','commit');
insert into results select 'identical retry-b',result::jsonb from dblink_get_result('b') as t(result text);
select is((select count(*) from dblink_get_result('b') as t(result text)),0::bigint,'identical retry: remote result fully drained');
select is((select result::text from results where label='identical retry-a'),(select result::text from results where label='identical retry-b'),'concurrent identical retry returns exact original response');
select is((select count(*) from public.commands),1::bigint,'duplicate concurrent operation has one command');
select is((select sum(seconds) from public.daily_grants),600::bigint,'duplicate concurrent operation has one grant');
select is((select count(*) from private.push_outbox),1::bigint,'duplicate concurrent operation has one outbox row');

select dblink_exec('a','begin');
insert into results select 'distinct additions-a',result::jsonb from dblink('a',$remote$select public.accept_control('00000021-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)::text$remote$) as t(result text);
select is(dblink_send_query('b',$remote$select public.accept_control('00000021-0000-4000-8000-000000000003','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)::text$remote$),1,'distinct additions: worker B dispatched asynchronously');
select ok(pg_temp.worker_waiting(),'distinct additions: overlapping session observed waiting on lock');
select dblink_exec('a','commit');
insert into results select 'distinct additions-b',result::jsonb from dblink_get_result('b') as t(result text);
select is((select count(*) from dblink_get_result('b') as t(result text)),0::bigint,'distinct additions: remote result fully drained');
select is((select version from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),3::bigint,'distinct concurrent additions serialize versions');
select is((select sum(seconds) from public.daily_grants),1800::bigint,'distinct additions preserve exact total');
select is((select count(distinct version) from public.commands),3::bigint,'versions remain unique');
update public.device_policies set daily_limit_seconds=84000 where device_id='00000003-0000-4000-8000-000000000001';

select dblink_exec('a','begin');
insert into results select 'allowance cap-a',result::jsonb from dblink('a',$remote$select public.accept_control('00000021-0000-4000-8000-000000000004','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)::text$remote$) as t(result text);
select is(dblink_send_query('b',$remote$select public.accept_control('00000021-0000-4000-8000-000000000005','00000003-0000-4000-8000-000000000001','ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp() at time zone 'Etc/UTC','YYYY-MM-DD')),null)::text$remote$),1,'allowance cap: worker B dispatched asynchronously');
select ok(pg_temp.worker_waiting(),'allowance cap: overlapping session observed waiting on lock');
select dblink_exec('a','commit');
select throws_ok($q$select * from dblink_get_result('b') as t(result text)$q$,'22023',null,'allowance cap: losing operation rejected');
select is((select count(*) from dblink_get_result('b') as t(result text)),0::bigint,'allowance cap: remote result fully drained');
select is((select daily_limit_seconds+(select sum(seconds) from public.daily_grants) from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),86400::bigint,'concurrent grants never exceed daily cap');
select is((select version from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),4::bigint,'rejected cap operation increments nothing');

select dblink_exec('a','begin');
insert into results select 'stale conflicting edits-a',result::jsonb from dblink('a',$remote$select public.accept_control('00000021-0000-4000-8000-000000000006','00000003-0000-4000-8000-000000000001','LOCK','{}'::jsonb,4)::text$remote$) as t(result text);
select is(dblink_send_query('b',$remote$select public.accept_control('00000021-0000-4000-8000-000000000007','00000003-0000-4000-8000-000000000001','UNLOCK','{}'::jsonb,4)::text$remote$),1,'stale conflicting edits: worker B dispatched asynchronously');
select ok(pg_temp.worker_waiting(),'stale conflicting edits: overlapping session observed waiting on lock');
select dblink_exec('a','commit');
select throws_ok($q$select * from dblink_get_result('b') as t(result text)$q$,'40001',null,'stale conflicting edits: losing operation rejected');
select is((select count(*) from dblink_get_result('b') as t(result text)),0::bigint,'stale conflicting edits: remote result fully drained');
select ok((select manual_lock and version=5 from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),'stale concurrent UNLOCK cannot overwrite accepted LOCK');

select dblink_exec('a','begin');
insert into results select 'cross-device operation ID reuse-a',result::jsonb from dblink('a',$remote$select public.accept_control('00000021-0000-4000-8000-000000000008','00000003-0000-4000-8000-000000000001','LOCK','{}'::jsonb,5)::text$remote$) as t(result text);
select is(dblink_send_query('b',$remote$select public.accept_control('00000021-0000-4000-8000-000000000008','00000003-0000-4000-8000-000000000003','LOCK','{}'::jsonb,0)::text$remote$),1,'cross-device operation ID reuse: worker B dispatched asynchronously');
select ok(pg_temp.worker_waiting(),'cross-device operation ID reuse: overlapping session observed waiting on lock');
select dblink_exec('a','commit');
select throws_ok($q$select * from dblink_get_result('b') as t(result text)$q$,'40001',null,'cross-device operation ID reuse: losing operation rejected');
select is((select count(*) from dblink_get_result('b') as t(result text)),0::bigint,'cross-device operation ID reuse: remote result fully drained');
select is((select version from public.device_policies where device_id='00000003-0000-4000-8000-000000000003'),0::bigint,'global ID conflict does not change sibling');
select is((select count(*) from public.commands),6::bigint,'only six accepted unique operations');
select is((select count(*) from private.push_outbox),6::bigint,'one outbox per committed command');
select is((select count(*) from private.audit_events),6::bigint,'one audit per committed command');

select dblink_exec('a','reset role');
select dblink_exec('a','begin');
select dblink_exec('a',$remote$delete from public.household_members where user_id='00000001-0000-4000-8000-000000000001'$remote$);
select is(dblink_send_query('b',$remote$select public.accept_control('00000021-0000-4000-8000-000000000009','00000003-0000-4000-8000-000000000001','UNLOCK','{}'::jsonb,6)::text$remote$),1,'membership removed: control dispatched');
select ok(pg_temp.worker_waiting(),'membership removed: control waits for record mutation');
select dblink_exec('a','commit');
select throws_ok($q$select * from dblink_get_result('b') as t(result text)$q$,'42501',null,'membership removed: authorization rechecked after lock wait');
select is((select count(*) from dblink_get_result('b') as t(result text)),0::bigint,'membership removed: remote result drained');
insert into public.household_members values ('00000002-0000-4000-8000-000000000001','00000001-0000-4000-8000-000000000001','owner',true);
select is((select version from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),6::bigint,'membership removed: denied operation changes nothing');

select dblink_exec('a','reset role');
select dblink_exec('a','begin');
select dblink_exec('a',$remote$update public.devices set revoked_at=now() where id='00000003-0000-4000-8000-000000000001'$remote$);
select is(dblink_send_query('b',$remote$select public.accept_control('00000021-0000-4000-8000-000000000009','00000003-0000-4000-8000-000000000001','UNLOCK','{}'::jsonb,6)::text$remote$),1,'device revoked: control dispatched');
select ok(pg_temp.worker_waiting(),'device revoked: control waits for record mutation');
select dblink_exec('a','commit');
select throws_ok($q$select * from dblink_get_result('b') as t(result text)$q$,'42501',null,'device revoked: authorization rechecked after lock wait');
select is((select count(*) from dblink_get_result('b') as t(result text)),0::bigint,'device revoked: remote result drained');
update public.devices set revoked_at=null where id='00000003-0000-4000-8000-000000000001';
select is((select version from public.device_policies where device_id='00000003-0000-4000-8000-000000000001'),6::bigint,'device revoked: denied operation changes nothing');
select dblink_disconnect('a'); select dblink_disconnect('b');
select * from finish();
