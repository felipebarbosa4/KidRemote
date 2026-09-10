<#
Goal: Exercise the local PNG capture worker's success and rejection finalization without ADB.
Context: A tiny temporary process streams a runtime-generated synthetic PNG or returns a coarse rejection.
Constraints: Windows-only synthetic media under the OS temp directory; no physical device, network, repository file or content output.
Done when: Completed frames are hashed/journalled and rejected capture stops INVALID without exposing bytes.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){Write-Host '0 visual capture-worker assertions skipped: Windows-only synthetic process.';exit 0}

$temporaryRoot=Join-Path ([IO.Path]::GetTempPath()) ('kr003-capture-worker-'+[Guid]::NewGuid().ToString('N'))
try{
    New-Item -ItemType Directory -Path $temporaryRoot|Out-Null
    Add-Type -AssemblyName System.Drawing
    $framePath=Join-Path $temporaryRoot 'synthetic.png';$bitmap=New-Object Drawing.Bitmap -ArgumentList 96,96
    $graphics=[Drawing.Graphics]::FromImage($bitmap);$graphics.Clear([Drawing.Color]::White);$graphics.FillRectangle([Drawing.Brushes]::Black,8,8,70,50);$graphics.Dispose();$bitmap.Save($framePath,[Drawing.Imaging.ImageFormat]::Png);$bitmap.Dispose()
    $fakePath=Join-Path $temporaryRoot 'fake-adb.exe'
    $source=@'
using System;
using System.IO;
public static class FakeAdb {
  public static int Main(string[] arguments) {
    if (Environment.GetEnvironmentVariable("KR003_TEST_CAPTURE_REJECT") == "1") { Console.Error.Write("rejected"); return 2; }
    using (var input = File.OpenRead(Environment.GetEnvironmentVariable("KR003_TEST_CAPTURE_FRAME"))) { input.CopyTo(Console.OpenStandardOutput()); }
    return 0;
  }
}
'@
    Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $fakePath -OutputType ConsoleApplication
    $enginePath=(Get-Process -Id $PID).Path;$worker=Join-Path $PSScriptRoot 'Capture-KR003-Frames.ps1'
    $env:KR003_TEST_CAPTURE_FRAME=$framePath;$env:KR003_TEST_CAPTURE_REJECT='0'
    $runDirectory=Join-Path $temporaryRoot 'pass';New-Item -ItemType Directory -Path $runDirectory|Out-Null
    $process=Start-Process -FilePath $enginePath -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$worker,'-Adb',$fakePath,'-RunDirectory',$runDirectory) -PassThru -WindowStyle Hidden
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do{$statePath=Join-Path $runDirectory 'capture-worker.json';if(Test-Path -LiteralPath $statePath){$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json;if($state.FrameCount -ge 3){break}};Start-Sleep -Milliseconds 100}while($watch.Elapsed.TotalSeconds -lt 10)
    Assert-Equal ($state.FrameCount -ge 3) $true
    [IO.File]::WriteAllText((Join-Path $runDirectory 'capture.stop'),'stop');$process.WaitForExit();Assert-Equal $process.ExitCode 0
    $state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json;Assert-Equal $state.Status 'COMPLETED'
    $journal=@(Get-Content -LiteralPath (Join-Path $runDirectory 'frame-journal.jsonl')|ForEach-Object{$_|ConvertFrom-Json})
    Assert-Equal ($journal.Count -ge 3) $true;Assert-Equal $journal[0].StderrClass 'NONE';Assert-Equal ([bool]($journal[0].Sha256 -match '^[a-f0-9]{64}$')) $true

    $env:KR003_TEST_CAPTURE_REJECT='1';$rejectedDirectory=Join-Path $temporaryRoot 'rejected';New-Item -ItemType Directory -Path $rejectedDirectory|Out-Null
    $rejected=Start-Process -FilePath $enginePath -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$worker,'-Adb',$fakePath,'-RunDirectory',$rejectedDirectory) -PassThru -WindowStyle Hidden
    $rejected.WaitForExit();Assert-Equal $rejected.ExitCode 2
    $rejectedState=Get-Content -LiteralPath (Join-Path $rejectedDirectory 'capture-worker.json') -Raw|ConvertFrom-Json
    Assert-Equal $rejectedState.Status 'INVALID';Assert-Equal $rejectedState.Reason 'INVALID:VISUAL_CAPTURE_REJECTED'
    Assert-Equal (Test-Path -LiteralPath (Join-Path $rejectedDirectory 'frame-journal.jsonl')) $false
    Write-Host ($script:Checks.ToString()+' visual capture-worker assertions passed using synthetic local media only.')
}finally{
    Remove-Item Env:KR003_TEST_CAPTURE_FRAME -ErrorAction SilentlyContinue;Remove-Item Env:KR003_TEST_CAPTURE_REJECT -ErrorAction SilentlyContinue
    if(Test-Path -LiteralPath $temporaryRoot){Remove-Item -LiteralPath $temporaryRoot -Recurse -Force}
}
