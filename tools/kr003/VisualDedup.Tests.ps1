<# Synthetic-only deduplication tests/benchmark. Never reads or emits media files. #>
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'VisualCalibration.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
function New-Pixels([int]$Size,[byte]$Red){
    $pixels=New-Object 'byte[]' ($Size*$Size*4)
    for($offset=0;$offset -lt $pixels.Length;$offset+=4){$pixels[$offset]=$Red;$pixels[$offset+1]=80;$pixels[$offset+2]=120;$pixels[$offset+3]=255}
    return ,$pixels
}
function New-Case([int]$Size=8,[int]$PerPhase=11){
    # References are authored before and separately from evaluated frame objects.
    $references=[PSCustomObject]@{Provenance='INDEPENDENT_SYNTHETIC';Version='synthetic-v1';Width=$Size;Height=$Size;
        Ordinary=(New-Pixels $Size 30);Restricted=(New-Pixels $Size 220)}
    $frames=@();$windows=@();$index=0
    foreach($phase in @('ORDINARY_BEFORE','RESTRICTED','ORDINARY_AFTER')){
        $start=$index*1000
        for($position=0;$position -lt $PerPhase;$position++){
            [byte[]]$bytes=$(if($phase -eq 'RESTRICTED'){$references.Restricted.Clone()}else{$references.Ordinary.Clone()})
            $frames+=[PSCustomObject]@{Index=$index+1;StartTicks=$index*1000;EndTicks=$index*1000+100;Phase=$phase;
                Bytes=$bytes;Sha256=(Get-KRVisualContentHash $bytes);Width=$Size;Height=$Size;CaptureStatus='ACCEPTED'}
            $index++
        }
        $windows+=[PSCustomObject]@{Name=$phase;StartTicks=$start;EndTicks=($index-1)*1000+100}
    }
    return @{Frames=$frames;PhaseWindows=$windows;Frequency=1000;References=$references;Format='DECODED_RGBA8';
        CaptureLiveness='VERIFIED_SYNTHETIC';SyntheticOnly=$true}
}
function Set-FrameBytes($Frame,[byte[]]$Bytes){$Frame.Bytes=$Bytes.Clone();$Frame.Sha256=Get-KRVisualContentHash $Frame.Bytes}
function Assert-Equivalent($Case){
    $cached=Invoke-KRVisualDedupPrototype @Case
    $plain=Invoke-KRVisualDedupPrototype @Case -DisableCache
    Assert-Equal $cached.Status $plain.Status
    Assert-Equal $cached.Coverage $plain.Coverage
    Assert-Equal $cached.CaptureLiveness $plain.CaptureLiveness
    Assert-Equal $cached.UniqueImages $plain.UniqueImages
    $fields=@('Index','StartTicks','EndTicks','Phase','Sha256','Label','Verdict','Reason')
    Assert-Equal ($cached.Rows|Select-Object $fields|ConvertTo-Json -Compress) ($plain.Rows|Select-Object $fields|ConvertTo-Json -Compress)
    Assert-Equal ($cached.Temporal|ConvertTo-Json -Compress) ($plain.Temporal|ConvertTo-Json -Compress)
    Assert-Equal $cached.QualificationRows 0;Assert-Equal $cached.Time04Rows 0
    Assert-Equal $cached.MatrixContribution 'NONE';Assert-Equal $cached.CheckpointSubstitutionAllowed $false
    return $cached
}

$case=New-Case
$result=Assert-Equivalent $case
Assert-Equal $result.Status 'PASS';Assert-Equal $result.FramesProcessed 33
Assert-Equal $result.UniqueImages 2;Assert-Equal $result.RecognitionCalls 2;Assert-Equal $result.CacheHits 31
Assert-Equal $case.References.Ordinary.Length $case.References.Restricted.Length
Assert-Equal (Test-KRVisualExactBytes $case.References.Ordinary $case.References.Restricted) $false

# Force hash-bucket collision. Equality, not length/hash, must distinguish images.
$collision=New-Case;$collision.SyntheticHashCollision=$true
$collisionResult=Assert-Equivalent $collision
Assert-Equal $collisionResult.Status 'PASS';Assert-Equal $collisionResult.RecognitionCalls 2

# A single-channel, one-pixel change must be recognized, not rounded away.
$changed=New-Case;[byte[]]$onePixel=$changed.References.Restricted.Clone();$onePixel[0]--
Set-FrameBytes $changed.Frames[16] $onePixel
$changedResult=Assert-Equivalent $changed
Assert-Equal $changedResult.RecognitionCalls 3;Assert-Equal $changedResult.Rows[16].Label 'UNKNOWN'
Assert-Equal $changedResult.Status 'INVALID'

# Cached labels are independent of phase: ordinary during hold is FAIL, even on hit.
$escape=New-Case;Set-FrameBytes $escape.Frames[16] $escape.References.Ordinary
$escapeResult=Assert-Equivalent $escape
Assert-Equal $escapeResult.Status 'FAIL';Assert-Equal $escapeResult.Rows[16].Label 'ORDINARY'
Assert-Equal $escapeResult.Rows[16].CacheHit $true;Assert-Equal $escapeResult.Rows[16].Verdict 'FAIL'

$third=New-Case;$wrong=New-Pixels 8 130
foreach($frame in @($third.Frames|Where-Object{$_.Phase -eq 'RESTRICTED'})){Set-FrameBytes $frame $wrong}
$thirdResult=Assert-Equivalent $third
Assert-Equal $thirdResult.Status 'INVALID'
Assert-Equal (@($thirdResult.Rows|Where-Object{$_.Phase -eq 'RESTRICTED' -and $_.Label -eq 'UNKNOWN'}).Count) 11

$missing=New-Case;$missing.Frames=@($missing.Frames|Where-Object{$_.Index -ne 16})
$missingResult=Assert-Equivalent $missing;Assert-Equal $missingResult.Status 'INVALID'
Assert-Equal $missingResult.Coverage 'INSUFFICIENT'
$truncated=New-Case -PerPhase 3
$truncatedResult=Assert-Equivalent $truncated;Assert-Equal $truncatedResult.Status 'INVALID'
foreach($liveness in @('UNKNOWN','STALE')){
    $stale=New-Case;$stale.CaptureLiveness=$liveness
    $staleResult=Assert-Equivalent $stale;Assert-Equal $staleResult.Status 'INVALID';Assert-Equal $staleResult.CacheHits 31
}
$timestamp=New-Case;$timestamp.Frames[16].StartTicks=$timestamp.Frames[15].StartTicks
$timestampResult=Assert-Equivalent $timestamp
Assert-Equal $timestampResult.Rows[16].Reason 'TIMESTAMP_SEQUENCE_INVALID'
$integrity=New-Case;$integrity.Frames[16].Sha256='0'*64
$integrityResult=Assert-Equivalent $integrity
Assert-Equal $integrityResult.Rows[16].Reason 'FRAME_INTEGRITY_INVALID';Assert-Equal $integrityResult.Rows[16].CacheHit $false
$phase=New-Case;$phase.Frames[16].Phase='ORDINARY_BEFORE'
$phaseResult=Assert-Equivalent $phase;Assert-Equal $phaseResult.Rows[16].Reason 'PHASE_CONTEXT_INVALID'

$newReference=New-Case;$newReference.References.Version='synthetic-v2'
$newVersionResult=Assert-Equivalent $newReference
Assert-Equal ($newVersionResult.ContextHash -cne $result.ContextHash) $true
$newReference.References.Restricted=New-Pixels 8 131
$newReferenceResult=Assert-Equivalent $newReference
Assert-Equal $newReferenceResult.Status 'INVALID'
Assert-Equal ($newReferenceResult.ContextHash -cne $newVersionResult.ContextHash) $true

# Actual PNG decode benchmark on Windows; no compressed-video decoder is added.
# DECODED_RGBA8 is the output boundary of a future single video decode pass.
if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){
    Add-Type -AssemblyName System.Drawing
    function New-SyntheticPng([byte]$Red){
        $bitmap=New-Object Drawing.Bitmap -ArgumentList 64,64
        $graphics=[Drawing.Graphics]::FromImage($bitmap);$stream=New-Object IO.MemoryStream
        try{
            $graphics.Clear([Drawing.Color]::FromArgb(255,$Red,80,120))
            $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
            return ,$stream.ToArray()
        }finally{$graphics.Dispose();$bitmap.Dispose();$stream.Dispose()}
    }
    $png=New-Case -Size 64 -PerPhase 20;$png.Format='PNG'
    $ordinaryPng=New-SyntheticPng 30;$restrictedPng=New-SyntheticPng 220
    Assert-Equal $ordinaryPng.Length $restrictedPng.Length
    Assert-Equal (Test-KRVisualExactBytes $ordinaryPng $restrictedPng) $false
    foreach($frame in $png.Frames){Set-FrameBytes $frame $(if($frame.Phase -eq 'RESTRICTED'){$restrictedPng}else{$ordinaryPng})}
    $pngResult=Assert-Equivalent $png
    Assert-Equal $pngResult.Status 'PASS';Assert-Equal $pngResult.DecodeCalls 2
    Assert-Equal $pngResult.UniqueImages 2;Assert-Equal $pngResult.CacheHits 58
    $novel=New-Case -Size 64 -PerPhase 20;$novel.Format='PNG'
    foreach($frame in $novel.Frames){Set-FrameBytes $frame (New-SyntheticPng ([byte](100+$frame.Index)))}
    $novelResult=Assert-Equivalent $novel
    Assert-Equal $novelResult.UniqueImages 60;Assert-Equal $novelResult.CacheHits 0
    Assert-Equal $novelResult.Status 'INVALID'
    # Two warm-up analyses per workload occurred above. Alternate measured order.
    # Outer stopwatch includes full analyzer call, not just recognition timing.
    $measurements=@()
    foreach($workload in @('REPEATED','ALL_NOVEL')){
        $benchmarkCase=$(if($workload -eq 'REPEATED'){$png}else{$novel})
        foreach($round in 1..3){
            $modes=$(if($round%2 -eq 1){@($true,$false)}else{@($false,$true)})
            foreach($uncached in $modes){
                $totalWatch=[Diagnostics.Stopwatch]::StartNew()
                $measured=Invoke-KRVisualDedupPrototype @benchmarkCase -DisableCache:$uncached
                $totalWatch.Stop()
                $measurements+=[PSCustomObject]@{Workload=$workload;Round=$round;Mode=$(if($uncached){'UNCACHED'}else{'CACHED'});
                    Frames=$measured.FramesProcessed;UniqueImages=$measured.UniqueImages;DecodeCalls=$measured.DecodeCalls;
                    RecognitionCalls=$measured.RecognitionCalls;CacheHits=$measured.CacheHits;TotalMillis=[Math]::Round($totalWatch.Elapsed.TotalMilliseconds,3)}
            }
        }
    }
    Write-Host ('SYNTHETIC_PNG_BENCHMARK '+($measurements|ConvertTo-Json -Compress))
}else{Write-Host 'PNG decode benchmark not run: requires local Windows System.Drawing. Decoded-pixel tests executed.'}
Write-Host ($script:Checks.ToString()+' dedup assertions passed; no device/media files; counts and timings only.')
