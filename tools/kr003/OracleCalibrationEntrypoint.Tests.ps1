<#
Goal: Execute the real calibration entrypoint initialization in a bundle-shaped directory without reaching ADB.
Context: AST/function-only tests missed a top-level automatic-variable collision in runner v3.
Constraints: Redirected noninteractive input must stop before directory creation, bundle reads or device commands.
Done when: The entrypoint returns its controlled pre-device exit under the current PowerShell engine and emits no variable-write failure.
#>
param([string]$BundleDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}

$temporaryRoot=Join-Path ([IO.Path]::GetTempPath()) ('kr003-calibration-entrypoint-'+[Guid]::NewGuid().ToString('N'))
try{
    if([string]::IsNullOrWhiteSpace($BundleDirectory)){
        $BundleDirectory=Join-Path $temporaryRoot 'bundle'
        New-Item -ItemType Directory -Path $BundleDirectory|Out-Null
        foreach($name in @('Test-KR003-OracleCalibration.ps1','CalibrationHost.psm1','DevicePreflight.psm1','OracleTransport.psm1','Qualification.psm1')){
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $BundleDirectory $name)
        }
    }
    $entrypoint=Join-Path $BundleDirectory 'Test-KR003-OracleCalibration.ps1'
    Assert-Equal (Test-Path -LiteralPath $entrypoint -PathType Leaf) $true
    $engineName=$(if($PSVersionTable.PSEdition -eq 'Core'){$(if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){'pwsh.exe'}else{'pwsh'})}else{'powershell.exe'})
    $engine=Join-Path $PSHOME $engineName
    Assert-Equal (Test-Path -LiteralPath $engine -PathType Leaf) $true
    $outputRoot=Join-Path $temporaryRoot 'must-not-exist'
    $transport=Join-Path $temporaryRoot 'unused-transport'
    $adb=Join-Path $temporaryRoot 'must-not-run-adb'
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$engine;$start.UseShellExecute=$false;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.CreateNoWindow=$true
    $start.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$entrypoint+'" -TransportEvidence "'+$transport+'" -Adb "'+$adb+'" -OutputRoot "'+$outputRoot+'"'
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start
    Assert-Equal $process.Start() $true
    $process.StandardInput.Close()
    $stdout=$process.StandardOutput.ReadToEnd();$stderr=$process.StandardError.ReadToEnd();$process.WaitForExit()
    Assert-Equal $process.ExitCode 2
    Assert-Equal (Test-Path -LiteralPath $outputRoot) $false
    $combined=$stdout+"`n"+$stderr
    Assert-Equal ([bool]($combined -match 'VariableNotWritable|read-only or constant|Cannot overwrite variable')) $false
    Write-Host ($script:Checks.ToString()+' bundled-entrypoint startup assertions passed under PowerShell '+$PSVersionTable.PSVersion.ToString()+'; no device command was executed.')
}finally{
    if(Test-Path -LiteralPath $temporaryRoot){Remove-Item -LiteralPath $temporaryRoot -Recurse -Force}
}
