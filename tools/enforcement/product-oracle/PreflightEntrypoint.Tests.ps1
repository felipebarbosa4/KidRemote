Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('kr-readonly-entry-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root);$oldLocal=$env:LOCALAPPDATA;$oldMode=$env:KR_INVENTORY_TEST_MODE;$n=0
try{
 $exe=Join-Path $root 'fixture.exe';$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
 $null=& $compiler /nologo /target:exe "/out:$exe" (Join-Path $PSScriptRoot 'InventoryFixture.cs');if($LASTEXITCODE -ne 0){throw 'FAKE_COMPILER'}
 foreach($file in @('ReadOnly.psm1','ReadOnly-Preflight.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $root}
 $m=@{scope='READ_ONLY_SAMSUNG_INVENTORY';source=('a'*40);files=@()}
 foreach($file in @('ReadOnly.psm1','ReadOnly-Preflight.ps1')){$m.files+=@{name=$file;sha256=(Get-FileHash (Join-Path $root $file)).Hash.ToLowerInvariant()}}
 $manifest=Join-Path $root 'bundle.json';[IO.File]::WriteAllText($manifest,($m|ConvertTo-Json -Depth 5));$hash=(Get-FileHash $manifest).Hash.ToLowerInvariant()
 $env:LOCALAPPDATA=$root
 $shell=Join-Path $PSHOME $(if($PSVersionTable.PSVersion.Major -eq 5){'powershell.exe'}else{'pwsh.exe'})
 foreach($case in @(@('normal','READY_FOR_INSTALL_REVIEW'),@('mismatch','CONFIGURATION_MISMATCH'),@('reject','INVALID_PREFLIGHT'))){
  $env:KR_INVENTORY_TEST_MODE=$case[0]
  $raw=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'ReadOnly-Preflight.ps1') -Adb $exe -ExpectedManifestHash $hash
  $r=($raw -join "`n")|ConvertFrom-Json;$n++;if($r.result.classification -cne $case[1]){throw 'ENTRY_CLASSIFICATION'}
  $n++;if(($raw -join ' ') -match 'SYNTHETIC_PRIVATE_SERIAL|PRIVATE_SERIAL_DETAIL'){throw 'ENTRY_SERIAL_LEAK'}
 }
 $n++;if(@(Get-ChildItem (Join-Path $root 'KidRemote\product-preflight-results') -Filter '*.json').Count -ne 3){throw 'INDEPENDENT_ATTEMPTS_NOT_PRESERVED'}
 # Hash rejection must happen before invoking even the fake executable.
 $raw=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'ReadOnly-Preflight.ps1') -Adb 'MUST_NOT_START.exe' -ExpectedManifestHash ('b'*64)
 $r=($raw -join "`n")|ConvertFrom-Json;$n++;if($r.result.classification -cne 'INVALID_PREFLIGHT'){throw 'HASH_GATE'}
 [IO.File]::AppendAllText((Join-Path $root 'ReadOnly.psm1'),'# tampered')
 $raw=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'ReadOnly-Preflight.ps1') -Adb 'MUST_NOT_START.exe' -ExpectedManifestHash $hash
 $r=($raw -join "`n")|ConvertFrom-Json;$n++;if($r.result.classification -cne 'INVALID_PREFLIGHT'){throw 'FILE_HASH_GATE'}
 $n++;if(@(Get-ChildItem (Join-Path $root 'KidRemote\product-preflight-results') -Filter '*.json').Count -ne 5){throw 'FAILED_ATTEMPTS_LOST'}
 Write-Output "READ_ONLY_NATIVE_ENTRY_CHECKS=$n;FAKE_EXECUTABLE_ONLY;DEVICE_COMMANDS=NONE"
}finally{$env:LOCALAPPDATA=$oldLocal;$env:KR_INVENTORY_TEST_MODE=$oldMode;Remove-Item -LiteralPath $root -Recurse -Force}
