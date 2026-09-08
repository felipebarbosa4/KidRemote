// Goal: create a clean-source bounded active-oracle calibration bundle for a transport-capable authorized configuration.
// Context: calibration is separate from fixture-only transport and from any 100-cycle qualification.
// Constraints: exact disposable APKs; no device command, overwrite, physical claim, network action or qualification loop.
// Done when: runner/modules/protocol/APKs and exact source are hash-pinned in a new directory.
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
  'Test-KR003-OracleCalibration.ps1':'tools/kr003/Test-KR003-OracleCalibration.ps1',
  'CalibrationHost.psm1':'tools/kr003/CalibrationHost.psm1',
  'DevicePreflight.psm1':'tools/kr003/DevicePreflight.psm1',
  'OracleTransport.psm1':'tools/kr003/OracleTransport.psm1',
  'Qualification.psm1':'tools/kr003/Qualification.psm1',
  'protocol.md':'docs/test-plans/KR-003-ACTIVE-ORACLE-CALIBRATION.md',
  'candidate.apk':'spikes/android-enforcement/app/build/outputs/apk/debug/app-debug.apk',
  'ordinary-fixture.apk':'spikes/android-enforcement/ordinary-fixture/build/outputs/apk/debug/ordinary-fixture-debug.apk',
};
const files=Object.entries(mapping).map(([name,source])=>{copyFileSync(resolve(root,source),resolve(output,name));return{name,sha256:createHash('sha256').update(readFileSync(resolve(output,name))).digest('hex')}});
const candidateSha256=files.find(file=>file.name==='candidate.apk').sha256,fixtureSha256=files.find(file=>file.name==='ordinary-fixture.apk').sha256;
assert.equal(candidateSha256,'5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b','Candidate drifted from the Q5-calibrated APK');
assert.equal(fixtureSha256,'223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc','Fixture drifted from reviewed independent Q7 fixture');
const manifest={schema:1,protocol:'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION',sourceCommit:commit,runnerVersion:3,calibrationOnly:true,
  physicalExecution:'NOT_RUN',candidateSha256,fixtureSha256,files,transportPrerequisite:'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT',
  oracleModel:'SHELL_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS',qualificationSamples:0,humanAgreementChecks:1};
assert.equal(git('status','--porcelain'),'','Build unexpectedly changed source');
writeFileSync(resolve(output,'bundle.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
process.stdout.write(JSON.stringify({output,bundle:basename(output),...manifest},null,2)+'\n');
