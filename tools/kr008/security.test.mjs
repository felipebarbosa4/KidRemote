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
