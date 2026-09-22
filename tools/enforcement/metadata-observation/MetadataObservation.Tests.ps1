Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../update-review/ProductRuntimeCatalog.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'MetadataObservation.psm1') -Force
$script:n=0
function Check([bool]$Value){$script:n++;if(-not $Value){throw "CHECK_$script:n"}}
function Eq($Actual,$Expected){$script:n++;if($Actual -cne $Expected){throw "CHECK_$script:n expected=$Expected actual=$Actual"}}
function Fails([scriptblock]$Body,[string]$Expected){$message='NONE';try{&$Body}catch{$message=$_.Exception.Message};Eq $message $Expected}
function Raw([string[]]$Known=@(),$Unexpected=@()){
 $lines=@('OD51META|1');foreach($kind in $Known){$lines+=('KNOWN|'+$kind+'|40')};foreach($u in $Unexpected){$lines+=('UNEXPECTED|'+$u.directory+'|'+$u.relativeName+'|'+$u.bytes)}
 $lines+=('COUNTS|'+($Known.Count+$Unexpected.Count)+'|'+$Known.Count+'|'+$Unexpected.Count);$lines+='END|1';return ($lines -join "`n")+"`n"
}
$paths=Get-ReviewStatePaths $true
Check ($paths.Count -gt (Get-ReviewStatePaths).Count)
Eq @($paths.Values|Select-Object -Unique).Count $paths.Count
$scriptText=Get-Od51MetadataScript $paths
Check ($scriptText.Contains('OD51META|1'))
Check ($scriptText.Contains('UNKNOWN') -eq $false)
Check ($scriptText -notmatch '(?m)(^|[;&|]\s*)(cat|sqlite3|rm|mv|cp|touch|mkdir|am|settings|appops|input|content)(\s|$)')

$empty=Convert-Od51MetadataOutput (Raw) $paths
Eq $empty.metadataStatus 'METADATA_ONLY';Eq $empty.metadataFinding 'METADATA_ONLY';Eq $empty.metadataKnown $true;Eq $empty.totalDurableFiles 0;Eq $empty.knownDurableFiles 0;Eq $empty.otherDurableFiles 0
$allKnown=@($paths.Keys);$known=Convert-Od51MetadataOutput (Raw $allKnown) $paths
Eq $known.metadataStatus 'METADATA_ONLY';Eq $known.totalDurableFiles $paths.Count;Eq $known.knownDurableFiles $paths.Count;Eq $known.otherDurableFiles 0;Eq @($known.knownPresent).Count $paths.Count
$one=@([pscustomobject]@{directory='files';relativeName='bounded-runtime.bin';bytes=17})
$unknown=Convert-Od51MetadataOutput (Raw @() $one) $paths
Eq $unknown.metadataStatus 'METADATA_ONLY';Eq $unknown.metadataFinding 'UNKNOWN_DURABLE_FILES_PRESENT';Eq $unknown.metadataKnown $true;Eq $unknown.otherDurableFiles 1;Eq $unknown.unexpectedStructuralEntries[0].directory 'files';Eq $unknown.unexpectedStructuralEntries[0].relativeName 'bounded-runtime.bin';Eq $unknown.unexpectedStructuralEntries[0].bytes 17
$many=@([pscustomobject]@{directory='no_backup';relativeName='one.dat';bytes=1},[pscustomobject]@{directory='databases';relativeName='nested/two.db';bytes=2},[pscustomobject]@{directory='shared_prefs';relativeName='three.xml';bytes=3})
$multiple=Convert-Od51MetadataOutput (Raw @('runtime_profile') $many) $paths
Eq $multiple.totalDurableFiles 4;Eq $multiple.knownDurableFiles 1;Eq $multiple.otherDurableFiles 3

$ok=[pscustomobject]@{exitCode=0;stdout=(Raw);stderrPresent=$false;outputTooLarge=$false}
Eq (Convert-Od51MetadataProcessResult $ok $paths).metadataStatus 'METADATA_ONLY'
foreach($case in @(@(1,'','RUN_AS_FAILED'),@(20,"OD51META|1`n",'PRIVATE_DIRECTORY_UNREADABLE'),@(21,"OD51META|1`n",'SYMLINK_OR_NONREGULAR_ENTRY'),@(22,"OD51META|1`n",'METADATA_OUTPUT_BOUNDS'),@(23,"OD51META|1`n",'METADATA_OUTPUT_SCHEMA_INVALID'))){
 $r=Convert-Od51MetadataProcessResult ([pscustomobject]@{exitCode=$case[0];stdout=$case[1];stderrPresent=$true;outputTooLarge=$false}) $paths;Eq $r.metadataStatus $case[2];Eq $r.metadataKnown $false
}
$malformed=Convert-Od51MetadataProcessResult ([pscustomobject]@{exitCode=0;stdout="OD51META|1`nBAD`nEND|1`n";stderrPresent=$false;outputTooLarge=$false}) $paths;Eq $malformed.metadataStatus 'METADATA_OUTPUT_SCHEMA_INVALID'
$oversized=Convert-Od51MetadataProcessResult ([pscustomobject]@{exitCode=0;stdout='';stderrPresent=$false;outputTooLarge=$true}) $paths;Eq $oversized.metadataStatus 'METADATA_OUTPUT_BOUNDS'
$stderrOnly=Convert-Od51MetadataProcessResult ([pscustomobject]@{exitCode=0;stdout=(Raw);stderrPresent=$true;outputTooLarge=$false}) $paths;Eq $stderrOnly.metadataStatus 'METADATA_OUTPUT_SCHEMA_INVALID'
Fails {Convert-Od51MetadataOutput ((Raw)+('x'*33000)) $paths} 'METADATA_OUTPUT_BOUNDS'
Fails {Convert-Od51MetadataOutput (Raw @() @([pscustomobject]@{directory='files';relativeName='../escape';bytes=1})) $paths} 'METADATA_OUTPUT_SCHEMA_INVALID'
Fails {Convert-Od51MetadataOutput (Raw @() @([pscustomobject]@{directory='files';relativeName='profileInstalled';bytes=1})) $paths} 'METADATA_OUTPUT_SCHEMA_INVALID'
Fails {Convert-Od51MetadataOutput "OD51META|1`nUNEXPECTED|cache|outside.dat|1`nCOUNTS|1|0|1`nEND|1`n" $paths} 'METADATA_OUTPUT_SCHEMA_INVALID'
$sixtyFive=@();for($i=0;$i -lt 65;$i++){$sixtyFive+=,[pscustomobject]@{directory='files';relativeName=('extra-'+$i+'.dat');bytes=$i}}
Fails {Convert-Od51MetadataOutput (Raw @() $sixtyFive) $paths} 'METADATA_OUTPUT_BOUNDS'

$fixed=$scriptText;$pull='C:\Temp\installed-base.apk'
foreach($allowed in @(
 @(@('devices'),''),
 @(@('shell','am','get-current-user'),''),
 @(@('shell','getprop','ro.product.model'),''),
 @(@('shell','pm','path','dev.kidremote.child.unassigned.debug'),''),
 @(@('shell','dumpsys','package','dev.kidremote.spike.ordinary'),''),
 @(@('shell','sha256sum','/data/app/x/base.apk'),''),
 @(@('reverse','--list'),''),
 @(@('pull','/data/app/x/base.apk',$pull),''),
 @(@('shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh'),$fixed)
)){Check (Test-Od51AdbCommand $allowed[0] $allowed[1] $fixed $pull)}

$forbidden=@(
 @('install','x.apk'),@('uninstall','dev.kidremote.child.unassigned.debug'),@('shell','pm','clear','dev.kidremote.child.unassigned.debug'),@('reverse','tcp:47366','tcp:47366'),
 @('shell','am','start','-n','x/y'),@('shell','settings','put','secure','x','1'),@('shell','appops','set','dev.kidremote.child.unassigned.debug','GET_USAGE_STATS','allow'),
 @('shell','input','tap','1','1'),@('shell','rm','x'),@('shell','mv','x','y'),@('shell','cp','x','y'),@('shell','touch','x'),@('shell','mkdir','x'),
 @('shell','sqlite3','x'),@('shell','cat','x'),@('shell','content','query','--uri','x'),@('shell','screencap','-p'),@('shell','-T','run-as','other.package','sh')
)
foreach($command in $forbidden){Check (-not (Test-Od51AdbCommand $command '' $fixed $pull))}
foreach($payload in @('rm x','cat no_backup/device-identity','sqlite3 no_backup/accounting.db','touch x','cp x y','mv x y','mkdir x')){Check (-not (Test-Od51AdbCommand @('shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh') $payload $fixed $pull))}
Check (-not (Test-Od51AdbCommand @('pull','/data/app/x/base.apk','C:\Temp\other.apk') '' $fixed $pull))
Eq (Select-Od51Target "List of devices attached`nSYNTHETIC-1`tdevice`n") 'SYNTHETIC-1'
foreach($bad in @("List of devices attached`n", "List of devices attached`nemulator-5554`tdevice`n", "List of devices attached`na`tdevice`nb`tdevice`n", "List of devices attached`na`tunauthorized`n")){Fails {Select-Od51Target $bad} 'ONE_AUTHORIZED_NON_EMULATOR_TARGET_REQUIRED'}
Eq (Test-Od51ReverseAbsent '' 47366) $true
Eq (Test-Od51ReverseAbsent "SYNTHETIC-1 tcp:47366 tcp:47366`n" 47366) $false
Eq (Test-Od51ReverseAbsent "SYNTHETIC-1 tcp:40000 tcp:40001`n" 47366) $true
Fails {Test-Od51ReverseAbsent 'PRIVATE malformed output' 47366} 'REVERSE_OUTPUT_INVALID'

$adbOk=[pscustomobject]@{exitCode=0;stdout='safe';stderrPresent=$false;outputTooLarge=$false}
Eq (Get-Od51AdbText $adbOk) 'safe'
Fails {Get-Od51AdbText ([pscustomobject]@{exitCode=0;stdout='safe';stderrPresent=$true;outputTooLarge=$false})} 'ADB_STDERR_PRESENT'
Fails {Get-Od51AdbText ([pscustomobject]@{exitCode=7;stdout='';stderrPresent=$false;outputTooLarge=$false})} 'ADB_EXIT_NONZERO'
Fails {Get-Od51AdbText ([pscustomobject]@{exitCode=0;stdout='';stderrPresent=$false;outputTooLarge=$true})} 'ADB_OUTPUT_TOO_LARGE'
$pullResult=[pscustomobject]@{exitCode=0;stdout='';stderrPresent=$true;outputTooLarge=$false}
Assert-Od51PullResult $pullResult $pull $pull;Check $true
Fails {Assert-Od51PullResult $pullResult 'C:\Temp\other.apk' $pull} 'READ_ONLY_COMMAND_REJECTED'
Fails {Assert-Od51PullResult ([pscustomobject]@{exitCode=8;stdout='';stderrPresent=$true;outputTooLarge=$false}) $pull $pull} 'ADB_EXIT_NONZERO'
Fails {Assert-Od51PullResult ([pscustomobject]@{exitCode=0;stdout='';stderrPresent=$true;outputTooLarge=$true}) $pull $pull} 'ADB_OUTPUT_TOO_LARGE'
$localApk=Join-Path ([IO.Path]::GetTempPath()) ('kr-pull-'+[Guid]::NewGuid()+'.apk')
try{
 [IO.File]::WriteAllText($localApk,'bounded apk bytes');$localHash=(Get-FileHash -LiteralPath $localApk -Algorithm SHA256).Hash.ToLowerInvariant()
 Assert-Od51LocalApk $localApk $localApk $localHash;Check $true
 Fails {Assert-Od51LocalApk $localApk $localApk ('0'*64)} 'PACKAGE_PROVENANCE_INVALID'
 Fails {Assert-Od51LocalApk ($localApk+'.missing') ($localApk+'.missing') $localHash} 'PACKAGE_PROVENANCE_INVALID'
}finally{if(Test-Path -LiteralPath $localApk){Remove-Item -LiteralPath $localApk -Force}}

$runtimeSource=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Read-CurrentMetadata.ps1'))
Check ($runtimeSource -notmatch 'Import-Module[^\r\n]*(Journal|BackendHost|EnrollmentHost|ProductTransport)|Invoke-WebRequest|HttpClient|screencap|screenshot')
Check ($runtimeSource -notmatch 'Invoke-RestMethod|https?://|\bLOCK\b|\bUNLOCK\b')
Check ($runtimeSource.Contains("scope='OD51_READ_ONLY_METADATA_OBSERVATION'"))
Check ($runtimeSource.Contains("deviceMutation=`$false"));Check ($runtimeSource.Contains("backendMutation=`$false"));Check ($runtimeSource.Contains("productPhysicalOracle='BLOCKED'"))
foreach($stage in @('DEVICE_SELECTION','CONFIGURATION_READ','CHILD_PACKAGE_READ','FIXTURE_PACKAGE_READ','REVERSE_READ','CHILD_APK_PULL','CHILD_APK_LOCAL_VERIFY','CHILD_APK_SIGNER_VERIFY','METADATA_RUN_AS','METADATA_PARSE')){Check ($runtimeSource.Contains("'$stage'"))}
Check ($runtimeSource -notmatch "'ADB_READ_FAILED'")
Write-Output "OD51_METADATA_OBSERVATION_CHECKS=$script:n;DEVICE=NOT_INVOKED"
