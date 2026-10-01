// Explicit native Windows test adapter; only the already-owned emulator is addressed.
// Default: Android loopback fixture. Connected modes: new isolated real backend; enrollment originates in Android, no credential handoff.
import {spawn,spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdtempSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createHash,randomUUID,randomBytes} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createServer} from 'node:net';
import {Lease,dockerCall,startGateway} from '../enforcement/physical-lab/lease.mjs';
import {health} from '../enforcement/physical-lab/health.mjs';
const check=(ok,code)=>{if(!ok)throw Error(code)};
const task=join(process.env.LOCALAPPDATA??'','KidRemote','kr006-runtime','e03b4820-193b-4132-b1fc-f7950eeed7fe');
const connected=['--connected','--connected-service'].includes(process.argv[3]);
const serviceMode=process.argv[3]==='--connected-service';
const apks=resolve(process.argv[2]??'');
check(process.platform==='win32'&&(process.argv.length===3||(process.argv.length===4&&connected))&&apks.startsWith(task+'\\'),'NATIVE_OWNED_APKS_REQUIRED');
const owner=JSON.parse(readFileSync(join(task,'owner.json'),'utf8').replace(/^\uFEFF/,''));
check(owner.Scope==='KR006_RUNTIME'&&owner.Directory===task&&owner.Port===5584&&owner.AvdName==='kr006_'+owner.Id.replaceAll('-',''),'OWNER_UNVERIFIED');
check(owner.Sdk==='C:\\Users\\3feli\\AppData\\Local\\Android\\Sdk','SDK_OWNER_MISMATCH');
const adb=join(owner.Sdk,'platform-tools','adb.exe'),target='emulator-5584',app='dev.kidremote.child.unassigned.debug';
const artifacts=JSON.parse(readFileSync(join(apks,'source.json'),'utf8'));
check(/^[a-f0-9]{40}$/.test(artifacts.source),'APK_SOURCE_REQUIRED');
const sha=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
for(const name of ['child-debug.apk','child-debug-androidTest.apk'])check(sha(join(apks,name))===artifacts.apks[name],'APK_HASH_MISMATCH');
function raw(args){return spawnSync(adb,['-s',target,...args],{encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:1024*1024});}
function guard(){const n=raw(['emu','avd','name']),q=raw(['shell','getprop','ro.kernel.qemu']);check(n.status===0&&n.stdout.trim().split(/\r?\n/)[0].trim()===owner.AvdName&&q.status===0&&q.stdout.trim()==='1','EMULATOR_IDENTITY_UNVERIFIED');}
function command(args){guard();const r=raw(args);check(!r.error&&r.status===0,'EMULATOR_COMMAND_FAILED');return r.stdout;}
function absent(name){guard();const r=raw(['shell','run-as',app,'test','-f','no_backup/'+name]);return r.status===1;}
const dir=mkdtempSync(join(task,'first-policy-observation-'));
const evidence={scope:connected?'NATIVE_OWNED_EMULATOR_REAL_FIRST_POLICY':'NATIVE_OWNED_EMULATOR_LOOPBACK_FIXTURE',source:artifacts.source,workingTreeChanged:artifacts.workingTreeChanged,apks:artifacts.apks,stages:[],physicalDeviceInvoked:false,backendInvoked:false,driverSha256:sha(fileURLToPath(import.meta.url)),testSources:artifacts.testSources??{},status:'NOT_PASSED',cleanup:'UNVERIFIED'};
let lease,gateway,originalBytes,originalPath,call;
async function backend(){
 originalPath=join(process.env.LOCALAPPDATA,'KidRemote','physical-lab','resources.json');originalBytes=readFileSync(originalPath);
 const original=JSON.parse(originalBytes),docker=join(process.env.LOCALAPPDATA,'Programs','DockerDesktop','resources','bin','docker.exe'),host='npipe:////./pipe/dockerDesktopLinuxEngine';
 call=dockerCall(docker,host);
 for(const id of Object.values(original.containers)){const x=JSON.parse(call(['inspect',id]))[0];check(x.Id===id&&!x.State.Running&&x.Config.Labels['org.kidremote.physical-lab']===original.id,'ORIGINAL_LAB_NOT_STOPPED');}
 for(const port of [47361,47362,47365,47366]){const socket=createServer();await new Promise((yes,no)=>{socket.once('error',no);socket.listen(port,'127.0.0.1',yes)});await new Promise(r=>socket.close(r));}
 lease=new Lease({root:fileURLToPath(new URL('../../',import.meta.url)),state:join(dir,'resources.json'),source:artifacts.source,id:randomUUID(),call,secrets:{database:randomBytes(32).toString('hex'),jwt:randomBytes(48).toString('hex'),parentPassword:randomBytes(32).toString('hex')+'aA1!',probePassword:randomBytes(32).toString('hex')+'aA1!'}});
 evidence.backendInvoked=true;check(await lease.start()==='CREATED','NEW_LEASE_REQUIRED');gateway=await startGateway(lease,docker,host);await health(lease);
}
try {
 guard();check(command(['shell','getprop','ro.build.version.sdk']).trim()==='36','API_MISMATCH');
 check(!command(['shell','settings','get','secure','enabled_accessibility_services']).includes(app),'PRIOR_SERVICE_ACTIVE');
 for(const name of ['device-identity','accounting.db','sync-retry'])check(absent(name),'PRIOR_EMULATOR_STATE_PRESENT');
 for(const name of ['child-debug.apk','child-debug-androidTest.apk'])check(command(['install','-r','-t',join(apks,name)]).includes('Success'),'INSTALL_FAILED');
 if(connected)await backend();
 for(const mode of (connected?[serviceMode?'connected-service':'connected']:['foreground','deadline'])){
  guard();const row={mode,status:'NOT_PASSED',started:new Date().toISOString()};evidence.stages.push(row);
  const p=spawn(adb,['-s',target,'shell','am','instrument','-w','-r','-e','class',(connected?'dev.kidremote.child.sync.ConnectedFirstPolicyRuntimeTest#bootstrapThroughRealGateway':'dev.kidremote.child.sync.FirstPolicyRuntimeTest#bootstrapForegroundAndBackoff'),'-e','first_policy_mode',mode,app+'.test/androidx.test.runner.AndroidJUnitRunner'],{stdio:['ignore','pipe','pipe'],windowsHide:true});
  let output='',overflow=false;for(const pipe of [p.stdout,p.stderr])pipe.on('data',b=>{if(output.length+b.length<=1024*1024)output+=b;else overflow=true});
  const timer=setTimeout(()=>{p.kill();},180000);
  const code=await new Promise(resolve=>{p.on('error',()=>resolve(-1));p.on('close',resolve)});clearTimeout(timer);
  row.exitCode=code;row.finished=new Date().toISOString();row.codes=[...output.matchAll(/firstpolicy=([A-Z0-9_]+)/g)].map(x=>x[1]);
  // Read only this instrumentation-generated report, never real app credentials or logs.
  const text=command(['exec-out','run-as',app,'cat','no_backup/first-policy-result.json']);check(text.length<=4096,'RESULT_BOUNDS');
  const observed=JSON.parse(text);const fields=['scope','physicalAcceptance','mode','serviceConnected','serviceSettingsCleanup','enrollmentConfirmed','serverReportVersion','serverRestrictionApplied','localAckConfirmed','observedMsAfterParentCommit','bootstrapResponses','initialAccountingAbsent','controlledRetryDelayMs','topLaunchStatusOk','topLaunchReused','withinInitialWindow','resumeCallbacksAfterTopLaunch','responsesAfterTopLaunch','converged','localFixtureAckConfirmed','fixtureAckRequests','responseCount','totalResumeCallbacks','observedMsAfterFixtureCommit','status','failureStage','failureLine'];
  check(Object.keys(observed).every(k=>fields.includes(k))&&observed.scope===(connected?'EMULATOR_REAL_GATEWAY_FIRST_POLICY':'EMULATOR_LIFECYCLE_LOOPBACK_FIXTURE')&&observed.mode===mode,'RESULT_SCHEMA');row.observation=observed;
  check(!overflow&&code===0&&/OK \(1 test\)/.test(output)&&!/FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed/.test(output)&&observed.status==='PASS','INSTRUMENTATION_FAILED');
  row.status='PASS';console.log(JSON.stringify(row));
  for(const pkg of [app,app+'.test']){command(['shell','am','force-stop',pkg]);check(command(['shell','pm','clear',pkg]).includes('Success'),'OWN_TEST_CLEANUP_FAILED');}
  check(absent('device-identity')&&absent('sync-retry')&&absent('accounting.db'),'OWN_TEST_CLEANUP_UNVERIFIED');row.cleanup='OWN_SYNTHETIC_APP_DATA_CLEARED';
 }
 evidence.status='PASS';evidence.cleanup='OWN_SYNTHETIC_APP_DATA_CLEARED';
}catch(e){evidence.failure=/^[A-Z0-9_]+$/.test(e.message)?e.message:'UNCLASSIFIED';process.exitCode=1;}
finally{
 if(gateway&&gateway.exitCode===null){const stopped=new Promise(r=>gateway.once('exit',r));gateway.kill();await stopped;}
 if(lease){try{lease.teardown(()=>{});evidence.backendCleanup='NEW_SYNTHETIC_LEASE_REMOVED';}catch{evidence.backendCleanup='UNVERIFIED';evidence.status='NOT_PASSED';process.exitCode=1;}}
 if(originalBytes){try{check(readFileSync(originalPath).equals(originalBytes),'ORIGINAL_RESOURCE_CHANGED');const old=JSON.parse(originalBytes);for(const id of Object.values(old.containers)){const x=JSON.parse(call(['inspect',id]))[0];check(x.Id===id&&!x.State.Running,'ORIGINAL_LAB_CHANGED');}evidence.originalLabUnchanged=true;}catch{evidence.originalLabUnchanged=false;evidence.status='NOT_PASSED';process.exitCode=1;}}
 writeFileSync(join(dir,'result.json'),JSON.stringify(evidence,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({scope:evidence.scope,status:evidence.status,cleanup:evidence.cleanup,resultDirectory:dir,...(evidence.failure?{failure:evidence.failure}:{})}));}
