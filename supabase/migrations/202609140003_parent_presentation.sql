begin;
-- One statement snapshot of existing data; invoker rights retain all parent RLS.
-- No new table, countdown, client target authority or history collection.
create function public.parent_devices(p_after uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $sql$
 select jsonb_build_object('protocol_version',1,'server_utc',statement_timestamp(),
 'devices',coalesce(jsonb_agg(row_data order by id),'[]'::jsonb)) from (
 select d.id,jsonb_build_object('id',d.id,'nickname',left(d.nickname,128),'model',left(d.model,128),
 'policy_epoch',d.policy_epoch,'revoked',d.revoked_at is not null,
 'version',p.version,'policy_configured',p.policy_configured,'daily_limit_seconds',p.daily_limit_seconds,
 'period_key',h.timezone_revision::text||':'||to_char(statement_timestamp() at time zone h.timezone_name,'YYYY-MM-DD'),
 'report',case when s.device_id is null then null else jsonb_build_object(
 'version',s.applied_version,'sequence',s.report_sequence,'period_key',s.period_key,
 'remaining_ms',s.remaining_ms,'used_ms',s.used_ms,'bonus_seconds',s.bonus_seconds,
 'manual_lock',s.manual_lock,'restriction_required',s.restriction_required,
 'restriction_applied',s.restriction_applied,'health',left(s.health,128),'received_at',s.received_at) end) row_data
 from public.devices d join public.households h on h.id=d.household_id
 join public.device_policies p on p.device_id=d.id
 left join public.device_state s on s.device_id=d.id and s.policy_epoch=d.policy_epoch
 where p_after is null or d.id>p_after order by d.id limit 50
 ) listed
$sql$;
revoke all on function public.parent_devices(uuid) from public,anon,authenticated,service_role;
grant execute on function public.parent_devices(uuid) to authenticated;
commit;
