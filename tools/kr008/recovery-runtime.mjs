// Local-only accounting tests: exact owner-manifest AVD, child packages, no physical discovery.
import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
const dir=process.env.KR006_RUNTIME_DIRECTORY;
if(!dir||!/^\/mnt\/c\/Users\/3feli\/AppData\/Local\/KidRemote\/kr006-runtime\/[a-f0-9-]{36}$/.test(dir))throw Error('TASK_DIRECTORY_REQUIRED');
const windows=p=>'C:'+p.slice(6).replaceAll('/','\\');
const owner=JSON.parse(readFileSync(join(dir,'owner.json'),'utf8').replace(/^\uFEFF/,''));
if(owner.Scope!=='KR006_RUNTIME'||owner.Directory!==windows(dir)||owner.AvdName!=='kr006_'+owner.Id.replaceAll('-','')||owner.Port!==5584||owner.Sdk!=='C:\\Users\\3feli\\AppData\\Local\\Android\\Sdk')throw Error('OWNER_UNVERIFIED');
const app='dev.kidremote.child.unassigned.debug',packages=[app,app+'.test'];
const adb='/mnt/c/Users/3feli/AppData/Local/Android/Sdk/platform-tools/adb.exe';
const report=join(dir,'kr008-recovery-'+new Date().toISOString().replaceAll(/[:.]/g,'-')+'.json');
const evidence={scope:'KR008_LOCAL_RECOVERY_EMULATOR',source:process.env.KR008_APK_SOURCE??'UNSPECIFIED',stages:[],hashes:{},overall:'NOT_PASSED',cleanup:'UNVERIFIED'};
function run(args,input){return new Promise(resolve=>{const p=spawn(adb,['-s','emulator-5584',...args],{stdio:[input===undefined?'ignore':'pipe','pipe','pipe']});let out='';const timer=setTimeout(()=>p.kill(),180000);p.stdout.on('data',x=>{if(out.length<1000000)out+=x});p.stderr.on('data',x=>{if(out.length<1000000)out+=x});p.on('error',()=>resolve({code:-1,out:''}));p.on('close',code=>{clearTimeout(timer);resolve({code,out})});if(input!==undefined)p.stdin.end(input)});}
async function guard(){const name=await run(['emu','avd','name']);if(name.code!==0||name.out.trim().split(/\r?\n/)[0].trim()!==owner.AvdName)throw Error('AVD_IDENTITY_UNVERIFIED');const q=await run(['shell','getprop','ro.kernel.qemu']);if(q.code!==0||q.out.trim()!=='1')throw Error('NOT_EMULATOR');}
async function command(args){await guard();const r=await run(args);if(r.code!==0)throw Error('TARGETED_COMMAND_FAILED');return r.out;}
let primary;
try {
 await guard();if((await command(['shell','getprop','ro.build.version.sdk'])).trim()!=='36')throw Error('API_MISMATCH');
 for(const [i,file] of ['child-debug.apk','child-debug-androidTest.apk'].entries()) {
  const path=join(dir,process.env.KR008_APK_BUNDLE??'apks-kr008-recovery',file);evidence.hashes[file]=createHash('sha256').update(readFileSync(path)).digest('hex');
  const exists=(await command(['shell','pm','list','packages',packages[i]])).replaceAll('\r','').trim().split('\n').includes('package:'+packages[i]);
  if(exists&&!(await command(['uninstall',packages[i]])).includes('Success'))throw Error('OWN_UNINSTALL_FAILED');
  if(!(await command(['install','-r','-t',windows(path)])).includes('Success'))throw Error('OWN_INSTALL_FAILED');
 }
 await command(['shell','run-as',app,'sh','-c','"mkdir -p no_backup && touch no_backup/sync-test-control"']);
 for(const method of ['completeAndIncompleteRecovery','prepareStorageFailure','restartStorageRecovery','trustedPeriodRecovery','killBeforeRecoveryCommit','afterRecoveryRollback','killAfterRecoveryCommit','afterRecoveryCommit','corruptRecoveryFailsClosed']) {
  await command(['shell','am','force-stop',app]);await guard();
  const r=await run(['shell','am','instrument','-w','-r','-e','class','dev.kidremote.child.accounting.AccountingRecoveryTest#'+method,app+'.test/androidx.test.runner.AndroidJUnitRunner']);
  const codes=[...r.out.matchAll(/kr008=([A-Z0-9_]+)/g)].map(m=>m[1]);
  const expected=method==='killBeforeRecoveryCommit'?'EXPECTED_KILL_RECOVERY_BEFORE_COMMIT':method==='killAfterRecoveryCommit'?'EXPECTED_KILL_RECOVERY_AFTER_COMMIT':null;
  let pass=r.code===0&&/OK \(1 test\)/.test(r.out)&&!/FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed/.test(r.out);
  if(expected) {
   const marker=(await command(['exec-out','run-as',app,'cat','no_backup/recovery-crash'])).trim();
   pass=marker===expected&&codes.includes(expected)&&/Process crashed/.test(r.out)&&!/OK \(1 test\)/.test(r.out);
  }
  const row={method,result:pass?(expected?'EXPECTED_PROCESS_DEATH':'PASS'):'FAIL',codes,hostExit:r.code};evidence.stages.push(row);console.log(JSON.stringify(row));
  if(!pass)throw Error('ACCOUNTING_STAGE_FAILED:'+method);
 }
 evidence.overall='PASS_THIS_EMULATOR_ONLY';
}catch(e){primary=e;evidence.error=e.message;}
finally {
 try{for(const pkg of packages){await command(['shell','am','force-stop',pkg]);if(!(await command(['shell','pm','clear',pkg])).includes('Success'))throw Error('CLEAR_FAILED')};evidence.cleanup='VERIFIED_OWN_APP_TEST_DATA_CLEARED';}
 catch{primary??=Error('CLEANUP_UNVERIFIED');evidence.overall='NOT_PASSED'}
 writeFileSync(report,JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify({overall:evidence.overall,cleanup:evidence.cleanup,report}));
}
if(primary)throw primary;
