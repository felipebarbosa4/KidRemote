Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Review.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ProductRuntimeOemOverlay.psm1') -Force
$script:n=0
function Eq($a,$b){$script:n++;if($a -cne $b){throw "OEM_OVERLAY_$script:n expected $b got $a"}}
function No($s,$e){$m='NONE';try{&$s}catch{$m=$_.Exception.Message};Eq $m $e}
function New-TestConfiguration([string]$manufacturer='samsung',[string]$model='SM-X400',[string]$build='BP4A.251205.006',[string]$patch='2026-07-05'){
 return [ordered]@{manufacturer=$manufacturer;model=$model;android='16';api='36';build=$build;patch=$patch}
}
function State($configuration,[string[]]$present=@(),[int]$extra=0,[string]$override=''){
 $keys=@((Get-ReviewStatePaths $true).Keys)+@((Get-ProductRuntimeOemOverlayPaths $configuration).Keys)
 $lines=@();foreach($key in $keys){$state=if($key -cin $present){'PRESENT|108'}else{'ABSENT|0'};$lines+=($key+'|'+$state)}
 if($override){$parts=$override -split '=',2;$lines=@($lines|ForEach-Object{if($_ -like ($parts[0]+'|*')){$parts[0]+'|'+$parts[1]}else{$_}})}
 $lines+='LINKS|0';$lines+=('TOTAL|'+($present.Count+$extra));return $lines -join "`n"
}
$exact=New-TestConfiguration
$genericCount=(Get-ReviewStatePaths $true).Count
Eq (Get-ProductRuntimeOemOverlayName $exact) 'SAMSUNG_SM_X400_ANDROID_16_API_36_BP4A_251205_006_PATCH_2026_07_05'
Eq (Get-ProductRuntimeOemOverlayName ([pscustomobject]$exact)) 'SAMSUNG_SM_X400_ANDROID_16_API_36_BP4A_251205_006_PATCH_2026_07_05'
Eq (Get-ProductRuntimeOemOverlayName ([pscustomobject]@{manufacturer='samsung'})) 'NONE'
Eq (Get-ProductRuntimeOemOverlayPaths $exact).runtime_samsung_ids 'shared_prefs/android.app.ActivityThread.IDS.xml'
Eq (Get-ReviewStatePaths $true).Count $genericCount
$observed=@('runtime_profile','runtime_work_no_backup','runtime_work_no_backup_wal','runtime_work_no_backup_shm','runtime_samsung_ids')
$r=Convert-ReviewState (State $exact $observed) $true $exact
Eq $r.otherDurableFiles 0;Eq (@($r.files|Where-Object{$_.kind -ceq 'runtime_samsung_ids' -and $_.presence -ceq 'PRESENT'}).Count) 1
$r=Convert-ReviewState (State $exact $observed 1) $true $exact;Eq $r.otherDurableFiles 1
foreach($different in @((New-TestConfiguration 'google'),(New-TestConfiguration 'samsung' 'SM-X410'),(New-TestConfiguration 'samsung' 'SM-X400' 'BP4A.251205.007'),(New-TestConfiguration 'samsung' 'SM-X400' 'BP4A.251205.006' '2026-08-05'))){
 Eq (Get-ProductRuntimeOemOverlayName $different) 'NONE'
 $raw=State $different @() 1
 $r=Convert-ReviewState $raw $true $different;Eq $r.otherDurableFiles 1
}
No {Convert-ReviewState (State $exact @('runtime_samsung_ids') 0 'runtime_samsung_ids=UNKNOWN|0') $true $exact} 'PRIVATE_STATE_REVIEW_REQUIRED'
# A directory/nonregular entry produces the same UNKNOWN row; a case/path mismatch is absent plus one unexplained file.
No {Convert-ReviewState (State $exact @('runtime_samsung_ids') 0 'runtime_samsung_ids=UNKNOWN|0') $true $exact} 'PRIVATE_STATE_REVIEW_REQUIRED'
$r=Convert-ReviewState (State $exact @() 1) $true $exact;Eq $r.otherDurableFiles 1
Eq (Get-ReviewStatePaths $true).Count $genericCount
$live=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../product-oracle/LivePreparation.psm1'))
Eq ($live -match '\$s\.runtimeConfiguration=\$i\.configuration') $true
Eq ($live -match 'Get-PrivateMetadata \$Adb \$Serial \$run \$true \$s\.runtimeConfiguration') $true
$evidencePath=Join-Path $PSScriptRoot '../../../docs/test-plans/evidence/PRODUCT-SAMSUNG-IDS-CLASSIFICATION-2026-09-16.json'
$evidence=(Get-Content -LiteralPath $evidencePath -Raw)|ConvertFrom-Json
Eq $evidence.probeAttempt '88af2a3b-bdfd-4d5b-b814-729facbac4a9'
Eq $evidence.probeResultSha256 'f4bff1b17176ce621db4c27c412710b8148f604422d0bc62fca6d968ecb13e14'
Eq $evidence.classification.logicalKind 'runtime_samsung_ids'
$physical=Join-Path $env:LOCALAPPDATA 'KidRemote\metadata-observation-results\88af2a3b-bdfd-4d5b-b814-729facbac4a9.json'
if(Test-Path -LiteralPath $physical){Eq (Get-FileHash -LiteralPath $physical -Algorithm SHA256).Hash.ToLowerInvariant() $evidence.probeResultSha256;Eq (Get-Item -LiteralPath $physical).Length ([long]$evidence.probeResultBytes)}
Write-Output "PRODUCT_RUNTIME_OEM_OVERLAY_CHECKS=$script:n;EXACT_CONFIGURATION_ONLY=PASS;DEVICE=NOT_INVOKED"
