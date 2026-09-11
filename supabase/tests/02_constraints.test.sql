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

select throws_ok($q$update public.device_policies set household_id='00000002-0000-4000-8000-000000000002' where device_id='00000003-0000-4000-8000-000000000001'$q$,'23503',null,'foreign policy household');
select throws_ok($q$update public.commands set household_id='00000002-0000-4000-8000-000000000002' where id='00000004-0000-4000-8000-000000000001'$q$,'23503',null,'foreign command household');
select throws_ok($q$update public.daily_grants set household_id='00000002-0000-4000-8000-000000000002' where command_id='00000004-0000-4000-8000-000000000001'$q$,'23503',null,'foreign grant household');
select throws_ok($q$update public.command_receipts set device_id='00000003-0000-4000-8000-000000000002' where command_id='00000004-0000-4000-8000-000000000001'$q$,'23503',null,'foreign receipt device');
select throws_ok($q$update public.device_state set household_id='00000002-0000-4000-8000-000000000002' where device_id='00000003-0000-4000-8000-000000000001'$q$,'23503',null,'foreign state household');
select throws_ok($q$update public.device_state set policy_epoch='00000005-0000-4000-8000-000000000002' where device_id='00000003-0000-4000-8000-000000000001'$q$,'23503',null,'wrong state epoch');
select throws_ok($q$update public.daily_grants set period_key='1:2026-09-12' where command_id='00000004-0000-4000-8000-000000000001'$q$,'23503',null,'wrong grant day');
select throws_ok($q$update public.daily_grants set seconds=1800 where command_id='00000004-0000-4000-8000-000000000001'$q$,'23503',null,'wrong grant amount');
select throws_ok($q$update public.daily_grants set seconds=1 where command_id='00000004-0000-4000-8000-000000000001'$q$,'23514',null,'invalid grant amount');
select throws_ok($q$insert into public.profiles(user_id) values ('00000001-0000-4000-8000-000000000003')$q$,'23503',null,'profile missing Auth identity');
select throws_ok($q$insert into public.commands(id,device_id,household_id,actor_user_id,version,kind,payload) values ('00000004-0000-4000-8000-000000000003','00000003-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001','00000001-0000-4000-8000-000000000001',1,'LOCK','{}')$q$,'23505',null,'duplicate device version');
select throws_ok($q$insert into public.household_members values ('00000002-0000-4000-8000-000000000002','00000001-0000-4000-8000-000000000001','owner',true)$q$,'23505',null,'one household per owner');
select throws_ok($q$insert into public.household_members values ('00000002-0000-4000-8000-000000000001','00000001-0000-4000-8000-000000000002','owner',true)$q$,'23505',null,'one owner per household');
select throws_ok($q$insert into public.commands(id,device_id,household_id,actor_user_id,version,kind,payload) values ('00000004-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001','00000001-0000-4000-8000-000000000001',3,'LOCK','{}')$q$,'23505',null,'duplicate operation');
select throws_ok($q$update public.commands set kind='OTHER' where id='00000004-0000-4000-8000-000000000001'$q$,'23514',null,'unknown operation');
select throws_ok($q$update public.commands set version=0 where id='00000004-0000-4000-8000-000000000001'$q$,'23514',null,'command zero version');
select throws_ok($q$update public.commands set payload='{"seconds":-600}' where id='00000004-0000-4000-8000-000000000001'$q$,'23514',null,'command invalid seconds');
select throws_ok($q$update public.commands set payload='{}' where id='00000004-0000-4000-8000-000000000001'$q$,'23514',null,'command missing seconds');
select throws_ok($q$update public.device_policies set daily_limit_seconds=null$q$,'23514',null,'configured limit NULL');
select throws_ok($q$update public.device_policies set policy_configured=false$q$,'23514',null,'unconfigured limit not NULL');
select throws_ok($q$update public.device_policies set daily_limit_seconds=-1$q$,'23514',null,'negative limit');
select throws_ok($q$update public.device_policies set daily_limit_seconds=86401$q$,'23514',null,'limit above cap');
select throws_ok($q$update public.device_policies set version=-1$q$,'23514',null,'negative policy version');
select throws_ok($q$update public.device_state set used_ms=-1$q$,'23514',null,'negative state consumption');
select throws_ok($q$update public.device_state set report_sequence=-1$q$,'23514',null,'negative state report sequence');
select throws_ok($q$update public.device_state set applied_version=-1$q$,'23514',null,'negative state version');
select throws_ok($q$update public.device_state set remaining_ms=86400001$q$,'23514',null,'remaining above cap');
select throws_ok($q$update public.device_state set bonus_seconds=86401$q$,'23514',null,'bonus above cap');
select throws_ok($q$update public.command_receipts set snapshot_version=-1$q$,'23514',null,'negative receipt version');
select throws_ok($q$update public.households set timezone_revision=0$q$,'23514',null,'zero timezone revision');
select throws_ok($q$update public.household_members set role='admin'$q$,'23514',null,'invalid member role');
select lives_ok($q$update public.device_policies set daily_limit_seconds=0$q$,'explicit zero limit valid');
select lives_ok($q$update public.device_policies set daily_limit_seconds=86400$q$,'explicit maximum limit valid');
select lives_ok($q$update public.device_policies set policy_configured=false,daily_limit_seconds=null$q$,'unconfigured NULL limit valid');
insert into private.device_credentials values ('00000006-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001',decode(repeat('01',32),'hex'),now(),now()+interval '90 days',null,1);
select throws_ok($q$update private.device_credentials set secret_digest=decode('01','hex')$q$,'23514',null,'digest must have 32 bytes');
select throws_ok($q$update private.device_credentials set expires_at=created_at$q$,'23514',null,'credential lifetime positive');
select throws_ok($q$update private.device_credentials set generation=0$q$,'23514',null,'credential generation positive');
insert into private.push_registrations values ('00000007-0000-4000-8000-000000000001','00000003-0000-4000-8000-000000000001','fcm','fid','synthetic-address',now(),null);
select throws_ok($q$insert into private.push_registrations values ('00000007-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000002','fcm','fid','synthetic-address',now(),null)$q$,'23505',null,'active push address cannot belong to two devices');
select lives_ok($q$insert into private.push_registrations values ('00000007-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000002','fcm','fid','synthetic-address',now(),now())$q$,'invalidated push address does not occupy active key');
insert into private.pairing_sessions values ('00000008-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001','00000001-0000-4000-8000-000000000001',decode(repeat('02',32),'hex'),now()+interval '5 minutes',null,null,'00000003-0000-4000-8000-000000000001');
select throws_ok($q$update private.pairing_sessions set device_id='00000003-0000-4000-8000-000000000002'$q$,'23503',null,'pairing cannot bind foreign device');
select throws_ok($q$update private.pairing_sessions set consumed_at=now(),cancelled_at=now()$q$,'23514',null,'pairing cannot be consumed and cancelled');
select throws_ok($q$insert into private.audit_events values ('00000009-0000-4000-8000-000000000001','00000002-0000-4000-8000-000000000001','parent','00000001-0000-4000-8000-000000000001','synthetic','denied','00000003-0000-4000-8000-000000000002',now())$q$,'23503',null,'audit cannot associate foreign device');
select throws_ok($q$insert into private.rate_limit_buckets values (decode(repeat('03',32),'hex'),now(),-1,now()+interval '1 minute')$q$,'23514',null,'negative rate counter denied');
select throws_ok($q$insert into private.push_outbox values ('00000009-0000-4000-8000-000000000002','00000003-0000-4000-8000-000000000001',1,now(),-1,null,'pending')$q$,'23514',null,'negative outbox attempts denied');
-- Every child-side FK has an indexed leading equality column. For composite
-- device keys, the unique device-id PK is already a selective access path;
-- duplicating that index merely to repeat household_id would add no lookup benefit.
select ok(not exists (
 select 1 from pg_constraint c join pg_namespace n on n.oid=c.connamespace
 where c.contype='f' and n.nspname in ('public','private')
 and not exists (select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid
   and i.indpred is null and i.indkey[0] = c.conkey[1])
), 'all tenant/FK lookups have an indexed leading equality column');
select * from finish();
rollback;
