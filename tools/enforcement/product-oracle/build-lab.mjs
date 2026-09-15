// Device-free artifact preparation only. No adb, install or backend calls.
import {execFileSync} from 'node:child_process';
import {mkdirSync,copyFileSync,readFileSync,writeFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
const source=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
const dirty=Boolean(execFileSync('git',['status','--porcelain'],{encoding:'utf8'}).trim());
const sdk=process.env.ANDROID_HOME;if(!sdk)throw Error('ANDROID_HOME_REQUIRED');
const gradle='spikes/android-enforcement/gradlew';
execFileSync(gradle,['-p','apps/parent-mobile','--no-daemon',':child:assembleDebug',':child:lintDebug',':child:assembleRelease',':child:lintRelease','-PkrPhysicalLab=true'],{stdio:'inherit'});
const path='apps/child-android/build/outputs/apk/debug/child-debug.apk';
const sha=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const metadata=execFileSync(sdk+'/build-tools/37.0.0/aapt',['dump','badging',path],{encoding:'utf8'}).split('\n')[0];
if(!metadata.includes("versionName='0.0.2-local-physical-lab'")||!metadata.includes("name='dev.kidremote.child.unassigned.debug'"))throw Error('LAB_IDENTITY');
const cert=execFileSync(sdk+'/build-tools/37.0.0/apksigner',['verify','--print-certs',path],{encoding:'utf8'}).match(/certificate SHA-256 digest: ([a-f0-9]{64})/)?.[1];if(!cert)throw Error('LAB_CERT');
// DEX and merged-manifest checks are artifact checks, not physical transport evidence.
execFileSync('python3',['-c',`import zipfile
for variant in ['debug','release']:
 z=zipfile.ZipFile('apps/child-android/build/outputs/apk/'+variant+'/child-'+variant+('-unsigned' if variant=='release' else '')+'.apk')
 dex=b''.join(z.read(n) for n in z.namelist() if n.endswith('.dex'))
 assert (b'http://127.0.0.1:47366' in dex)==(variant=='debug')
 assert b'http://10.0.2.2:47366' not in dex
print('LAB_DEBUG_RELEASE_ENDPOINT_ISOLATION=PASS')`],{stdio:'inherit'});
const dir='apps/child-android/build/outputs/product-lab/'+source;
const manifest={source,sourceWorkingTreeChanged:dirty,scope:'LAB_ONLY_NOT_INSTALLED',endpoint:'http://127.0.0.1:47366',transport:'FUTURE_ADB_REVERSE_NOT_EXECUTED',package:'dev.kidremote.child.unassigned.debug',versionCode:2,versionName:'0.0.2-local-physical-lab',sha256:sha(path),signerSha256:cert,releaseSha256:sha('apps/child-android/build/outputs/apk/release/child-release-unsigned.apk')};if(!dirty){if(existsSync(dir))throw Error('PRESERVE_EXISTING_LAB_ARTIFACT');mkdirSync(dir,{recursive:true});copyFileSync(path,dir+'/child-physical-lab.apk');writeFileSync(dir+'/provenance.json',JSON.stringify(manifest,null,2)+'\n');}console.log(JSON.stringify(manifest));
