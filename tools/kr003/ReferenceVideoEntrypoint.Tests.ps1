param([string]$BundleDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){Write-Host 'SKIP: reference-video entrypoint fake executable requires Windows.';exit 0}
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('kr003-video-entry-'+[Guid]::NewGuid().ToString('N'))
$testRun=Join-Path 'C:\platform-tools\kr003-reference-video' ('video-20000101-000000-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
try{
    New-Item -ItemType Directory -Path $temporary|Out-Null
    if(-not $BundleDirectory){
        $BundleDirectory=Join-Path $temporary 'bundle';New-Item -ItemType Directory -Path $BundleDirectory|Out-Null
        foreach($name in @('Start-KR003.ps1','Qualification.psm1','DevicePreflight.psm1','VisualCalibration.psm1','Start-KR003-ReferenceVideo.ps1','Clear-KR003-ReferenceVideo.ps1','ReferenceVideo.Runner.ps1','ReferenceVideo.psm1','ReferenceVideoCore.cs','reference-comparator.json')){
            Copy-Item (Join-Path $PSScriptRoot $name) (Join-Path $BundleDirectory $name)
        }
        $bundle=[PSCustomObject]@{schema=1;protocol='KR003-REFERENCE-VIDEO-CHARACTERIZATION';sourceCommit='a'*40;physicalExecution='NOT_RUN';
            runnerVersion=1;diagnosticOnly=$true;requiresOffline=$false;qualificationCycles=0;time04Rows=0;matrixContribution='NONE';humanCheckpointMaximum=2;checkpointReplacementAuthorized=$false;resumeAllowed=$false;poolingAllowed=$false;
            classifierModel='LOCAL_TILE_MAE_RGB24_V1';captureModel='BOUNDED_SCREENRECORD_MP4';rawMediaPolicy='OWNER_LOCAL_ONLY_EXCLUDED_FROM_REPOSITORY_CLOUD_AND_TOOL_OUTPUT';
            candidateSha256='b'*64;fixtureSha256='c'*64;files=@();
            approvedConfiguration=[PSCustomObject]@{schema=1;manufacturer='samsung';model='SM-X400';androidVersion='16';apiLevel='36';securityPatch='2026-07-05';buildId='BP4A.251205.006'};
            calibratedBy=[PSCustomObject]@{protocol='KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION';sourceCommit='d'*40;runDirectory='calibration-20000101-000000-12345678';status='PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY';reason='COMPLETED';summarySha256='e'*64;deviceSha256='f'*64;transportDeviceEvidenceSha256='a'*64;calibrationSamples=1;qualificationSamples=0;physicalAgreement='PASS';candidateSha256='b'*64;fixtureSha256='c'*64}}
        $bundle.files=@(Get-ChildItem -LiteralPath $BundleDirectory -File|ForEach-Object{[PSCustomObject]@{name=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
        [IO.File]::WriteAllText((Join-Path $BundleDirectory 'bundle.json'),($bundle|ConvertTo-Json -Depth 8))
    }else{$bundle=Get-Content -LiteralPath (Join-Path $BundleDirectory 'bundle.json') -Raw|ConvertFrom-Json}
    $fake=Join-Path $temporary 'fake-adb.exe';$source=Join-Path $temporary 'fake.cs'
    [IO.File]::WriteAllText($source,'public static class Fake { public static int Main(string[] a) { System.IO.File.WriteAllText(System.Reflection.Assembly.GetExecutingAssembly().Location+".called", "FAKE_ONLY"); return 2; } }')
    $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $compiler /nologo /target:exe (('/out:')+$fake) $source
    if($LASTEXITCODE -ne 0){throw 'FAKE_COMPILER_FAILED'}
    $engine=Join-Path $PSHOME $(if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'})
    function Invoke-Entry([string]$Name,[string]$Extra){
        $process=New-Object Diagnostics.Process;$process.StartInfo=New-Object Diagnostics.ProcessStartInfo
        $process.StartInfo.FileName=$engine;$process.StartInfo.UseShellExecute=$false;$process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardInput=$true;$process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true
        $process.StartInfo.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+(Join-Path $BundleDirectory $Name)+'" -Adb "'+$fake+'" '+$Extra
        [void]$process.Start();$process.StandardInput.Close();$outTask=$process.StandardOutput.ReadToEndAsync();$errTask=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill();throw 'FAKE_ENTRY_TIMEOUT'}
        $text=$outTask.Result+$errTask.Result
        Assert-Equal ($text -match 'VariableNotWritable|Cannot overwrite variable') $false
        Assert-Equal $process.ExitCode 1
        return $text
    }
    $output=Invoke-Entry 'Start-KR003-ReferenceVideo.ps1' ''
    Assert-Equal ($output -match 'INVALID:INTERACTIVE_OPERATOR_REQUIRED') $true
    Assert-Equal (Test-Path -LiteralPath ($fake+'.called')) $false
    New-Item -ItemType Directory -Path $testRun|Out-Null
    [IO.File]::WriteAllText((Join-Path $testRun 'manifest.json'),([PSCustomObject]@{RunId=(Split-Path -Leaf $testRun);Bundle=$bundle}|ConvertTo-Json -Depth 10))
    $output=Invoke-Entry 'Clear-KR003-ReferenceVideo.ps1' ('-RunDirectory "'+$testRun+'"')
    Assert-Equal ($output -match 'INVALID:ADB_REJECTED') $true
    Assert-Equal (Test-Path -LiteralPath ($fake+'.called')) $true
    Write-Host ($script:Checks.ToString()+' real reference-video entrypoint/bailout assertions passed; fake ADB only.')
}finally{
    if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}
    if(Test-Path -LiteralPath $testRun){Remove-Item -LiteralPath $testRun -Recurse -Force}
}
