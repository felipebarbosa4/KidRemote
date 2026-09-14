param([string]$Adb='C:\platform-tools\adb.exe',[string]$ExpectedManifestHash)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$safeHash=if($ExpectedManifestHash -cmatch '^[a-f0-9]{64}$'){$ExpectedManifestHash}else{'UNSPECIFIED'}
$attempt=[Guid]::NewGuid().ToString();$source='UNSPECIFIED';$exitCode=0
# No product transport/control modules are imported. This entrypoint never starts apps or sends input.
try{
 $manifestPath=Join-Path $PSScriptRoot 'bundle.json'
 if($ExpectedManifestHash -cnotmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedManifestHash){throw 'INVALID:BUNDLE_HASH'}
 $m=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
 if($m.scope -cne 'READ_ONLY_SAMSUNG_INVENTORY' -or $m.source -cnotmatch '^[a-f0-9]{40}$' -or $m.files.Count -ne 2){throw 'INVALID:BUNDLE_SCHEMA'}
 if(@($m.files|Where-Object{$_.name -ceq 'ReadOnly.psm1'}).Count -ne 1 -or @($m.files|Where-Object{$_.name -ceq 'ReadOnly-Preflight.ps1'}).Count -ne 1){throw 'INVALID:BUNDLE_FILES'}
 $source=$m.source
 foreach($file in $m.files){if($file.name -cnotin @('ReadOnly.psm1','ReadOnly-Preflight.ps1') -or (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $file.name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $file.sha256){throw 'INVALID:BUNDLE_FILE_HASH'}}
 Import-Module (Join-Path $PSScriptRoot 'ReadOnly.psm1') -Force
 $serial=Select-InventoryTarget (Invoke-InventoryAdb $Adb '' @('devices'))
 $read={param($argsToRead) Invoke-InventoryAdb $Adb $serial $argsToRead}.GetNewClosure()
 $result=Invoke-ReadOnlyInventory $read
 if(($result|ConvertTo-Json -Depth 8 -Compress).Contains($serial)){throw 'INVALID:SERIAL_REDACTION'}
 $serial=$null
}catch{$serial=$null;$exitCode=1;$result=[ordered]@{scope='READ_ONLY_INVENTORY_NOT_ENFORCEMENT';classification='INVALID_PREFLIGHT';physicalOracle='BLOCKED';reason='BUNDLE_TRANSPORT_OR_SCHEMA_UNVERIFIED'}}
$output=[ordered]@{attempt=$attempt;utc=[DateTime]::UtcNow.ToString('o');source=$source;bundleSha256=$safeHash;result=$result}
try{
 $dir=Join-Path $env:LOCALAPPDATA 'KidRemote\product-preflight-results';[void][IO.Directory]::CreateDirectory($dir)
 $path=Join-Path $dir ($attempt+'.json');$raw=$output|ConvertTo-Json -Depth 8
 $f=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.Encoding]::UTF8.GetBytes($raw);$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}
 Write-Output $raw
}catch{Write-Output '{"classification":"INVALID_PREFLIGHT","physicalOracle":"BLOCKED","reason":"HOST_EVIDENCE_WRITE_FAILED"}';exit 1}
exit $exitCode
