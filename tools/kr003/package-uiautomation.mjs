// Goal: produce an immutable UiAutomation transport preflight bundle from a clean source commit.
// Context: shell input is denied by the Mi 8; test a separate self-targeted instrumentation bridge.
// Constraints: no device execution, overwrite, candidate change, secrets or raw ADB diagnostics.
// Done when: script/module/fixture bytes are hashed and the reviewed fixture APK is unchanged.
import {mkdirSync,copyFileSync,readFileSync,writeFileSync} from 'node:fs';
import {resolve,basename} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root=resolve(import.meta.dirname,'../..'),git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
assert.equal(git('status','--porcelain'),'','Commit all changes before packaging');
const commit=git('rev-parse','HEAD'),destination=process.argv[2]; assert(destination,'Provide a new output directory (no overwrite)');
const output=resolve(destination); mkdirSync(output,{recursive:false});
const spike=resolve(root,'spikes/android-enforcement');
execFileSync(resolve(spike,'gradlew'),['--no-daemon','testDebugUnitTest','lintDebug','assembleDebug','lintRelease','assembleRelease'],{cwd:spike,stdio:'inherit'});
execFileSync(process.execPath,[resolve(root,'tools/validate.mjs')],{cwd:root,stdio:'inherit'});
execFileSync(process.execPath,[resolve(root,'tools/kr003/audit-build.mjs')],{cwd:root,stdio:'inherit'});
const mapping={'Test-KR003-UiAutomationTransport.ps1':'tools/kr003/Test-KR003-UiAutomationTransport.ps1','OracleTransport.psm1':'tools/kr003/OracleTransport.psm1','Qualification.psm1':'tools/kr003/Qualification.psm1','protocol.md':'docs/test-plans/KR-003-UIAUTOMATION-TRANSPORT.md','input-probe.apk':'spikes/android-enforcement/input-probe/build/outputs/apk/debug/input-probe-debug.apk','ordinary-fixture.apk':'spikes/android-enforcement/ordinary-fixture/build/outputs/apk/debug/ordinary-fixture-debug.apk'};
const files=Object.entries(mapping).map(([name,source])=>{copyFileSync(resolve(root,source),resolve(output,name));return{name,sha256:createHash('sha256').update(readFileSync(resolve(output,name))).digest('hex')}});
const manifest={schema:1,protocol:'KR003-UIAUTOMATION-TRANSPORT-PREFLIGHT',sourceCommit:commit,runnerVersion:1,diagnosticOnly:true,physicalExecution:'NOT_RUN',files,probeSha256:files.find(f=>f.name==='input-probe.apk').sha256,fixtureSha256:files.find(f=>f.name==='ordinary-fixture.apk').sha256,ownerDeviceClass:{model:'Xiaomi Mi 8',miui:'MIUI Global 12.0.3',api:29,codename:'dipper'}};
assert.equal(manifest.fixtureSha256,'223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc','Fixture drifted from Q7');
assert.equal(git('status','--porcelain'),'','Build unexpectedly changed source');
writeFileSync(resolve(output,'bundle.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
process.stdout.write(JSON.stringify({output,bundle:basename(output),...manifest},null,2)+'\n');
