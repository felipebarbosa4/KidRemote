// Host-only immutable preparation. No rebuild, adb, device or backend command.
import {execFileSync} from 'node:child_process';
import {readFileSync,existsSync,mkdirSync,copyFileSync,writeFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {createHash} from 'node:crypto';
const [root,java,jar]=process.argv.slice(2);if(!root||!java||!jar)throw Error('OWNER_ROOT_JAVA_JAR_REQUIRED');
if(execFileSync('git',['status','--porcelain'],{encoding:'utf8'}).trim())throw Error('CLEAN_SOURCE_REQUIRED');
const source=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),sha=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const artifact='apps/child-android/build/outputs/product-lab/668ab87a22591319afd43167d55ef9ac0909c1b3/';
const lab=JSON.parse(readFileSync(artifact+'provenance.json','utf8'));
if(lab.source!=='668ab87a22591319afd43167d55ef9ac0909c1b3'||lab.sourceWorkingTreeChanged||sha(artifact+'child-physical-lab.apk')!=='f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56')throw Error('APPROVED_LAB_PROVENANCE');
lab.service='dev.kidremote.child.unassigned.debug/dev.kidremote.child.enforcement.ChildEnforcementService';
const entries=[['ProductRuntimeCatalog.psm1','tools/enforcement/update-review/ProductRuntimeCatalog.psm1'],['Review.psm1','tools/enforcement/update-review/Review.psm1'],['ReadOnly-UpdateReview.ps1','tools/enforcement/update-review/ReadOnly-UpdateReview.ps1'],['ReadOnly.psm1','tools/enforcement/product-oracle/ReadOnly.psm1'],['lab-reference.apk',artifact+'child-physical-lab.apk']];
const files=entries.map(([name,p])=>({name,sha256:sha(p)}));
const manifest={scope:'READ_ONLY_SIGNER_STATE_UPDATE_REVIEW',source,files,lab,javaSha256:sha(java),apksignerSha256:sha(jar),
 installedExpectedSha256:'3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9',
 expectedConfiguration:{manufacturer:'samsung',model:'SM-X400',android:'16',api:'36',build:'BP4A.251205.006',patch:'2026-07-05',user:0,batterySaver:'0',appStandby:'1'},
 behavior:'READ_ONLY: prior inventory; installed base APK pull to unique host temp; SHA256; SDK apksigner verify only; metadata-only run-as stdin program twice; remove temporary installed bytes. No install/update/clear/uninstall/permissions/launch/input/backend/reverse.',
 interpretation:'Any durable state or unknown inventory requires review. Mismatched signer blocks. SAFE is technical eligibility only, never update authorization.',physicalExecution:'NOT_RUN'};
const dir=resolve(root,source);if(existsSync(dir))throw Error('PRESERVE_EXISTING_BUNDLE');mkdirSync(dir,{recursive:true});for(const [name,p]of entries)copyFileSync(p,join(dir,name));
writeFileSync(join(dir,'bundle.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({directory:dir,source,manifestSha256:sha(join(dir,'bundle.json')),files,javaSha256:manifest.javaSha256,apksignerSha256:manifest.apksignerSha256,physicalExecution:'NOT_RUN'}));
