import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {parseQR} from '../../supabase/functions/pairing/protocol.mjs';
export async function testEnrollmentRuntime(args){const {testAndroidRuntime}=await import('../kr006/android-runtime.mjs');await testAndroidRuntime({...args,enrollment:true});}
export async function exerciseEnrollment({command,run,guard,dir,windowsPath,app,test,evidence,sql,installFresh,apkDirectory='apks-kr007',cameraStorage=false,gatewayAvailable}) {
 const child='dev.kidremote.child.unassigned.debug';
 for(const [pkg,file] of [[child,'child-debug.apk'],[child+'.test','child-debug-androidTest.apk']]) {
  const path=join(dir,apkDirectory,file);evidence.apkHashes[pkg]=createHash('sha256').update(readFileSync(path)).digest('hex');
  await installFresh(pkg,path);
  if(!(await command(['shell','pm','clear',pkg])).includes('Success'))throw Error('CHILD_FRESH_STATE_FAILED');
 }
 async function stage(pkg,clazz,method) {
  await command(['shell','am','force-stop',pkg]);await guard();
  const r=await run(['shell','am','instrument','-w','-r','-e','class',clazz+'#'+method,pkg+'.test/androidx.test.runner.AndroidJUnitRunner'],240000);
  const passed=r.code===0&&/OK \(1 test\)/.test(r.out)&&!/FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed/.test(r.out);
  const codes=[...r.out.matchAll(/kr00[67]=([A-Z0-9_]+)/g)].map(x=>x[1]);
  const result={method,result:passed?'PASS':'FAIL',codes,hostExit:r.code};evidence.stages.push(result);console.log(JSON.stringify(result));
  if(!passed)throw Error('ENROLLMENT_ANDROID_FAILED:'+method);
 }
 await stage(app,'dev.kidremote.parent.ParentRuntimeTest','createEnrollmentQr');
 async function handoff(){
  const qr=(await command(['exec-out','run-as',app,'cat','no_backup/qr-handoff'])).trim();
  const parsed=parseQR(qr);if(!parsed)throw Error('HANDOFF_NOT_MINIMAL_QR');
  await guard();
  if((await run(['shell','run-as',child,'sh','-c','"mkdir -p no_backup && cat > no_backup/qr-handoff"'],10000,qr)).code!==0)throw Error('LOCAL_QR_HANDOFF_FAILED');
  return parsed.session_id;
 }
 const enrollmentSession=await handoff();
 await stage(child,'dev.kidremote.child.EnrollmentRuntimeTest','decodeRedeemAndRead');
 await stage(child,'dev.kidremote.child.EnrollmentRuntimeTest','restartAndNegatives');
 await stage(app,'dev.kidremote.parent.ParentRuntimeTest','parentSeesEnrollment');
 const count=sql("select count(*) from public.devices d join public.household_members m on m.household_id=d.household_id join auth.users u on u.id=m.user_id where u.email like 'kr006-runtime-%@example.test';");
 if(count.trim()!=='1')throw Error('NOT_EXACTLY_ONE_RUNTIME_DEVICE');
 evidence.enrollmentDeviceCount=1;evidence.cameraEvidence='GENERATED_QR_DECODER_INPUT_NOT_CAMERA_CAPTURE';
 if(process.env.KR007_REMOVAL_RUNTIME==='1') {
  const removal=method=>stage(child,'dev.kidremote.child.RemovalRuntimeTest',method);
  const counts=()=>sql("select count(*) from public.devices;select count(*) from private.device_credentials;");
  const before=counts();
  await removal('remember');
  await removal('unknown');
  await gatewayAvailable(false);
  try{await removal('offlineRestart');}finally{await gatewayAvailable(true);}
  sql("update private.device_credentials c set expires_at=clock_timestamp() from public.devices d join public.household_members m on m.household_id=d.household_id join auth.users u on u.id=m.user_id where c.device_id=d.id and u.email like 'kr006-runtime-%@example.test';");
  await removal('expired');
  const actor=sql("select u.id from auth.users u join public.household_members m on m.user_id=u.id where u.email like 'kr006-runtime-%@example.test';");
  if(!/^[a-f0-9-]{36}$/.test(actor))throw Error('REMOVAL_ACTOR_UNVERIFIED');
  const revoked=JSON.parse(sql(`set role authenticated;set "request.jwt.claim.sub"='${actor}';select public.finish_pairing('${enrollmentSession}',true);`));
  if(revoked.result!=='REVOKED_FRESH_QR_REQUIRED')throw Error('REMOVAL_NOT_REAL_PARENT_TRANSACTION');
  await removal('removed');
  await gatewayAvailable(false);
  try {
   await removal('removedOfflineRestart');
   await removal('invalidEnvelopesAndStorage');
   await removal('explicitClear');
   await removal('clearedOfflineRestart');
  }finally{await gatewayAvailable(true);}
  if(counts()!==before)throw Error('REMOVAL_CREATED_IDENTITY_OR_CREDENTIAL');
  evidence.removal='REAL_PARENT_SQL_GATEWAY_VALIDATED_REMOVAL_OFFLINE_RESTART_EXPLICIT_CLEAR';
  evidence.configuredPolicy='NOT_IMPLEMENTED_NOT_TESTED_KR009_BOUNDARY';
  return;
 }
 // AC-6: stored timestamp fixtures only, never host/emulator clocks. Real app contact drives renewal.
 const ageCurrent=()=>sql("update private.device_credentials c set created_at=clock_timestamp()-interval '31 days' from public.devices d join public.household_members m on m.household_id=d.household_id join auth.users u on u.id=m.user_id where c.device_id=d.id and c.revoked_at is null and u.email like 'kr006-runtime-%@example.test';");
 const rotations=()=>sql("select count(*) from private.credential_rotations r join public.devices d on d.id=r.device_id join public.household_members m on m.household_id=d.household_id join auth.users u on u.id=m.user_id where u.email like 'kr006-runtime-%@example.test';");
 ageCurrent();await stage(child,'dev.kidremote.child.RotationRuntimeTest','normal');
 for(const method of ['loseBegin','loseConfirm']) {
  ageCurrent();const before=Number(rotations());await stage(child,'dev.kidremote.child.RotationRuntimeTest',method);
  if(Number(rotations())!==before+1)throw Error('ROTATION_NOT_REAL_COMMIT');
  if(method==='loseBegin') {
   await gatewayAvailable(false);
   try{await stage(child,'dev.kidremote.child.RotationRuntimeTest','outageRetains');}finally{await gatewayAvailable(true);}
  }
  await stage(child,'dev.kidremote.child.RotationRuntimeTest','restartPending');
  if(Number(rotations())!==before+1)throw Error('ROTATION_RESTART_DUPLICATED_GENERATION');
 }
 await gatewayAvailable(false);
 try{await stage(child,'dev.kidremote.child.RotationRuntimeTest','outageRetains');}finally{await gatewayAvailable(true);}
 if(sql("select count(*) from public.devices d join public.household_members m on m.household_id=d.household_id join auth.users u on u.id=m.user_id where u.email like 'kr006-runtime-%@example.test';")!=='1')throw Error('ROTATION_DUPLICATE_DEVICE');
 evidence.rotation='REAL_APP_HTTP_DB:LOSS_AFTER_HTTP_BEFORE_RENEWAL_CONSUMPTION:PROCESS_RESTART:UNCHANGED_DEVICE';
 await stage(child,'dev.kidremote.child.EnrollmentRuntimeTest','corruptIdentityRecovery');
 await command(['shell','pm','clear',child]);
 await stage(app,'dev.kidremote.parent.ParentRuntimeTest','prepareInterruptedQr');
 const interrupted=await handoff();
 await stage(child,'dev.kidremote.child.EnrollmentRuntimeTest','interruptAfterCommit');
 if(sql(`select count(*) from private.pairing_sessions where id='${interrupted}' and consumed_at is not null;`)!=='1')throw Error('INTERRUPTION_NOT_COMMITTED');
 await stage(child,'dev.kidremote.child.EnrollmentRuntimeTest','interruptedRestart');
 await stage(app,'dev.kidremote.parent.ParentRuntimeTest','recoverInterruptedQr');
 if(sql(`select count(*) from private.pairing_sessions s join public.devices d on d.id=s.device_id where s.id='${interrupted}' and d.revoked_at is not null;`)!=='1')throw Error('LOST_IDENTITY_NOT_REVOKED');
 const fresh=await handoff();if(fresh===interrupted)throw Error('NOT_FRESH_QR');
 await stage(child,'dev.kidremote.child.EnrollmentRuntimeTest','recoverWithFreshQr');
 await stage(child,'dev.kidremote.child.EnrollmentRuntimeTest','restartAndNegatives');
 evidence.interruptedCommitRecovery='ACTUAL_COMMIT_TEST_FAULT_BEFORE_PERSIST_REVOKE_FRESH_QR';

 if(cameraStorage){const {exerciseCameraStorage}=await import('./camera-storage-runtime.mjs');await exerciseCameraStorage({command,run,guard,dir,windowsPath,app,child,evidence,sql,installFresh,stage,apkDirectory,gatewayAvailable});}

 // Final synthetic identity: no valid credential may be revived by app contact.
 sql("update private.device_credentials c set expires_at=clock_timestamp() from public.devices d join public.household_members m on m.household_id=d.household_id join auth.users u on u.id=m.user_id where c.device_id=d.id and c.revoked_at is null and u.email like 'kr006-runtime-%@example.test';");
 await stage(child,'dev.kidremote.child.RotationRuntimeTest','expiredRetains');
 sql("update public.devices d set revoked_at=clock_timestamp() from public.household_members m join auth.users u on u.id=m.user_id where m.household_id=d.household_id and u.email like 'kr006-runtime-%@example.test';");
 await stage(child,'dev.kidremote.child.RotationRuntimeTest','revokedRetains');
 evidence.expiredRevoked='ACTUAL_APP_HTTP_DENIAL_ENCRYPTED_IDENTITY_RETAINED';
}
