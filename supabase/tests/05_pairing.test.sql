-- Synthetic persistence tests, real client/service roles; no Auth HTTP signature claim.
begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to authenticated, service_role, anon;
set search_path=public,extensions;
select no_plan();
insert into auth.users(id) values ('50000001-0000-4000-8000-000000000001'),('50000001-0000-4000-8000-000000000002');
insert into public.profiles(user_id) select id from auth.users where id::text like '50000001%';
insert into public.households(id,timezone_name,timezone_revision,deletion_state) values
 ('50000002-0000-4000-8000-000000000001','Etc/UTC',1,'active'),
 ('50000002-0000-4000-8000-000000000002','Etc/UTC',1,'active');
insert into public.household_members values
 ('50000002-0000-4000-8000-000000000001','50000001-0000-4000-8000-000000000001','owner',true),
 ('50000002-0000-4000-8000-000000000002','50000001-0000-4000-8000-000000000002','owner',true);
create temp table cases(label text primary key, token bytea, cred bytea, source bytea, reply jsonb, result jsonb);
grant all on cases to authenticated,service_role;
insert into cases(label,token,cred,source) select x,extensions.gen_random_bytes(32),extensions.gen_random_bytes(32),extensions.gen_random_bytes(32)
 from unnest(array['good','expired','cancelled','failed','rollback','revoked-member','foreign','quota']) x;
set local role authenticated;
set local "request.jwt.claim.sub"='50000001-0000-4000-8000-000000000001';
select is(current_user::text,'authenticated','actual authenticated parent context');
update cases set reply=public.create_pairing(token) where label='good';
select is((select reply->>'result' from cases where label='good'),'CREATED','own parent creates');
reset role;
select is((select household_id from private.pairing_sessions where id=(select (reply->>'session_id')::uuid from cases where label='good')),
 '50000002-0000-4000-8000-000000000001'::uuid,'scope derived from membership');
select is((select expires_at-created_at from private.pairing_sessions limit 1),interval '5 minutes','server five minute TTL');
-- More independent sessions are seeded as privileged synthetic fixtures, not rate-limit bypass API.
insert into private.pairing_sessions(id,household_id,created_by,token_digest,expires_at)
 select gen_random_uuid(),'50000002-0000-4000-8000-000000000001','50000001-0000-4000-8000-000000000001',token,clock_timestamp()+interval '5 minutes'
 from cases where label<>'good';
update cases c set reply=jsonb_build_object('session_id',s.id) from private.pairing_sessions s where s.token_digest=c.token and c.label<>'good';
update private.pairing_sessions set expires_at=clock_timestamp() where token_digest=(select token from cases where label='expired');
set local role authenticated;
select is(public.create_pairing(null)->>'result','INVALID','missing digest denied');
select throws_ok($q$select public.redeem_pairing(null,null,null,null,null)$q$,'42501',null,'parent cannot call privileged redemption');
select is(public.finish_pairing((select (reply->>'session_id')::uuid from cases where label='cancelled'))->>'result','CANCELLED','owner cancels');
set local "request.jwt.claim.sub"='50000001-0000-4000-8000-000000000002';
select is(public.finish_pairing((select (reply->>'session_id')::uuid from cases where label='foreign'))->>'result','DENIED','foreign parent cannot cancel');
set local "request.jwt.claim.sub"='';
select is(public.create_pairing(extensions.gen_random_bytes(32))->>'result','DENIED','missing auth denied');
select is(public.finish_pairing((select (reply->>'session_id')::uuid from cases where label='good'))->>'result','DENIED','missing auth cannot finish');
reset role;
set local role service_role;
select is(current_user::text,'service_role','actual privileged gateway role for redemption only');
select throws_ok($q$select public.create_pairing(null)$q$,'42501',null,'device gateway cannot create parent challenge');
update cases set result=public.redeem_pairing((reply->>'session_id')::uuid,token,cred,source,
 '{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}') where label in ('good','expired','cancelled');
select is((select result->>'result' from cases where label='good'),'REDEEMED','valid redemption');
select is((select result->>'result' from cases where label='expired'),'DENIED','expires_at equality or earlier denied');
select is((select result->>'result' from cases where label='cancelled'),'DENIED','cancelled denied');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,token,cred,source,
 '{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='good'),'DENIED','replay cannot return identity or new secret');
reset role;
select is((select count(*) from public.devices where household_id='50000002-0000-4000-8000-000000000001'),1::bigint,'exactly one identity');
select is((select count(*) from private.device_credentials where device_id=(select (result->>'device_id')::uuid from cases where label='good')),1::bigint,'one credential');
select ok((select c.secret_digest=t.cred and c.expires_at-c.created_at=interval '90 days' and c.generation=1
 from private.device_credentials c join cases t on c.device_id=(t.result->>'device_id')::uuid where t.label='good'),'digest only, 90 days and generation one');
select ok((select not policy_configured and daily_limit_seconds is null and not manual_lock and version=0 from public.device_policies
 where device_id=(select (result->>'device_id')::uuid from cases where label='good')),'bootstrap has no invented allowance/enforcement');
set local role authenticated;
set local "request.jwt.claim.sub"='50000001-0000-4000-8000-000000000001';
select is(public.finish_pairing((select (reply->>'session_id')::uuid from cases where label='good'))->>'result','ALREADY_REDEEMED','response loss requires explicit recovery, not cancel/replay');
select is(public.finish_pairing((select (reply->>'session_id')::uuid from cases where label='good'),true)->>'result','REVOKED_FRESH_QR_REQUIRED','explicit incomplete recovery');
reset role;
select ok((select revoked_at is not null from public.devices where id=(select (result->>'device_id')::uuid from cases where label='good')),'incomplete device revoked');
select ok((select revoked_at is not null from private.device_credentials where device_id=(select (result->>'device_id')::uuid from cases where label='good')),'incomplete credential revoked');
select ok((select consumed_at is not null and cancelled_at is null from private.pairing_sessions where token_digest=(select token from cases where label='good')),'consumption retained after recovery');
-- Fault injection is test-only, no application failpoint parameter.
create function pg_temp.abort_credential() returns trigger language plpgsql as $f$ begin raise exception using errcode='P0001',message='INJECTED'; end $f$;
create trigger pairing_fault after insert on private.device_credentials for each row execute function pg_temp.abort_credential();
set local role service_role;
select throws_ok($q$select public.redeem_pairing((reply->>'session_id')::uuid,token,cred,source,
 '{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}') from cases where label='rollback'$q$,'P0001','INJECTED','failure before commit');
reset role;
drop trigger pairing_fault on private.device_credentials;
select is((select count(*) from public.devices where household_id='50000002-0000-4000-8000-000000000001'),1::bigint,'rollback leaves no partial device');
select ok((select consumed_at is null and device_id is null from private.pairing_sessions where token_digest=(select token from cases where label='rollback')),'rollback leaves challenge available');
set local role service_role;
select is((select public.redeem_pairing((reply->>'session_id')::uuid,token,cred,source,
 '{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='rollback'),'REDEEMED','retry before commit succeeds');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,extensions.gen_random_bytes(32),cred,source,'{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='failed'),'DENIED','invalid token attempt 1');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,extensions.gen_random_bytes(32),cred,source,'{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='failed'),'DENIED','invalid token attempt 2');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,extensions.gen_random_bytes(32),cred,source,'{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='failed'),'DENIED','invalid token attempt 3');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,extensions.gen_random_bytes(32),cred,source,'{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='failed'),'DENIED','invalid token attempt 4');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,extensions.gen_random_bytes(32),cred,source,'{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='failed'),'DENIED','invalid token attempt 5');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,token,cred,source,'{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='failed'),'DENIED','valid token denied after five failures');
reset role;
select is((select failed_attempts from private.pairing_sessions where token_digest=(select token from cases where label='failed')),5,'negative attempts persist and cap at five');
update public.household_members set active=false where user_id='50000001-0000-4000-8000-000000000001';
set local role service_role;
select is((select public.redeem_pairing((reply->>'session_id')::uuid,token,cred,source,'{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='revoked-member'),'DENIED','removed membership rechecked at redemption');
reset role;
update public.household_members set active=true where user_id='50000001-0000-4000-8000-000000000001';
set local role authenticated;
select is(public.create_pairing(extensions.gen_random_bytes(32))->>'result','CREATED','create quota attempt 2');
select is(public.create_pairing(extensions.gen_random_bytes(32))->>'result','CREATED','create quota attempt 3');
select is(public.create_pairing(extensions.gen_random_bytes(32))->>'result','CREATED','create quota attempt 4');
select is(public.create_pairing(extensions.gen_random_bytes(32))->>'result','CREATED','create quota attempt 5');
select is(public.create_pairing(extensions.gen_random_bytes(32))->>'result','RATE_LIMITED','create quota attempt 6');
reset role;
set local role service_role;
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 1');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 2');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 3');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 4');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 5');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 6');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 7');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 8');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 9');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'INVALID','source quota attempt 10');
select is((select public.redeem_pairing(null,null,null,source,'{}')->>'result' from cases where label='quota'),'RATE_LIMITED','source quota attempt 11');
reset role;
select ok(not has_function_privilege('anon','public.create_pairing(bytea)','EXECUTE'),'anon create denied');
select ok(not has_function_privilege('anon','public.redeem_pairing(uuid,bytea,bytea,bytea,jsonb)','EXECUTE'),'anon redemption SQL denied');
select ok(not has_function_privilege('authenticated','public.redeem_pairing(uuid,bytea,bytea,bytea,jsonb)','EXECUTE'),'parent redemption SQL denied');
select ok(not has_schema_privilege('authenticated','private','USAGE'),'private schema still inaccessible');
-- Direct SQL validation is independent of the JavaScript payload validator.
set local role service_role;
select is((select public.redeem_pairing((reply->>'session_id')::uuid,token,cred,extensions.gen_random_bytes(32),
 '{"platform":null,"os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='foreign'),'INVALID','null platform denied at SQL boundary');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,token,cred,extensions.gen_random_bytes(32),
 '{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic","household_id":"foreign"}')->>'result' from cases where label='foreign'),'INVALID','SQL foreign target field rejected');
select is((select public.redeem_pairing((reply->>'session_id')::uuid,(select token from cases where label='expired'),cred,extensions.gen_random_bytes(32),
 '{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result' from cases where label='foreign'),'DENIED','token from another challenge rejected');
select is(public.redeem_pairing(gen_random_uuid(),extensions.gen_random_bytes(32),extensions.gen_random_bytes(32),extensions.gen_random_bytes(32),
 '{"platform":"android","os_major":16,"agent_version":"synthetic","nickname":"synthetic"}')->>'result','DENIED','unknown challenge indistinguishable');
reset role;
update private.rate_limit_buckets set window_start=window_start-interval '1 day'
 where scope_hash=extensions.digest('pair-create:50000001-0000-4000-8000-000000000001','sha256');
set local role authenticated;
select is(public.create_pairing(extensions.gen_random_bytes(32))->>'result','CREATED','new create window restores bounded retry');
reset role;
select * from finish();
rollback;
