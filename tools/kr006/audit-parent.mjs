import {readFileSync,readdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {parentPermissionsAllowed} from './manifest-policy.mjs';
const root=resolve('apps/parent-mobile/app');
const check=(ok,why)=>{if(!ok) throw Error(why);};
const files=p=>readdirSync(p,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(resolve(p,e.name)):[resolve(p,e.name)]);
const expected=files(root+'/src/test').filter(p=>p.endsWith('.kt')).reduce((n,p)=>n+(readFileSync(p,'utf8').match(/@Test\b/g)??[]).length,0);
const results=files(root+'/build/test-results/testDebugUnitTest').filter(p=>p.endsWith('.xml')).map(p=>readFileSync(p,'utf8')).join('');
check(expected>=4 && (results.match(/<testcase\b/g)??[]).length===expected && !/<failure\b|<error\b|<skipped\b/.test(results),'PARENT_JVM_TESTS_UNVERIFIED');
for(const variant of ['debug','release']) {
 const task='process'+(variant==='debug'?'Debug':'Release')+'Manifest';
 const manifest=readFileSync(`${root}/build/intermediates/merged_manifests/${variant}/${task}/AndroidManifest.xml`,'utf8');
 check(parentPermissionsAllowed(manifest),'PARENT_PERMISSION_SCOPE');
 check(manifest.includes('android:allowBackup="false"') && manifest.includes('android:usesCleartextTraffic="false"'),'PARENT_MANIFEST_SECURITY');
 check(!/android.intent.action.VIEW|BIND_ACCESSIBILITY_SERVICE|DEVICE_ADMIN/.test(manifest),'PARENT_EXPORTED_SCOPE');
 const apk=`${root}/build/outputs/apk/${variant}/app-${variant}${variant==='release'?'-unsigned':''}.apk`;
 const dex=execFileSync('unzip',['-p',apk,'classes*.dex'],{maxBuffer:128*1024*1024});
 for(const marker of ['GOTRUE_JWT_SECRET','service_role','supabase_auth_admin','POSTGRES_PASSWORD','LabControlReceiver'])
  check(!dex.includes(Buffer.from(marker)),'PARENT_PRIVILEGED_CODE_IN_APK');
 if(variant==='release') for(const marker of ['10.0.2.2:57361','10.0.2.2:57362','127.0.0.1:57361'])
  check(!dex.includes(Buffer.from(marker)),'RELEASE_LOCAL_ENDPOINT');
 console.log('PARENT_APK_'+variant.toUpperCase()+'_SHA256='+createHash('sha256').update(readFileSync(apk)).digest('hex'));
}
console.log('PARENT_JVM_AND_RELEASE_AUDIT_PASS:tests='+expected+':emulator=UNRUN:physical=UNRUN');
