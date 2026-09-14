import {isDeepStrictEqual} from 'node:util';
import {randomUUID,randomBytes} from 'node:crypto';
export async function testSync({http,sql,gatewayAvailable}) {
 let count=0;const ok=(v,k)=>{if(!v)throw Error('KR009_HTTP_FAILED:'+k);count++};
 const root='http://127.0.0.1:47366',auth='http://127.0.0.1:47361',rest='http://127.0.0.1:47362';
 const json=r=>{try{return JSON.parse(r.body)}catch{return null}};
 const send=async(path,body,token,method='POST')=>{const r=await http(root+path,method,body,token?{authorization:'Bearer '+token}:{});return {...r,json:json(r)}};
 async function parent(){
  const email='kr009-'+randomUUID()+'@example.test',password=randomBytes(24).toString('base64url')+'aA1!';
  ok((await http(auth+'/signup','POST',{email,password})).status===200,'SIGNUP');
  let token;
  for(let i=0;i<30&&!token;i++) {
   const mail=json(await http('http://127.0.0.1:47365/api/v1/messages'));
   const hit=mail?.messages?.find(m=>m.To?.some(t=>t.Address===email));
   if(hit){const d=json(await http('http://127.0.0.1:47365/api/v1/message/'+hit.ID));const url=(d.HTML??d.Text??'').replaceAll('&amp;','&').match(/http:\/\/127\.0\.0\.1:47361\/verify\?[^\s"<>]+/)?.[0];if(url)token=new URL(url).searchParams.get('token')}
   if(!token)await new Promise(r=>setTimeout(r,200));
  }
  ok(Boolean(token),'LOCAL_EMAIL');const login=await http(auth+'/verify','POST',{token_hash:token,type:'signup'});ok(login.status===200,'REAL_CONFIRMED_JWT');const session=json(login);
  const h=await http(rest+'/rpc/bootstrap_household','POST',{p_timezone:'Etc/UTC'},{authorization:'Bearer '+session.access_token});ok(h.status===200,'REAL_HOUSEHOLD');
  return {token:session.access_token,user:session.user.id,house:json(h).household_id};
 }
 async function enroll(p){const q=await send('/parent/pairing-sessions',{},p.token);ok(q.status===200,'AUTHENTICATED_PAIRING');const r=await send('/pairing/redeem',{qr:q.json.qr,metadata:{platform:'android',os_major:16,agent_version:'kr009-local',nickname:'fixture'}});ok(r.status===200,'REAL_REDEEM');return r.json}
 const a=await parent(),b=await parent(),d=await enroll(a),sibling=await enroll(a),foreign=await enroll(b);
 const op=async(kind,payload={},expected=null,id=randomUUID(),target=d.device_id,actor=a)=>send('/parent/devices/'+target+'/operations',{protocol_version:1,operation_id:id,device_id:target,kind,payload,expected_version:expected},actor.token);
 const sync=(identity=d,after=0)=>send('/device/sync',{protocol_version:1,after_version:after},identity.credential);
 let r=await op('SET_DAILY_LIMIT',{daily_limit_seconds:3600},0);ok(r.status===200&&r.json.version===1,'LIMIT_ACCEPTED');
 r=await op('LOCK',{},1);ok(r.status===200&&r.json.status==='accepted','LOCK_ACCEPTED');
 let snapshot=(await sync()).json;ok(snapshot.policy_configured&&snapshot.manual_lock&&snapshot.version===2,'CONFIGURED_OWN_SNAPSHOT');
 ok((await send('/parent/devices/'+d.device_id+'/operations',undefined,a.token,'GET')).json.every(x=>x.status==='pending'),'NO_DELIVERY_AS_APPLIED');
 const id=randomUUID(),body={seconds:600,period_key:snapshot.period_key};r=await op('ADD_TIME',body,null,id);ok(r.status===200,'PLUS10');const original=r.json;
 const replays=await Promise.all(Array.from({length:100},()=>op('ADD_TIME',body,null,id)));ok(replays.every(x=>x.status===200&&JSON.stringify(x.json)===JSON.stringify(original)),'100_IDENTICAL_REAL_HTTP_REPLAYS');
 ok(sql(`select count(*) from public.daily_grants where command_id='${id}';`)==='1','ONE_IMMUTABLE_GRANT');
 const changed=await op('ADD_TIME',{...body,seconds:1800},null,id);console.log('KR009_CONFLICT_HTTP_STATUS='+changed.status+':code='+(['OPERATION_CONFLICT','OPERATION_REJECTED','TEMPORARILY_UNAVAILABLE','UNAUTHORIZED'].includes(changed.json?.code)?changed.json.code:'UNSPECIFIED'));ok(changed.status===409,'PAYLOAD_CONFLICT');
 ok((await op('LOCK',{},0,id,sibling.device_id)).status===409,'OWN_TARGET_CONFLICT');
 ok((await op('LOCK',{},0,id,foreign.device_id)).status===403,'FOREIGN_NO_METADATA');
 ok((await op('LOCK',{},0,id,randomUUID())).status===403,'MISSING_SAME_DENIAL');
 // Explicit owner-substitution fixture respects the existing one-owner/one-household uniqueness.
 sql(`begin;delete from public.household_members where user_id in ('${a.user}','${b.user}');insert into public.household_members values('${a.house}','${b.user}','owner',true),('${b.house}','${a.user}','owner',true);commit;`);
 ok((await op('ADD_TIME',body,null,id,d.device_id,b)).status===409,'CHANGED_AUTHENTICATED_ACTOR');
 sql(`begin;delete from public.household_members where user_id in ('${a.user}','${b.user}');insert into public.household_members values('${a.house}','${a.user}','owner',true),('${b.house}','${b.user}','owner',true);commit;`);
 r=await op('ADD_TIME',{...body,seconds:1800});ok(r.status===200,'PLUS30');snapshot=(await sync()).json;
 ok(snapshot.bonus_seconds===2400&&snapshot.version===4,'ABSOLUTE_600_PLUS_1800');
 ok((await op('UNLOCK',{},2)).status===409,'STALE_UNLOCK_DENIED');
 ok((await op('UNLOCK',{},4)).status===200,'ORDERED_UNLOCK');ok((await op('LOCK',{},5)).status===200,'NEWER_LOCK');snapshot=(await sync()).json;
 const report={protocol_version:1,device_id:d.device_id,policy_epoch:d.policy_epoch,applied_version:6,report_sequence:1,period_key:snapshot.period_key,used_ms:5000000,bonus_seconds:2400,remaining_ms:1000000,manual_lock:true,restriction_required:true,restriction_applied:false,health:'ENFORCEMENT_UNAVAILABLE',accounting_status:'HISTORY',observed_at:snapshot.server_utc};
 const ack=()=>send('/device/ack',report,d.credential);const first=await ack();ok(first.status===200,'REAL_REPORT_COMMIT');
 // Real HTTP response is consumed then deliberately discarded by caller, not a storage stub.
 await ack();const retry=await ack();ok(retry.status===200&&JSON.stringify(retry.json)===JSON.stringify(first.json),'LOST_ACK_RESPONSE_IDEMPOTENT_FRESHNESS');
 let status=(await send('/parent/devices/'+d.device_id+'/operations',undefined,a.token,'GET')).json;
 ok(status.find(x=>x.version===6).status==='persisted'&&status.find(x=>x.version===5).status==='superseded'&&status.every(x=>x.status!=='applied'),'HONEST_PERSISTED_SUPERSEDED');
 ok((await send('/device/ack',{...report,remaining_ms:1},d.credential)).status===409,'SAME_SEQUENCE_DIFFERENT_BODY');
 ok((await send('/device/ack',{...report,report_sequence:0},d.credential)).status===400,'SEQUENCE_BACKWARD');
 for(const identity of [sibling,foreign])ok((await send('/device/ack',report,identity.credential)).status===403,'SIBLING_FOREIGN_ACK_DENIED');
 ok((await send('/device/ack',{...report,policy_epoch:randomUUID()},d.credential)).status===403,'EPOCH_DENIED');
 ok((await send('/device/sync',{protocol_version:1,after_version:0,device_id:sibling.device_id},d.credential)).status===400,'SYNC_TARGET_OVERRIDE');
 ok((await send('/device/sync',{protocol_version:1,after_version:0},a.token)).status===401,'PARENT_ON_DEVICE_DENIED');
 ok((await send('/parent/devices/'+d.device_id+'/operations',{},d.credential)).status===401,'DEVICE_ON_PARENT_DENIED');
 r=await op('SET_DAILY_LIMIT',{daily_limit_seconds:1800},6);ok(r.status===200,'LOWER_LIMIT_ACCEPTED');
 await gatewayAvailable(false);try{ok((await sync()).status===0,'ACTUAL_GATEWAY_OUTAGE_AFTER_COMMIT')}finally{await gatewayAvailable(true)}
 snapshot=(await sync()).json;ok(snapshot.version===7&&snapshot.daily_limit_seconds===1800,'EXPLICIT_SYNC_WITHOUT_PUSH_CONVERGES');
 ok((await send('/device/ack',{...report,applied_version:7,report_sequence:2,remaining_ms:0,observed_at:snapshot.server_utc},d.credential)).status===200,'BELOW_USED_ZERO_REMAINS_USED');
 ok(sql(`select used_ms from public.device_state where device_id='${d.device_id}';`)==='5000000','SERVER_REPORT_NO_USAGE_RESET');
 sql(`update private.device_credentials set created_at=clock_timestamp()-interval '91 days',expires_at=clock_timestamp()-interval '1 second' where device_id='${d.device_id}';`);
 ok((await sync()).status===401,'EXPIRED_CANNOT_SYNC');
 sql(`update private.device_credentials set expires_at=clock_timestamp()+interval '1 day' where device_id='${d.device_id}';update public.devices set revoked_at=clock_timestamp() where id='${d.device_id}';`);
 const removed=await sync();ok(removed.status===403&&removed.json.code==='DEVICE_REVOKED','TYPED_REMOVAL');
 ok((await sync({...d,credential:randomBytes(32).toString('base64url')})).status===401,'UNKNOWN_GENERIC');
 ok(!JSON.stringify(snapshot).includes(d.credential),'NO_SNAPSHOT_SECRET');
 const history=await enroll(b);
 sql(`set role authenticated;set "request.jwt.claim.sub"='${b.user}';do $bounded$ begin
 perform public.accept_control(gen_random_uuid(),'${history.device_id}','SET_DAILY_LIMIT','{"daily_limit_seconds":3600}',0);
 for i in 1..105 loop perform public.accept_control(gen_random_uuid(),'${history.device_id}',case when i%2=1 then 'LOCK' else 'UNLOCK' end,'{}',i);end loop;end $bounded$;`);
 const bounded=(await sync(history)).json;ok(bounded.version===106&&bounded.operations.length===100&&!bounded.history_pruned&&bounded.operations.every((x,i)=>x.version===i+1),'FIRST_IMMUTABLE_PAGE');
 ok(isDeepStrictEqual((await sync(history)).json,bounded),'DUPLICATE_FIRST_PAGE_IDENTICAL');
 const pageBody={protocol_version:1,after_version:0,cursor:bounded.next_cursor};
 const page=()=>send('/device/sync',pageBody,history.credential);
 sql(`set role authenticated;set "request.jwt.claim.sub"='${b.user}';select public.accept_control(gen_random_uuid(),'${history.device_id}','UNLOCK','{}',106);`);
 const second=await page();ok(second.status===200&&second.json.version===106&&second.json.manual_lock===bounded.manual_lock&&second.json.operations.length===6&&second.json.operations.every((x,i)=>x.version===i+101)&&second.json.next_cursor===null,'NEW_COMMIT_CANNOT_CONTAMINATE_PAGE');
 ok(JSON.stringify((await page()).json)===JSON.stringify(second.json),'DUPLICATE_PAGE_IDENTICAL');
 ok((await send('/device/sync',pageBody,sibling.credential)).status===410,'FOREIGN_CURSOR_RESTART_NO_DATA');
 for(const cursor of ['bad',bounded.snapshot_id+':101',bounded.snapshot_id+':1000'])ok((await send('/device/sync',{...pageBody,cursor},history.credential)).status===400,'MALFORMED_CURSOR_REJECTED');
 ok((await send('/device/sync',{...pageBody,after_version:1},history.credential)).status===410,'CURSOR_ANCHOR_MISMATCH');
 ok((await send('/device/sync',{...pageBody,page_size:101},history.credential)).status===400,'CALLER_PAGE_SIZE_DENIED');
 ok((await send('/device/sync',{protocol_version:1,after_version:0,padding:'x'.repeat(65536)},history.credential)).status===400,'REQUEST_64K_BOUND');
 ok(Buffer.byteLength(JSON.stringify(bounded))<=65536&&Buffer.byteLength(JSON.stringify(second.json))<=65536,'RESPONSE_64K_BOUND');
 sql(`update private.sync_snapshots set expires_at=clock_timestamp()-interval '1 second' where device_id='${history.device_id}';`);
 const expiredPage=await page();ok(expiredPage.status===410&&expiredPage.json.code==='SNAPSHOT_RESTART_REQUIRED','EXPIRED_EXPLICIT_RESTART');
 const restarted=(await sync(history)).json;ok(restarted.version===107&&restarted.snapshot_id!==bounded.snapshot_id,'FULL_RESTART_NEW_SNAPSHOT');
 ok((await page()).status===410,'REPLACED_SNAPSHOT_CURSOR_REJECTED');
 const current=(await sync(history,107)).json;ok(current.operations.length===0&&!current.history_pruned&&current.version===107,'CURRENT_HIGHWATER_CONVERGENCE');
 sql(`set role authenticated;set "request.jwt.claim.sub"='${b.user}';do $pruned$ begin for i in 107..1106 loop perform public.accept_control(gen_random_uuid(),'${history.device_id}',case when i%2=1 then 'LOCK' else 'UNLOCK' end,'{}',i);end loop;end $pruned$;`);
 const pruned=(await sync(history)).json;ok(pruned.version===1107&&pruned.history_pruned&&pruned.operations[0].version===108,'PRUNED_AUTHORITATIVE_SNAPSHOT');
 let lastPage=pruned,total=lastPage.operations.length,pages=1;
 while(lastPage.next_cursor){lastPage=(await send('/device/sync',{protocol_version:1,after_version:0,cursor:lastPage.next_cursor},history.credential)).json;ok(lastPage.version===1107&&lastPage.snapshot_id===pruned.snapshot_id&&lastPage.operations.length<=100,'PAGE_SNAPSHOT_BOUND');total+=lastPage.operations.length;pages++;}
 ok(total===1000&&pages===10&&lastPage.operations.at(-1).version===1107,'BOUNDED_HISTORY_HIGHWATER');
 ok((await send('/parent/devices/'+foreign.device_id+'/operations',undefined,a.token,'GET')).json.length===0,'FOREIGN_STATUS_RLS_EMPTY');
 const live=await enroll(a);const setup=await op('SET_DAILY_LIMIT',{daily_limit_seconds:3600},0,randomUUID(),live.device_id);ok(setup.status===200,'RUNTIME_CANONICAL_SETUP');
 console.log('KR009_REAL_HTTP_PASS:assertions='+count+':replays=100:storage=POSTGRES:auth=REAL:push=NONE');
 return {identity:live,operation:(kind,payload,expected)=>op(kind,payload,expected,randomUUID(),live.device_id),ownSync:()=>sync(live),readStatus:()=>send('/parent/devices/'+live.device_id+'/operations',undefined,a.token,'GET')};
}
