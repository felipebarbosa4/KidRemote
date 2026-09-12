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
test('camera continuation uses native virtual scene and platform permission UI, never decoder injection as camera evidence',()=>{
 const testSource=read('apps/child-android/src/androidTest/java/dev/kidremote/child/CameraStorageRuntimeTest.kt');
 assert.match(testSource,/CameraManager/);assert.match(testSource,/permission_deny_button/);
 assert.doesNotMatch(testSource,/model\.decoded|decodePixels|decodeLuma|takeScreenshot|dumpWindowHierarchy/);
 const runtime=read('tools/kr007/camera-storage-runtime.mjs');
 assert.match(runtime,/virtualscene-image/);assert.match(runtime,/camera-storage-/);assert.match(runtime,/writeFileSync\(path,bytes\)/);
 assert.doesNotMatch(runtime,/webcam|image_url|base64|console\.log.*(?:bytes|cipher|qr)/);
 assert.match(read('.gitignore'),/synthetic-identity\.ciphertext/);
 const start=read('tools/kr006/windows-emulator.ps1');assert.match(start,/'-camera-back','virtualscene','-camera-front','none'/);
});
import {backupResourcePath} from './backup-resource.mjs';
test('camera boundary counters are content-free and release has no counter storage',()=>{
 const debug=read('apps/child-android/src/debug/java/dev/kidremote/child/EnrollmentFaults.kt');
 const release=read('apps/child-android/src/release/java/dev/kidremote/child/EnrollmentFaults.kt');
 assert.match(debug,/AtomicIntegerArray\(8\)/);assert.match(debug,/cameraStage\(stage:Int\)/);
 assert.doesNotMatch(debug,/String|Bitmap|ByteArray|File|Log\./);
 assert.doesNotMatch(release,/AtomicInteger|cameraCounts/);
 assert.match(release,/inline fun cameraStage/);
 const fixture=read('apps/child-android/src/androidTest/java/dev/kidremote/child/InvalidQrFixtureTest.kt');
 assert.match(fixture,/NOT_CAMERA/);assert.doesNotMatch(fixture,/model\.decoded|EnrollmentApi|CameraManager/);
 const boundary=read('apps/child-android/src/androidTest/java/dev/kidremote/child/CameraStorageRuntimeTest.kt');
 assert.match(boundary,/COMPOSE_TIMEOUT/);assert.match(boundary,/kr007metrics/);
 assert.doesNotMatch(boundary,/printStackTrace|\be\.message|\be\.toString/);
});
test('packaged backup audit resolves optimized release paths and rejects missing or ambiguous resources',()=>{
 for(const path of ['res/xml/backup_rules.xml','res/a1.xml'])assert.equal(backupResourcePath(`    resource 0x7f0e0000 xml/backup_rules\n      () (file) ${path} type=XML\n`,'backup_rules'),path);
 assert.throws(()=>backupResourcePath('','backup_rules'));
 assert.throws(()=>backupResourcePath('resource 0x7f0e0000 xml/backup_rules\n () (file) res/../secret.xml type=XML','backup_rules'));
 const entry='resource 0x7f0e0000 xml/backup_rules\n () (file) res/a.xml type=XML\n';assert.throws(()=>backupResourcePath(entry+entry,'backup_rules'));
});
