// Local-only accounting tests: exact owner-manifest AVD, child packages, no physical discovery.
import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {createHash,randomUUID} from 'node:crypto';
export async function testSyncRuntime({identity,operation,ownSync,readStatus,sql,gatewayAvailable}) {
const dir=process.env.KR006_RUNTIME_DIRECTORY;
if(!dir||!/^\/mnt\/c\/Users\/3feli\/AppData\/Local\/KidRemote\/kr006-runtime\/[a-f0-9-]{36}$/.test(dir))throw Error('TASK_DIRECTORY_REQUIRED');
const windows=p=>'C:'+p.slice(6).replaceAll('/','\\');
const owner=JSON.parse(readFileSync(join(dir,'owner.json'),'utf8').replace(/^\uFEFF/,''));
if(owner.Scope!=='KR006_RUNTIME'||owner.Directory!==windows(dir)||owner.AvdName!=='kr006_'+owner.Id.replaceAll('-','')||owner.Port!==5584||owner.Sdk!=='C:\\Users\\3feli\\AppData\\Local\\Android\\Sdk')throw Error('OWNER_UNVERIFIED');
const app='dev.kidremote.child.unassigned.debug',packages=[app,app+'.test'];
const adb='/mnt/c/Users/3feli/AppData/Local/Android/Sdk/platform-tools/adb.exe';
const report=join(dir,'kr009-'+new Date().toISOString().replaceAll(/[:.]/g,'-')+'.json');
const evidence={scope:'KR009_LOCAL_SYNC_ACK_EMULATOR',source:process.env.KR009_APK_SOURCE??'UNSPECIFIED',stages:[],hashes:{},overall:'NOT_PASSED',cleanup:'UNVERIFIED'};
function run(args,input){return new Promise(resolve=>{const p=spawn(adb,['-s','emulator-5584',...args],{stdio:[input===undefined?'ignore':'pipe','pipe','pipe']});let out='';const timer=setTimeout(()=>p.kill(),180000);p.stdout.on('data',x=>{if(out.length<1000000)out+=x});p.stderr.on('data',x=>{if(out.length<1000000)out+=x});p.on('error',()=>resolve({code:-1,out:''}));p.on('close',code=>{clearTimeout(timer);resolve({code,out})});if(input!==undefined)p.stdin.end(input)});}
async function guard(){const name=await run(['emu','avd','name']);if(name.code!==0||name.out.trim().split(/\r?\n/)[0].trim()!==owner.AvdName)throw Error('AVD_IDENTITY_UNVERIFIED');const q=await run(['shell','getprop','ro.kernel.qemu']);if(q.code!==0||q.out.trim()!=='1')throw Error('NOT_EMULATOR');}
async function command(args){await guard();const r=await run(args);if(r.code!==0){const code=r.out.match(/INSTALL_FAILED_[A-Z_]+|DELETE_FAILED_[A-Z_]+/)?.[0]??'UNSPECIFIED';throw Error('TARGETED_COMMAND_FAILED:'+args[0]+':'+code);}return r.out;}
let primary;
const record=row=>{evidence.stages.push(row);console.log(JSON.stringify(row))};
const ok=(v,code)=>{if(!v)throw Error(code)};
async function stage(method,death=false){
 await command(['shell','am','force-stop',app]);await guard();
 const r=await run(['shell','am','instrument','-w','-r','-e','class','dev.kidremote.child.sync.SyncRuntimeTest#'+method,app+'.test/androidx.test.runner.AndroidJUnitRunner']);
 const codes=[...r.out.matchAll(/kr009=([A-Z0-9_]+)/g)].map(m=>m[1]);
 let passed=r.code===0&&/OK \(1 test\)/.test(r.out)&&!/FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed/.test(r.out);
 if(death){const marker=(await command(['exec-out','run-as',app,'cat','no_backup/sync-crash'])).trim();passed=marker==='KR009_EXPECTED_KILL_AFTER_PERSIST'&&codes.includes(marker)&&/Process crashed/.test(r.out)}
 record({method,result:passed?(death?'EXPECTED_PROCESS_DEATH':'PASS'):'FAIL',codes,hostExit:r.code});ok(passed,'SYNC_ANDROID_STAGE_FAILED:'+method);
}
async function control(kind,payload,expected){const r=await operation(kind,payload,expected);ok(r.status===200&&r.json.version===expected+1,'PARENT_OPERATION_FAILED');record({method:kind,result:'ACCEPTED_NOT_APPLIED'});}
try {
 ok(/^[a-f0-9]{40}$/.test(process.env.KR009_APK_SOURCE??''),'APK_SOURCE_REQUIRED');
 await guard();ok((await command(['shell','getprop','ro.build.version.sdk'])).trim()==='36','API_MISMATCH');
 for(const [i,file] of ['child-debug.apk','child-debug-androidTest.apk'].entries()) {
  const path=join(dir,'apks-kr009-'+process.env.KR009_APK_SOURCE.slice(0,7),file);evidence.hashes[file]=createHash('sha256').update(readFileSync(path)).digest('hex');
  const exists=(await command(['shell','pm','list','packages','-u',packages[i]])).replaceAll('\r','').trim().split('\n').includes('package:'+packages[i]);
  if(exists)ok((await command(['uninstall',packages[i]])).includes('Success'),'OWN_UNINSTALL_FAILED');
  ok((await command(['install','-r','-t',windows(path)])).includes('Success'),'OWN_INSTALL_FAILED');
 }
 await command(['shell','run-as',app,'sh','-c','"mkdir -p no_backup && touch no_backup/sync-test-control"']);
 await guard();ok((await run(['shell','run-as',app,'sh','-c','"mkdir -p no_backup && cat > no_backup/sync-handoff"'],JSON.stringify(identity))).code===0,'IDENTITY_HANDOFF_FAILED');
 await stage('prepareIdentityAndUsage');
 await control('LOCK',{},1);await stage('lockPersisted');
 ok((await readStatus()).json.find(x=>x.version===2).status==='persisted','LOCK_NOT_PERSISTED');
 await control('UNLOCK',{},2);await control('SET_DAILY_LIMIT',{daily_limit_seconds:0},3);
 await stage('zeroUnlockAndReordered');await stage('malformedSnapshotRetainsPolicy');
 const period=(await ownSync()).json.period_key;
 let added=await operation('ADD_TIME',{seconds:600,period_key:period},null);ok(added.status===200&&added.json.version===5,'PLUS10_NOT_ACCEPTED');
 await stage('killAfterGrantPersistence',true);
 ok((await readStatus()).json.find(x=>x.version===5).status==='pending','CRASH_BEFORE_ACK_NOT_PENDING');
 await stage('restartResendsPendingAck');
 ok((await readStatus()).json.find(x=>x.version===5).status==='persisted','RESTART_ACK_NOT_PERSISTED');
 added=await operation('ADD_TIME',{seconds:1800,period_key:period},null);ok(added.status===200&&added.json.version===6,'PLUS30_NOT_ACCEPTED');
 await stage('loseAckResponse');
 ok((await readStatus()).json.find(x=>x.version===6).status==='persisted','LOST_ACK_NOT_COMMITTED');
 const before=sql(`select report_sequence::text||':'||received_at::text from public.device_state where device_id='${identity.device_id}';`);
 await stage('retryLostAckAfterRestart');
 ok(sql(`select report_sequence::text||':'||received_at::text from public.device_state where device_id='${identity.device_id}';`)===before,'LOST_ACK_CHANGED_FRESHNESS_OR_SEQUENCE');
 await control('LOCK',{},6);await gatewayAvailable(false);
 try{await stage('offlinePreservesLedger')}finally{await gatewayAvailable(true)}
 await stage('explicitRestartConverges');
 // Explicit historical SQL fixture, not a parent backdated operation or edited clock.
 const late=randomUUID();
 sql(`begin;insert into public.commands(id,device_id,household_id,actor_user_id,version,kind,payload,period_key,accepted_at)
 select '${late}',c.device_id,c.household_id,c.actor_user_id,8,'ADD_TIME',jsonb_build_object('seconds',600,'period_key','1:'||to_char(clock_timestamp()-interval '1 day','YYYY-MM-DD')),'1:'||to_char(clock_timestamp()-interval '1 day','YYYY-MM-DD'),clock_timestamp()-interval '1 day' from public.commands c where c.device_id='${identity.device_id}' and c.version=1;
 insert into public.daily_grants select id,device_id,household_id,period_key,600 from public.commands where id='${late}';update public.device_policies set version=8 where device_id='${identity.device_id}';commit;`);
 await stage('yesterdayGrantNotCredited');
 ok((await readStatus()).json.find(x=>x.version===8).status==='expired_for_period','OLD_GRANT_OUTCOME_INCORRECT');
 sql(`update private.device_credentials set created_at=clock_timestamp()-interval '91 days',expires_at=clock_timestamp()-interval '1 second' where device_id='${identity.device_id}';`);
 await stage('expiredRetainsLedger');
 sql(`update private.device_credentials set expires_at=clock_timestamp()+interval '1 day' where device_id='${identity.device_id}';update public.devices set revoked_at=clock_timestamp() where id='${identity.device_id}';`);
 await stage('revokedRetainsUntilExplicitRemoval');
 evidence.overall='PASS_THIS_EMULATOR_ONLY';
}catch(e){primary=e;evidence.error=e.message;}
finally {
 try{for(const pkg of packages){await command(['shell','am','force-stop',pkg]);ok((await command(['shell','pm','clear',pkg])).includes('Success'),'CLEAR_FAILED')};evidence.cleanup='VERIFIED_OWN_APP_TEST_DATA_CLEARED'}
 catch{primary??=Error('CLEANUP_UNVERIFIED');evidence.overall='NOT_PASSED'}
 writeFileSync(report,JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify({overall:evidence.overall,cleanup:evidence.cleanup,report}));
}
if(primary)throw primary;
}
