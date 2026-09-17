// Builds owner-local immutable bytes only. Never invokes Windows, ADB or Docker.
// The source gate remains clean-commit + exact required CI. Runtime metadata admission
// is rechecked in the runner for the exact Samsung configuration before mutation.
import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync,copyFileSync,readdirSync,lstatSync,existsSync,unlinkSync} from 'node:fs';
import {resolve,join,dirname,relative} from 'node:path';import {createHash} from 'node:crypto';
import {compatibility} from './compatibility.mjs';
const root=process.argv[2];if(!root)throw Error('OWNER_LOCAL_DESTINATION_REQUIRED');
const git=args=>execFileSync('git',args,{encoding:'utf8'}).trim();
if(git(['status','--porcelain']))throw Error('CLEAN_COMMITTED_SOURCE_REQUIRED');
const source=git(['rev-parse','HEAD']);
const runs=JSON.parse(execFileSync('gh',['run','list','--branch','kr-product-enforcement-integration','--limit','12','--json','headSha,status,conclusion,databaseId'],{encoding:'utf8'}));
const ci=runs.find(r=>r.headSha===source&&r.status==='completed'&&r.conclusion==='success');if(!ci)throw Error('CURRENT_SOURCE_REQUIRED_CI_NOT_PASSED');
const dir=resolve(root,source);if(existsSync(dir))throw Error('IMMUTABLE_DESTINATION_ALREADY_EXISTS');
const sha=b=>createHash('sha256').update(b).digest('hex');
const inputs={
 'lab-reference.apk':['apps/child-android/build/outputs/product-lab/668ab87a22591319afd43167d55ef9ac0909c1b3/child-physical-lab.apk','f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'],
 'fixture-reference.apk':['spikes/android-enforcement/ordinary-fixture/build/outputs/apk/debug/ordinary-fixture-debug.apk','223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'],
 'runtime/node-LICENSE':['/tmp/od51-runtime-notices/node-LICENSE','4573185d56580da2b890ba34a85a409257640f1c5632eade4300137266194d18'],
 'runtime/node.exe':['/mnt/c/Program Files/nodejs/node.exe','63c259c81e5d472b5f11c8d506070130cb04a1ecf84b80377a34ed6ec9048088'],
 'runtime/apksigner.jar':['/mnt/c/Users/3feli/AppData/Local/Android/Sdk/build-tools/37.0.0/lib/apksigner.jar','2defad215d7ff52968a409cde528cdaef7918b115e276b8e3378ca7a178e4180'],
 'zxing-core.jar':['/home/felby/.gradle/caches/modules-2/files-2.1/com.google.zxing/core/3.5.4/955fcd6bcd0723ddfb8ee6ed502d5fdf0e9676a9/core-3.5.4.jar',null],
 'host-qr.jar':['/tmp/od51-host-qr/host-qr.jar',null],
};
for(const [path,hash] of Object.values(inputs))if(hash&&sha(readFileSync(path))!==hash)throw Error('INPUT_PROVENANCE_MISMATCH');
const jbr='/mnt/c/Program Files/Android/Android Studio/jbr';
if(sha(readFileSync(join(jbr,'bin/java.exe')))!=='7148521120f35659dc0b233358a107c67ca7ca92993391519660ee6c80a9df9a')throw Error('JAVA_PROVENANCE_MISMATCH');
mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'.incomplete'),'NOT_OWNER_READY',{flag:'wx'});
function copy(from,to){mkdirSync(dirname(to),{recursive:true});if(/\.ps(m)?1$/i.test(to)){const b=readFileSync(from);writeFileSync(to,b.subarray(0,3).equals(Buffer.from([239,187,191]))?b:Buffer.concat([Buffer.from([239,187,191]),b]));}else copyFileSync(from,to);}
const tracked=git(['ls-files','-z']).split('\0');for(const f of tracked){if(!f)continue;copy(f,join(dir,'source',f));}
for(const [to,[from]] of Object.entries(inputs))copy(from,join(dir,to));
function tree(from,to){for(const f of readdirSync(from)){const p=join(from,f),out=join(to,f);if(lstatSync(p).isSymbolicLink())throw Error('RUNTIME_LINK_UNSUPPORTED');if(lstatSync(p).isDirectory())tree(p,out);else copy(p,out);}}
tree(jbr,join(dir,'runtime/jbr'));
copy('tools/enforcement/product-oracle/Run-ProductReplacement.ps1',join(dir,'Start-ProductSlice.ps1'));
writeFileSync(join(dir,'backend-compatibility.json'),JSON.stringify({...compatibility('.'),source}));
const files=[];function inventory(path){for(const f of readdirSync(path).sort()){if(f==='.incomplete')continue;const p=join(path,f);if(lstatSync(p).isDirectory())inventory(p);else{const name=relative(dir,p).replaceAll('\\','/');if(!/^[A-Za-z0-9_./-]+$/.test(name))throw Error('BUNDLE_FILENAME');files.push({name,sha256:sha(readFileSync(p))});}}}inventory(dir);
const manifest={scope:'OD51_ONE_PERSISTENT_LAB_PRODUCT_SLICE',readiness:'READY_FOR_ONE_OWNER_RUN',source,ci:ci.databaseId,files,
 javaSha256:'7148521120f35659dc0b233358a107c67ca7ca92993391519660ee6c80a9df9a',apksignerSha256:inputs['runtime/apksigner.jar'][1],
 runtimes:{node:{version:'24.14.0',sha256:inputs['runtime/node.exe'][1]},java:{version:'25.0.3+-15898627-b508.16',allFilesHashed:true},zxing:{version:'3.5.4'},hostQr:{compiledFrom:source}},
 old:{package:'dev.kidremote.child.unassigned.debug',versionCode:1,sha256:'3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9',signer:'771bc0fa9b91aecba8fd2d0e7d1e3af27237840198327731e098bb83dcbc97d7'},
 lab:{source:'668ab87a22591319afd43167d55ef9ac0909c1b3',package:'dev.kidremote.child.unassigned.debug',versionCode:2,versionName:'0.0.2-local-physical-lab',sha256:inputs['lab-reference.apk'][1],signer:'638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb',service:'dev.kidremote.child.unassigned.debug/dev.kidremote.child.enforcement.ChildEnforcementService',endpoint:'http://127.0.0.1:47366'},
 fixture:{package:'dev.kidremote.spike.ordinary',sha256:inputs['fixture-reference.apk'][1]},
 samsung:{manufacturer:'samsung',model:'SM-X400',android:'16',api:'36',build:'BP4A.251205.006',patch:'2026-07-05',batterySaver:'0',appStandby:'1',androidUser:0},
 lease:{format:1,label:'org.kidremote.physical-lab',id:'kr-physical-<UUID>',state:'%LOCALAPPDATA%/KidRemote/physical-lab',secrets:'DPAPI current user + restricted ACL',onExit:'stop services; retain owned DB volume/identity',onReuse:'exact ownership source/schema + backend compatibility digest; installed package independently reconciled; fresh authenticated ACK before policy; missing consent only'},
 journal:{format:'hash-chained fsync-before-admission events',originalVerdict:'immutable',cleanup:'independent',partial:'exact immutable inventory plus source-controlled review; Policy/Lock/unknown history fails closed'},
 resume:{historicalAttempts:['d9157ae6-a6ff-4849-919f-c8f13fe08f7e','28756da0-cbcf-410b-9957-d7aade9afcf4'],latestHistoricalVerdict:'INVALID:HOST_OR_TRANSPORT_FAILURE',historicalCleanup:'UNVERIFIED',backendCompatibility:compatibility('.').digest,pairingResidue:'exact reviewed own open session cancelled through finish_pairing before one fresh QR; any mismatch blocks',paths:['SAFE_REUSE_ENROLLED','SAFE_RESUME_FROM_ENROLLMENT','SAFE_RESET_SYNTHETIC_KIDREMOTE_STATE_AND_REENROLL','INVALID_PARTIAL_STATE_REVIEW_REQUIRED'],reset:'only exact unconfigured/unreported synthetic pairing and fixed child package data; no lab APK reinstall'},
 runtimeMetadataOverlay:{kind:'runtime_samsung_ids',path:'shared_prefs/android.app.ActivityThread.IDS.xml',scope:'samsung/SM-X400/Android16/API36/BP4A.251205.006/2026-07-05 only',meaning:'OEM runtime structural file; contents unread; every other unknown still blocks'},
 ownerActions:{firstRunLogicalMaximum:5,reuse:0,extraVisualConfirmation:0},
 hostGate:'bundle, native tools, owned lease, live Auth/bootstrap/control, fixed ports, artifacts, durable journal, read-only exact target; all before device mutation. Failure INVALID_HOST_PREFLIGHT.',
 verdicts:{PASS:'independent positive input, blocked counter/focus under canonical Lock, corroborating actual product status, canonical Unlock and independent restored input',FAIL:'usable fixture input/focus under restriction',INVALID:'ambiguous transport/provenance/setup/counter/focus or incomplete corroboration'},
 recovery:'canonical Unlock first; manual product Accessibility-disable path only if canonical restoration unavailable; never rewrites original verdict',physicalExecution:'NOT_RUN',notProduction:true};
writeFileSync(join(dir,'bundle.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});unlinkSync(join(dir,'.incomplete'));
console.log(JSON.stringify({directory:dir,source,ci:ci.databaseId,fileCount:files.length,manifestSha256:sha(readFileSync(join(dir,'bundle.json'))),entrypointSha256:sha(readFileSync(join(dir,'Start-ProductSlice.ps1'))),physicalExecution:'NOT_RUN'}));
