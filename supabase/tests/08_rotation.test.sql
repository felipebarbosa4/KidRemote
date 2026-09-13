begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
insert into public.households(id,timezone_name,timezone_revision,deletion_state)
values('80000000-0000-4000-8000-000000000001','Etc/UTC',1,'active');
insert into public.devices(id,household_id,nickname,platform,os_major,agent_version,policy_epoch)
select ('80000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'80000000-0000-4000-8000-000000000001','synthetic','android',16,'test',gen_random_uuid() from generate_series(10,15)i;
create temp table rot(label int,old bytea,new bytea,op uuid,result jsonb);
insert into rot select i,gen_random_bytes(32),gen_random_bytes(32),gen_random_uuid(),null from generate_series(10,15)i;
insert into private.device_credentials(credential_id,device_id,secret_digest,created_at,expires_at,generation)
select gen_random_uuid(),('80000000-0000-4000-8000-'||lpad(label::text,12,'0'))::uuid,old,clock_timestamp()-interval '31 days',clock_timestamp()+interval '59 days',1 from rot;
select ok(not has_table_privilege('authenticated','private.credential_rotations','SELECT'),'rotation private');
select ok(not has_function_privilege('authenticated','public.rotate_device_credential(bytea,uuid,text,bytea)','EXECUTE'),'no parent direct rotation');
select ok(not has_function_privilege('anon','public.rotate_device_credential(bytea,uuid,text,bytea)','EXECUTE'),'no anonymous direct rotation');
select is(public.rotate_device_credential(null,gen_random_uuid(),'BEGIN',null)->>'result','INVALID','null denied');
update rot set result=public.rotate_device_credential(old,op,'BEGIN',new) where label=10;
select is((select result->>'result' from rot where label=10),'PENDING','begin');
select is((select count(*) from private.device_credentials where device_id='80000000-0000-4000-8000-000000000010'),2::bigint,'one new generation');
select is(public.rotate_device_credential(old,op,'BEGIN',new),result,'identical retry stable status/deadline') from rot where label=10;
select is(public.rotate_device_credential(old,gen_random_uuid(),'BEGIN',new)->>'result','CONFLICT','other operation denied') from rot where label=10;
select is(public.rotate_device_credential(old,op,'BEGIN',gen_random_bytes(32))->>'result','CONFLICT','changed digest denied') from rot where label=10;
select is(public.rotate_device_credential(old,op,'CONFIRM')->>'result','NEW_POSSESSION_REQUIRED','old cannot confirm new') from rot where label=10;
select is(public.rotate_device_credential(new,op,'CONFIRM')->>'result','CONFIRMED','possession confirmation') from rot where label=10;
select is(public.rotate_device_credential(old,op,'STATUS')->>'result','REVOKED','old retired') from rot where label=10;
select is(public.rotate_device_credential(new,op,'CONFIRM')->>'result','CONFIRMED','lost confirmation idempotent') from rot where label=10;
select is(public.rotate_device_credential(new,gen_random_uuid(),'BEGIN',gen_random_bytes(32))->>'result','NOT_DUE','cannot rotate repeatedly') from rot where label=10;
select is(public.rotate_device_credential(old,(select op from rot where label=10),'STATUS')->>'result','NOT_FOUND','sibling operation no access') from rot where label=11;
-- Trigger belongs only to this rolled-back test; no production fault switch.
create function pg_temp.break_rotation() returns trigger language plpgsql as $$begin raise exception using errcode='P0001',message='SYNTHETIC_FAILURE';end$$;
create trigger fail_rotation before insert on private.credential_rotations for each row execute function pg_temp.break_rotation();
select throws_ok(format('select public.rotate_device_credential(%L::bytea,%L::uuid,''BEGIN'',%L::bytea)',old,op,new),'P0001','SYNTHETIC_FAILURE','before commit failure') from rot where label=11;
drop trigger fail_rotation on private.credential_rotations;
select is((select count(*) from private.device_credentials where device_id='80000000-0000-4000-8000-000000000011'),1::bigint,'failure no partial generation');
select ok((select expires_at>clock_timestamp()+interval '58 days' from private.device_credentials where secret_digest=(select old from rot where label=11)),'failure no shortened expiry');
update rot set result=public.rotate_device_credential(old,op,'BEGIN',new) where label in(11,12,13);
select ok(bool_and(overlap_until<=created_at+interval '5 minutes'),'bounded overlap') from private.credential_rotations;
select ok(bool_and(expires_at=created_at+interval '90 days'),'new generation 90 days') from private.device_credentials where generation=2;
-- Expiry fixtures move stored dates, never server/host clocks.
update private.device_credentials set expires_at=clock_timestamp() where secret_digest=(select old from rot where label=11);
select is(public.rotate_device_credential(old,op,'STATUS')->>'result','UNAUTHORIZED','overlap expired old denied') from rot where label=11;
select is(public.rotate_device_credential(new,op,'CONFIRM')->>'result','CONFIRMED','durable new confirms without old revival') from rot where label=11;
update public.devices set revoked_at=clock_timestamp() where id='80000000-0000-4000-8000-000000000012';
select is(public.rotate_device_credential(new,op,'CONFIRM')->>'result','REVOKED','revocation during pending') from rot where label=12;
update private.device_credentials set created_at=clock_timestamp()-interval '91 days',expires_at=clock_timestamp() where secret_digest=(select new from rot where label=13);
select is(public.rotate_device_credential(new,op,'CONFIRM')->>'result','UNAUTHORIZED','expired new cannot confirm') from rot where label=13;
update private.device_credentials set created_at=clock_timestamp(),expires_at=clock_timestamp()+interval '90 days' where secret_digest=(select old from rot where label=14);
select is(public.rotate_device_credential(old,op,'BEGIN',new)->>'result','NOT_DUE','before day30 refused') from rot where label=14;
select * from finish();
rollback;
