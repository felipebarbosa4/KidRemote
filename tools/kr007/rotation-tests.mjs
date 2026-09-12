import {randomBytes,randomUUID} from 'node:crypto';
import {credentialDigest} from '../../supabase/functions/device-gateway/handler.mjs';
export async function testRotation({http,sql}) {
 let count=0;const ok=(v,c)=>{if(!v)throw Error('ROTATION_HTTP_FAILED:'+c);count++;};
 const house=randomUUID();sql(`insert into public.households(id,timezone_name,timezone_revision,deletion_state) values('${house}','Etc/UTC',1,'active');`);
 const secrets=[];
 function fixture(h=house) {
  const id=randomUUID(),epoch=randomUUID(),old=randomBytes(32).toString('base64url'),next=randomBytes(32).toString('base64url'),op=randomUUID();secrets.push(old,next);
  sql(`insert into public.devices(id,household_id,nickname,platform,os_major,agent_version,policy_epoch) values('${id}','${h}','synthetic rotation','android',16,'test','${epoch}');
   insert into public.device_policies(device_id,household_id,version,policy_configured,daily_limit_seconds,manual_lock) values('${id}','${h}',0,false,null,false);
   insert into private.device_credentials(credential_id,device_id,secret_digest,created_at,expires_at,generation) values(gen_random_uuid(),'${id}',decode('${credentialDigest(old)}','hex'),clock_timestamp()-interval '30 days',clock_timestamp()+interval '60 days',1);`);
  return {id,epoch,old,next,op};
 }
 const send=async(path,body,secret)=>{const r=await http('http://127.0.0.1:57366'+path,'POST',body,{authorization:'Bearer '+secret});return {status:r.status,body:JSON.parse(r.body||'{}')};};
 const rotate=(f,phase,secret=phase==='BEGIN'?f.old:f.next,extra={})=>send('/device/credentials/rotate',{protocol_version:1,operation_id:f.op,phase,...(phase==='BEGIN'?{new_credential:f.next}:{}),...extra},secret);
 const read=s=>send('/device/sync',{protocol_version:1,after_version:0},s);
 const f=fixture();const before=await read(f.old);ok(before.status===200&&before.body.credential_lifecycle.rotation_due,'SERVER_DUE_DAY30');
 const parallel=await Promise.all(Array.from({length:20},()=>rotate(f,'BEGIN')));
 ok(parallel.every(r=>r.status===200&&r.body.result==='PENDING'&&r.body.generation===2),'20_IDENTICAL_CONCURRENT_BEGIN');
 ok(new Set(parallel.map(r=>r.body.overlap_until)).size===1,'NO_OVERLAP_EXTENSION');
 ok(sql(`select count(*) from private.device_credentials where device_id='${f.id}';`)==='2','ONLY_TWO_GENERATIONS');
 ok(sql(`select count(*) from public.devices where id='${f.id}' and household_id='${house}' and policy_epoch='${f.epoch}';`)==='1','IDENTITY_SCOPE_UNCHANGED');
 ok((await rotate(f,'CONFIRM',f.old)).status===409,'OLD_CANNOT_CONFIRM');
 ok((await read(f.next)).status===200,'NEW_READ_DURING_OVERLAP');
 const status=await rotate(f,'STATUS');ok(status.status===200&&status.body.generation===2,'COMMITTED_RESPONSE_DISCARDED_STATUS_NEW');
 await rotate(f,'CONFIRM'); // Real committed reply deliberately discarded at test caller.
 ok((await rotate(f,'CONFIRM')).body.result==='CONFIRMED','CONFIRM_RESPONSE_LOSS_RETRY');
 ok((await read(f.old)).status===403,'OLD_RETIRED');ok((await read(f.next)).status===200,'NEW_READ_AFTER_CONFIRM');
 const sibling=fixture();const foreignHouse=randomUUID();sql(`insert into public.households(id,timezone_name,timezone_revision,deletion_state) values('${foreignHouse}','Etc/UTC',1,'active');`);
 const foreign=fixture(foreignHouse);
 for(const other of [sibling,foreign]) {
  ok((await rotate(f,'STATUS',other.old)).status===409,'OTHER_DEVICE_OPERATION_DENIED');
  ok((await rotate(f,'BEGIN',other.old,{device_id:f.id})).status===400,'CALLER_TARGET_DENIED');
 }
 ok((await send('/parent/pairing-sessions',{},f.next)).status===401,'NEW_NO_PARENT_PRIVILEGE');
 const race=fixture();const conflict={...race,op:randomUUID(),next:randomBytes(32).toString('base64url')};
 const outcomes=await Promise.all([rotate(race,'BEGIN'),rotate(conflict,'BEGIN')]);
 ok(outcomes.filter(r=>r.status===200).length===1&&outcomes.filter(r=>r.status===409).length===1,'CONFLICTING_CONCURRENT_SERIALIZED');
 ok(sql(`select count(*) from private.device_credentials where device_id='${race.id}';`)==='2','CONFLICT_NO_EXTRA_GENERATION');
 const revoked=fixture();await rotate(revoked,'BEGIN');sql(`update public.devices set revoked_at=clock_timestamp() where id='${revoked.id}';`);
 ok((await rotate(revoked,'CONFIRM')).status===403,'REVOKE_PENDING_DENIED');ok((await read(revoked.next)).status===403,'REVOKE_NEW_READ_DENIED');
 const expiry=fixture();await rotate(expiry,'BEGIN');
 sql(`update private.device_credentials set expires_at=clock_timestamp() where device_id='${expiry.id}' and generation=1;`);
 ok((await read(expiry.old)).status===401,'OLD_OVERLAP_END_DENIED');ok((await rotate(expiry,'CONFIRM')).status===200,'NEW_RECOVERY_NO_OLD_REVIVAL');
 sql(`update private.device_credentials set created_at=clock_timestamp()-interval '91 days',expires_at=clock_timestamp() where device_id='${expiry.id}' and generation=2;`);
 ok((await rotate(expiry,'CONFIRM')).status===401,'EXPIRED_NEW_NO_RECOVERY_BYPASS');
 const stored=sql('select row_to_json(c) from private.device_credentials c;select row_to_json(r) from private.credential_rotations r;');
 ok(secrets.every(s=>!stored.includes(s)),'DIGEST_ONLY_STORAGE');
 console.log('REAL_ROTATION_HTTP_DB_PASS:assertions='+count+':concurrentIdentical=20:storage=POSTGRES:loss=REAL_RESPONSE_DISCARDED_AT_CALLER');
}
