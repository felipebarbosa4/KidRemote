// Freeze host files only. Never executes the preflight, adb, a device or network request.
import {execFileSync} from 'node:child_process';
import {readFileSync,mkdirSync,writeFileSync,copyFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,join} from 'node:path';
const root=process.argv[2];if(!root)throw Error('OWNER_LOCAL_ROOT_REQUIRED');
if(execFileSync('git',['status','--porcelain'],{encoding:'utf8'}).trim())throw Error('CLEAN_COMMITTED_SOURCE_REQUIRED');
const source=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
const sha=b=>createHash('sha256').update(b).digest('hex');
const dir=resolve(root,source);if(existsSync(dir))throw Error('IMMUTABLE_BUNDLE_ALREADY_EXISTS');
const files=['ReadOnly.psm1','ReadOnly-Preflight.ps1'].map(name=>({name,sha256:sha(readFileSync('tools/enforcement/product-oracle/'+name))}));
const manifest={scope:'READ_ONLY_SAMSUNG_INVENTORY',source,files,adb:'C:\\platform-tools\\adb.exe',readOnly:true,
 expectedConfiguration:{manufacturer:'samsung',model:'SM-X400',android:'16',api:'36',build:'BP4A.251205.006',patch:'2026-07-05',batterySaver:'0',appStandby:'1',androidUser:0},
 packages:['dev.kidremote.child.unassigned.debug','dev.kidremote.spike.ordinary'],
 behavior:'One attached authorized target, memory-only serial; metadata/settings/appops/APK hash reads only. No input, launch, install, update, settings write, reverse, backend or qualification. Every result requires owner review; physical oracle remains BLOCKED.',
 unknowns:'Signing certificate digest may be unavailable. Package absence cannot prove absence of retained data. No result authorizes installation.',
 resultDirectory:'%LOCALAPPDATA%\\KidRemote\\product-preflight-results',physicalExecution:'NOT_RUN'};
mkdirSync(dir,{recursive:true});for(const f of files)copyFileSync('tools/enforcement/product-oracle/'+f.name,join(dir,f.name));
const raw=JSON.stringify(manifest,null,2)+'\n';writeFileSync(join(dir,'bundle.json'),raw,{flag:'wx'});
console.log(JSON.stringify({directory:dir,source,manifestSha256:sha(raw),files,physicalExecution:'NOT_RUN'}));
