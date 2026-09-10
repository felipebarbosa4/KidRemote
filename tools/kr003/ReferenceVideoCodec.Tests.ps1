<# Synthetic codec prerequisite check only. No ADB, private media or media output. #>
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){Write-Host 'Synthetic Windows codec prerequisite test not run on this host.';exit 0}
$ffmpeg=Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
if($null -eq $ffmpeg){Write-Host 'FFmpeg dependency unavailable; codec prerequisite remains unverified.';exit 0}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('kr003-synthetic-codec-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary|Out-Null
function Invoke-SyntheticFfmpeg([string[]]$Arguments){
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$ffmpeg.Source;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.Arguments=(@('-hide_banner','-nostdin','-loglevel','error')+$Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start
    try{
        [void]$process.Start();$outputTask=$process.StandardOutput.ReadToEndAsync();$errorTask=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill();throw 'SYNTHETIC_CODEC_TIMEOUT'}
        $null=$outputTask.Result;$null=$errorTask.Result
        if($process.ExitCode -ne 0){throw 'SYNTHETIC_CODEC_REJECTED'}
    }finally{$process.Dispose()}
}
try{
    $reference=Join-Path $temporary 'synthetic-reference.png'
    $referencePixels=Join-Path $temporary 'synthetic-reference.rgba'
    $video=Join-Path $temporary 'synthetic-held-out.mp4'
    $decoded=Join-Path $temporary 'synthetic-decoded.rgba'
    $timings=Join-Path $temporary 'synthetic-timestamps.sha256'
    Invoke-SyntheticFfmpeg @('-f','lavfi','-i','testsrc2=size=64x64:rate=5','-frames:v','1',$reference)
    Invoke-SyntheticFfmpeg @('-i',$reference,'-pix_fmt','rgba','-f','rawvideo',$referencePixels)
    # Frozen independent PNG reference is not regenerated from encoded test frames.
    Invoke-SyntheticFfmpeg @('-loop','1','-framerate','5','-i',$reference,'-frames:v','10','-c:v','libx264','-pix_fmt','yuv420p','-crf','23',$video)
    # Decode the held-out video ONCE: rawvideo packets feed both exact comparison
    # pixels and the documented framehash muxer carrying native integer timestamps.
    $tee='[f=rawvideo]'+$decoded.Replace('\','/')+'|[f=framehash:hash=sha256]'+$timings.Replace('\','/')
    Invoke-SyntheticFfmpeg @('-copyts','-i',$video,'-map','0:v:0','-pix_fmt','rgba','-c:v','rawvideo','-fps_mode','passthrough','-enc_time_base','demux','-f','tee',$tee)
    [byte[]]$expected=[IO.File]::ReadAllBytes($referencePixels)
    [byte[]]$actual=[IO.File]::ReadAllBytes($decoded)
    if($expected.Length -ne 64*64*4 -or $actual.Length -ne 10*$expected.Length){throw 'SYNTHETIC_CODEC_FRAME_SHAPE'}
    $exact=0;$changedChannels=0
    for($frame=0;$frame -lt 10;$frame++){
        $equal=$true
        for($offset=0;$offset -lt $expected.Length;$offset++){
            if($expected[$offset] -ne $actual[$frame*$expected.Length+$offset]){$equal=$false;$changedChannels++}
        }
        if($equal){$exact++}
    }
    $records=@(Get-Content -LiteralPath $timings|Where-Object{$_ -match '^\s*0,'})
    $timeBase=@(Get-Content -LiteralPath $timings|Where-Object{$_ -match '^#tb 0: [0-9]+/[0-9]+$'})
    if($records.Count -ne 10 -or $timeBase.Count -ne 1){throw 'SYNTHETIC_CODEC_TIMESTAMPS_MISSING'}
    if($exact -ne 0 -or $changedChannels -eq 0){throw 'SYNTHETIC_CODEC_COUNTEREXAMPLE_NOT_REPRODUCED'}
    $pts=@($records|ForEach-Object{[long](($_ -split ',')[2].Trim())})
    Write-Host ('SYNTHETIC_CODEC_PREREQUISITE '+([PSCustomObject]@{Frames=10;ExactReferenceMatches=$exact;
        UnknownUnderExactReference=10-$exact;ChangedChannelComparisons=$changedChannels;
        TimeBase=($timeBase[0] -replace '^#tb 0: ','');OriginalPts=$pts;
        HeldOutDecodePasses=1;CheckpointReplacementAuthorized=$false}|ConvertTo-Json -Compress))
}finally{
    # Only this freshly created synthetic test directory is removed. No physical evidence.
    if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}
}
