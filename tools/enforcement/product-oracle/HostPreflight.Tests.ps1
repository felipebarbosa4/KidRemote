Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-host-tests-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
$prior=$env:LOCALAPPDATA;$env:LOCALAPPDATA=Join-Path $root 'state';$script:n=0
function Check($b){$script:n++;if(-not $b){throw "HOST_PREFLIGHT_CHECK_$script:n"}}
try{
 $bundle=Join-Path $root 'bundle';[void][IO.Directory]::CreateDirectory($bundle)
 $entry=Join-Path $bundle 'Start-ProductSlice.ps1'
 Copy-Item (Join-Path $PSScriptRoot 'Run-ProductReplacement.ps1') $entry
 $r=(& $entry -ExpectedManifestHash ('a'*64) | Out-String)|ConvertFrom-Json
 Check ($r.hostFailureStage -ceq 'BUNDLE_VERIFY');Check ($r.hostDiagnosticWrite -ceq 'DURABLE');Check (-not $r.hostValidated)
 $records=Join-Path $env:LOCALAPPDATA 'KidRemote/product-host-failures'
 Check (@(Get-ChildItem $records -Filter '*.json').Count -eq 1)
 [void][IO.Directory]::CreateDirectory((Join-Path $bundle 'source'))
 Copy-Item (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path (Join-Path $bundle 'source/tools') -Recurse
 foreach($rel in @('runtime/jbr/bin/java.exe','runtime/apksigner.jar','lab-reference.apk','host-qr.jar','zxing-core.jar','extra')){
  $p=Join-Path $bundle $rel;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p));[IO.File]::WriteAllText($p,'SYNTHETIC_NONEXECUTABLE')
 }
 # Entire test bundle is synthetic. No executable Node or ADB can reach the host gate.
 $files=@(Get-ChildItem $bundle -Recurse -File | ForEach-Object {@{name=$_.FullName.Substring($bundle.Length+1).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
 $m=@{scope='OD51_ONE_PERSISTENT_LAB_PRODUCT_SLICE';source=('a'*40);readiness='READY_FOR_ONE_OWNER_RUN';files=$files;javaSha256=(Get-FileHash (Join-Path $bundle 'runtime/jbr/bin/java.exe')).Hash.ToLowerInvariant();apksignerSha256=(Get-FileHash (Join-Path $bundle 'runtime/apksigner.jar')).Hash.ToLowerInvariant()}
 $manifest=Join-Path $bundle 'bundle.json';[IO.File]::WriteAllText($manifest,($m|ConvertTo-Json -Depth 5));$hash=(Get-FileHash $manifest).Hash.ToLowerInvariant()
 $r=(& $entry -ExpectedManifestHash $hash -Adb 'SYNTHETIC_REJECTED' | Out-String)|ConvertFrom-Json
 Check ($r.hostFailureStage -ceq 'ADB_PREREQUISITE');Check ($r.backendCleanup -ceq 'NOT_STARTED');Check ($r.reverseCleanup -ceq 'NOT_CREATED')
 $r=(& $entry -ExpectedManifestHash $hash | Out-String)|ConvertFrom-Json
 Check ($r.hostFailureStage -ceq 'ADB_PREREQUISITE');Check ($r.hostFailureCode -ceq 'NATIVE_TOOLS');Check ($r.backendCleanup -ceq 'NOT_STARTED')
 $attempts=Join-Path $env:LOCALAPPDATA 'KidRemote/product-slice-attempts'
 $dirs=@(Get-ChildItem $attempts -Directory);Check ($dirs.Count -eq 1)
 $j=Read-ProductJournal $dirs[0].FullName;Check ($j.verdict -ceq 'INVALID');Check ($j.cleanup -ceq 'NOT_REQUIRED')
 # Repeat creates a distinct diagnostic and journal, never overwrites the previous failure.
 $r=(& $entry -ExpectedManifestHash $hash | Out-String)|ConvertFrom-Json
 Check (@(Get-ChildItem $attempts -Directory).Count -eq 2);Check (@(Get-ChildItem $records -Filter '*.json').Count -eq 4)
 foreach($stage in @('BUNDLE_VERIFY','RUNTIME_VERIFY','DOCKER_CLIENT','DOCKER_ENGINE','LAB_PORTS','LEASE_STATE','LEASE_START','POSTGRES_READY','AUTH_READY','GATEWAY_READY','BACKEND_HEALTH','JOURNAL_READY','ADB_PREREQUISITE','DEVICE_READONLY_PREFLIGHT')){
  $s=@{stage=$stage;deviceCalls=0};$ops=@{Bundle={};Tools={};Lease={$e=New-Object Exception('INVALID:SYNTHETIC');$e.Data['hostStage']=$s.stage;throw $e}.GetNewClosure();LiveHealth={};Ports={};Artifacts={};Journal={};ReadOnlyTarget={$s.deviceCalls++}.GetNewClosure()}
  try{Invoke-ProductHostGate $ops;throw 'MISSING_FAILURE'}catch{Check ($_.Exception.Data['hostStage'] -ceq $stage)}
  Check ($s.deviceCalls -eq 0)
 }
 Write-Output "HOST_PREFLIGHT_CHECKS=$script:n;DEVICE=NOT_INVOKED;EARLY_DIAGNOSTICS=DURABLE"
}finally{
 foreach($module in @(Get-Module -All|Where-Object{$_.Path -and $_.Path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)})){Remove-Module -ModuleInfo $module -Force -ErrorAction SilentlyContinue}
 $env:LOCALAPPDATA=$prior;Remove-Item $root -Recurse -Force
}
