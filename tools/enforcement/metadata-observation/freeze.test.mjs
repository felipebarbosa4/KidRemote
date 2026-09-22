import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const freeze=readFileSync('tools/enforcement/metadata-observation/freeze.mjs','utf8');
const runner=readFileSync('tools/enforcement/metadata-observation/Read-CurrentMetadata.ps1','utf8');
const module=readFileSync('tools/enforcement/metadata-observation/MetadataObservation.psm1','utf8');
test('dedicated freezer is host-only and keeps the product oracle blocked',()=>{
 assert.match(freeze,/scope:'OD51_READ_ONLY_METADATA_OBSERVATION'/);
 assert.match(freeze,/productPhysicalOracle:'BLOCKED'/);
 assert.match(freeze,/physicalExecution:'NOT_RUN'/);
 assert.doesNotMatch(freeze,/Start-ProductSlice|Run-ProductReplacement|child-physical-lab\.apk|fixture-reference\.apk/);
 assert.doesNotMatch(freeze,/spawnSync|execSync\(|adb\.exe|docker/);
});
test('runtime has no backend, product-control, journal or capture capability',()=>{
 for(const source of [runner,module])assert.doesNotMatch(source,/Import-Module[^\r\n]*(BackendHost|EnrollmentHost|Journal|ProductTransport|LiveSlice)|Invoke-WebRequest|HttpClient|screencap|screenshot/i);
 for(const source of [runner,module])assert.doesNotMatch(source,/Invoke-RestMethod|https?:\/\/|\bLOCK\b|\bUNLOCK\b/);
 assert.match(runner,/deviceMutation=\$false/);assert.match(runner,/backendMutation=\$false/);assert.match(runner,/mutationJournalCreated=\$false/);
 assert.match(module,/line -ceq 'reverse --list'/);assert.doesNotMatch(module,/line -ceq 'reverse tcp:/);
 assert.match(module,/function Assert-Od51PullResult/);
 assert.match(module,/if\(\$Result\.stderrPresent\)\{throw 'ADB_STDERR_PRESENT'\}/);
 assert.doesNotMatch(runner,/ADB_READ_FAILED/);
 for(const command of ['install','uninstall','pm clear','am start','settings put','appops set','shell input','shell rm','shell mv','shell cp','shell touch','shell mkdir','shell sqlite3','shell cat','shell content']){
  assert.doesNotMatch(module,new RegExp(`line -ceq '${command.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}`));
 }
});
