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

test('retry mode requires scoped immutable manifest and emits no private record',()=>{
 const parser=readFileSync('tools/enforcement/metadata-observation/SyncRetryDiagnostic.cs','utf8');
 const shell=readFileSync('tools/enforcement/metadata-observation/Read-SyncRetry.sh','utf8');
 const adapter=readFileSync('tools/enforcement/metadata-observation/SyncRetryDiagnostic.psm1','utf8');
 assert.match(freeze,/workflowName==='Planning checks'/);
 assert.match(freeze,/PRIOR_MANIFEST_MISMATCH/);
 assert.match(freeze,/manifest.scope='OD51_BOUNDED_RETRY_DIAGNOSTIC'/);
 assert.match(runner,/\$manifest.scope -cne \$scope/);
 assert.match(runner,/\[switch\]\$RetrySummary/);
 assert.match(runner,/privateRead.path -cne 'no_backup\/sync-retry'/);
 assert.match(runner,/\$raw=\$null/);
 assert.match(shell,/od -An -v -tx1 -N 1025 "\$p"/);
 assert.match(shell,/\[ "\$size" -le 1024 \]/);
 assert.match(shell,/p=no_backup\/sync-retry/);
 assert.doesNotMatch(shell,/device-identity|\.bak|logcat|sqlite|curl|wget|\bcat\b|\brm\b|\bcp\b|\bmv\b/);
 assert.doesNotMatch(parser,/File\.|Console\.|Process\.|Http|Socket|WriteAll/);
 assert.doesNotMatch(adapter,/Write-Output|Write-Host|WriteAll|Add-Content|Set-Content|Out-File/);
 assert.match(parser,/values.ContainsKey\(key\)/);
 assert.match(parser,/new UTF8Encoding\(false,true\)/);
 assert.match(parser,/pairs.Count>1024/);
 assert.match(parser,/frame.Length>4096/);
 assert.match(runner,/privateRead.framing -cne 'HEX1'/);
 assert.match(freeze,/framing:'HEX1'/);
 assert.doesNotMatch(shell,/\r/);
});
