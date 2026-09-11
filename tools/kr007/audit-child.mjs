import {readFileSync,readdirSync} from 'node:fs';import{execFileSync}from'node:child_process';import{createHash}from'node:crypto';
const root='apps/child-android/build/';
let count=0;for(const f of readdirSync(root+'test-results/testDebugUnitTest'))if(f.endsWith('.xml')){const s=readFileSync(root+'test-results/testDebugUnitTest/'+f,'utf8');if(/<(?:failure|error|skipped)\b/.test(s))throw Error('CHILD_TEST_FAILURE');count+=(s.match(/<testcase\b/g)||[]).length;}
if(count!==5)throw Error('CHILD_TEST_COUNT');
for(const variant of ['debug','release']){
 const manifest=readFileSync(root+`intermediates/merged_manifests/${variant}/process${variant==='debug'?'Debug':'Release'}Manifest/AndroidManifest.xml`,'utf8');
 const id='dev.kidremote.child.unassigned'+(variant==='debug'?'.debug':'');
 const permissions=[...manifest.matchAll(/<uses-permission\b[^>]*android:name="([^"]+)"/g)].map(m=>m[1]);
 console.log('CHILD_MERGED_PERMISSION_METADATA='+JSON.stringify({variant,permissions,backupDisabled:manifest.includes('android:allowBackup="false"'),extractionRules:manifest.includes('android:dataExtractionRules=')}));
 if(permissions.some(p=>!['android.permission.INTERNET','android.permission.CAMERA',id+'.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'].includes(p))||!manifest.includes('android:allowBackup="false"')||!manifest.includes('android:dataExtractionRules='))throw Error('CHILD_PERMISSION_BACKUP_SCOPE');
 const guard=[...manifest.matchAll(/<permission\b[^>]*>/g)].map(m=>m[0]).find(p=>p.includes('android:name="'+id+'.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"'));
 if(!permissions.includes('android.permission.CAMERA')||!permissions.includes('android.permission.INTERNET')||new Set(permissions).size!==permissions.length||!guard?.includes('android:protectionLevel="signature"'))throw Error('CHILD_PERMISSION_GUARD');
 const apk=root+`outputs/apk/${variant}/child-${variant}${variant==='release'?'-unsigned':''}.apk`;
 const dex=execFileSync('unzip',['-p',apk,'classes*.dex'],{maxBuffer:64*1024*1024}).toString('latin1');
 if(/GOTRUE_JWT_SECRET|service_role|POSTGRES_PASSWORD|LabControlReceiver|UsageStatsManager|DeviceAdminReceiver|MediaProjectionManager/.test(dex))throw Error('CHILD_PRIVILEGE_ISOLATION');
 if(variant==='release'&&/http:\/\/(?:10\.0\.2\.2|127\.0\.0\.1)/.test(dex))throw Error('CHILD_RELEASE_LAB_ENDPOINT');
 if(variant==='release'&&/setBeforeIdentitySave|INJECTED_RESPONSE_LOSS/.test(dex))throw Error('CHILD_RELEASE_TEST_FAULT');
 console.log('CHILD_APK_'+variant.toUpperCase()+'_SHA256='+createHash('sha256').update(readFileSync(apk)).digest('hex'));
}
console.log('CHILD_JVM_TESTS_PASS='+count);
