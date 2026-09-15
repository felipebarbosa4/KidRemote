Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'QrPresentation.psm1') -Force
$script:n=0;function Check($b){$script:n++;if(-not $b){throw "QR_CHECK_$script:n"}}
function FakeWindow([bool]$Ready){
 $w=[pscustomobject]@{readyValue=$Ready;closedValue=$false}
 $w|Add-Member ScriptMethod Snapshot {return [pscustomobject]@{Ready=$this.readyValue;Visible=$this.readyValue;ValidHandle=$this.readyValue;TitleMatches=$true;TopMost=$true;Interactive=$true;ActivationAttempted=$true;Closed=$this.closedValue;TimedOut=$false}}
 $w|Add-Member ScriptMethod Dispose {$this.closedValue=$true};return $w
}
$s=@{open=0;instruction=0;poll=0};$w=FakeWindow $false
try{$null=Invoke-ProductQrEnrollment $w {$s.open++} {$s.poll++} {$s.instruction++};throw 'MISSING_FAILURE'}catch{Check ($_.Exception.Message -ceq 'INVALID:QR_PRESENTATION_FAILED')}
Check ($s.open -eq 0 -and $s.poll -eq 0 -and $s.instruction -eq 0);Check $w.closedValue
$w=FakeWindow $true
try{$null=Invoke-ProductQrEnrollment $w {$w.readyValue=$false} {$s.poll++} {$s.instruction++};throw 'MISSING_FAILURE'}catch{Check ($_.Exception.Message -ceq 'INVALID:QR_PRESENTATION_FAILED')}
Check ($s.poll -eq 0 -and $s.instruction -eq 0);Check $w.closedValue
$w=FakeWindow $true;$r=Invoke-ProductQrEnrollment $w {} {[pscustomobject]@{synthetic='ENROLLED'}} {$s.instruction++}
Check ($r.synthetic -ceq 'ENROLLED');Check $w.closedValue;Check ($s.instruction -eq 1)
$w=FakeWindow $true
try{$null=Invoke-ProductQrEnrollment $w {} {$null} {} 1;throw 'MISSING_TIMEOUT'}catch{Check ($_.Exception.Message -ceq 'INVALID:PAIRING_TIMEOUT')};Check $w.closedValue
if($env:OS -cne 'Windows_NT'){Write-Output "QR_GATE_CHECKS=$script:n;NATIVE_UI=NOT_RUN";exit 0}
Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
# Only a synthetic image, never a real pairing token or device. No capture or screenshots.
$bitmap=New-Object Drawing.Bitmap(512,512);$g=[Drawing.Graphics]::FromImage($bitmap);$g.Clear([Drawing.Color]::White)
$g.FillRectangle([Drawing.Brushes]::Black,32,32,128,128);$g.FillRectangle([Drawing.Brushes]::Black,352,32,128,128);$g.FillRectangle([Drawing.Brushes]::Black,32,352,128,128)
$memory=New-Object IO.MemoryStream;$bitmap.Save($memory,[Drawing.Imaging.ImageFormat]::Png);$encoded=[Convert]::ToBase64String($memory.ToArray());$w=$null;$other=$null
try{
 Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public static class QrFocusFixture{[DllImport("kernel32.dll")]public static extern IntPtr GetConsoleWindow();[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);}'
 $console=[QrFocusFixture]::GetConsoleWindow();if($console -ne [IntPtr]::Zero){$null=[QrFocusFixture]::SetForegroundWindow($console)}
 $w=New-ProductQrWindow $encoded 10000;$q=$w.Snapshot()
 Check $q.Ready;Check $q.Visible;Check $q.ValidHandle;Check ($q.Hwnd -ne 0);Check $q.TitleMatches
 Check ($q.Title -match '^KidRemote - QR de pareamento - [a-f0-9]{32}$');Check $q.TopMost;Check $q.Interactive;Check $q.ActivationAttempted
 $ticks=$q.PumpTicks;Start-Sleep -Milliseconds 2500;$q=$w.Snapshot();Check ($q.Ready -and $q.Visible -and $q.PumpTicks -gt $ticks+10)
 $other=New-ProductQrWindow $encoded 10000;Check ($other.Snapshot().Title -cne $q.Title);$other.Dispose();Check $other.Snapshot().Closed
 $seen=@{instructions=0};$result=Invoke-ProductQrEnrollment $w {} {[pscustomobject]@{synthetic='OK'}} {$seen.instructions++}
 Check ($result.synthetic -ceq 'OK' -and $seen.instructions -eq 1);Check $w.Snapshot().Closed;Check (-not $w.Snapshot().ValidHandle)
 $w=New-ProductQrWindow $encoded 1000;Start-Sleep -Milliseconds 1500;Check $w.Snapshot().TimedOut;Check $w.Snapshot().Closed;Check (-not $w.Snapshot().Visible)
 $caught=$false;try{$bad=New-ProductQrWindow 'NOT_PNG'}catch{$caught=$_.Exception.Message -ceq 'INVALID:QR_PRESENTATION_FAILED'};Check $caught
 $source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'LivePreparation.psm1'))
 Check ($source -notmatch '\$form\.Show\(');Check ($source -notmatch 'Write-(Host|Output).*\$(q|encoded)')
 Write-Output "QR_PRESENTATION_CHECKS=$script:n;NATIVE_UI=PASS;SYNTHETIC_IMAGE_ONLY;DEVICE=NOT_INVOKED"
}catch{Write-Output ('QR_NATIVE_FAILURE_PHASE='+$_.Exception.Data['qrPhase']+';TYPE='+$_.Exception.Data['qrExceptionType']+';CHECKS_COMPLETED='+$script:n);throw}finally{if($w){$w.Dispose()};if($other){$other.Dispose()};$encoded=$null;$memory.Dispose();$g.Dispose();$bitmap.Dispose()}
