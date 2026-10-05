import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync,readdirSync} from 'node:fs';
import {createControlHandler} from '../../supabase/functions/control/handler.mjs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const device='90000000-0000-4000-8000-000000000001',id='90000000-0000-4000-8000-000000000002';
const body={protocol_version:1,operation_id:id,device_id:device,kind:'LOCK',payload:{},expected_version:0};
const req=(b=body,token='a.b.c')=>new Request('http://127.0.0.1/parent/devices/'+device+'/operations',{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},body:JSON.stringify(b)});
test('parent boundary requires JWT verification before existing transaction',async()=>{let calls=0;const h=createControlHandler({verify:async()=>false,rpc:async()=>{calls++;}});assert.equal((await h(req())).status,401);assert.equal((await h(req(body,'a'.repeat(43)))).status,401);assert.equal(calls,0)});
test('parent route rejects timestamp/actor and invalid version schema',async()=>{const h=createControlHandler({verify:async()=>true,rpc:async()=>{throw Error('NOT_EXPECTED')}});for(const b of [{...body,actor_user_id:id},{...body,client_time:1},{...body,expected_version:'1'},{...body,device_id:id}])assert.equal((await h(req(b))).status,400)});
test('transaction conflict returns bounded rejected status, no dependency error leakage',async()=>{const h=createControlHandler({verify:async()=>true,rpc:async()=>({ok:false,value:{message:'OPERATION_CONFLICT',details:'hidden'}})});const r=await h(req());assert.equal(r.status,409);assert.deepEqual(await r.json(),{status:'rejected',code:'OPERATION_CONFLICT'})});
test('accepted is not persisted or applied',async()=>{const h=createControlHandler({verify:async()=>true,rpc:async()=>({ok:true,value:{status:'accepted'}})});assert.deepEqual(await(await h(req())).json(),{status:'accepted'})});
test('no provider/package history in sync; applied derives from explicit adapter observation',()=>{const root='apps/child-android/src/main/java/dev/kidremote/child/sync/';for(const f of readdirSync(new URL('../../'+root,import.meta.url))){assert.doesNotMatch(read(root+f),/Firebase|FCM|UsageStatsManager|packageName|Log\.|println|AccessibilityService/)}assert.match(read(root+'DeviceSync.kt'),/put\("restriction_applied",observed.applied\(s\)\)/)});
test('sync test modes never keep services or invoke prior camera runtime',()=>{const s=read('tools/kr004/test-local-db.mjs');assert.match(s,/keep:\['--parent-dev','--enrollment-dev'\]\.includes/);assert.match(s,/syncRuntime:options\[2\]==='--sync-runtime'/);const r=read('tools/kr009/android-runtime.mjs');assert.match(r,/OWNER_UNVERIFIED/);assert.match(r,/ro.kernel.qemu/);assert.doesNotMatch(r,/camera|logcat|screencap|kill-server|devices -l/)});

// Source/capability audits only; actual emulator execution is recorded separately.
test('first-policy native driver has no physical target fallback or secret handoff',()=>{
 const driver=read('tools/kr009/first-policy-native.mjs');
 assert.match(driver,/target='emulator-5584'/);assert.match(driver,/ro.kernel.qemu/);
 assert.match(driver,/n.stdout.trim\(\).split\(\/\\r\?\\n\/\)\[0\].trim\(\)===owner.AvdName/);
 assert.match(driver,/ORIGINAL_LAB_NOT_STOPPED/);assert.match(driver,/NEW_LEASE_REQUIRED/);
 assert.match(driver,/NEW_SYNTHETIC_LEASE_REMOVED/);assert.match(driver,/PRIOR_EMULATOR_STATE_PRESENT/);
 assert.match(driver,/physicalDeviceInvoked:false/);assert.match(driver,/INSTRUMENTATION_FAILED/);
 assert.doesNotMatch(driver,/sync-handoff|qr-handoff|logcat|screencap|kill-server|devices -l|pm','grant/);
});
test('first-policy instrumentation separates loopback fixture from real backend evidence',()=>{
 const path='apps/child-android/src/androidTest/java/dev/kidremote/child/sync/';
 const fixture=read(path+'FirstPolicyRuntimeTest.kt'),connected=read(path+'ConnectedFirstPolicyRuntimeTest.kt');
 for(const s of [fixture,connected]){assert.match(s,/ro.kernel.qemu/);assert.match(s,/kr006_e03b4820193b4132b1fcf7950eeed7fe/);assert.match(s,/physicalAcceptance\",false/);assert.doesNotMatch(s,/Log\.|println|logcat|screenshot|sync-handoff/);}
 assert.match(fixture,/EMULATOR_LIFECYCLE_LOOPBACK_FIXTURE/);assert.match(fixture,/controlledRetryDelayMs\",45000/);
 assert.match(connected,/EMULATOR_REAL_GATEWAY_FIRST_POLICY/);assert.match(connected,/model.decoded/);
 assert.match(connected,/serverReportVersion/);assert.match(connected,/serviceSettingsCleanup/);
 assert.match(connected,/FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES/);
});
