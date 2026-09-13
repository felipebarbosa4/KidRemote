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
const report=join(dir,'kr008-update-'+new Date().toISOString().replaceAll(/[:.]/g,'-')+'.json');
const bundle=join(dir,'apks-kr008-update-'+process.env.KR008_UPDATE_SOURCE?.slice(0,7));
const manifest=JSON.parse(readFileSync(join(bundle,'update-apks.json'),'utf8'));
if(!/^[a-f0-9]{40}$/.test(process.env.KR008_UPDATE_SOURCE??'')||manifest.source!==process.env.KR008_UPDATE_SOURCE)throw Error('SOURCE_UNVERIFIED');
const evidence={scope:'KR008_REAL_APK_UPDATE_EMULATOR',manifest,stages:[],overall:'NOT_PASSED',cleanup:'UNVERIFIED'};
function run(args,input){return new Promise(resolve=>{const p=spawn(adb,['-s','emulator-5584',...args],{stdio:[input===undefined?'ignore':'pipe','pipe','pipe']});let out='';const timer=setTimeout(()=>p.kill(),180000);p.stdout.on('data',x=>{if(out.length<1000000)out+=x});p.stderr.on('data',x=>{if(out.length<1000000)out+=x});p.on('error',()=>resolve({code:-1,out:''}));p.on('close',code=>{clearTimeout(timer);resolve({code,out})});if(input!==undefined)p.stdin.end(input)});}
async function guard(){const name=await run(['emu','avd','name']);if(name.code!==0||name.out.trim().split(/\r?\n/)[0].trim()!==owner.AvdName)throw Error('AVD_IDENTITY_UNVERIFIED');const q=await run(['shell','getprop','ro.kernel.qemu']);if(q.code!==0||q.out.trim()!=='1')throw Error('NOT_EMULATOR');}
async function command(args){await guard();const r=await run(args);if(r.code!==0)throw Error('TARGETED_COMMAND_FAILED');return r.out;}
for(const file of ['pre-v1.apk','post-v2.apk','update-test.apk']) {
 if(createHash('sha256').update(readFileSync(join(bundle,file))).digest('hex')!==manifest.apks[file]?.sha256)throw Error('APK_HASH_MISMATCH');
}
if(manifest.apks['pre-v1.apk'].versionCode!==1||manifest.apks['post-v2.apk'].versionCode!==2||new Set(Object.values(manifest.apks).map(x=>x.certificate)).size!==1)throw Error('UPDATE_VERSION_OR_SIGNER_MISMATCH');
let primary,scenario;
function record(row){evidence.stages.push({scenario,...row});console.log(JSON.stringify({scenario,...row}));}
async function stage(method,expectedKill=false) {
 await command(['shell','am','force-stop',app]);await guard();
 const r=await run(['shell','am','instrument','-w','-r','-e','class','dev.kidremote.child.accounting.AccountingUpdateTest#'+method,app+'.test/androidx.test.runner.AndroidJUnitRunner']);
 const codes=[...r.out.matchAll(/kr008=([A-Z0-9_]+)/g)].map(m=>m[1]);
 let pass=r.code===0&&/OK \(1 test\)/.test(r.out)&&!/FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed/.test(r.out);
 if(expectedKill) {
  const marker=(await command(['exec-out','run-as',app,'cat','no_backup/update-crash'])).trim();
  pass=marker==='EXPECTED_KILL_DURING_MIGRATION'&&codes.includes(marker)&&/Process crashed/.test(r.out)&&!/OK \(1 test\)/.test(r.out);
 }
 record({method,result:pass?(expectedKill?'EXPECTED_PROCESS_DEATH':'PASS'):'FAIL',codes,hostExit:r.code});
 if(!pass)throw Error('UPDATE_STAGE_FAILED:'+method);
}
async function install(file){if(!(await command(['install','-r','-t',windows(join(bundle,file))])).includes('Success'))throw Error('INSTALL_FAILED');}
try {
 await guard();if((await command(['shell','getprop','ro.build.version.sdk'])).trim()!=='36')throw Error('API_MISMATCH');
 for(scenario of ['CURRENT_SCHEMA','LEGACY_SCHEMA_MIGRATION']) {
  // Independent synthetic scenario setup ONLY. No uninstall/clear between prepare and final verification.
  for(const pkg of [...packages].reverse()) {
   const exists=(await command(['shell','pm','list','packages',pkg])).replaceAll('\r','').trim().split('\n').includes('package:'+pkg);
   if(exists&&!(await command(['uninstall',pkg])).includes('Success'))throw Error('FIXTURE_UNINSTALL_FAILED');
  }
  await install('pre-v1.apk');await install('update-test.apk');
  await stage(scenario==='CURRENT_SCHEMA'?'prepareCurrent':'prepareLegacy');
  await install('post-v2.apk');record({method:'install-r-v1-to-v2',result:'PASS_DATA_RETAINING_APK_REPLACEMENT'});
  await stage('verifyReplacement');
  if(scenario==='CURRENT_SCHEMA')await stage('currentSchemaNeedsNoMigration');
  else {
   await stage('refuseMissingMigration');await stage('killDuringMigration',true);
   await stage('verifyMigrationRollback');await stage('completeMigrationAndReopen');
  }
  await stage('reconcileAfterUpdate');
  await guard();const down=await run(['install','-r','-t',windows(join(bundle,'pre-v1.apk'))]);
  const refused=down.code!==0&&/INSTALL_FAILED_VERSION_DOWNGRADE/.test(down.out);
  record({method:'apk-downgrade-without-override',result:refused?'EXPECTED_REFUSAL':'FAIL',hostExit:down.code});
  if(!refused)throw Error('DOWNGRADE_NOT_REFUSED');
  await stage('verifyRefusedApkDowngrade');
 }
 evidence.overall='PASS_THIS_EMULATOR_ONLY';
}catch(e){primary=e;evidence.error=e.message;}
finally {
 try{for(const pkg of packages){await command(['shell','am','force-stop',pkg]);if(!(await command(['shell','pm','clear',pkg])).includes('Success'))throw Error('CLEAR_FAILED')};evidence.cleanup='VERIFIED_OWN_APP_TEST_DATA_CLEARED';}
 catch{primary??=Error('CLEANUP_UNVERIFIED');evidence.overall='NOT_PASSED'}
 writeFileSync(report,JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify({overall:evidence.overall,cleanup:evidence.cleanup,report}));
}
if(primary)throw primary;
