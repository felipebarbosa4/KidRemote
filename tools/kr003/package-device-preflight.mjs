// Goal: create a clean-source, fixture-only onboarding/transport bundle for one authorized Android configuration.
// Context: device facts and shell-input capability are unknown until the owner runs the bundle.
// Constraints: no candidate APK, device command, overwrite, serial/account/content data or physical claim.
// Done when: runner/modules/protocol/fixture bytes and exact source are hash-pinned in a new directory.
import {mkdirSync,copyFileSync,readFileSync,writeFileSync} from 'node:fs';
import {resolve,basename} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root=resolve(import.meta.dirname,'../..'),git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
assert.equal(git('status','--porcelain'),'','Commit all changes before packaging');
const commit=git('rev-parse','HEAD'),destination=process.argv[2];assert(destination,'Provide a new output directory (no overwrite)');
const output=resolve(destination);mkdirSync(output,{recursive:false});
const spike=resolve(root,'spikes/android-enforcement');
execFileSync(resolve(spike,'gradlew'),['--no-daemon','testDebugUnitTest','lintDebug','assembleDebug','lintRelease','assembleRelease'],{cwd:spike,stdio:'inherit'});
execFileSync(process.execPath,[resolve(root,'tools/validate.mjs')],{cwd:root,stdio:'inherit'});
execFileSync(process.execPath,[resolve(root,'tools/kr003/audit-build.mjs')],{cwd:root,stdio:'inherit'});
const mapping={
  'Test-KR003-DeviceTransport.ps1':'tools/kr003/Test-KR003-DeviceTransport.ps1',
  'DevicePreflight.psm1':'tools/kr003/DevicePreflight.psm1',
  'OracleTransport.psm1':'tools/kr003/OracleTransport.psm1',
  'Qualification.psm1':'tools/kr003/Qualification.psm1',
  'protocol.md':'docs/test-plans/KR-003-DEVICE-ONBOARDING.md',
  'ordinary-fixture.apk':'spikes/android-enforcement/ordinary-fixture/build/outputs/apk/debug/ordinary-fixture-debug.apk',
};
const files=Object.entries(mapping).map(([name,source])=>{copyFileSync(resolve(root,source),resolve(output,name));return{name,sha256:createHash('sha256').update(readFileSync(resolve(output,name))).digest('hex')}});
const fixtureSha256=files.find(file=>file.name==='ordinary-fixture.apk').sha256;
assert.equal(fixtureSha256,'223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc','Fixture drifted from reviewed independent Q7 fixture');
const manifest={schema:1,protocol:'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT',sourceCommit:commit,runnerVersion:1,fixtureOnly:true,
  physicalExecution:'NOT_RUN',candidateIncluded:false,fixtureSha256,files,
  collectedFields:['manufacturer','model','androidVersion','apiLevel','securityPatch','buildId','batteryManagement','requiredPermissionState'],
  forbiddenFields:['serial','account','androidId','buildFingerprint','content','packageHistory']};
assert.equal(git('status','--porcelain'),'','Build unexpectedly changed source');
writeFileSync(resolve(output,'bundle.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
process.stdout.write(JSON.stringify({output,bundle:basename(output),...manifest},null,2)+'\n');
