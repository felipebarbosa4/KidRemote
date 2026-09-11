-- Direct DB security fixtures, not a forged successful Auth flow. Real Auth is tested separately.
begin;
-- Before GoTrue starts, the base image has a minimal Auth stub. These fixture-only
-- columns roll back; the separate HTTP suite uses GoTrue's actual migrations.
alter table auth.users add column if not exists email_confirmed_at timestamptz;
alter table auth.users add column if not exists deleted_at timestamptz;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to authenticated;
set search_path=public,extensions;
select no_plan();
insert into auth.users(id) values ('70000001-0000-4000-8000-000000000001');
set local role authenticated;
set local "request.jwt.claim.sub"='';
select throws_ok($q$select public.bootstrap_household('Etc/UTC')$q$,'42501','AUTH_REQUIRED','missing SQL subject denied');
set local "request.jwt.claim.sub"='70000001-0000-4000-8000-000000000001';
select throws_ok($q$select public.bootstrap_household('Etc/UTC')$q$,'42501','CONFIRMED_ACCOUNT_REQUIRED','unconfirmed server record denied despite caller subject');
reset role;
-- Confirmed DB fixture only; never used to claim email verification evidence.
update auth.users set email_confirmed_at=clock_timestamp() where id='70000001-0000-4000-8000-000000000001';
set local role authenticated;
create temporary table pg_timezone_names(name text);
insert into pg_timezone_names values ('Synthetic/Invalid');
select throws_ok($q$select public.bootstrap_household('Synthetic/Invalid')$q$,'22023','INVALID_TIMEZONE','temporary relation cannot shadow trusted timezone catalog');
select ok((public.bootstrap_household('Etc/UTC')->>'created')::boolean,'confirmed synthetic role can bootstrap');
select ok(not (public.bootstrap_household('Etc/UTC')->>'created')::boolean,'retry reuses own membership');
select is((select count(*) from public.household_members),1::bigint,'actual RLS own single membership');
reset role;
select is((select count(*) from public.profiles where user_id='70000001-0000-4000-8000-000000000001'),1::bigint,'single profile persisted');
select ok(not has_function_privilege('anon','public.bootstrap_household(text)','EXECUTE'),'anonymous SQL execute denied');
select ok(not has_function_privilege('service_role','public.bootstrap_household(text)','EXECUTE'),'unscoped service execute denied');
select * from finish();
rollback;
