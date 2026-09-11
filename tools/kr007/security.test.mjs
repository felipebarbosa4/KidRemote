import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('child source keeps camera foreground and closes frames without capture retention',()=>{
 const s=read('apps/child-android/src/main/java/dev/kidremote/child/ChildActivity.kt');
 assert.match(s,/override fun onPause\(\)\{stopCamera/);assert.match(s,/finally\{image.close\(\)\}/);
 assert.doesNotMatch(s,/ImageCapture|MediaStore|Bitmap.compress|Log\.|FileOutputStream/);
 const m=read('apps/child-android/src/main/AndroidManifest.xml');assert.doesNotMatch(m,/ACCESSIBILITY|PACKAGE_USAGE_STATS|SYSTEM_ALERT_WINDOW|DEVICE_ADMIN|READ_MEDIA|READ_EXTERNAL_STORAGE/);
});
test('child credentials are wrapped and backup/transfer excluded, release has no lab endpoint',()=>{
 const s=read('apps/child-android/src/main/java/dev/kidremote/child/Enrollment.kt');assert.match(s,/AndroidKeyStore/);assert.match(s,/AES\/GCM\/NoPadding/);assert.match(s,/noBackupFilesDir/);
 assert.match(s,/Durable uncertainty boundary BEFORE HTTP/);
 assert.match(read('apps/child-android/src/main/res/xml/extraction_rules.xml'),/device-transfer.*exclude/);
 assert.doesNotMatch(read('apps/child-android/src/release/java/dev/kidremote/child/Backend.kt'),/http|10\.0\.2\.2/);
});
test('database gateway holds transaction locks; no storage stub or caller scope selection',()=>{
 const s=read('supabase/functions/device-gateway/local-database.mjs');assert.match(s,/repeatable read/);assert.match(s,/for share of c,v,h/);assert.match(s,/policy_configured!==false/);assert.doesNotMatch(s,/STUB_|body\.device/);
 const server=read('tools/kr007/local-gateway.mjs');assert.match(server,/server.listen\(57366,'127.0.0.1'/);assert.match(server,/57361\/user/);assert.match(server,/email_confirmed_at/);assert.doesNotMatch(server,/console.*(?:req|authorization|credential)/);
});
test('fresh runtime reinstall is restricted to task packages after emulator guard; absent apps do not fail cleanup',()=>{
 const s=read('tools/kr006/android-runtime.mjs');
 assert.match(s,/if\(!ownedPackages.includes\(pkg\)\)throw Error\('PACKAGE_NOT_TASK_OWNED'\)/);
 assert.match(s,/if\(await installed\(pkg\)\)if\(!\(await command\(\['uninstall',pkg\]\)/);
 assert.match(s,/if\(!await installed\(pkg\)\)continue/);
 assert.match(s,/async function command\(args\)\{await guard\(\)/);
 assert.doesNotMatch(s,/uninstall.*\*|kill-server|wipe-data/);
});
