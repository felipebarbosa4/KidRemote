Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'EnrollmentHost.psm1') -Force
$script:n=0;function Check($value){$script:n++;if(-not $value){throw "PAIRING_CLEANUP_CHECK_$script:n"}}
$jwt=ConvertTo-SecureString 'synthetic-private-jwt' -AsPlainText -Force
try{
 $cancelled=[Guid]::NewGuid().ToString();$open=[Guid]::NewGuid().ToString()
 $review=[pscustomobject]@{sessions=@([pscustomobject]@{id=$cancelled;device=$null;consumed=$false;cancelled=$true},[pscustomobject]@{id=$open;device=$null;consumed=$false;cancelled=$false})}
 $history=@([pscustomobject]@{pairingSession=[pscustomobject]@{id=$cancelled;disposition='CANCELLED'}},[pscustomobject]@{pairingSession=[pscustomobject]@{id=$open;disposition='OPEN'}})
 $state=@{calls=@()};$wire={param($service,$path,$method,$body,$secret)$state.calls+=,[pscustomobject]@{service=$service;path=$path;method=$method;session=$body.p_session};if($path -ceq '/rpc/finish_pairing'){return [pscustomobject]@{result='CANCELLED'}};return [pscustomobject]@{protocol_version=1;devices=@()}}.GetNewClosure()
 Check ((Invoke-ReviewedPairingCleanup $review $history $wire $jwt) -ceq 'EXACT_REVIEWED_PAIRING_SESSIONS_CANCELLED')
 Check ($state.calls.Count -eq 2);Check ($state.calls[0].path -ceq '/rpc/finish_pairing');Check ($state.calls[0].session -ceq $open);Check ($state.calls[1].path -ceq '/rpc/parent_devices')
 Check (($state.calls|Where-Object{$_.path -ceq '/parent/pairing-sessions'}|Measure-Object).Count -eq 0)
 $foreign=[Guid]::NewGuid().ToString();$review.sessions+=,[pscustomobject]@{id=$foreign;device=$null;consumed=$false;cancelled=$false};$before=$state.calls.Count;$caught=$false
 try{$null=Invoke-ReviewedPairingCleanup $review $history $wire $jwt}catch{$caught=$_.Exception.Message -ceq 'INVALID:PAIRING_CLEANUP_UNREVIEWED_SESSION'}
 Check $caught;Check ($state.calls.Count -eq $before)
 $review.sessions=@([pscustomobject]@{id=$open;device=$null;consumed=$false;cancelled=$false});$history=@([pscustomobject]@{pairingSession=[pscustomobject]@{id=$open;disposition='OPEN'}})
 $wire={param($service,$path,$method,$body,$secret)if($path -ceq '/rpc/finish_pairing'){return [pscustomobject]@{result='ALREADY_REDEEMED'}};throw 'UNEXPECTED_CALL'}
 $caught=$false;try{$null=Invoke-ReviewedPairingCleanup $review $history $wire $jwt}catch{$caught=$_.Exception.Message -ceq 'INVALID:PAIRING_CLEANUP_CONCURRENT_REDEMPTION'};Check $caught
 Write-Output "PAIRING_CLEANUP_CHECKS=$script:n;CANONICAL_FINISH_PAIRING=PASS;NO_DUPLICATE_DEVICE=PASS;DEVICE=NOT_INVOKED"
}finally{$jwt.Dispose()}
