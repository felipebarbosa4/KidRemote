// One CI signing identity; versioned debug APK fixtures only. Never modifies source or signing keys.
import {execFileSync} from 'node:child_process';
import {copyFileSync,mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {certificateDigest} from './apk-identity.mjs';
const output='apps/child-android/build/outputs/kr008-update';mkdirSync(output,{recursive:true});
const apk='apps/child-android/build/outputs/apk/debug/child-debug.apk';
copyFileSync(apk,join(output,'post-v2.apk'));
copyFileSync('apps/child-android/build/outputs/apk/androidTest/debug/child-debug-androidTest.apk',join(output,'update-test.apk'));
execFileSync('spikes/android-enforcement/gradlew',['-p','apps/parent-mobile','--no-daemon','-Pkr008UpdateVersion=1',':child:assembleDebug'],{stdio:'inherit'});
copyFileSync(apk,join(output,'pre-v1.apk'));copyFileSync(join(output,'post-v2.apk'),apk);
const sdk=process.env.ANDROID_HOME??process.env.ANDROID_SDK_ROOT;
const source=process.env.KR008_SOURCE;if(!/^[a-f0-9]{40}$/.test(source??''))throw Error('SOURCE_REQUIRED');
const result={source,checkout:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),baseline:'609c0fd7fc1d114c7f36dba5451f4f0023714628',apks:{}};
for(const file of ['pre-v1.apk','post-v2.apk','update-test.apk']) {
 const path=join(output,file),badging=execFileSync(join(sdk,'build-tools/37.0.0/aapt2'),['dump','badging',path],{encoding:'utf8'});
 const m=badging.match(/package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'/);if(!m)throw Error('APK_MANIFEST_UNVERIFIED');
 const sign=execFileSync(join(sdk,'build-tools/37.0.0/apksigner'),['verify','--print-certs',path],{encoding:'utf8'});
 const certificate=certificateDigest(sign);
 result.apks[file]={sha256:createHash('sha256').update(readFileSync(path)).digest('hex'),package:m[1],versionCode:Number(m[2]),versionName:m[3],certificate};
}
const pre=result.apks['pre-v1.apk'],post=result.apks['post-v2.apk'],test=result.apks['update-test.apk'];
if(pre.versionCode!==1||post.versionCode!==2||pre.package!=='dev.kidremote.child.unassigned.debug'||post.package!==pre.package||test.package!==pre.package+'.test'||new Set([pre.certificate,post.certificate,test.certificate]).size!==1)throw Error('UPDATE_PAIR_UNVERIFIED');
writeFileSync(join(output,'update-apks.json'),JSON.stringify(result,null,2)+'\n');
console.log('KR008_VERSIONED_UPDATE_APKS_SAME_SIGNER_VERIFIED');
