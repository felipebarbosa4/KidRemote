-- KR-004 AC-1–4. Apply as migration owner to a fresh Supabase database.
-- No client mutations, gateway or business RPCs in this slice.
begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
revoke create on schema public from public, anon, authenticated;
grant usage on schema public to authenticated;
alter default privileges in schema public revoke all on tables from public, anon, authenticated;
alter default privileges in schema private revoke all on tables from public, anon, authenticated;
-- PostgreSQL's global PUBLIC EXECUTE default cannot be subtracted per schema.
-- Scope is this migration owner, not other owners; future migrations must also
-- explicitly revoke EXECUTE on any new private/definer function.
alter default privileges revoke execute on functions from public, anon, authenticated;

create table public.profiles (
  user_id uuid primary key references auth.users(id),
  display_name text,
  created_at timestamptz not null default now()
);
create table public.households (
  id uuid primary key,
  timezone_name text not null check (length(timezone_name) > 0),
  timezone_revision bigint not null check (timezone_revision > 0),
  created_at timestamptz not null default now(),
  deletion_state text not null check (length(deletion_state) > 0)
);
create table public.household_members (
  household_id uuid not null references public.households(id),
  user_id uuid not null references public.profiles(user_id),
  role text not null check (role = 'owner'),
  active boolean not null,
  primary key (household_id, user_id),
  -- OD-12: one owner and one household per parent; invitations are not implemented.
  unique (household_id),
  unique (user_id)
);
create table public.devices (
  id uuid primary key,
  household_id uuid not null references public.households(id),
  nickname text not null check (length(nickname) > 0),
  platform text not null check (platform = 'android'),
  model text,
  os_major integer not null check (os_major > 0),
  agent_version text not null check (length(agent_version) > 0),
  policy_epoch uuid not null,
  revoked_at timestamptz,
  unique (id, household_id),
  unique (id, household_id, policy_epoch)
);
create index devices_household_idx on public.devices(household_id);
create table public.device_policies (
  device_id uuid primary key,
  household_id uuid not null,
  version bigint not null check (version >= 0),
  policy_configured boolean not null,
  daily_limit_seconds integer,
  manual_lock boolean not null,
  updated_by uuid references public.profiles(user_id),
  updated_at timestamptz not null default now(),
  foreign key (device_id, household_id) references public.devices(id, household_id),
  check ((not policy_configured and daily_limit_seconds is null) or
    (policy_configured and daily_limit_seconds is not null and daily_limit_seconds between 0 and 86400))
);
create index device_policies_household_idx on public.device_policies(household_id);
create index device_policies_actor_idx on public.device_policies(updated_by);
create table public.commands (
  id uuid primary key,
  device_id uuid not null,
  household_id uuid not null,
  actor_user_id uuid not null references public.profiles(user_id),
  version bigint not null check (version > 0),
  kind text not null check (kind in ('LOCK', 'UNLOCK', 'ADD_TIME', 'SET_DAILY_LIMIT')),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  period_key text,
  -- Relational projection only: bind a grant to the matching ADD_TIME amount/day.
  grant_seconds integer generated always as
    (case when kind = 'ADD_TIME' then (payload->>'seconds')::integer end) stored,
  accepted_at timestamptz not null default now(),
  foreign key (device_id, household_id) references public.devices(id, household_id),
  unique (device_id, version),
  unique (id, device_id),
  unique (id, device_id, household_id),
  unique (id, device_id, household_id, period_key, grant_seconds),
  check (kind <> 'ADD_TIME' or (grant_seconds is not null and grant_seconds in (600,1800)
    and jsonb_typeof(payload->'seconds') = 'number')),
  check ((kind = 'ADD_TIME' and period_key is not null and length(period_key) > 0) or
    (kind <> 'ADD_TIME' and period_key is null))
);
create index commands_household_idx on public.commands(household_id);
create index commands_actor_idx on public.commands(actor_user_id);
create table public.daily_grants (
  command_id uuid primary key,
  device_id uuid not null,
  household_id uuid not null,
  period_key text not null check (length(period_key) > 0),
  seconds integer not null check (seconds in (600, 1800)),
  foreign key (command_id, device_id, household_id, period_key, seconds)
    references public.commands(id, device_id, household_id, period_key, grant_seconds),
  foreign key (device_id, household_id) references public.devices(id, household_id)
);
create index daily_grants_period_idx on public.daily_grants(device_id, period_key);
create index daily_grants_household_idx on public.daily_grants(household_id);
create table public.command_receipts (
  command_id uuid primary key,
  device_id uuid not null,
  snapshot_version bigint not null check (snapshot_version >= 0),
  outcome text not null check (outcome in
    ('persisted', 'applied', 'superseded', 'expired_for_period', 'failed', 'rejected')),
  observed_enforcement boolean not null,
  received_at timestamptz not null default now(),
  error_code text,
  foreign key (command_id, device_id) references public.commands(id, device_id),
  foreign key (device_id) references public.devices(id)
);
create index command_receipts_device_idx on public.command_receipts(device_id);
create table public.device_state (
  device_id uuid primary key,
  household_id uuid not null,
  policy_epoch uuid not null,
  applied_version bigint not null check (applied_version >= 0),
  report_sequence bigint not null check (report_sequence >= 0),
  period_key text not null check (length(period_key) > 0),
  used_ms bigint not null check (used_ms >= 0),
  bonus_seconds integer not null check (bonus_seconds between 0 and 86400),
  remaining_ms bigint not null check (remaining_ms between 0 and 86400000),
  manual_lock boolean not null,
  restriction_required boolean not null,
  restriction_applied boolean not null,
  health text not null check (length(health) > 0),
  observed_at timestamptz not null,
  received_at timestamptz not null default now(),
  foreign key (device_id, household_id, policy_epoch)
    references public.devices(id, household_id, policy_epoch)
);
create index device_state_household_idx on public.device_state(household_id);

create table private.pairing_sessions (
  id uuid primary key,
  household_id uuid not null references public.households(id),
  created_by uuid not null references public.profiles(user_id),
  token_digest bytea not null unique check (octet_length(token_digest) = 32),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  cancelled_at timestamptz,
  device_id uuid,
  foreign key (device_id, household_id) references public.devices(id, household_id),
  check (consumed_at is null or cancelled_at is null)
);
create index pairing_sessions_household_idx on private.pairing_sessions(household_id);
create index pairing_sessions_creator_idx on private.pairing_sessions(created_by);
create index pairing_sessions_device_idx on private.pairing_sessions(device_id, household_id);
create index pairing_sessions_expiry_idx on private.pairing_sessions(expires_at);
create table private.device_credentials (
  credential_id uuid primary key,
  device_id uuid not null references public.devices(id),
  secret_digest bytea not null unique check (octet_length(secret_digest) = 32),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  generation bigint not null check (generation > 0),
  unique (device_id, generation),
  check (expires_at > created_at)
);
create table private.push_registrations (
  id uuid primary key,
  device_id uuid not null references public.devices(id),
  provider text not null check (length(provider) > 0),
  address_kind text not null check (length(address_kind) > 0),
  address text not null check (length(address) > 0),
  updated_at timestamptz not null default now(),
  invalidated_at timestamptz
);
create unique index push_registrations_active_address_idx
  on private.push_registrations(provider, address) where invalidated_at is null;
create index push_registrations_device_idx on private.push_registrations(device_id);
create table private.push_outbox (
  id uuid primary key,
  device_id uuid not null references public.devices(id),
  newest_version bigint not null check (newest_version >= 0),
  next_attempt_at timestamptz not null,
  attempts integer not null check (attempts >= 0),
  lease_until timestamptz,
  state text not null check (length(state) > 0)
);
create index push_outbox_device_idx on private.push_outbox(device_id);
create index push_outbox_schedule_idx on private.push_outbox(state, next_attempt_at);
create table private.audit_events (
  id uuid primary key,
  household_id uuid references public.households(id),
  actor_type text not null check (length(actor_type) > 0),
  actor_id uuid,
  action text not null check (length(action) > 0),
  outcome text not null check (length(outcome) > 0),
  device_id uuid,
  created_at timestamptz not null default now(),
  foreign key (device_id, household_id) references public.devices(id, household_id),
  check (device_id is null or household_id is not null)
);
create index audit_events_household_idx on private.audit_events(household_id);
create index audit_events_device_idx on private.audit_events(device_id, household_id);
create table private.rate_limit_buckets (
  scope_hash bytea not null check (octet_length(scope_hash) = 32),
  window_start timestamptz not null,
  count integer not null check (count >= 0),
  expires_at timestamptz not null,
  primary key (scope_hash, window_start),
  check (expires_at > window_start)
);
create index rate_limit_buckets_expiry_idx on private.rate_limit_buckets(expires_at);

-- Fixed inventory: never grant on every object in a shared Supabase schema.
do $migration$
declare t text;
begin
  foreach t in array array['profiles','households','household_members','devices',
    'device_policies','commands','daily_grants','command_receipts','device_state']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
  foreach t in array array['pairing_sessions','device_credentials','push_registrations',
    'push_outbox','audit_events','rate_limit_buckets']
  loop
    execute format('alter table private.%I enable row level security', t);
    execute format('revoke all on private.%I from public, anon, authenticated', t);
  end loop;
end $migration$;

create policy own_profile on public.profiles for select to authenticated
  using (user_id = (select auth.uid()));
create policy own_active_membership on public.household_members for select to authenticated
  using (user_id = (select auth.uid()) and active);
create policy own_household on public.households for select to authenticated
  using (exists (select 1 from public.household_members m where m.household_id = households.id));
do $migration$
declare t text;
begin
  foreach t in array array['devices','device_policies','commands','daily_grants','device_state']
  loop
    execute format('create policy own_household on public.%I for select to authenticated
      using (exists (select 1 from public.household_members m where m.household_id = %I.household_id))', t, t);
  end loop;
end $migration$;
create policy own_device on public.command_receipts for select to authenticated
  using (exists (select 1 from public.devices d where d.id = command_receipts.device_id));
commit;
