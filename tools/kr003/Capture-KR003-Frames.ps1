<#
Goal: Capture a bounded sequence of local-only PNG samples for the excluded KR-003 visual-channel calibration.
Context: The parent runner controls phase timing while this worker continuously requests Android screencap frames.
Constraints: Raw PNGs stay under the owner-local run directory; stdout contains no image bytes; secure/protected capture is never bypassed.
Done when: Every completed request has monotonic timing, a SHA-256 hash and a coarse command result, and the worker stops on the sentinel or an error.
#>
param([string]$Adb,[string]$RunDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$frameDirectory=Join-Path $RunDirectory 'raw-frames';$journalPath=Join-Path $RunDirectory 'frame-journal.jsonl'
$statePath=Join-Path $RunDirectory 'capture-worker.json';$stopPath=Join-Path $RunDirectory 'capture.stop'
$encoding=New-Object Text.UTF8Encoding($false);$status='RUNNING';$reason='NONE';$frameCount=0
function Write-WorkerState {
    $record=[PSCustomObject]@{Schema=1;Status=$status;Reason=$reason;FrameCount=$frameCount;Frequency=[Diagnostics.Stopwatch]::Frequency;UpdatedUtc=[DateTime]::UtcNow.ToString('o')}
    [IO.File]::WriteAllText($statePath,(ConvertTo-Json -InputObject $record -Compress),$encoding)
}
function Get-StderrClass([string]$Text){if($Text -match 'SecurityException'){'SECURITY_EXCEPTION'}elseif($Text -match 'Permission Denial'){'PERMISSION_DENIAL'}elseif([string]::IsNullOrWhiteSpace($Text)){'NONE'}else{'OTHER'}}

try{
    if(-not (Test-Path -LiteralPath $Adb)){throw 'INVALID:ADB_MISSING'}
    New-Item -ItemType Directory -Path $frameDirectory | Out-Null
    Write-WorkerState
    while(-not (Test-Path -LiteralPath $stopPath)){
        $frameCount++;$fileName=('frame-{0:D6}.png' -f $frameCount);$finalPath=Join-Path $frameDirectory $fileName;$temporaryPath=$finalPath+'.partial'
        $process=New-Object Diagnostics.Process;$process.StartInfo=New-Object Diagnostics.ProcessStartInfo
        $process.StartInfo.FileName=$Adb;$process.StartInfo.Arguments='exec-out screencap -p';$process.StartInfo.UseShellExecute=$false
        $process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true;$process.StartInfo.CreateNoWindow=$true
        try{
            $startTicks=[Diagnostics.Stopwatch]::GetTimestamp();[void]$process.Start();$stderrTask=$process.StandardError.ReadToEndAsync()
            $frameStream=[IO.File]::Open($temporaryPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try{$copyTask=$process.StandardOutput.BaseStream.CopyToAsync($frameStream);if(-not $process.WaitForExit(10000)){$process.Kill();throw 'INVALID:VISUAL_CAPTURE_TIMEOUT'};$copyTask.GetAwaiter().GetResult()}finally{$frameStream.Dispose()}
            $endTicks=[Diagnostics.Stopwatch]::GetTimestamp();$stderr=$stderrTask.GetAwaiter().GetResult();$stderrClass=Get-StderrClass $stderr
            if($process.ExitCode -ne 0 -or $stderrClass -ne 'NONE'){throw 'INVALID:VISUAL_CAPTURE_REJECTED'}
            $bytes=(Get-Item -LiteralPath $temporaryPath).Length;if($bytes -lt 128){throw 'INVALID:VISUAL_CAPTURE_EMPTY'}
            [IO.File]::Move($temporaryPath,$finalPath)
            $hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $finalPath).Hash.ToLowerInvariant()
            $entry=[PSCustomObject]@{Schema=1;Index=$frameCount;FileName=$fileName;StartTicks=$startTicks;EndTicks=$endTicks;Sha256=$hash;Bytes=$bytes;ExitCode=[int]$process.ExitCode;StderrClass=$stderrClass}
            [IO.File]::AppendAllText($journalPath,(ConvertTo-Json -InputObject $entry -Compress)+[Environment]::NewLine,$encoding)
            Write-WorkerState
        }finally{
            $process.Dispose();if(Test-Path -LiteralPath $temporaryPath){Move-Item -LiteralPath $temporaryPath -Destination ($temporaryPath+'.preserved') -ErrorAction SilentlyContinue}
        }
    }
    $status='COMPLETED';$reason='STOP_SENTINEL_OBSERVED'
}catch{
    $status='INVALID';$reason=if($_.Exception.Message -match '^INVALID:[A-Z0-9_]+$'){$_.Exception.Message}else{'INVALID:VISUAL_CAPTURE_HOST_EXCEPTION'}
}finally{Write-WorkerState}
if($status -eq 'COMPLETED'){exit 0};exit 2
