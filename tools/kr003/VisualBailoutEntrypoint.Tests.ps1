<#
Goal: Prove the immutable visual-calibration bundle's standalone CLEAR helper accepts its own protocol before physical handoff.
Context: The bailout must remain available from a second Windows PowerShell window even if the main runner is inconvenient.
Constraints: Temporary fake ADB only; no device, timer mutation, raw media or repository output.
Done when: Native Windows PowerShell accepts the visual bundle schema and stops at the fake ADB rejection rather than bundle validation.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){Write-Host '0 visual bailout-entrypoint assertions skipped: native Windows-only fake process.';exit 0}

$temporaryRoot=Join-Path ([IO.Path]::GetTempPath()) ('kr003-visual-bailout-'+[Guid]::NewGuid().ToString('N'))
try{
    New-Item -ItemType Directory -Path $temporaryRoot|Out-Null
    foreach($name in @('Clear-KR003-Lab.ps1','Qualification.psm1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $temporaryRoot $name)}
    $files=@('Clear-KR003-Lab.ps1','Qualification.psm1')|ForEach-Object{[PSCustomObject]@{name=$_;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $temporaryRoot $_)).Hash.ToLowerInvariant()}}
    $bundle=[PSCustomObject]@{protocol='KR003-VISUAL-CHANNEL-CALIBRATION';runnerVersion=1;diagnosticOnly=$true;diagnosticScope='VISUAL_CHANNEL_ONLY';files=$files}
    [IO.File]::WriteAllText((Join-Path $temporaryRoot 'bundle.json'),($bundle|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
    $fakeAdb=Join-Path $temporaryRoot 'fake-adb.exe'
    Add-Type -TypeDefinition 'public static class FakeAdb { public static int Main(string[] arguments) { return 2; } }' -Language CSharp -OutputAssembly $fakeAdb -OutputType ConsoleApplication
    $engine=Join-Path $PSHOME 'powershell.exe';$entrypoint=Join-Path $temporaryRoot 'Clear-KR003-Lab.ps1'
    $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$engine;$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.CreateNoWindow=$true
    $start.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$entrypoint+'" -Adb "'+$fakeAdb+'"'
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Assert-Equal $process.Start() $true
    $stdout=$process.StandardOutput.ReadToEnd();$stderr=$process.StandardError.ReadToEnd();$process.WaitForExit();Assert-Equal $process.ExitCode 2
    $combined=$stdout+"`n"+$stderr;Assert-Equal ([bool]($combined -match 'INVALID:BUNDLE_SCHEMA')) $false
    Assert-Equal ([bool]($combined -match 'INVALID:ADB_REJECTED')) $true
    Write-Host ($script:Checks.ToString()+' visual bailout-entrypoint assertions passed; fake ADB stopped before any device operation.')
}finally{if(Test-Path -LiteralPath $temporaryRoot){Remove-Item -LiteralPath $temporaryRoot -Recurse -Force}}
