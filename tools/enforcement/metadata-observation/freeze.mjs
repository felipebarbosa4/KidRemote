// Host-only immutable preparation. Never invokes ADB, a device, an emulator or a backend.
import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync,copyFileSync,readdirSync,lstatSync,existsSync,unlinkSync} from 'node:fs';
import {resolve,join,dirname,relative} from 'node:path';
import {createHash} from 'node:crypto';
const retry=process.argv[3]==='--retry-summary';if(process.argv.length>4||(process.argv[3]&&!retry))throw Error('FREEZE_MODE_INVALID');
const root=process.argv[2];if(!root)throw Error('OWNER_LOCAL_DESTINATION_REQUIRED');
const git=args=>execFileSync('git',args,{encoding:'utf8'}).trim();
if(git(['status','--porcelain']))throw Error('CLEAN_COMMITTED_SOURCE_REQUIRED');
const source=git(['rev-parse','HEAD']);
const runs=JSON.parse(execFileSync('gh',['run','list','--branch','kr-product-enforcement-integration','--limit','12','--json','headSha,status,conclusion,databaseId,workflowName'],{encoding:'utf8'}));
const ci=runs.find(r=>r.headSha===source&&r.workflowName==='Planning checks'&&r.status==='completed'&&r.conclusion==='success');if(!ci)throw Error('CURRENT_SOURCE_REQUIRED_CI_NOT_PASSED');
const dir=resolve(root,source);if(existsSync(dir))throw Error('IMMUTABLE_DESTINATION_ALREADY_EXISTS');
const sha=b=>createHash('sha256').update(b).digest('hex');
// Reuse only the verified immutable public runtime; ignore mutable workstation installs.
const prior=resolve(dirname(root),'read-only-metadata-probes','8ebcc89e0b483af1f5d3cf3a081fca640da37e10');
const priorHash='e4d8ab75d9b6c44ca08d3c5cb3958e3992afa4a254518f4fdebb450ba0cc29ee';
if(sha(readFileSync(join(prior,'bundle.json')))!==priorHash)throw Error('PRIOR_MANIFEST_MISMATCH');
const priorManifest=JSON.parse(readFileSync(join(prior,'bundle.json'),'utf8'));
for(const file of priorManifest.files){const p=join(prior,file.name);if(lstatSync(p).isSymbolicLink()||sha(readFileSync(p))!==file.sha256)throw Error('PRIOR_FILE_MISMATCH');}
const javaRoot=join(prior,'runtime/jbr'),signer=join(prior,'runtime/apksigner.jar');
if(sha(readFileSync(join(javaRoot,'bin/java.exe')))!=='7148521120f35659dc0b233358a107c67ca7ca92993391519660ee6c80a9df9a')throw Error('JAVA_PROVENANCE_MISMATCH');
if(sha(readFileSync(signer))!=='2defad215d7ff52968a409cde528cdaef7918b115e276b8e3378ca7a178e4180')throw Error('APKSIGNER_PROVENANCE_MISMATCH');
mkdirSync(dir,{recursive:true});writeFileSync(join(dir,'.incomplete'),'NOT_OWNER_READY',{flag:'wx'});
function copy(from,to){mkdirSync(dirname(to),{recursive:true});if(/\.ps(m)?1$/i.test(to)){const b=readFileSync(from);writeFileSync(to,b.subarray(0,3).equals(Buffer.from([239,187,191]))?b:Buffer.concat([Buffer.from([239,187,191]),b]));}else copyFileSync(from,to);}
copy('tools/enforcement/metadata-observation/MetadataObservation.psm1',join(dir,'MetadataObservation.psm1'));
copy('tools/enforcement/metadata-observation/Read-CurrentMetadata.ps1',join(dir,'Read-CurrentMetadata.ps1'));
copy('tools/enforcement/update-review/ProductRuntimeCatalog.psm1',join(dir,'ProductRuntimeCatalog.psm1'));
if(retry){for(const name of ['SyncRetryDiagnostic.psm1','SyncRetryDiagnostic.cs','Read-SyncRetry.sh'])copy(join('tools/enforcement/metadata-observation',name),join(dir,name));}
copy(signer,join(dir,'runtime/apksigner.jar'));
function tree(from,to){for(const name of readdirSync(from)){const path=join(from,name),out=join(to,name);const stat=lstatSync(path);if(stat.isSymbolicLink())throw Error('RUNTIME_LINK_UNSUPPORTED');if(stat.isDirectory())tree(path,out);else copy(path,out);}}
tree(javaRoot,join(dir,'runtime/jbr'));
const files=[];function inventory(path){for(const name of readdirSync(path).sort()){if(name==='.incomplete'||name==='bundle.json')continue;const item=join(path,name),stat=lstatSync(item);if(stat.isSymbolicLink())throw Error('BUNDLE_LINK_UNSUPPORTED');if(stat.isDirectory())inventory(item);else{const logical=relative(dir,item).replaceAll('\\','/');if(!/^[A-Za-z0-9_./-]{1,240}$/.test(logical))throw Error('BUNDLE_FILENAME_INVALID');files.push({name:logical,sha256:sha(readFileSync(item))});}}}inventory(dir);
const manifest={scope:'OD51_READ_ONLY_METADATA_OBSERVATION',readiness:'READY_FOR_ONE_OWNER_RUN',source,ci:ci.databaseId,files,labPort:47366,
 expectedConfiguration:{manufacturer:'samsung',model:'SM-X400',android:'16',api:'36',build:'BP4A.251205.006',securityPatch:'2026-07-05',androidUser:0},
 child:{package:'dev.kidremote.child.unassigned.debug',sha256:'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56',signerSha256:'638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb',versionCode:2,versionName:'0.0.2-local-physical-lab'},
 fixture:{package:'dev.kidremote.spike.ordinary',sha256:'223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'},
 boundaries:{deviceMutation:false,backendMutation:false,appPrivateWrites:false,historicalJournalWrites:false,contentReads:false,screenshots:false,unexpectedEntryMaximum:64,relativePathMaximum:200,directories:['no_backup','files','databases','shared_prefs']},
 behavior:'One exact authorized non-emulator target; configuration and installed APK provenance reads; exact reverse list; child APK host-temporary signer verification; one fixed metadata-only run-as script. Structural regular-file names and byte sizes only. Host temporary APK is deleted.',
 interpretation:'Independent current diagnostic evidence only. It never changes historical metadataKnown/noUnknownFiles and never authorizes a product-slice run.',productPhysicalOracle:'BLOCKED',physicalExecution:'NOT_RUN'};
if(retry){
 manifest.scope='OD51_BOUNDED_RETRY_DIAGNOSTIC';
 manifest.privateRead={path:'no_backup/sync-retry',maximumBytes:1024,framing:'HEX1',oversizeSentinelBytes:1,rawRetained:false,identityBindingEmitted:false,backupRead:false};
 manifest.boundaries={deviceMutation:false,backendMutation:false,appPrivateWrites:false,historicalJournalWrites:false,contentReads:true,screenshots:false,privateReadScope:'SYNC_RETRY_ONLY'};
 manifest.behavior='Existing exact target/APK/signer/reverse checks then one fixed bounded base-file read into host memory. CRC32 and writer-schema validation; only allowlisted technical flags/count/delay. No raw bytes, identity, credentials, backup/fallback read, HTTP, launch or repair.';
 manifest.requiredSwitch='-RetrySummary';
}
manifest.runtimeProvenance={priorManifestSha256:priorHash,source:priorManifest.source};
writeFileSync(join(dir,'bundle.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});unlinkSync(join(dir,'.incomplete'));
console.log(JSON.stringify({directory:dir,source,ci:ci.databaseId,fileCount:files.length,manifestSha256:sha(readFileSync(join(dir,'bundle.json'))),entrypointSha256:sha(readFileSync(join(dir,'Read-CurrentMetadata.ps1'))),physicalExecution:'NOT_RUN',productPhysicalOracle:'BLOCKED',readOnlyMetadataProbe:'READY_FOR_ONE_OWNER_RUN'}));
