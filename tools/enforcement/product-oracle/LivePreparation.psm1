Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'ReplacementAdb.psm1')
Import-Module (Join-Path $PSScriptRoot 'ReadOnly.psm1')
Import-Module (Join-Path $PSScriptRoot '../update-review/Review.psm1')
Import-Module (Join-Path $PSScriptRoot 'Canonical.psm1')
Import-Module (Join-Path $PSScriptRoot 'EnrollmentHost.psm1')
Import-Module (Join-Path $PSScriptRoot 'QrPresentation.psm1')
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
Import-Module (Join-Path $PSScriptRoot 'ProductOracle.psm1')

function New-LivePreparation([string]$Adb,[string]$Serial,[string]$Bundle,[string]$Temporary,[Security.SecureString]$Jwt,[bool]$Reuse=$false,$SavedDevice=$null,[string]$Directory=''){
 $java=Join-Path $Bundle 'runtime\jbr\bin\java.exe'
 $jar=Join-Path $Bundle 'runtime\apksigner.jar'
 $apk=Join-Path $Bundle 'lab-reference.apk'
 $run={param($e,$a,$inputText) Invoke-ReviewProcess $e $a $inputText}
 $read={param($a) Invoke-InventoryAdb $Adb $Serial $a}.GetNewClosure()
 $wire={param($s,$p,$m,$b,$j) Invoke-LabWire $s $p $m $b $j}
 $s=@{new=$Reuse;device=$SavedDevice;reverse=$false;reverseAttempted=$false;runtimeConfiguration=$null}
 $action={param($name) $null=Invoke-ReplacementAdb $Adb $Serial $name $apk $run}.GetNewClosure()
 $ops=@{}
 $ops.HostReady={
  $r=& $run $java @('--enable-native-access=ALL-UNNAMED','-jar',$jar,'verify','--verbose','--print-certs',$apk) ''
  if($r.stderr.Trim() -or (Convert-ReviewSigner $r.stdout) -cne '638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb'){throw 'INVALID:LAB_SIGNER'}

 }.GetNewClosure()
 $ops.Configuration={
  $i=Invoke-ReadOnlyInventory $read
  if($i.classification -ceq 'CONFIGURATION_MISMATCH'){throw 'INVALID:CONFIGURATION_MISMATCH'}
  $s.runtimeConfiguration=$i.configuration
  Assert-LabReverse (Invoke-ReplacementAdb $Adb $Serial ReverseRead $apk $run) $false
 }.GetNewClosure()
 $ops.FixtureHash={(Get-InventoryPackage 'dev.kidremote.spike.ordinary' $read).sha256}.GetNewClosure()
 $ops.Installed={
  $p=Get-InventoryPackage 'dev.kidremote.child.unassigned.debug' $read
  if(-not $p.installed){throw 'INVALID:CHILD_ABSENT'}
  $hash=if($p.sha256 -ceq 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'){'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'}else{'3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9'}
  $signed=Get-InstalledSigner $Adb $Serial $p.basePath $Temporary $java $jar $run $hash
  if($p.sha256 -cne $signed.sha256){throw 'INVALID:INSTALLED_HASH_CHANGED'}
  [pscustomobject]@{package='dev.kidremote.child.unassigned.debug';sha256=$signed.sha256;signer=$signed.signerSha256;version=[int]$p.versionCode;versionName=$p.versionName;serviceRegistered=$p.serviceRegistered}
 }.GetNewClosure()
 $ops.Uninstall={& $action Uninstall}.GetNewClosure()
 $ops.Absent={-not (Get-InventoryPackage 'dev.kidremote.child.unassigned.debug' $read).installed}.GetNewClosure()
 $ops.Install={& $action Install;$s.new=$true}.GetNewClosure()
 $ops.Reverse={
  Assert-LabReverse (Invoke-ReplacementAdb $Adb $Serial ReverseRead $apk $run) $false
  $s.reverseAttempted=$true;& $action Reverse;$s.reverse=$true
  Assert-LabReverse (Invoke-ReplacementAdb $Adb $Serial ReverseRead $apk $run) $true
 }.GetNewClosure()
 $ops.Enroll={
  $q=New-ProductPairing $wire $Jwt
  $window=$null
  try{
   $encoded=& $run $java @('-cp',((Join-Path $Bundle 'host-qr.jar')+';'+(Join-Path $Bundle 'zxing-core.jar')),'HostQr') ($q.qr|ConvertTo-Json -Compress)
   if($encoded.stderr.Trim()){throw 'INVALID:QR_PRESENTATION_FAILED'}
   $window=New-ProductQrWindow $encoded.stdout
   $poll={Get-OnlyLabChild $wire $Jwt}.GetNewClosure()
   $open={& $action OpenChild}.GetNewClosure()
   $instruction={
    Write-Host 'QR_WINDOW_READY: janela KidRemote verificada e sempre no topo; a ativacao de foco depende do Windows.'
    Write-Host 'No KidRemote: toque Escanear QR, permita a camera se solicitado e escaneie o QR exibido.'
   }
   $s.device=Invoke-ProductQrEnrollment $window $open $poll $instruction
  }finally{if($window){$window.Dispose()};$q=$null;$encoded=$null}
 }.GetNewClosure()
 $ops.Consent={
  $i=Invoke-ReadOnlyInventory $read
  if($i.usageAccess -cne 'ENABLED'){
   & $action OpenUsage;Write-Host 'Ative somente o Acesso ao uso do KidRemote. A conclusão será detectada automaticamente.'
   $timer=[Diagnostics.Stopwatch]::StartNew()
   do{Start-Sleep -Milliseconds 1000;$i=Invoke-ReadOnlyInventory $read}while($i.usageAccess -cne 'ENABLED' -and $timer.Elapsed.TotalSeconds -lt 180)
   if($i.usageAccess -cne 'ENABLED'){throw 'INVALID:USAGE_CONSENT_TIMEOUT'}
  }
  if($i.accessibility -cne 'ENABLED'){
  & $action OpenChild
  Write-Host 'No KidRemote: toque Concordo · abrir configuração de Acessibilidade; ative o serviço KidRemote nas Configurações.'
  $timer=[Diagnostics.Stopwatch]::StartNew()
  do{Start-Sleep -Milliseconds 1000;$i=Invoke-ReadOnlyInventory $read}while($i.accessibility -cne 'ENABLED' -and $timer.Elapsed.TotalSeconds -lt 180)
  if($i.accessibility -cne 'ENABLED'){throw 'INVALID:ACCESSIBILITY_CONSENT_TIMEOUT'}
  }
  & $action OpenChild
 }.GetNewClosure()
 $ops.Configure={param($eventId)
  $null=Set-InitialLabLimit $wire $Jwt $s.device $eventId
  & $action OpenChild
 }.GetNewClosure()
 $ops.Recovery={param($stage,$changed)
  # No policy is configured before the final preparation stage. Never reinstall old bytes.
  if($stage -ceq 'POLICY_ADMITTED' -and $s.new){& $action OpenAccessibility;Write-Host 'LAB RECOVERY: se houver restrição, desative manualmente somente a Acessibilidade do KidRemote. Resultado permanece INVALID.'}
 }.GetNewClosure()
 $ops.ReuseIdentityPermissions={
  $i=Invoke-ReadOnlyInventory $read;$d=Get-OnlyLabChild $wire $Jwt
  if($null -eq $SavedDevice -or $null -eq $d -or $d.id -cne $SavedDevice.id -or $d.policy_epoch -cne $SavedDevice.policy_epoch -or $i.accessibility -cne 'ENABLED' -or $i.usageAccess -cne 'ENABLED'){throw 'INVALID:REUSE_IDENTITY_OR_PERMISSIONS'}
  $s.device=$d
 }.GetNewClosure()
 $ops.Metadata={Get-PrivateMetadata $Adb $Serial $run $true $s.runtimeConfiguration}.GetNewClosure()
 $ops.VerifyReuse={
  $before=Get-OnlyLabChild $wire $Jwt
  if(-not $before -or -not $SavedDevice -or $before.id -cne $SavedDevice.id -or $before.policy_epoch -cne $SavedDevice.policy_epoch){throw 'INVALID:REUSE_IDENTITY_MISMATCH'}
  $sequence=if($before.report){[long]$before.report.sequence}else{-1}
  $started=[DateTimeOffset]::UtcNow;& $action OpenChild
  $timer=[Diagnostics.Stopwatch]::StartNew();$verified=$false
  do{
   $after=Get-OnlyLabChild $wire $Jwt
   if($after -and $after.id -ceq $before.id -and $after.policy_epoch -ceq $before.policy_epoch -and $after.report -and $after.report.sequence -gt $sequence -and [DateTimeOffset]::Parse($after.report.received_at) -ge $started){$verified=$true;break}
   Start-Sleep -Milliseconds 500
  }while($timer.Elapsed.TotalSeconds -lt 45)
  if(-not $verified){throw 'INVALID:REUSE_AUTHENTICATED_ACK_NOT_ESTABLISHED'}
  $s.device=$after
 }.GetNewClosure()
 $ops.Resume={& $action OpenChild}.GetNewClosure()
 $ops.Normalize={param($eventId)
  $d=Get-OnlyLabChild $wire $Jwt
  if($d.id -cne $SavedDevice.id -or $d.policy_epoch -cne $SavedDevice.policy_epoch -or -not $d.policy_configured){throw 'INVALID:REUSE_POLICY'}
  # A fresh expected-version canonical UNLOCK cannot silently leave a previous lab lock.
  $q=New-ProductOperation $eventId $d.id UNLOCK $d.version
  $r=Invoke-StableLabOperation $wire $Jwt $q;Assert-ProductAccepted $r $q $d.policy_epoch
  & $action OpenChild
  $timer=[Diagnostics.Stopwatch]::StartNew();$current=$null
  do{try{$current=Get-LabDevice $wire $Jwt $d.id $d.policy_epoch}catch{if($_.Exception.Message -cne 'INVALID:REPORT_STALE_OR_CONCURRENT'){throw}};if($current -and $current.version -eq $r.version){break};Start-Sleep -Milliseconds 500}while($timer.Elapsed.TotalSeconds -lt 30)
  if(-not $current -or $current.version -ne $r.version -or $current.report.manual_lock){throw 'INVALID:REUSE_UNLOCK_UNVERIFIED'}
  if($current.report.remaining_ms -le 180000){
   $grant=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $grant ALLOWANCE_ADMITTED OD51_FIXED_SCOPE
   $q=@{protocol_version=1;operation_id=$grant;device_id=$d.id;kind='ADD_TIME';payload=@{seconds=600;period_key=$current.report.period_key};expected_version=$null}
   $added=Invoke-StableLabOperation $wire $Jwt $q
   if($added.status -cne 'accepted' -or $added.operation_id -cne $grant -or $added.device_id -cne $d.id -or $added.policy_epoch -cne $d.policy_epoch -or $added.version -ne $current.version+1){throw 'INVALID:REUSE_ALLOWANCE_RESULT'}
   & $action OpenChild
  }
 }.GetNewClosure()
 return @{ops=$ops;state=$s;wire=$wire;read=$read;action=$action}
}
Export-ModuleMember -Function New-LivePreparation
