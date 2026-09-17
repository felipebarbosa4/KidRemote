Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'ReplacementAdb.psm1')
Import-Module (Join-Path $PSScriptRoot 'ReadOnly.psm1')
Import-Module (Join-Path $PSScriptRoot '../update-review/Review.psm1')
Import-Module (Join-Path $PSScriptRoot 'Canonical.psm1')
Import-Module (Join-Path $PSScriptRoot 'EnrollmentHost.psm1')
Import-Module (Join-Path $PSScriptRoot 'QrPresentation.psm1')
Import-Module (Join-Path $PSScriptRoot 'QrRenderer.psm1')
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
Import-Module (Join-Path $PSScriptRoot 'ProductOracle.psm1')

function Set-ProductPreparationStage($State,[string]$Stage){
 $allowed=@('NONE','PAIRING_SESSION_CLEANUP','RESET_RECONCILIATION','REVERSE_CREATE','PAIRING_SESSION_CREATE','PAIRING_SESSION_VALIDATE','QR_RENDER_PROCESS','QR_RENDER_VALIDATE','QR_WINDOW_CREATE','QR_WINDOW_READY_INITIAL','CHILD_OPEN_FOR_SCAN','QR_WINDOW_READY_AFTER_CHILD_OPEN','QR_ENROLLMENT_POLL','QR_ENROLLMENT_TIMEOUT','CONSENT_USAGE','CONSENT_ACCESSIBILITY','INITIAL_POLICY','PRODUCT_SLICE')
 if($Stage -cnotin $allowed){throw 'INVALID:PREPARATION_STAGE_SCHEMA'};$State.preparationStage=$Stage
}
function Throw-ProductPreparationFailure($State,[string]$Message){
 $stage=[string]$State.preparationStage
 $code=switch($stage){
  'PAIRING_SESSION_CLEANUP' {'PAIRING_SESSION_CLEANUP_FAILED'}
  'RESET_RECONCILIATION' {'RESET_RECONCILIATION_FAILED'}
  'REVERSE_CREATE' {'REVERSE_CREATE_FAILED'}
  'PAIRING_SESSION_CREATE' {'PAIRING_SESSION_CREATE_FAILED'}
  'PAIRING_SESSION_VALIDATE' {'PAIRING_SESSION_INVALID'}
  'QR_RENDER_PROCESS' {'QR_RENDER_PROCESS_FAILED'}
  'QR_RENDER_VALIDATE' {'QR_RENDER_OUTPUT_INVALID'}
  'QR_WINDOW_CREATE' {'QR_WINDOW_CREATE_FAILED'}
  'QR_WINDOW_READY_INITIAL' {'QR_WINDOW_NOT_READY'}
  'CHILD_OPEN_FOR_SCAN' {'CHILD_OPEN_FAILED'}
  'QR_WINDOW_READY_AFTER_CHILD_OPEN' {'QR_WINDOW_NOT_READY'}
  'QR_ENROLLMENT_POLL' {'QR_ENROLLMENT_POLL_FAILED'}
  'QR_ENROLLMENT_TIMEOUT' {'PAIRING_TIMEOUT'}
  'CONSENT_USAGE' {if($Message -ceq 'INVALID:USAGE_CONSENT_TIMEOUT'){'USAGE_CONSENT_TIMEOUT'}else{'CONSENT_USAGE_FAILED'}}
  'CONSENT_ACCESSIBILITY' {if($Message -ceq 'INVALID:ACCESSIBILITY_CONSENT_TIMEOUT'){'ACCESSIBILITY_CONSENT_TIMEOUT'}else{'CONSENT_ACCESSIBILITY_FAILED'}}
  'INITIAL_POLICY' {'INITIAL_POLICY_FAILED'}
  default {'PREPARATION_ORCHESTRATION_FAILED'}
 }
 $error=New-Object Exception('INVALID:'+$code);$error.Data['preparationStage']=$stage;$error.Data['preparationCode']=$code;throw $error
}
function Invoke-ProductEnrollmentPreparation($State,[scriptblock]$Pairing,[scriptblock]$Render,[scriptblock]$WindowFactory,[scriptblock]$OpenChild,[scriptblock]$Poll,[scriptblock]$Instruction,[scriptblock]$Stage,[int]$TimeoutMs=240000){
 $q=$null;$encoded=$null;$window=$null
 try{
  $q=& $Pairing $Stage
  $encoded=& $Render $q.qr $Stage
  & $Stage QR_WINDOW_CREATE
  $window=& $WindowFactory $encoded
  return Invoke-ProductQrEnrollment $window $OpenChild $Poll $Instruction $TimeoutMs $Stage
 }catch{Throw-ProductPreparationFailure $State $_.Exception.Message}finally{if($window){$window.Dispose()};$q=$null;$encoded=$null}
}
function Get-ProductPreparationFailure($ErrorRecord,$State){
 $message=[string]$ErrorRecord.Exception.Message
 $stateStage=$null
 if($State -is [Collections.IDictionary]){$stateStage=$State['preparationStage']}elseif($State -and $State.PSObject.Properties.Name -contains 'preparationStage'){$stateStage=$State.preparationStage}
 $stage=if($ErrorRecord.Exception.Data.Contains('preparationStage')){[string]$ErrorRecord.Exception.Data['preparationStage']}elseif($stateStage -and $stateStage -cne 'NONE'){[string]$stateStage}else{'PREPARATION_ORCHESTRATION'}
 $code=if($ErrorRecord.Exception.Data.Contains('preparationCode')){[string]$ErrorRecord.Exception.Data['preparationCode']}elseif($message -cmatch '^INVALID:[A-Z0-9_]{1,120}$'){$message.Substring(8)}else{'PREPARATION_ORCHESTRATION_FAILED'}
 if($stage -cnotmatch '^[A-Z0-9_]{1,80}$'){$stage='PREPARATION_ORCHESTRATION'}
 if($code -cnotmatch '^[A-Z0-9_]{1,120}$'){$code='PREPARATION_ORCHESTRATION_FAILED'}
 return [pscustomobject]@{stage=$stage;code=$code;reason=('INVALID:'+$code)}
}

function New-LivePreparation([string]$Adb,[string]$Serial,[string]$Bundle,[string]$Temporary,[Security.SecureString]$Jwt,[bool]$Reuse=$false,$SavedDevice=$null,[string]$Directory=''){
 $java=Join-Path $Bundle 'runtime\jbr\bin\java.exe'
 $jar=Join-Path $Bundle 'runtime\apksigner.jar'
 $apk=Join-Path $Bundle 'lab-reference.apk'
 $run={param($e,$a,$inputText) Invoke-ReviewProcess $e $a $inputText}
 $read={param($a) Invoke-InventoryAdb $Adb $Serial $a}.GetNewClosure()
 $wire={param($s,$p,$m,$b,$j) Invoke-LabWire $s $p $m $b $j}
 $s=@{new=$Reuse;device=$SavedDevice;reverse=$false;reverseAttempted=$false;runtimeConfiguration=$null;preparationStage='NONE'}
 # GetNewClosure creates a dynamic module. Capture the private function body so
 # Windows PowerShell 5.1 does not have to resolve its private command name later.
 $stageSetter=${function:Set-ProductPreparationStage}
 $stage={param($value)& $stageSetter $s $value}.GetNewClosure()
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
  & $stage REVERSE_CREATE
  Assert-LabReverse (Invoke-ReplacementAdb $Adb $Serial ReverseRead $apk $run) $false
  $s.reverseAttempted=$true;& $action Reverse;$s.reverse=$true
  Assert-LabReverse (Invoke-ReplacementAdb $Adb $Serial ReverseRead $apk $run) $true
 }.GetNewClosure()
 $ops.Enroll={
  $pairing={param($onStage) New-ProductPairing $wire $Jwt $onStage}.GetNewClosure()
  $render={param($qr,$onStage) Invoke-ProductQrRenderer $java @('-cp',((Join-Path $Bundle 'host-qr.jar')+';'+(Join-Path $Bundle 'zxing-core.jar')),'HostQr') ($qr|ConvertTo-Json -Compress) $onStage}.GetNewClosure()
  $factory={param($encoded) New-ProductQrWindow $encoded}
  $poll={Get-OnlyLabChild $wire $Jwt}.GetNewClosure()
  $open={& $action OpenChild}.GetNewClosure()
  $instruction={
    Write-Host 'QR_WINDOW_READY: janela KidRemote verificada e sempre no topo; a ativacao de foco depende do Windows.'
    Write-Host 'No KidRemote: toque Escanear QR, permita a camera se solicitado e escaneie o QR exibido.'
  }
  $s.device=Invoke-ProductEnrollmentPreparation $s $pairing $render $factory $open $poll $instruction $stage
 }.GetNewClosure()
 $ops.Consent={
  try{
   & $stage CONSENT_USAGE
   $i=Invoke-ReadOnlyInventory $read
   if($i.usageAccess -cne 'ENABLED'){
    & $action OpenUsage;Write-Host 'Ative somente o Acesso ao uso do KidRemote. A conclusão será detectada automaticamente.'
    $timer=[Diagnostics.Stopwatch]::StartNew()
    do{Start-Sleep -Milliseconds 1000;$i=Invoke-ReadOnlyInventory $read}while($i.usageAccess -cne 'ENABLED' -and $timer.Elapsed.TotalSeconds -lt 180)
    if($i.usageAccess -cne 'ENABLED'){throw 'INVALID:USAGE_CONSENT_TIMEOUT'}
   }
   & $stage CONSENT_ACCESSIBILITY
   if($i.accessibility -cne 'ENABLED'){
    & $action OpenChild
    Write-Host 'No KidRemote: toque Concordo · abrir configuração de Acessibilidade; ative o serviço KidRemote nas Configurações.'
    $timer=[Diagnostics.Stopwatch]::StartNew()
    do{Start-Sleep -Milliseconds 1000;$i=Invoke-ReadOnlyInventory $read}while($i.accessibility -cne 'ENABLED' -and $timer.Elapsed.TotalSeconds -lt 180)
    if($i.accessibility -cne 'ENABLED'){throw 'INVALID:ACCESSIBILITY_CONSENT_TIMEOUT'}
   }
   & $action OpenChild
  }catch{Throw-ProductPreparationFailure $s $_.Exception.Message}
 }.GetNewClosure()
 $ops.Configure={param($eventId)
  & $stage INITIAL_POLICY
  try{$null=Set-InitialLabLimit $wire $Jwt $s.device $eventId;& $action OpenChild}catch{Throw-ProductPreparationFailure $s $_.Exception.Message}
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
Export-ModuleMember -Function New-LivePreparation,Invoke-ProductEnrollmentPreparation,Get-ProductPreparationFailure
