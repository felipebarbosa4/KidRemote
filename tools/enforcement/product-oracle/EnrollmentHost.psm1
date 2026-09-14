Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Canonical.psm1') -Force
function New-ProductPairing([scriptblock]$Wire,[Security.SecureString]$Jwt){
 $r=& $Wire gateway '/parent/pairing-sessions' POST @{} $Jwt
 if($r.result -cne 'CREATED' -or $r.qr.protocol_version -ne 1 -or $r.qr.session_id -cnotmatch '^[a-f0-9-]{36}$' -or $r.qr.token -cnotmatch '^[A-Za-z0-9_-]{43}$'){throw 'INVALID:PAIRING_SCHEMA'}
 try{$expires=[DateTimeOffset]::Parse($r.expires_at)}catch{throw 'INVALID:PAIRING_EXPIRY'}
 if($expires -le [DateTimeOffset]::UtcNow -or $expires -gt [DateTimeOffset]::UtcNow.AddMinutes(6)){throw 'INVALID:PAIRING_EXPIRY'}
 return $r
}
function Get-OnlyLabChild([scriptblock]$Wire,[Security.SecureString]$Jwt){
 $r=& $Wire rest '/rpc/parent_devices' POST @{p_after=$null} $Jwt
 if($r.protocol_version -ne 1 -or $r.devices -isnot [Array] -or $r.devices.Count -gt 1){throw 'INVALID:PAIRING_DUPLICATE_OR_SCHEMA'}
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
Export-ModuleMember -Function New-ProductPairing,Get-OnlyLabChild,Invoke-StableLabOperation,Set-InitialLabLimit
