begin;
-- One bounded, replaceable page sequence per device; no credential or extra event log.
create table private.sync_snapshots (
 device_id uuid primary key references public.devices(id) on delete cascade,
 policy_epoch uuid not null,
 snapshot_id uuid not null,
 after_version bigint not null check(after_version>=0),
 expires_at timestamptz not null,
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=262144 and jsonb_array_length(payload->'operations')<=1000)
);
alter table private.sync_snapshots enable row level security;
revoke all on private.sync_snapshots from public,anon,authenticated;
grant select,insert,update,delete on private.sync_snapshots to service_role;
commit;
