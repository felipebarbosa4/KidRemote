import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync,readdirSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('local accounting has no package history, networking, enforcement or receipt implementation',()=>{
 const root='apps/child-android/src/main/java/dev/kidremote/child/accounting/';
 for(const file of readdirSync(new URL('../../'+root,import.meta.url))) {
  const s=read(root+file);assert.doesNotMatch(s,/getPackageName|packageName|UsageStatsManager|HttpURLConnection|Firebase|AccessibilityService|Log\.|println|System.currentTimeMillis/);
 }
 const probe=read('apps/child-android/src/debug/java/dev/kidremote/child/accounting/UsageHistoryProbe.kt');assert.doesNotMatch(probe,/packageName|getPackageName|queryUsageStats|queryAndAggregateUsageStats|File|Log\./);assert.match(probe,/coverageProven:Boolean=false/);
 const manifest=read('apps/child-android/src/main/AndroidManifest.xml');assert.doesNotMatch(manifest,/PACKAGE_USAGE_STATS|ACCESSIBILITY|SYSTEM_ALERT_WINDOW|DEVICE_ADMIN/);
});
test('Room storage stays aggregate-only, no destructive migration fallback or independent identity secret',()=>{
 const s=read('apps/child-android/src/main/java/dev/kidremote/child/accounting/ChildAccounting.kt');assert.match(s,/IdentityStore/);assert.match(s,/noBackupFilesDir/);assert.match(s,/runInTransaction/);assert.match(s,/accounting_initialized/);assert.doesNotMatch(s,/fallbackToDestructiveMigration|credential|UUID.randomUUID/);
 const row=read('apps/child-android/accounting-storage/src/main/java/dev/kidremote/accounting/storage/LedgerRow.java');assert.doesNotMatch(row,/packageName|credential|eventHistory/);
});
test('accounting runtime is fixed to verified task AVD and keeps crash classifications',()=>{
 const s=read('tools/kr008/android-runtime.mjs');assert.match(s,/\['-s','emulator-5584'/);assert.match(s,/ro.kernel.qemu/);assert.match(s,/OWNER_UNVERIFIED/);assert.match(s,/EXPECTED_PROCESS_DEATH/);assert.doesNotMatch(s,/kill-server|devices -l|screencap|screenrecord|logcat|appops/);
});
test('update suite keeps replacement window intact and uses the unchanged validated migration',()=>{
 const s=read('tools/kr008/update-runtime.mjs');const window=s.slice(s.indexOf("await stage(scenario==='CURRENT_SCHEMA'"),s.indexOf("evidence.overall='PASS_THIS_EMULATOR_ONLY'"));
 assert.match(window,/install\('post-v2.apk'\)/);assert.doesNotMatch(window,/uninstall|pm','clear/);
 assert.match(s,/INSTALL_FAILED_VERSION_DOWNGRADE/);assert.doesNotMatch(s,/'-d'|kill-server|logcat|screencap|appops/);
 const t=read('apps/child-android/src/androidTest/java/dev/kidremote/child/accounting/AccountingUpdateTest.kt');
 assert.match(t,/LedgerDatabase.MIGRATION_1_2.migrate\(db\)/);assert.match(t,/db.inTransaction\(\)/);assert.doesNotMatch(t,/fallbackToDestructiveMigration|queryUsageStats|UsageStatsManager/);
 const build=read('tools/kr008/build-update.mjs');assert.match(build,/apksigner/);assert.match(build,/certificate/);
});
test('signature digest parser supports actual build-tools 37 output and rejects ambiguity',async()=>{
 const {certificateDigest}=await import('./apk-identity.mjs');const a='a'.repeat(64),b='b'.repeat(64);
 assert.equal(certificateDigest('V2 Signer: certificate SHA-256 digest: '+a),a);
 assert.equal(certificateDigest('Signer #1 certificate SHA-256 digest: '+a),a);
 assert.throws(()=>certificateDigest('V2 Signer: certificate SHA-256 digest: '+a+'\nV3 Signer: certificate SHA-256 digest: '+b));
 assert.throws(()=>certificateDigest('Unknown signer certificate SHA-256 digest: '+a));
 assert.throws(()=>certificateDigest('verification did not produce a certificate'));
});
