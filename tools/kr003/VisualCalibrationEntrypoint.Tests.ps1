<#
Goal: Execute visual-calibration entrypoint initialization under the native PowerShell engine without reaching ADB.
Context: Startup execution catches parameter/reserved-variable defects before physical handoff.
Constraints: Redirected input must stop before output creation, capture startup or any device command.
Done when: Windows PowerShell 5.1 and PowerShell 7 return the controlled pre-device exit.
#>
param([string]$BundleDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
$temporaryRoot=Join-Path ([IO.Path]::GetTempPath()) ('kr003-visual-entrypoint-'+[Guid]::NewGuid().ToString('N'))
try{
    if([string]::IsNullOrWhiteSpace($BundleDirectory)){
        $BundleDirectory=Join-Path $temporaryRoot 'bundle';New-Item -ItemType Directory -Path $BundleDirectory|Out-Null
        foreach($name in @('Start-KR003.ps1','Qualification.psm1','DevicePreflight.psm1','VisualCalibration.psm1','Capture-KR003-Frames.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $BundleDirectory $name)}
    }
    $entrypoint=Join-Path $BundleDirectory 'Start-KR003.ps1';Assert-Equal (Test-Path -LiteralPath $entrypoint -PathType Leaf) $true
    $engineName=$(if($PSVersionTable.PSEdition -eq 'Core'){$(if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){'pwsh.exe'}else{'pwsh'})}else{'powershell.exe'})
    $engine=Join-Path $PSHOME $engineName;Assert-Equal (Test-Path -LiteralPath $engine -PathType Leaf) $true
    $adb=Join-Path $temporaryRoot 'must-not-run-adb'
    $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$engine;$start.UseShellExecute=$false;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.CreateNoWindow=$true
    $start.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$entrypoint+'" -VisualCalibration -Adb "'+$adb+'"'
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Assert-Equal $process.Start() $true;$process.StandardInput.Close()
    $stdout=$process.StandardOutput.ReadToEnd();$stderr=$process.StandardError.ReadToEnd();$process.WaitForExit()
    $expectedExit=$(if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){2}else{1})
    Assert-Equal $process.ExitCode $expectedExit
    $combined=$stdout+"`n"+$stderr;Assert-Equal ([bool]($combined -match 'VariableNotWritable|read-only or constant|Cannot overwrite variable')) $false
    Assert-Equal ([bool]($combined -match 'exec-out|screencap')) $false
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){Assert-Equal ([bool]($combined -match 'INVALID:VISUAL_OUTPUT_ROOT_NOT_OWNER_LOCAL')) $true}
    Write-Host ($script:Checks.ToString()+' visual-calibration entrypoint assertions passed under PowerShell '+$PSVersionTable.PSVersion.ToString()+'; no device or capture command was executed.')
}finally{if(Test-Path -LiteralPath $temporaryRoot){Remove-Item -LiteralPath $temporaryRoot -Recurse -Force}}
