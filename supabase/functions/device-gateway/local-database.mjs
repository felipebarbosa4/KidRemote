import {randomUUID} from 'node:crypto';
// Local-only adapter: one actual PostgreSQL transaction across handler verification/read.
// The injected SQL session is transport, not an authorization/storage-result stub.
const literal=s=>"'"+String(s).replaceAll("'","''")+"'";
const digest=d=>{if(!/^[0-9a-f]{64}$/.test(d))throw Error('INVALID_DIGEST');return `decode('${d}','hex')`;};
export function databaseRepository(session) {
 return {rotate:async(d,p)=>session(async query=>{
  if(!/^[0-9a-f-]{36}$/i.test(p.operation_id)||!['BEGIN','CONFIRM','STATUS'].includes(p.phase))throw Error('INVALID_ROTATION');
  return JSON.parse(await query(`select public.rotate_device_credential(${digest(d)},'${p.operation_id}'::uuid,'${p.phase}',${p.new_digest?digest(p.new_digest):'null'});`));
 }),withCredential:async(d,callback)=>session(async query=>{
  await query('begin isolation level repeatable read;');
  try {
   const row=JSON.parse(await query(`select coalesce((select jsonb_build_object('credential',to_jsonb(c)||jsonb_build_object('secret_digest',encode(c.secret_digest,'hex')),'device',to_jsonb(v))
    from private.device_credentials c join public.devices v on v.id=c.device_id join public.households h on h.id=v.household_id
    where c.secret_digest=${digest(d)} and h.deletion_state='active' for update of v for share of c,h),'null'::jsonb);`));
   if(!row){const out=await callback(null);await query('commit;');return out;}
   // ID came from the credential join, not from request target fields.
   if(!/^[0-9a-f-]{36}$/.test(row.device.id))throw Error('INVALID_RECORD');
   const policy=JSON.parse(await query(`select row_to_json(p) from public.device_policies p where device_id='${row.device.id}'::uuid for share;`));
   const out=await callback({...row,report:async body=>JSON.parse(await query(`select public.accept_device_report(${digest(d)},${literal(JSON.stringify(body))}::jsonb);`)),sync:async(scope,{after_version,cursor})=>{
    if(cursor) {
     const [token,offset]=cursor.split(':');
     const saved=JSON.parse(await query(`select coalesce((select payload from private.sync_snapshots where device_id='${scope.device_id}' and policy_epoch='${scope.policy_epoch}' and snapshot_id=${literal(token)}::uuid and after_version=${after_version} and expires_at>clock_timestamp()),'null'::jsonb);`));
     if(!saved || Number(offset)>=saved.operations.length)return {code:'SNAPSHOT_RESTART_REQUIRED'};
     return page(saved,Number(offset));
    }
    if(policy.policy_configured===true) {
     if(after_version>policy.version)throw Error('CURSOR_AHEAD');
     const cached=JSON.parse(await query(`select coalesce((select s.payload from private.sync_snapshots s join public.households h on h.id='${scope.household_id}' where s.device_id='${scope.device_id}' and s.policy_epoch='${scope.policy_epoch}' and s.after_version=${after_version} and s.expires_at>clock_timestamp() and (s.payload->>'version')::bigint=${policy.version} and (s.payload->'credential_lifecycle'->>'generation')::bigint=${row.credential.generation} and s.payload->>'timezone_name'=h.timezone_name and s.payload->>'period_key'=h.timezone_revision::text||':'||to_char(clock_timestamp() at time zone h.timezone_name,'YYYY-MM-DD')),'null'::jsonb);`));
     if(cached)return page(cached,0);
     const snapshot=JSON.parse(await query(`with t as (select clock_timestamp() as utc), h as (select * from public.households where id='${scope.household_id}'::uuid),
      ops as (select c.id,c.version,c.kind,c.period_key,s.status from public.commands c join public.operation_status s on s.operation_id=c.id where c.device_id='${scope.device_id}'::uuid and c.version>${after_version} and c.version<=${policy.version} order by c.version desc limit 1000)
      select jsonb_build_object('timezone_name',h.timezone_name,'timezone_revision',h.timezone_revision,'server_utc',t.utc,
      'period_key',h.timezone_revision::text||':'||to_char(t.utc at time zone h.timezone_name,'YYYY-MM-DD'),
      'bonus_seconds',(select coalesce(sum(seconds),0) from public.daily_grants where device_id='${scope.device_id}'::uuid and period_key=h.timezone_revision::text||':'||to_char(t.utc at time zone h.timezone_name,'YYYY-MM-DD')),
      'operations',coalesce((select jsonb_agg(jsonb_build_object('operation_id',id,'version',version,'kind',kind,'period_key',period_key,'status',status) order by version) from ops),'[]'::jsonb),
      'history_pruned',(select count(*)>1000 from public.commands where device_id='${scope.device_id}'::uuid and version>${after_version} and version<=${policy.version})) from h,t;`));
     const complete={protocol_version:1,kind:'CONFIGURED_SNAPSHOT',device_id:scope.device_id,policy_epoch:scope.policy_epoch,version:policy.version,
      policy_configured:true,daily_limit_seconds:policy.daily_limit_seconds,manual_lock:policy.manual_lock,enforcement_available:false,...snapshot,credential_lifecycle:{generation:row.credential.generation,expires_at:row.credential.expires_at,rotate_after:new Date(Date.parse(row.credential.created_at)+30*86400000).toISOString(),rotation_due:JSON.parse(await query(`select to_json(clock_timestamp() >= created_at + interval '30 days') from private.device_credentials where credential_id='${row.credential.credential_id}'::uuid;`))}};
     complete.snapshot_id=randomUUID();
     await query(`insert into private.sync_snapshots(device_id,policy_epoch,snapshot_id,after_version,expires_at,payload) values('${scope.device_id}','${scope.policy_epoch}','${complete.snapshot_id}',${after_version},clock_timestamp()+interval '5 minutes',${literal(JSON.stringify(complete))}::jsonb) on conflict(device_id) do update set policy_epoch=excluded.policy_epoch,snapshot_id=excluded.snapshot_id,after_version=excluded.after_version,expires_at=excluded.expires_at,payload=excluded.payload;`);
     return page(complete,0);
    }

    if(after_version!==0)throw Error('ONLY_INITIAL_CURSOR_IMPLEMENTED');
    if(policy.household_id!==scope.household_id || policy.policy_configured!==false || policy.daily_limit_seconds!==null || policy.version!==0)
     throw Error('ONLY_UNCONFIGURED_BOOTSTRAP_IMPLEMENTED');
    return {protocol_version:1,kind:'ENROLLMENT_BOOTSTRAP',device_id:scope.device_id,policy_epoch:scope.policy_epoch,
     version:policy.version,policy_configured:policy.policy_configured,daily_limit_seconds:policy.daily_limit_seconds,
     manual_lock:policy.manual_lock,enforcement_available:false,
     credential_lifecycle:{generation:row.credential.generation,expires_at:row.credential.expires_at,
      rotate_after:new Date(Date.parse(row.credential.created_at)+30*86400000).toISOString(),
      rotation_due:JSON.parse(await query(`select to_json(clock_timestamp() >= created_at + interval '30 days') from private.device_credentials where credential_id='${row.credential.credential_id}'::uuid;`))}};
   }});
   await query('commit;');return out;
  } catch(e){try{await query('rollback;');}catch{}throw e;}
 })};
}

function page(saved,offset) {
 const end=offset+100;
 const out={...saved,operations:saved.operations.slice(offset,end),next_cursor:end<saved.operations.length?saved.snapshot_id+':'+end:null};
 if(Buffer.byteLength(JSON.stringify(out))>65536)throw Error('PAGE_TOO_LARGE');
 return out;
}
