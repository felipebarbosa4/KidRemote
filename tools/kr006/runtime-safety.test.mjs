import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const host=readFileSync(new URL('./android-runtime.mjs',import.meta.url),'utf8');
const device=readFileSync(new URL('../../apps/parent-mobile/app/src/androidTest/java/dev/kidremote/parent/ParentRuntimeTest.kt',import.meta.url),'utf8');
test('runtime host always selects fixed emulator and verifies AVD plus qemu before app commands',()=>{
 assert.match(host,/spawn\(adb,\['-s',serial/);
 assert.match(host,/EMULATOR_AVD_IDENTITY_UNVERIFIED/);assert.match(host,/NOT_VERIFIED_EMULATOR/);
 assert.doesNotMatch(host,/kill-server|start-server|tcpip|adb.*devices/);
 assert.match(host,/if\(!dir \|\| !/);assert.match(host,/RUNTIME_OWNER_UNVERIFIED/);
});
test('actual test uses Compose activity and local mail, never fabricated auth/state',()=>{
 assert.match(device,/createAndroidComposeRule<MainActivity>/);
 assert.match(device,/57365\/api\/v1\/message/);assert.match(device,/UUID.randomUUID/);
 assert.doesNotMatch(device,/setContent|model\.(login|setup)|mock|\/admin\/|email_confirmed_at\s*=/i);
 assert.match(device,/PROCESS_DID_NOT_RESTART/);assert.match(device,/SESSION_KEY_REMAINS/);
});
test('runtime credentials cannot enter instrumentation argv or raw host output',()=>{
 assert.doesNotMatch(host,/console\.(log|error)\(r\.out|writeFileSync\([^;]*r\.out/);
 assert.doesNotMatch(device,/println|Log\.|printToLog|printToString/);
 assert.match(host,/const codes=\[\.\.\.r\.out\.matchAll/);
 assert.match(device,/catch \(_: Throwable\) \{ throw AssertionError\(code\) \}/);
});
