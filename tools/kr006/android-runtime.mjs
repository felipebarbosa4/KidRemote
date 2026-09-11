// Opt-in only: one manifest-verified Windows emulator. No discovery/global ADB commands.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
const app='dev.kidremote.parent.unassigned.debug';
const test=app+'.test';
const delay=ms=>new Promise(r=>setTimeout(r,ms));
export async function testAndroidRuntime({restAvailable,sql,enrollment=false,gatewayAvailable}) {
 const dir=process.env.KR006_RUNTIME_DIRECTORY;
 if(!dir || !/^\/mnt\/c\/Users\/3feli\/AppData\/Local\/KidRemote\/kr006-runtime\/[a-f0-9-]{36}$/.test(dir))throw Error('RUNTIME_DIRECTORY_REQUIRED');
 const state=JSON.parse(readFileSync(join(dir,'owner.json'),'utf8').replace(/^\uFEFF/,''));
 const windowsPath=p=>'C:'+p.slice('/mnt/c'.length).replaceAll('/','\\');
 if(state.Scope!=='KR006_RUNTIME'||state.Directory!==windowsPath(dir)||state.AvdName!=='kr006_'+state.Id.replaceAll('-','')||state.Port!==5584 ||
    state.Sdk!=='C:\\Users\\3feli\\AppData\\Local\\Android\\Sdk')throw Error('RUNTIME_OWNER_UNVERIFIED');
 const adb='/mnt/c/Users/3feli/AppData/Local/Android/Sdk/platform-tools/adb.exe';
 const serial='emulator-5584';
 function run(args,timeout=180000,input,binary=false) {
  return new Promise(resolve=>{
   const p=spawn(adb,['-s',serial,...args],{stdio:[input===undefined?'ignore':'pipe','pipe','pipe']});
   if(input!==undefined)p.stdin.end(input);
   let out='',timer;const chunks=[];let bytes=0;const finish=(code)=>{clearTimeout(timer);resolve({code,out:binary?Buffer.concat(chunks):out});};
   p.stdout.on('data',x=>{if(binary){bytes+=x.length;if(bytes<=1000000)chunks.push(x);else p.kill();}else if(out.length<1000000)out+=x});p.stderr.on('data',x=>{if(!binary&&out.length<1000000)out+=x});
   p.on('error',()=>finish(-1));p.on('close',finish);
   timer=setTimeout(()=>{p.kill();},timeout);
  });
 }
 async function guard() {
  const n=await run(['emu','avd','name'],10000);
  if(n.code!==0||n.out.replaceAll('\r','').trim().split('\n')[0]!==state.AvdName)throw Error('EMULATOR_AVD_IDENTITY_UNVERIFIED');
  const q=await run(['shell','getprop','ro.kernel.qemu'],10000);
  if(q.code!==0||q.out.trim()!=='1')throw Error('NOT_VERIFIED_EMULATOR');
 }
 async function command(args){await guard();const r=await run(args);if(r.code!==0)throw Error('TARGETED_ANDROID_OPERATION_REJECTED');return r.out;}
 const ownedPackages=[app,test,...(enrollment?['dev.kidremote.child.unassigned.debug','dev.kidremote.child.unassigned.debug.test']:[])];
 async function installed(pkg) {
  if(!ownedPackages.includes(pkg))throw Error('PACKAGE_NOT_TASK_OWNED');
  return (await command(['shell','pm','list','packages',pkg])).replaceAll('\r','').trim().split('\n').includes('package:'+pkg);
 }
 async function installFresh(pkg,path) {
  // Different CI jobs use different debug signing keys. This fresh synthetic test
  // may replace only its exact packages on the already owner-verified task AVD.
  if(await installed(pkg))if(!(await command(['uninstall',pkg])).includes('Success'))throw Error('OWN_PACKAGE_REINSTALL_FAILED');
  if(!(await command(['install','-r','-t',windowsPath(path)])).includes('Success'))throw Error('APK_INSTALL_FAILED');
 }
 const evidence={scope:enrollment?'KR007_ENROLLMENT_EMULATOR_ONLY':'KR006_EMULATOR_ONLY',avd:state.AvdName,serial,stages:[],primary:'UNRUN',cleanup:'UNRUN',apkHashes:{}};
 const report=join(dir,'results-'+new Date().toISOString().replaceAll(/[:.]/g,'-')+'.json');
 const cameraStorage=enrollment&&process.env.KR007_CAMERA_STORAGE==='1';
 const apkDirectory=cameraStorage?'apks-kr007-camera':enrollment?'apks-kr007':'apks';
 let primary,networkRestored=true;
 try {
  await guard();
  for(const key of ['ro.build.version.sdk','ro.build.version.release','ro.build.fingerprint']) evidence[key]=(await command(['shell','getprop',key])).trim();
  if(evidence['ro.build.version.sdk']!=='36')throw Error('EMULATOR_API_MISMATCH');
  for(const [name,file] of [['app','app-debug.apk'],['test','app-debug-androidTest.apk']]) {
   const path=join(dir,apkDirectory,file);evidence.apkHashes[name]=createHash('sha256').update(readFileSync(path)).digest('hex');
   await installFresh(name==='app'?app:test,path);
  }
  // Only this dedicated task AVD and these two synthetic packages; never another app/profile.
  for(const pkg of [app,test]) {if(!(await command(['shell','pm','clear',pkg])).includes('Success'))throw Error('FRESH_RUNTIME_STATE_UNVERIFIED');}
  for(const method of ['enrollAndPersist','restoreAndLogout','restartLoggedOutAndRecover','networkFailureAndRecovery']) {
   await command(['shell','am','force-stop',app]);
   if(method==='networkFailureAndRecovery'){restAvailable(false);networkRestored=false;}
   await guard();
   let done=false;
   const execution=run(['shell','am','instrument','-w','-r','-e','class','dev.kidremote.parent.ParentRuntimeTest#'+method,test+'/androidx.test.runner.AndroidJUnitRunner'],240000).then(r=>{done=true;return r;});
   if(!networkRestored) {
    for(let i=0;i<100&&!done;i++) {
     await delay(1000);
     const marker=await command(['shell','run-as',app,'sh','-c','"test -f files/kr006-restore-rest && echo RESTORE || echo WAIT"']);
     if(marker.trim()==='RESTORE'){restAvailable(true);networkRestored=true;break;}
    }
   }
   const r=await execution;
   const codes=[...r.out.matchAll(/kr006=([A-Z0-9_]+)/g)].map(m=>m[1]);
   const passed=r.code===0&&/OK \(1 test\)/.test(r.out)&&!/FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed/.test(r.out);
   evidence.stages.push({method,result:passed?'PASS':'FAIL',codes,hostExit:r.code});
   console.log(JSON.stringify(evidence.stages.at(-1)));
   if(!passed)throw Error('ANDROID_RUNTIME_STAGE_FAILED:'+method);
  }
  const count=sql("select count(*) from public.household_members m join auth.users u on u.id=m.user_id where u.email like 'kr006-runtime-%@example.test';");
  if(count.trim()!=='1')throw Error('RUNTIME_SOLE_HOUSEHOLD_COUNT_FAILED');
  if(enrollment) {
   const {exerciseEnrollment}=await import('../kr007/android-runtime.mjs');
   await exerciseEnrollment({command,run,guard,dir,windowsPath,app,test,evidence,sql,installFresh,apkDirectory,cameraStorage,gatewayAvailable});
  }
  evidence.primary='PASS_THIS_EMULATOR_ONLY';
 } catch(e) {primary=e;evidence.primary=e.message;}
 finally {
  try {
   if(!networkRestored)restAvailable(true);
   await command(['shell','am','force-stop',app]);
   for(const pkg of [app,test,...(enrollment?['dev.kidremote.child.unassigned.debug','dev.kidremote.child.unassigned.debug.test']:[])]) {
    if(!await installed(pkg))continue;
    await command(['shell','am','force-stop',pkg]);
    if(!(await command(['shell','pm','clear',pkg])).includes('Success'))throw Error('CLEAR_FAILED');}
   evidence.cleanup='VERIFIED_SYNTHETIC_APP_AND_TEST_DATA_CLEARED';
  } catch {evidence.cleanup='UNVERIFIED';primary??=Error('RUNTIME_CLEANUP_UNVERIFIED');}
  evidence.overall=primary?'NOT_PASSED':'PASS_THIS_EMULATOR_ONLY';
  mkdirSync(dir,{recursive:true});writeFileSync(report,JSON.stringify(evidence,null,2)+'\n');
  console.log(JSON.stringify({runtimeResult:evidence.primary,cleanup:evidence.cleanup,report}));
 }
 if(primary)throw primary;
}
