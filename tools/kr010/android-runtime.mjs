// Reuses the owner-verified emulator runner; no discovery, camera or screenshots.
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {createHash,randomUUID} from 'node:crypto';
import {parseQR} from '../../supabase/functions/pairing/protocol.mjs';
export async function exerciseControls({command,run,guard,dir,windowsPath,app,evidence,sql,installFresh,apkDirectory,restAvailable}) {
 const child='dev.kidremote.child.unassigned.debug';
 for(const [pkg,file] of [[child,'child-debug.apk'],[child+'.test','child-debug-androidTest.apk']]){
  const path=join(dir,apkDirectory,file);evidence.apkHashes[pkg]=createHash('sha256').update(readFileSync(path)).digest('hex');await installFresh(pkg,path);
 }
 await command(['shell','run-as',app,'sh','-c','"mkdir -p no_backup && touch no_backup/control-test"']);
 await command(['shell','run-as',child,'sh','-c','"mkdir -p no_backup && touch no_backup/sync-test-control"']);
 let device,actor;
 async function stage(pkg,clazz,method,args={},seam){
  await command(['shell','am','force-stop',pkg]);await guard();
  if(seam)await command(['shell','run-as',pkg,'rm','-f','no_backup/control-ready','no_backup/control-release']);
  let done=false;
  const execution=run(['shell','am','instrument','-w','-r','-e','class',clazz+'#'+method,...Object.entries(args).flatMap(([k,v])=>['-e',k,String(v)]),pkg+'.test/androidx.test.runner.AndroidJUnitRunner'],240000).then(r=>{done=true;return r});
  let seamError;
  if(seam)try{
   let ready=false;for(let n=0;n<300&&!done;n++){await guard();const r=await run(['exec-out','run-as',pkg,'cat','no_backup/control-ready'],5000);if(r.code===0&&r.out.trim()==='READY'){ready=true;break};await new Promise(r=>setTimeout(r,100));}
   if(!ready)throw Error('UI_SEAM_NOT_READY');await seam();await command(['shell','run-as',pkg,'touch','no_backup/control-release']);
  }catch(e){seamError=e}
  const r=await execution;const codes=[...r.out.matchAll(/kr0(?:06|07|10)=([A-Z0-9_]+)/g)].map(m=>m[1]);
  const pass=!seamError&&r.code===0&&/OK \(1 test\)/.test(r.out)&&!/FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed/.test(r.out);
  const row={method,step:args.step??'',result:pass?'PASS':'FAIL',codes};evidence.stages.push(row);console.log(JSON.stringify(row));if(!pass)throw Error('KR010_UI_STAGE_FAILED:'+method+':'+(args.step??''));
 }
 const parent=(step,args={},seam)=>stage(app,'dev.kidremote.parent.ControlsRuntimeTest','step',{step,...args},seam);
 const sync=(remaining,manual=false,step='sync')=>stage(child,'dev.kidremote.child.sync.ParentControlRuntimeTest','step',{step,remaining,manual});
 await stage(app,'dev.kidremote.parent.ParentRuntimeTest','createEnrollmentQr');
 const qr=(await command(['exec-out','run-as',app,'cat','no_backup/qr-handoff'])).trim();const parsed=parseQR(qr);if(!parsed)throw Error('QR_INVALID');
 await guard();if((await run(['shell','run-as',child,'sh','-c','"mkdir -p no_backup && cat > no_backup/qr-handoff"'],10000,qr)).code!==0)throw Error('QR_HANDOFF_FAILED');
 await stage(child,'dev.kidremote.child.EnrollmentRuntimeTest','decodeRedeemAndRead');
 device=sql(`select device_id from private.pairing_sessions where id='${parsed.session_id}';`);
 actor=sql(`select created_by from private.pairing_sessions where id='${parsed.session_id}';`);
 if(![device,actor].every(x=>/^[a-f0-9-]{36}$/.test(x)))throw Error('RUNTIME_SCOPE_INVALID');
 const used=()=>sql(`select used_ms from public.device_state where device_id='${device}';`);
 const grant=()=>sql(`select coalesce(sum(seconds),0) from public.daily_grants where device_id='${device}';`);
 const control=(kind)=>{const v=sql(`select version from public.device_policies where device_id='${device}';`);if(!/^\d+$/.test(v))throw Error('VERSION_INVALID');sql(`set role authenticated;set "request.jwt.claim.sub"='${actor}';select public.accept_control('${randomUUID()}','${device}','${kind}','{}',${v});`)};
 await parent('limit',{value:3600});await sync(0,false,'initialize');await parent('report',{remaining:0,outcome:'persisted'});
 await parent('plus10');if(grant()!=='600')throw Error('PLUS10_NOT_EXACT');await sync(600000);await parent('report',{remaining:600000,outcome:'persisted'});
 await parent('loss');if(grant()!=='2400')throw Error('PLUS30_NOT_EXACT');await parent('retry');if(grant()!=='2400')throw Error('RETRY_DUPLICATED_GRANT');await sync(2400000);await parent('report',{remaining:2400000,outcome:'persisted'});
 await parent('lock');await sync(2400000,true);await parent('report',{remaining:2400000,manual:true,outcome:'persisted'});
 await parent('plus10');if(grant()!=='3000')throw Error('LOCKED_PLUS10_NOT_EXACT');await sync(3000000,true);await parent('report',{remaining:3000000,manual:true,outcome:'persisted'});
 await parent('limit',{value:0});await sync(0,true);await parent('report',{remaining:0,manual:true,outcome:'persisted'});
 await parent('unlock');await sync(0);await parent('report',{remaining:0,outcome:'persisted'});
 await parent('lock');control('UNLOCK');await sync(0);await parent('report',{remaining:0,outcome:'superseded'});
 await parent('conflict',{},()=>control('LOCK'));await sync(0,true);await parent('invalid');
 try{await parent('outage',{},()=>restAvailable(false))}finally{restAvailable(true)}
 sql(`update public.device_state set received_at=clock_timestamp()-interval '1 hour' where device_id='${device}';`);
 await parent('stale');await parent('warm');await parent('healthFixtures');
 const font=(await command(['shell','settings','get','system','font_scale'])).trim();if(!/^\d+(\.\d+)?$/.test(font))throw Error('FONT_STATE_UNVERIFIED');
 try{await command(['shell','settings','put','system','font_scale','2.0']);await parent('accessibility')}
 finally{await command(['shell','settings','put','system','font_scale',font]);}
 const before=used();await parent('logout');if(used()!==before||before!=='3600000'||grant()!=='3000')throw Error('LOGOUT_CHANGED_CHILD');
 evidence.flow='REAL_COMPOSE_AUTH_POSTGRES_GATEWAY_ROOM_ACK';evidence.plus10=600;evidence.plus30=1800;evidence.replayGrantTotal=2400;evidence.usedMs=3600000;evidence.lockedAddition=600;evidence.finalBonus=3000;
 evidence.font='EMULATOR_2X_CRITICAL_ACTION_SEMANTICS_ONLY_RESTORED';evidence.physical='UNRUN';
}
