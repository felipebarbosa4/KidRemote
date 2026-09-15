Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Review.psm1') -Force
$script:n=0
function Eq($a,$b){$script:n++;if($a -cne $b){throw "CHECK_$script:n expected $b got $a"}}
function No($s,$e){$m='NONE';try{&$s}catch{$m=$_.Exception.Message};Eq $m $e}
function State($present=''){
 $lines=@();foreach($key in (Get-ReviewStatePaths).Keys){$lines+=($key+'|'+$(if($present -ceq $key){'PRESENT|40'}else{'ABSENT|0'}))}
 $lines+='LINKS|0';$lines+=('TOTAL|'+$(if($present){'1'}else{'0'}));return $lines -join "`n"
}
$empty=Convert-ReviewState (State);Eq $empty.sufficientForEmptyStateReview $true
foreach($key in (Get-ReviewStatePaths).Keys){$r=Convert-ReviewState (State $key);Eq $r.sufficientForEmptyStateReview $false;Eq $r.totalDurableFiles 1}
foreach($raw in @(((State)+"`nidentity|ABSENT|0"),(State).Replace('LINKS|0','LINKS|1'),(State).Replace('identity|ABSENT|0','identity|UNKNOWN|0'),(State).Replace('TOTAL|0','TOTAL|x'),(State).Replace('identity|ABSENT|0','secret|ABSENT|0'),(State).Replace('identity|ABSENT|0','identity|ABSENT|2'))){No {Convert-ReviewState $raw} 'PRIVATE_STATE_REVIEW_REQUIRED'}
$r=Convert-ReviewState ((State).Replace('TOTAL|0','TOTAL|1'));Eq $r.otherDurableFiles 1;Eq $r.sufficientForEmptyStateReview $false
$cert='a'*64;$sig="Verifies`nNumber of signers: 1`nV2 Signer: certificate SHA-256 digest: $cert`n"
Eq (Convert-ReviewSigner $sig) $cert
Eq (Convert-ReviewSigner $sig.Replace('V2 Signer:','Signer #1')) $cert
foreach($bad in @($sig.Replace('Verifies','DOES NOT VERIFY'),$sig.Replace('SHA-256','SHA-1'),$sig.Replace('signers: 1','signers: 2'),($sig+"Signer #2 certificate SHA-256 digest: $cert`n"),'UNKNOWN')){No {Convert-ReviewSigner $bad} 'READ_ONLY_REVIEW_INVALID'}
$i=[pscustomobject]@{signerSha256=$cert}
Eq (Get-UpdateReviewDecision $i $empty $cert $true) 'SAFE_DATA_PRESERVING_UPDATE_REVIEW'
Eq (Get-UpdateReviewDecision $i (Convert-ReviewState (State identity)) $cert $true) 'PRIVATE_STATE_REVIEW_REQUIRED'
Eq (Get-UpdateReviewDecision $i $empty ('b'*64) $true) 'SIGNER_MISMATCH_BLOCKED'
Eq (Get-UpdateReviewDecision $i $empty $cert $false) 'LAB_APK_PROVENANCE_UNVERIFIED'
Eq (Get-UpdateReviewDecision $null $empty $cert $true) 'READ_ONLY_REVIEW_INVALID'
$r=Get-PrivateMetadata 'FAKE' 'SYNTHETIC' {throw 'PRIVATE_RAW_DENIAL'};Eq $r.status 'UNKNOWN'
$scriptText=Get-ReviewStateScript
Eq ($scriptText -match '\b(cat|sqlite3|rm|touch|chmod|am|monkey|input|reboot)\b') $false
$root=Join-Path ([IO.Path]::GetTempPath()) ('kr-review-test-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
try{
 $known=Join-Path $root 'fixture';[IO.File]::WriteAllText($known,'synthetic APK bytes');$hash=(Get-FileHash $known).Hash.ToLowerInvariant()
 $run={param($exe,$a,$stdinText)
  if($exe -eq 'FAKE_ADB'){Copy-Item -LiteralPath $known -Destination $a[-1];return [pscustomobject]@{stdout='SYNTHETIC_PRIVATE_SERIAL';stderr=''}}
  return [pscustomobject]@{stdout=$sig;stderr=''}
 }
 $r=Get-InstalledSigner FAKE_ADB SYNTHETIC /data/app/x/base.apk $root FAKE_JAVA jar $run $hash
 Eq $r.signerSha256 $cert;Eq (Test-Path (Join-Path $root 'installed-base.apk')) $false
 No {Get-InstalledSigner FAKE_ADB SYNTHETIC /data/app/x/base.apk $root FAKE_JAVA jar $run ('b'*64)} 'READ_ONLY_REVIEW_INVALID'
 Eq (Test-Path (Join-Path $root 'installed-base.apk')) $false
 No {Get-InstalledSigner FAKE_ADB SYNTHETIC '/data/app/../x/base.apk' $root FAKE_JAVA jar $run $hash} 'READ_ONLY_REVIEW_INVALID'
 $failure={param($exe,$a,$stdinText) if($exe -eq 'FAKE_ADB'){Copy-Item $known $a[-1];return};throw 'READ_ONLY_REVIEW_INVALID'}
 No {Get-InstalledSigner FAKE_ADB SYNTHETIC /data/app/x/base.apk $root FAKE_JAVA jar $failure $hash} 'READ_ONLY_REVIEW_INVALID'
 Eq (Test-Path (Join-Path $root 'installed-base.apk')) $false
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
Write-Output "UPDATE_REVIEW_SYNTHETIC_CHECKS=$script:n;PHYSICAL_EXECUTION=NOT_RUN"
