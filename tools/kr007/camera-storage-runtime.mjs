// Bounded continuation of the existing owned-emulator enrollment test, not a camera simulator.
import {mkdirSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
export async function exerciseCameraStorage({command,run,guard,dir,windowsPath,app,child,evidence,sql,installFresh,stage,apkDirectory,gatewayAvailable}) {
 const clazz='dev.kidremote.child.CameraStorageRuntimeTest';
 const local=join(dir,'camera-storage-'+new Date().toISOString().replaceAll(/[:.]/g,'-'));mkdirSync(local);
 evidence.cameraStorage={scope:'SYNTHETIC_OWNED_EMULATOR_ONLY',localArtifacts:local,camera:'UNRUN',storage:'UNRUN',posterCleanup:'UNRUN'};
 const count=()=>sql('select count(*) from public.devices;');
 const before=count();
 async function readOwned(pkg,file) {
  await guard();const r=await run(['exec-out','run-as',pkg,'cat','no_backup/'+file],10000,undefined,true);
  if(r.code!==0||r.out.length===0||r.out.length>=1000000)throw Error('LOCAL_BINARY_READ_FAILED');return r.out;
 }
 async function writeOwned(file,bytes) {
  await guard();const r=await run(['shell','run-as',child,'sh','-c','"mkdir -p no_backup && cat > no_backup/'+file+'"'],10000,bytes);
  if(r.code!==0)throw Error('LOCAL_BINARY_RESTORE_FAILED');
 }
 async function marker(file) {
  return (await command(['shell','run-as',child,'sh','-c','"test -f no_backup/'+file+' && echo READY || echo WAIT"'])).trim()==='READY';
 }
 const cipher=await readOwned(child,'device-identity');writeFileSync(join(local,'synthetic-identity.ciphertext'),cipher);
 evidence.cameraStorage.ciphertextHash=createHash('sha256').update(cipher).digest('hex');
 await gatewayAvailable(false);
 let restored=false,outageFailure;
 const caught=stage(child,clazz,'backendOutagePreservesIdentity').then(()=>null,e=>e);
 try {
  for(let i=0;i<45;i++){await pause(500);if(await marker('gateway-restore-ready')){await gatewayAvailable(true);restored=true;break;}}
  if(!restored)throw Error('OUTAGE_RESTORE_MARKER_MISSING');
 } catch(e){outageFailure=e;}
 finally {
  if(!restored)try{await gatewayAvailable(true);}catch(e){outageFailure??=e;}
 }
 const outageResult=await caught;if(outageResult)throw outageResult;if(outageFailure)throw outageFailure;
 await stage(child,clazz,'authenticatedCiphertextCorruption');
 await stage(child,clazz,'missingKeyDiagnostic');
 await installFresh(child,join(dir,apkDirectory,'child-debug.apk'));
 await writeOwned('device-identity',cipher);
 await stage(child,clazz,'isolatedCiphertextWithoutKey');
 if(count()!==before)throw Error('STORAGE_FAILURE_CREATED_IDENTITY');
 evidence.cameraStorage.storage='PASS_NO_NEW_DEVICE';
 await command(['shell','pm','clear',child]);
 // Native virtual scene only. No host camera, screenshot, decoder input, or scene reconstruction.
 async function poster(surface,path) {
  const out=await command(['emu','virtualscene-image',surface,...(path?[windowsPath(path)]:[])]);
  if(!/\bOK\b/.test(out)||/\bKO\b/.test(out))throw Error('NATIVE_VIRTUAL_SCENE_REJECTED');
 }
 try {
  await poster('wall');await poster('table');
  await stage(child,clazz,'permissionAndLifecycle');
  await command(['shell','am','force-stop',child]);await guard();
  const pending=run(['shell','am','instrument','-w','-r','-e','class',clazz+'#revocationVictim',child+'.test/androidx.test.runner.AndroidJUnitRunner'],90000);
  let ready=false;for(let i=0;i<40;i++){await pause(500);if(await marker('camera-revoke-ready')){ready=true;break;}}
  if(!ready){await pending;throw Error('CAMERA_REVOCATION_PRECONDITION_MISSING');}
  await command(['shell','pm','revoke',child,'android.permission.CAMERA']);
  const interrupted=await pending;
  const killed=(await run(['shell','pidof',child],10000)).out.trim()==='';
  evidence.cameraStorage.revocation={cameraOpenMarker:true,osProcessAbsent:killed,instrumentationCompleted:/OK \(1 test\)/.test(interrupted.out),expectedTermination:true};
  if(!killed||evidence.cameraStorage.revocation.instrumentationCompleted)throw Error('EXPECTED_REVOKE_TERMINATION_NOT_ESTABLISHED');
  await stage(child,clazz,'afterPermissionRevocation');
  if(count()!==before)throw Error('PERMISSION_FLOW_CREATED_IDENTITY');
  await stage(app,'dev.kidremote.parent.ParentRuntimeTest','prepareCameraQr');
  for(const kind of ['invalid','valid']) {
   const bytes=await readOwned(app,'scene-'+kind+'.png');
   if(!bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))throw Error('NOT_SYNTHETIC_PNG');
   const path=join(local,'scene-'+kind+'.png');writeFileSync(path,bytes);
   evidence.cameraStorage[kind+'SceneHash']=createHash('sha256').update(bytes).digest('hex');
   await poster('wall',path);await poster('table',path);
   await stage(child,clazz,kind+'CameraQr');
   if(count()!==(kind==='invalid'?before:String(Number(before)+1)))throw Error('CAMERA_REDEMPTION_COUNT');
  }
  await stage(child,clazz,'sameIdentityAfterCameraRestart');
  evidence.cameraStorage.camera='PASS_NATIVE_VIRTUAL_SCENE_CAMERAX_REAL_HTTP_DB';
 } catch(e) {evidence.cameraStorage.camera='NOT_PASSED';throw e;}
 finally {
  try{await poster('wall');await poster('table');evidence.cameraStorage.posterCleanup='VERIFIED_DEFAULTS_RESTORED';}
  catch{evidence.cameraStorage.posterCleanup='UNVERIFIED';}
 }
 if(evidence.cameraStorage.posterCleanup!=='VERIFIED_DEFAULTS_RESTORED')throw Error('POSTER_CLEANUP_UNVERIFIED');
}
