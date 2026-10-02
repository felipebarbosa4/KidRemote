Set-StrictMode -Version Latest
function New-ProductQrWindow([string]$PngBase64,[int]$TimeoutMs=240000){
 $phase='WINDOWS_REQUIRED'
 try{
  if($env:OS -cne 'Windows_NT' -or $PngBase64.Length -gt 350000){throw 'presentation'}
  $phase='ASSEMBLY_LOAD'
  Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
  if(-not ('KidRemote.Lab.QrWindow' -as [type])){
   $refs=@('System.Windows.Forms','System.Drawing')
   if($PSVersionTable.PSVersion.Major -ge 7){
    $refs=@(Get-ChildItem (Join-Path $PSHOME 'ref') -Filter '*.dll'|ForEach-Object{$_.FullName})
    $refs+=@([Windows.Forms.Form].Assembly.Location,[Drawing.Bitmap].Assembly.Location)
    $refs+=Join-Path ([IO.Path]::GetDirectoryName([Windows.Forms.Form].Assembly.Location)) 'System.Windows.Forms.Primitives.dll'
   }
   $phase='COMPILE'
   Add-Type -Path (Join-Path $PSScriptRoot 'QrWindow.cs') -ReferencedAssemblies $refs
  }
  $phase='CREATE'
  return [KidRemote.Lab.QrWindow]::new([Convert]::FromBase64String($PngBase64),$TimeoutMs)
 }catch{
  $detail=$_.Exception.GetBaseException().Message
  if($detail -cmatch '^INVALID:QR_PRESENTATION_FAILED_([A-Z0-9_]{1,180})$'){$phase=$Matches[1]}
  $e=New-Object Exception('INVALID:QR_PRESENTATION_FAILED');$e.Data['qrPhase']=$phase;$e.Data['qrExceptionType']=$_.Exception.GetBaseException().GetType().Name;throw $e
 }
}
function Assert-ProductQrReady($Window){
 try{$q=$Window.Snapshot();if($q.TimedOut){throw 'INVALID:PAIRING_TIMEOUT'};if(-not($q.Ready -and $q.Visible -and $q.ValidHandle -and $q.TitleMatches -and $q.TopMost -and $q.Interactive -and $q.ActivationAttempted -and -not $q.Closed)){throw 'INVALID:QR_PRESENTATION_FAILED'}}catch{if($_.Exception.Message -ceq 'INVALID:PAIRING_TIMEOUT'){throw};throw 'INVALID:QR_PRESENTATION_FAILED'}
}
function Invoke-ProductQrEnrollment($Window,[scriptblock]$OpenChild,[scriptblock]$Poll,[scriptblock]$Instruction,[int]$TimeoutMs=240000,[scriptblock]$OnStage={}){
 try{
  & $OnStage QR_WINDOW_READY_INITIAL
  Assert-ProductQrReady $Window
  & $OnStage CHILD_OPEN_FOR_SCAN
  & $OpenChild
  & $OnStage QR_WINDOW_READY_AFTER_CHILD_OPEN
  Assert-ProductQrReady $Window
  & $Instruction
  $timer=[Diagnostics.Stopwatch]::StartNew()
  while($timer.ElapsedMilliseconds -lt $TimeoutMs){
   & $OnStage QR_ENROLLMENT_POLL
   Assert-ProductQrReady $Window;$d=& $Poll
   Assert-ProductQrReady $Window
   if($null -ne $d){return $d};Start-Sleep -Milliseconds 250
  };& $OnStage QR_ENROLLMENT_TIMEOUT;throw 'INVALID:PAIRING_TIMEOUT'
 }finally{$Window.Dispose()}
}
Export-ModuleMember -Function New-ProductQrWindow,Assert-ProductQrReady,Invoke-ProductQrEnrollment
