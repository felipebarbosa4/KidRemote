Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Canonical.psm1')
function New-ProductPairing([scriptblock]$Wire,[Security.SecureString]$Jwt,[scriptblock]$OnStage={}){
 & $OnStage PAIRING_SESSION_CREATE
 $r=& $Wire gateway '/parent/pairing-sessions' POST @{} $Jwt
 & $OnStage PAIRING_SESSION_VALIDATE
 if($r.result -cne 'CREATED' -or $r.qr.protocol_version -ne 1 -or $r.qr.session_id -cnotmatch '^[a-f0-9-]{36}$' -or $r.qr.token -cnotmatch '^[A-Za-z0-9_-]{43}$'){throw 'INVALID:PAIRING_SCHEMA'}
 try{$expires=[DateTimeOffset]::Parse($r.expires_at)}catch{throw 'INVALID:PAIRING_EXPIRY'}
 if($expires -le [DateTimeOffset]::UtcNow -or $expires -gt [DateTimeOffset]::UtcNow.AddMinutes(6)){throw 'INVALID:PAIRING_EXPIRY'}
 return $r
}
function Get-OnlyLabChild([scriptblock]$Wire,[Security.SecureString]$Jwt){
 $r=& $Wire rest '/rpc/parent_devices' POST @{p_after=$null} $Jwt
 if($r.protocol_version -ne 1 -or $r.devices -isnot [Array] -or $r.devices.Count -gt 50){throw 'INVALID:PAIRING_DUPLICATE_OR_SCHEMA'}
 if(@($r.devices|Where-Object{$_.revoked -isnot [bool]}).Count){throw 'INVALID:PAIRING_DEVICE_SCHEMA'}
 $r.devices=@($r.devices|Where-Object{-not $_.revoked})
 if($r.devices.Count -gt 1){throw 'INVALID:PAIRING_DUPLICATE_OR_SCHEMA'}
 if($r.devices.Count -eq 0){return $null}
 $d=$r.devices[0]
 foreach($k in @('id','policy_epoch')){if($d.$k -cnotmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'){throw 'INVALID:PAIRING_DEVICE_SCHEMA'}}
 if($d.version -isnot [int] -and $d.version -isnot [long]){throw 'INVALID:PAIRING_DEVICE_VERSION'}
 return $d
}
function Invoke-StableLabOperation([scriptblock]$Wire,[Security.SecureString]$Jwt,$Request){
 # One retry of an ambiguous HTTP result, exact object/UUID/version. Never retries conflicts/auth denial.
 for($i=0;$i -lt 2;$i++){
  try{return (& $Wire gateway ('/parent/devices/'+$Request.device_id+'/operations') POST $Request $Jwt)}
  catch{if($i -eq 1 -or $_.Exception.Message -cnotin @('INVALID:HTTP_TIMEOUT_OR_REFUSED','INVALID:HTTP_503')){throw}}
 }
}
function Set-InitialLabLimit([scriptblock]$Wire,[Security.SecureString]$Jwt,$Device,[string]$OperationId){
 if($Device.version -ne 0 -or $Device.policy_configured -isnot [bool] -or $Device.policy_configured){throw 'INVALID:INITIAL_POLICY_ALREADY_CHANGED'}
 $q=@{protocol_version=1;operation_id=$OperationId;device_id=$Device.id;kind='SET_DAILY_LIMIT';payload=@{daily_limit_seconds=3600};expected_version=0}
 $r=Invoke-StableLabOperation $Wire $Jwt $q
 if($r.status -cne 'accepted' -or $r.operation_id -cne $OperationId -or $r.device_id -cne $Device.id -or $r.policy_epoch -cne $Device.policy_epoch -or $r.version -ne 1){throw 'INVALID:INITIAL_POLICY_RESULT'}
 return $r
}
function Get-ReviewedPairingExpectations($HistoryReviews){
 $created=@{};$resolved=@{}
 foreach($history in @($HistoryReviews)){
  if($history.PSObject.Properties.Name -contains 'pairingSession'){
   $session=$history.pairingSession
   if($null -eq $session -or $session.id -cnotmatch '^[a-f0-9-]{36}$' -or $session.disposition -cnotin @('OPEN','CANCELLED') -or $created.ContainsKey($session.id)){throw 'INVALID:PAIRING_REVIEW_SCHEMA'}
   $created[$session.id]=[string]$session.disposition
  }
  if($history.PSObject.Properties.Name -contains 'pairingResolution'){
   $resolution=$history.pairingResolution
   if($null -eq $resolution -or $resolution.id -cnotmatch '^[a-f0-9-]{36}$' -or $resolution.from -cne 'OPEN' -or $resolution.to -cne 'CANCELLED' -or $resolved.ContainsKey($resolution.id)){throw 'INVALID:PAIRING_REVIEW_SCHEMA'}
   $resolved[$resolution.id]=$true
  }
 }
 foreach($id in $resolved.Keys){
  if(-not $created.ContainsKey($id) -or $created[$id] -cne 'OPEN'){throw 'INVALID:PAIRING_REVIEW_SCHEMA'}
  $created[$id]='CANCELLED'
 }
 return @($created.GetEnumerator()|Sort-Object Name|ForEach-Object{[pscustomobject]@{id=$_.Key;disposition=$_.Value}})
}
function Invoke-ReviewedPairingCleanup($Review,$HistoryReviews,[scriptblock]$Wire,[Security.SecureString]$Jwt){
 $expected=Get-ReviewedPairingExpectations $HistoryReviews
 $approvedOpen=@($expected|Where-Object{$_.disposition -ceq 'OPEN'}|ForEach-Object{$_.id})
 $actualOpen=@($Review.sessions|Where-Object{-not $_.consumed -and -not $_.cancelled})
 $approvedCount=($approvedOpen|Measure-Object).Count;$actualCount=($actualOpen|Measure-Object).Count;$unreviewedCount=($actualOpen|Where-Object{$_.id -cnotin $approvedOpen}|Measure-Object).Count
 if($actualCount -ne $approvedCount -or $unreviewedCount){throw 'INVALID:PAIRING_CLEANUP_UNREVIEWED_SESSION'}
 foreach($session in $actualOpen){
  $result=& $Wire rest '/rpc/finish_pairing' POST @{p_session=$session.id;p_revoke_incomplete=$false} $Jwt
  if($result.result -cne 'CANCELLED'){throw 'INVALID:PAIRING_CLEANUP_CONCURRENT_REDEMPTION'}
 }
 if($null -ne (Get-OnlyLabChild $Wire $Jwt)){throw 'INVALID:PAIRING_CLEANUP_CREATED_DEVICE'}
 return 'EXACT_REVIEWED_PAIRING_SESSIONS_CANCELLED'
}
Export-ModuleMember -Function New-ProductPairing,Get-OnlyLabChild,Invoke-StableLabOperation,Set-InitialLabLimit,Get-ReviewedPairingExpectations,Invoke-ReviewedPairingCleanup
