// Local-only adapter: one actual PostgreSQL transaction across handler verification/read.
// The injected SQL session is transport, not an authorization/storage-result stub.
const digest=d=>{if(!/^[0-9a-f]{64}$/.test(d))throw Error('INVALID_DIGEST');return `decode('${d}','hex')`;};
export function databaseRepository(session) {
 return {withCredential:async(d,callback)=>session(async query=>{
  await query('begin isolation level repeatable read;');
  try {
   const row=JSON.parse(await query(`select coalesce((select jsonb_build_object('credential',to_jsonb(c)||jsonb_build_object('secret_digest',encode(c.secret_digest,'hex')),'device',to_jsonb(v))
    from private.device_credentials c join public.devices v on v.id=c.device_id join public.households h on h.id=v.household_id
    where c.secret_digest=${digest(d)} and h.deletion_state='active' for share of c,v,h),'null'::jsonb);`));
   if(!row){const out=await callback(null);await query('commit;');return out;}
   // ID came from the credential join, not from request target fields.
   if(!/^[0-9a-f-]{36}$/.test(row.device.id))throw Error('INVALID_RECORD');
   const policy=JSON.parse(await query(`select row_to_json(p) from public.device_policies p where device_id='${row.device.id}'::uuid for share;`));
   const out=await callback({...row,sync:async scope=>{
    if(policy.household_id!==scope.household_id || policy.policy_configured!==false || policy.daily_limit_seconds!==null || policy.version!==0)
     throw Error('ONLY_UNCONFIGURED_BOOTSTRAP_IMPLEMENTED');
    return {protocol_version:1,kind:'ENROLLMENT_BOOTSTRAP',device_id:scope.device_id,policy_epoch:scope.policy_epoch,
     version:policy.version,policy_configured:policy.policy_configured,daily_limit_seconds:policy.daily_limit_seconds,
     manual_lock:policy.manual_lock,enforcement_available:false};
   }});
   await query('commit;');return out;
  } catch(e){try{await query('rollback;');}catch{}throw e;}
 })};
}
