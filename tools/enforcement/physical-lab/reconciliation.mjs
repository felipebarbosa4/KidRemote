// Private host pipe metadata. Never selects credentials/digests or child DB contents.
import {check} from './lease.mjs';
export function inspectEnrollment(lease){
 check(/^[a-f0-9-]{36}$/.test(lease.id),'REVIEW_LEASE_ID');lease.inspect();
 const email='product-lab-'+lease.id+'@example.test';
 const raw=lease.sql(`select jsonb_build_object('owners',(select count(*) from auth.users where email='${email}'),
 'households',(select count(*) from public.household_members m join auth.users u on u.id=m.user_id where u.email='${email}' and m.active and m.role='owner'),
 'sessions',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'device',s.device_id,'consumed',s.consumed_at is not null,'cancelled',s.cancelled_at is not null)) from private.pairing_sessions s join auth.users u on u.id=s.created_by where u.email='${email}'),'[]'::jsonb),
 'devices',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'epoch',d.policy_epoch,'configured',p.policy_configured,'manualLock',p.manual_lock,'reported',exists(select 1 from public.device_state x where x.device_id=d.id),'usable',exists(select 1 from private.device_credentials c where c.device_id=d.id and c.revoked_at is null and c.expires_at>clock_timestamp()))) from public.devices d join public.device_policies p on p.device_id=d.id join public.household_members m on m.household_id=d.household_id join auth.users u on u.id=m.user_id where u.email='${email}' and m.active and m.role='owner' and d.revoked_at is null),'[]'::jsonb));`);
 check(raw.length<=16384,'REVIEW_BOUNDS');const r=JSON.parse(raw);
 check(r.owners===1&&r.households===1&&Array.isArray(r.sessions)&&r.sessions.length<=100&&Array.isArray(r.devices)&&r.devices.length<=1,'REVIEW_OWNERSHIP_AMBIGUOUS');
 for(const s of r.sessions)check(/^[a-f0-9-]{36}$/.test(s.id)&&(s.device===null||/^[a-f0-9-]{36}$/.test(s.device))&&typeof s.consumed==='boolean'&&typeof s.cancelled==='boolean','REVIEW_SESSION_SCHEMA');
 for(const d of r.devices)check(/^[a-f0-9-]{36}$/.test(d.id)&&/^[a-f0-9-]{36}$/.test(d.epoch)&&['configured','manualLock','reported','usable'].every(k=>typeof d[k]==='boolean'),'REVIEW_DEVICE_SCHEMA');
 return r;
}
