<#
Goal: Execute the real excluded dual-Home diagnostic entrypoint initialization without reaching ADB.
Context: Native engine execution catches top-level PowerShell collisions and binding defects before owner handoff.
Constraints: Redirected input must stop before output-directory creation, bundle reads, settings changes or device commands.
Done when: The entrypoint returns its controlled pre-device exit under the current engine without a variable-write error.
#>
param([string]$BundleDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}

$temporaryRoot=Join-Path ([IO.Path]::GetTempPath()) ('kr003-dual-home-entrypoint-'+[Guid]::NewGuid().ToString('N'))
try{
    if([string]::IsNullOrWhiteSpace($BundleDirectory)){
        $BundleDirectory=Join-Path $temporaryRoot 'bundle'
        New-Item -ItemType Directory -Path $BundleDirectory|Out-Null
        foreach($name in @('Start-KR003.ps1','Qualification.psm1','DevicePreflight.psm1')){
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $BundleDirectory $name)
        }
    }
    $entrypoint=Join-Path $BundleDirectory 'Start-KR003.ps1'
    Assert-Equal (Test-Path -LiteralPath $entrypoint -PathType Leaf) $true
    $engineName=$(if($PSVersionTable.PSEdition -eq 'Core'){$(if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){'pwsh.exe'}else{'pwsh'})}else{'powershell.exe'})
    $engine=Join-Path $PSHOME $engineName
    Assert-Equal (Test-Path -LiteralPath $engine -PathType Leaf) $true
    $outputRoot=Join-Path $temporaryRoot 'must-not-exist'
    $adb=Join-Path $temporaryRoot 'must-not-run-adb'
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$engine;$start.UseShellExecute=$false;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.CreateNoWindow=$true
    $start.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$entrypoint+'" -DualHomeDiagnostic -Adb "'+$adb+'" -OutputRoot "'+$outputRoot+'"'
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start
    Assert-Equal $process.Start() $true
    $process.StandardInput.Close()
    $stdout=$process.StandardOutput.ReadToEnd();$stderr=$process.StandardError.ReadToEnd();$process.WaitForExit()
    Assert-Equal $process.ExitCode 2
    Assert-Equal (Test-Path -LiteralPath $outputRoot) $false
    $combined=$stdout+"`n"+$stderr
    Assert-Equal ([bool]($combined -match 'VariableNotWritable|read-only or constant|Cannot overwrite variable')) $false
    Write-Host ($script:Checks.ToString()+' dual-Home diagnostic entrypoint assertions passed under PowerShell '+$PSVersionTable.PSVersion.ToString()+'; no device command was executed.')
}finally{
    if(Test-Path -LiteralPath $temporaryRoot){Remove-Item -LiteralPath $temporaryRoot -Recurse -Force}
}
