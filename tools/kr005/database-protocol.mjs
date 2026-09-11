// Invoked INSIDE the verified disposable DB runner, never accepts a remote DB target.
// Pairing adapter: real committed SQL. Device gateway operation storage: explicitly stubbed.
import { randomBytes,randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import { createPairing,redeemPairing,createPairingHandler,secretDigest } from '../../supabase/functions/pairing/protocol.mjs';
import { createDeviceHandler } from '../../supabase/functions/device-gateway/handler.mjs';
export async function runPairingIntegration(sql,logs) {
 let assertions=0;
 const check=(value,label)=>{ if(!value) throw Error('PAIRING_INTEGRATION_FAILED:'+label); assertions++; };
 const literal=s=>"'"+String(s).replaceAll("'","''")+"'";
 const digest=s=>{if(!/^[0-9a-f]{64}$/.test(s)) throw Error('INVALID_DIGEST');return "decode('"+s+"','hex')";};
 const parent=randomUUID(), household=randomUUID(), sibling=randomUUID(),foreign=randomUUID(), foreignHouse=randomUUID();
 sql(`insert into auth.users(id) values (${literal(parent)});
 insert into public.profiles(user_id) values (${literal(parent)});
 insert into public.households(id,timezone_name,timezone_revision,deletion_state) values
 (${literal(household)},'Etc/UTC',1,'active'),(${literal(foreignHouse)},'Etc/UTC',1,'active');
 insert into public.household_members values (${literal(household)},${literal(parent)},'owner',true);
 insert into public.devices(id,household_id,nickname,platform,os_major,agent_version,policy_epoch) values
 (${literal(sibling)},${literal(household)},'synthetic','android',16,'synthetic',gen_random_uuid()),
 (${literal(foreign)},${literal(foreignHouse)},'synthetic','android',16,'synthetic',gen_random_uuid());`);
 const parentSQL=q=>sql(`set role authenticated; set "request.jwt.claim.sub"=${literal(parent)}; ${q}`);
 const adapter={
  create:async d=>JSON.parse(parentSQL(`select public.create_pairing(${digest(d)});`)),
  redeem:async p=>JSON.parse(sql(`set role service_role; select public.redeem_pairing(${literal(p.session_id)}::uuid,
   ${digest(p.token_digest)},${digest(p.credential_digest)},${digest(p.source_hash)},${literal(JSON.stringify(p.metadata))}::jsonb);`)),
 };
 const metadata={platform:'android',os_major:16,agent_version:'synthetic',nickname:'synthetic'};
 const created=await createPairing(adapter);check(created.result==='CREATED','CREATE_REAL_DB');
 const source=()=>randomBytes(32).toString('hex');
 const pairingHandler=createPairingHandler(adapter,async()=>source());
 let operationCalls=0;
 const commands=new Map([[randomUUID(),{device_id:sibling,household_id:household,version:1}],
  [randomUUID(),{device_id:foreign,household_id:foreignHouse,version:1}]]);
 const gateway=createDeviceHandler({withCredential:async(d,callback)=>{
  const row=JSON.parse(sql(`select coalesce((select jsonb_build_object('credential',to_jsonb(c)||jsonb_build_object('secret_digest',encode(c.secret_digest,'hex')),
   'device',to_jsonb(dev)) from private.device_credentials c join public.devices dev on dev.id=c.device_id
   where c.secret_digest=${digest(d)}),'null'::jsonb);`));
  // Real freshly paired credential/device records; no claim of serialized gateway DB adapter.
  if(!row) return callback(null);
  return callback({...row,policy_version:1,findCommand:async id=>commands.get(id),
   sync:async scope=>{operationCalls++;return {device_id:scope.device_id,household_id:scope.household_id};},
   ack:async()=>{operationCalls++;return {};}});
 }});
 const server=createServer(async(req,res)=>{
  try {
   const request=new Request('http://127.0.0.1'+req.url,{method:req.method,headers:req.headers,
    body:Readable.toWeb(req),duplex:'half'});
   const response=await (req.url.startsWith('/pairing')?pairingHandler:gateway)(request);
   res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));
  } catch {res.writeHead(500);res.end('{"result":"UNAVAILABLE"}');}
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 const base='http://127.0.0.1:'+server.address().port;
 const responses=[];
 const send=async(path,body,bearer)=>{
  const r=await fetch(base+path,{method:'POST',headers:{'content-type':'application/json',...(bearer?{authorization:'Bearer '+bearer}:{})},body:JSON.stringify(body)});
  const text=await r.text();responses.push({status:r.status,text});return {status:r.status,body:JSON.parse(text)};
 };
 try {
  const redeemed=await send('/pairing/redeem',{qr:created.qr,metadata});
  check(redeemed.status===200 && redeemed.body.result==='REDEEMED','HTTP_REDEEM_REAL_DB');
  const identity=redeemed.body;
  const own=await send('/device/sync',{protocol_version:1,after_version:0},identity.credential);
  check(own.status===200 && own.body.device_id===identity.device_id && own.body.household_id===household,'DERIVED_OWN_SCOPE');
  for(const [id] of commands) {
   const denied=await send('/device/ack',{protocol_version:1,command_id:id,policy_epoch:identity.policy_epoch,snapshot_version:1,outcome:'persisted',observed_enforcement:false},identity.credential);
   check(denied.status===403,'SIBLING_FOREIGN_DENIED');
  }
  for(const path of ['/parent/pairing-sessions','/parent/devices/'+identity.device_id+'/operations','/rpc/accept_control'])
   check((await send(path,{protocol_version:1},identity.credential)).status===404,'PARENT_RPC_DENIED');
  check(operationCalls===1,'NO_UNAUTHORIZED_STORAGE_EFFECT');
  check((await send('/pairing/redeem',{qr:created.qr,metadata})).status===401,'REPLAY_HTTP_DENIED');
  check((await send('/pairing/redeem',{qr:created.qr,metadata,household_id:foreignHouse})).status===400,'FOREIGN_TARGET_HTTP_DENIED');
  const recovery=JSON.parse(parentSQL(`select public.finish_pairing(${literal(created.qr.session_id)},true);`));
  check(recovery.result==='REVOKED_FRESH_QR_REQUIRED','RECOVERY_REAL_DB');
  check((await send('/device/sync',{protocol_version:1,after_version:0},identity.credential)).status===403,'NEW_CREDENTIAL_REVOCATION_ENFORCED');
  // Actual COMMIT followed by lost response: adapter throws only AFTER sql returns.
  const second=await createPairing(adapter);check(second.result==='CREATED','FRESH_QR_AFTER_RECOVERY');
  const lost=await redeemPairing({redeem:async p=>{await adapter.redeem(p);throw Error('SIMULATED_RESPONSE_LOSS');}},
   {qr:second.qr,metadata},source());
  check(lost.result==='UNAVAILABLE','COMMIT_RESPONSE_LOSS_REDACTED');
  check((await redeemPairing(adapter,{qr:second.qr,metadata},source())).result==='DENIED','POSTCOMMIT_REPLAY_DENIED');
  check(JSON.parse(parentSQL(`select public.finish_pairing(${literal(second.qr.session_id)});`)).result==='ALREADY_REDEEMED','LOST_RESPONSE_IDENTITY_PARENT_VISIBLE');
  check(JSON.parse(parentSQL(`select public.finish_pairing(${literal(second.qr.session_id)},true);`)).result==='REVOKED_FRESH_QR_REQUIRED','LOST_RESPONSE_EXPLICIT_REVOKE');
  const stored=sql('select row_to_json(s) from private.pairing_sessions s; select row_to_json(c) from private.device_credentials c; select row_to_json(a) from private.audit_events a;');
  for(const raw of [created.qr.token,second.qr.token,identity.credential]) {
   check(!stored.includes(raw),'NO_PLAINTEXT_PERSISTENCE');
   check(!logs().includes(raw),'NO_RAW_SECRET_DATABASE_LOGS');
   check(responses.filter(r=>r.status!==200).every(r=>!r.text.includes(raw)),'NO_RAW_SECRET_ERROR_BODY');
  }
  check(secretDigest(identity.credential).length===64,'CANONICAL_BEARER_DIGEST');
 } finally {
  await new Promise(resolve=>server.close(resolve));
 }
 console.log('PAIRING_DATABASE_PROTOCOL_HTTP_PASS:assertions='+assertions+':pairingSQL=REAL:gatewayStorage=STUB:AuthEdge=UNRUN');
}
