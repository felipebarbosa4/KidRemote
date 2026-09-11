import {randomUUID,randomBytes} from 'node:crypto';
import {createPairing,secretDigest} from '../../supabase/functions/pairing/protocol.mjs';
export async function testEnrollment({http,sql}) {
 let count=0;const ok=(b,c)=>{if(!b)throw Error('ENROLLMENT_HTTP_FAILED:'+c);count++;};
 const id=randomUUID(),house=randomUUID(),foreign=randomUUID(),sibling=randomUUID(),foreignHouse=randomUUID();
 const literal=s=>"'"+String(s).replaceAll("'","''")+"'";
 sql(`insert into auth.users(id) values('${id}');insert into public.profiles(user_id) values('${id}');
 insert into public.households(id,timezone_name,timezone_revision,deletion_state) values('${house}','Etc/UTC',1,'active');
 insert into public.household_members values('${house}','${id}','owner',true);`);
 sql(`insert into public.households(id,timezone_name,timezone_revision,deletion_state) values('${foreignHouse}','Etc/UTC',1,'active');
 insert into public.devices(id,household_id,nickname,platform,os_major,agent_version,policy_epoch) values
 ('${sibling}','${house}','synthetic sibling','android',16,'test',gen_random_uuid()),
 ('${foreign}','${foreignHouse}','synthetic foreign','android',16,'test',gen_random_uuid());`);
 const parent=q=>sql(`set role authenticated;set "request.jwt.claim.sub"='${id}';${q}`);
 const create=()=>createPairing({create:async d=>JSON.parse(parent(`select public.create_pairing(decode('${d}','hex'));`))});
 const finish=(sid,revoke=false)=>JSON.parse(parent(`select public.finish_pairing('${sid}',${revoke});`));
 const send=async(path,body,bearer)=>{const r=await http('http://127.0.0.1:57366'+path,'POST',body,bearer?{authorization:'Bearer '+bearer}:{});return {...r,json:JSON.parse(r.body||'{}')};};
 const metadata={platform:'android',os_major:16,agent_version:'kr007-synthetic',nickname:'fixture'};
 const q=await create();ok(q.result==='CREATED','REAL_SQL_CREATE');
 const r=await send('/pairing/redeem',{qr:q.qr,metadata});ok(r.status===200,'REAL_HTTP_REDEMPTION');
 const credential=r.json.credential;const device=r.json.device_id;
 const read=()=>send('/device/sync',{protocol_version:1,after_version:0},credential);
 const own=await read();ok(own.status===200 && own.json.device_id===device,'REAL_DB_OWN_READ');
 ok(own.json.policy_configured===false&&own.json.daily_limit_seconds===null&&own.json.enforcement_available===false,'NO_DEFAULT_POLICY_OR_PROTECTION');
 ok(sql(`select household_id from public.devices where id='${device}';`)===house,'SESSION_DERIVED_HOUSEHOLD');
 for(const target of [sibling,foreign])ok((await send('/device/sync',{protocol_version:1,after_version:0,device_id:target},credential)).status===400,'TARGET_OVERRIDE_DENIED');
 for(const path of ['/parent/pairing-sessions','/parent/devices/'+sibling+'/operations','/rpc/accept_control','/device/ack'])
  ok([401,404].includes((await send(path,{},credential)).status),'PARENT_OTHER_ROUTE_DENIED');
 ok((await read()).status===200,'DENIALS_DID_NOT_REVOKE_OWN');
 ok((await send('/device/sync',{protocol_version:1,after_version:0},randomBytes(32).toString('base64url'))).status===401,'INVALID_CREDENTIAL');
 ok((await send('/device/sync',{protocol_version:1,after_version:0})).status===401,'MISSING_CREDENTIAL');
 sql(`update private.device_credentials set created_at=clock_timestamp()-interval '91 days',expires_at=clock_timestamp()-interval '1 second' where device_id='${device}';`);
 ok((await read()).status===401,'EXPIRED_CREDENTIAL');
 sql(`update private.device_credentials set expires_at=clock_timestamp()+interval '1 day' where device_id='${device}';`);
 ok((await send('/pairing/redeem',{qr:q.qr,metadata})).status===401,'REPLAY');
 ok(finish(q.qr.session_id,true).result==='REVOKED_FRESH_QR_REQUIRED','RECOVERY_REVOKES_INCOMPLETE');
 ok((await read()).status===403,'REVOKED_CURRENT_RECORD');
 const expired=await create();sql(`update private.pairing_sessions set expires_at=clock_timestamp()-interval '1 second',created_at=clock_timestamp()-interval '6 minutes' where id='${expired.qr.session_id}';`);
 ok((await send('/pairing/redeem',{qr:expired.qr,metadata})).status===401,'EXPIRED_QR');
 const cancelled=await create();ok(finish(cancelled.qr.session_id).result==='CANCELLED','CANCEL');
 ok((await send('/pairing/redeem',{qr:cancelled.qr,metadata})).status===401,'CANCELLED_QR');
 ok((await send('/pairing/redeem',{qr:{...q.qr,backend:'https://invalid.example'},metadata})).status===400,'FOREIGN_BACKEND_QR');
 const lost=await create();
 // Actual HTTP+commit, deliberately discard secret response. No plaintext replay recovery.
 await send('/pairing/redeem',{qr:lost.qr,metadata});
 ok(finish(lost.qr.session_id).result==='ALREADY_REDEEMED','DISCARDED_RESPONSE_COMMITTED');
 ok((await send('/pairing/redeem',{qr:lost.qr,metadata})).status===401,'DISCARDED_RESPONSE_REPLAY_DENIED');
 ok(finish(lost.qr.session_id,true).result==='REVOKED_FRESH_QR_REQUIRED','DISCARDED_RESPONSE_REVOKE_FRESH_QR');
 const stored=sql('select row_to_json(c) from private.device_credentials c;select row_to_json(s) from private.pairing_sessions s;');
 ok(!stored.includes(credential)&&!stored.includes(q.qr.token),'NO_STORED_PLAINTEXT');
 ok(stored.includes('\\x'+secretDigest(credential)),'DIGEST_STORED');
 ok((await http('http://127.0.0.1:57362/devices?select=id','GET',undefined,{authorization:'Bearer '+credential})).status===401,'DEVICE_NOT_DATA_API_PARENT');
 console.log('REAL_ENROLLMENT_HTTP_DB_PASS:assertions='+count+':parentCreationFixture=SQL_ROLE:deviceRead=REAL_TRANSACTION');
}
