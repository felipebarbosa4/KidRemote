Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'ReplacementAdb.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ReadOnly.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../update-review/Review.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Canonical.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'EnrollmentHost.psm1') -Force

function New-LivePreparation([string]$Adb,[string]$Serial,[string]$Bundle,[string]$Temporary,[Security.SecureString]$Jwt){
 $java='C:\Program Files\Android\Android Studio\jbr\bin\java.exe'
 $jar=Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\37.0.0\lib\apksigner.jar'
 $apk=Join-Path $Bundle 'lab-reference.apk'
 $run={param($e,$a,$inputText) Invoke-ReviewProcess $e $a $inputText}
 $read={param($a) Invoke-InventoryAdb $Adb $Serial $a}.GetNewClosure()
 $wire={param($s,$p,$m,$b,$j) Invoke-LabWire $s $p $m $b $j}
 $s=@{new=$false;device=$null;reverse=$false;reverseAttempted=$false}
 $action={param($name) $null=Invoke-ReplacementAdb $Adb $Serial $name $apk $run}.GetNewClosure()
 $ops=@{}
 $ops.HostReady={
  $r=& $run $java @('--enable-native-access=ALL-UNNAMED','-jar',$jar,'verify','--verbose','--print-certs',$apk) ''
  if($r.stderr.Trim() -or (Convert-ReviewSigner $r.stdout) -cne '638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb'){throw 'INVALID:LAB_SIGNER'}
  if($null -ne (Get-OnlyLabChild $wire $Jwt)){throw 'INVALID:NEW_HOUSEHOLD_NOT_EMPTY'}
 }.GetNewClosure()
 $ops.Configuration={
  $i=Invoke-ReadOnlyInventory $read
  if($i.classification -ceq 'CONFIGURATION_MISMATCH'){throw 'INVALID:CONFIGURATION_MISMATCH'}
  Assert-LabReverse (Invoke-ReplacementAdb $Adb $Serial ReverseRead $apk $run) $false
 }.GetNewClosure()
 $ops.FixtureHash={(Get-InventoryPackage 'dev.kidremote.spike.ordinary' $read).sha256}.GetNewClosure()
 $ops.Installed={
  $p=Get-InventoryPackage 'dev.kidremote.child.unassigned.debug' $read
  if(-not $p.installed){throw 'INVALID:CHILD_ABSENT'}
  $hash=if($s.new){'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'}else{'3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9'}
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
  $image=$null;$stream=$null;$form=$null
  try{
   $encoded=& $run $java @('-cp',((Join-Path $Bundle 'host-qr.jar')+';'+(Join-Path $Bundle 'zxing-core.jar')),'HostQr') ($q.qr|ConvertTo-Json -Compress)
   if($encoded.stderr.Trim()){throw 'INVALID:QR_RENDER_FAILED'}
   Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
   $stream=New-Object IO.MemoryStream(,[Convert]::FromBase64String($encoded.stdout));$image=[Drawing.Image]::FromStream($stream)
   $form=New-Object Windows.Forms.Form;$form.Text='KidRemote — escaneie este único QR no tablet';$form.ClientSize=New-Object Drawing.Size(540,540)
   $box=New-Object Windows.Forms.PictureBox;$box.Dock='Fill';$box.SizeMode='Zoom';$box.Image=$image;$form.Controls.Add($box);$form.Show()
   & $action OpenChild
   Write-Host 'No KidRemote: toque Escanear QR, permita a câmera se solicitado e escaneie o QR exibido.'
   $timer=[Diagnostics.Stopwatch]::StartNew()
   while($timer.Elapsed.TotalSeconds -lt 240 -and $form.Visible){
    [Windows.Forms.Application]::DoEvents();$d=Get-OnlyLabChild $wire $Jwt
    if($null -ne $d){$s.device=$d;return};Start-Sleep -Milliseconds 500
   };throw 'INVALID:PAIRING_TIMEOUT'
  }finally{if($form){$form.Dispose()};if($image){$image.Dispose()};if($stream){$stream.Dispose()};$q=$null;$encoded=$null}
 }.GetNewClosure()
 $ops.Consent={
  $i=Invoke-ReadOnlyInventory $read
  if($i.usageAccess -cne 'ENABLED'){
   & $action OpenUsage;Write-Host 'Ative somente o Acesso ao uso do KidRemote. A conclusão será detectada automaticamente.'
   $timer=[Diagnostics.Stopwatch]::StartNew()
   do{Start-Sleep -Milliseconds 1000;$i=Invoke-ReadOnlyInventory $read}while($i.usageAccess -cne 'ENABLED' -and $timer.Elapsed.TotalSeconds -lt 180)
   if($i.usageAccess -cne 'ENABLED'){throw 'INVALID:USAGE_CONSENT_TIMEOUT'}
  }
  & $action OpenChild
  Write-Host 'No KidRemote: toque Concordo · abrir configuração de Acessibilidade; ative o serviço KidRemote nas Configurações.'
  $timer=[Diagnostics.Stopwatch]::StartNew()
  do{Start-Sleep -Milliseconds 1000;$i=Invoke-ReadOnlyInventory $read}while($i.accessibility -cne 'ENABLED' -and $timer.Elapsed.TotalSeconds -lt 180)
  if($i.accessibility -cne 'ENABLED'){throw 'INVALID:ACCESSIBILITY_CONSENT_TIMEOUT'}
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
 return @{ops=$ops;state=$s;wire=$wire;read=$read;action=$action}
}
Export-ModuleMember -Function New-LivePreparation
