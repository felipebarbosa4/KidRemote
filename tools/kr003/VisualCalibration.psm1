Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-KRVisualVectorDistance {
    param([double[]]$Left, [double[]]$Right)
    if ($null -eq $Left -or $null -eq $Right -or $Left.Count -ne $Right.Count -or $Left.Count -eq 0) {
        throw 'INVALID:VISUAL_FEATURE_SCHEMA'
    }
    $sum=0.0
    for($position=0;$position -lt $Left.Count;$position++){$sum += [Math]::Abs($Left[$position]-$Right[$position])}
    return $sum/$Left.Count
}

function Get-KRVisualCentroid {
    param([object[]]$Frames)
    if($null -eq $Frames -or $Frames.Count -eq 0){throw 'INVALID:VISUAL_PHASE_EMPTY'}
    $length=[int]$Frames[0].Feature.Count
    if($length -eq 0){throw 'INVALID:VISUAL_FEATURE_SCHEMA'}
    $centroid=New-Object 'double[]' $length
    foreach($frame in $Frames){
        if($frame.Feature.Count -ne $length){throw 'INVALID:VISUAL_FEATURE_SCHEMA'}
        for($position=0;$position -lt $length;$position++){$centroid[$position]+=[double]$frame.Feature[$position]}
    }
    for($position=0;$position -lt $length;$position++){$centroid[$position]/=$Frames.Count}
    return $centroid
}

function Get-KRVisualTemporalMetrics {
    param([object[]]$Frames,$Window,[long]$Frequency)
    if($Frequency -le 0 -or $null -eq $Window -or $Window.EndTicks -le $Window.StartTicks){throw 'INVALID:VISUAL_TIMESTAMP_SCHEMA'}
    $ordered=@($Frames|Sort-Object StartTicks,EndTicks)
    if($ordered.Count -eq 0){throw 'INVALID:VISUAL_PHASE_EMPTY'}
    $toMillis=1000.0/[double]$Frequency
    $durations=@($ordered|ForEach-Object{([long]$_.EndTicks-[long]$_.StartTicks)*$toMillis})
    $worstBlind=([long]$ordered[0].EndTicks-[long]$Window.StartTicks)*$toMillis
    for($index=1;$index -lt $ordered.Count;$index++){
        $possibleGap=([long]$ordered[$index].EndTicks-[long]$ordered[$index-1].StartTicks)*$toMillis
        if($possibleGap -gt $worstBlind){$worstBlind=$possibleGap}
    }
    $tail=([long]$Window.EndTicks-[long]$ordered[-1].StartTicks)*$toMillis
    if($tail -gt $worstBlind){$worstBlind=$tail}
    $windowMillis=([long]$Window.EndTicks-[long]$Window.StartTicks)*$toMillis
    $spanMillis=([long]$ordered[-1].EndTicks-[long]$ordered[0].StartTicks)*$toMillis
    $maximumDuration=($durations|Measure-Object -Maximum).Maximum
    return [PSCustomObject]@{
        FrameCount=$ordered.Count;WindowMillis=[Math]::Round($windowMillis,3);ObservedSpanMillis=[Math]::Round($spanMillis,3)
        SpanCoverageRatio=[Math]::Round([Math]::Min(1.0,$spanMillis/$windowMillis),6)
        MaximumCaptureDurationMillis=[Math]::Round([double]$maximumDuration,3)
        TimestampAlignmentUncertaintyMillis=[Math]::Round([double]$maximumDuration,3)
        WorstCaseSamplingGapMillis=[Math]::Round([Math]::Max(0.0,$worstBlind),3)
        DefensibleInterruptionDetectionBoundMillis=[Math]::Round([Math]::Max(0.0,$worstBlind),3)
    }
}

function Get-KRVisualSpatialSeparation {
    param([double[]]$Ordinary,[double[]]$Restricted,[int]$GridWidth,[int]$GridHeight)
    if($GridWidth -lt 4 -or $GridHeight -lt 4 -or $Ordinary.Count -ne $GridWidth*$GridHeight*3 -or $Restricted.Count -ne $Ordinary.Count){
        throw 'INVALID:VISUAL_FEATURE_SCHEMA'
    }
    $tileDistances=@()
    for($tile=0;$tile -lt $GridWidth*$GridHeight;$tile++){
        $base=$tile*3
        $tileDistances+=([Math]::Abs($Ordinary[$base]-$Restricted[$base])+[Math]::Abs($Ordinary[$base+1]-$Restricted[$base+1])+[Math]::Abs($Ordinary[$base+2]-$Restricted[$base+2]))/3.0
    }
    $mean=($tileDistances|Measure-Object -Average).Average
    $threshold=[Math]::Max(0.025,[double]$mean*0.50)
    $changed=@()
    for($tile=0;$tile -lt $tileDistances.Count;$tile++){if($tileDistances[$tile] -ge $threshold){$changed+=$tile}}
    if($changed.Count -eq 0){return [PSCustomObject]@{ChangedTileFraction=0.0;HorizontalSpan=0.0;VerticalSpan=0.0}}
    $xs=@($changed|ForEach-Object{$_%$GridWidth});$ys=@($changed|ForEach-Object{[Math]::Floor($_/$GridWidth)})
    return [PSCustomObject]@{
        ChangedTileFraction=[Math]::Round($changed.Count/[double]$tileDistances.Count,6)
        HorizontalSpan=[Math]::Round((($xs|Measure-Object -Maximum).Maximum-($xs|Measure-Object -Minimum).Minimum+1)/[double]$GridWidth,6)
        VerticalSpan=[Math]::Round((($ys|Measure-Object -Maximum).Maximum-($ys|Measure-Object -Minimum).Minimum+1)/[double]$GridHeight,6)
    }
}

function New-KRVisualResult {
    param([string]$Status,[string]$Reason,[object[]]$Frames,$Temporal,$Spatial,[object[]]$Classifications,[double]$BetweenDistance,[double]$OrdinaryRoundTripDistance,[int]$RepeatedHashes)
    [PSCustomObject]@{
        Schema=1;Status=$Status;Reason=$Reason;ClassifierModel='DETERMINISTIC_FULL_FRAME_RGB_GRID_NEAREST_PROTOTYPE'
        TimestampModel='HOST_MONOTONIC_CAPTURE_REQUEST_INTERVALS';GridWidth=24;GridHeight=24
        FrameCount=$Frames.Count;OrdinaryBeforeFrames=@($Frames|Where-Object{$_.Phase -eq 'ORDINARY_BEFORE'}).Count
        RestrictedFrames=@($Frames|Where-Object{$_.Phase -eq 'RESTRICTED'}).Count
        OrdinaryAfterFrames=@($Frames|Where-Object{$_.Phase -eq 'ORDINARY_AFTER'}).Count
        BlankFrames=@($Frames|Where-Object{$_.Blank}).Count;RepeatedImageHashes=$RepeatedHashes
        BetweenClassDistance=[Math]::Round($BetweenDistance,6);OrdinaryRoundTripDistance=[Math]::Round($OrdinaryRoundTripDistance,6)
        ChangedTileFraction=$(if($null -eq $Spatial){$null}else{$Spatial.ChangedTileFraction})
        ChangedHorizontalSpan=$(if($null -eq $Spatial){$null}else{$Spatial.HorizontalSpan})
        ChangedVerticalSpan=$(if($null -eq $Spatial){$null}else{$Spatial.VerticalSpan})
        RestrictedTemporalCoverage=$Temporal;Classifications=@($Classifications)
        CaptureLiveness=$(if($Status -eq 'PASS'){'CONTROLLED_ORDINARY_RESTRICTED_ORDINARY_TRANSITIONS_VERIFIED'}else{'NOT_VERIFIED'})
        QualificationRows=0;Time04Rows=0;MatrixContribution='NONE';HumanObservationSerialized=$false
        RawMediaIncluded=$false;RawMediaLocation='OWNER_LOCAL_RUN_DIRECTORY_ONLY'
    }
}

function Get-KRVisualClassification {
    param([object[]]$Frames,[object[]]$PhaseWindows,[long]$Frequency,[int]$GridWidth=24,[int]$GridHeight=24)
    $orderedFrames=@($Frames|Sort-Object Index)
    for($index=0;$index -lt $orderedFrames.Count;$index++){
        if([long]$orderedFrames[$index].EndTicks -le [long]$orderedFrames[$index].StartTicks -or
            ($index -gt 0 -and [long]$orderedFrames[$index].StartTicks -lt [long]$orderedFrames[$index-1].EndTicks)){
            return New-KRVisualResult 'INVALID' 'CAPTURE_TIMESTAMP_SEQUENCE_UNVERIFIED' $Frames $null $null @() 0 0 0
        }
    }
    $required=@('ORDINARY_BEFORE','RESTRICTED','ORDINARY_AFTER')
    foreach($name in $required){
        if(@($PhaseWindows|Where-Object{$_.Name -eq $name}).Count -ne 1){throw 'INVALID:VISUAL_PHASE_SCHEMA'}
        if(@($Frames|Where-Object{$_.Phase -eq $name}).Count -lt 3){
            return New-KRVisualResult 'INVALID' 'TEMPORAL_COVERAGE_INSUFFICIENT' $Frames $null $null @() 0 0 0
        }
    }
    if(@($Frames|Where-Object{$_.Blank}).Count){return New-KRVisualResult 'INVALID' 'CAPTURE_BLANK_OR_PROTECTED' $Frames $null $null @() 0 0 0}
    $ordinaryBefore=@($Frames|Where-Object{$_.Phase -eq 'ORDINARY_BEFORE'})
    $restricted=@($Frames|Where-Object{$_.Phase -eq 'RESTRICTED'})
    $ordinaryAfter=@($Frames|Where-Object{$_.Phase -eq 'ORDINARY_AFTER'})
    $ordinary=@($ordinaryBefore)+@($ordinaryAfter)
    $ordinaryPrototype=Get-KRVisualCentroid $ordinary
    $restrictedPrototype=Get-KRVisualCentroid $restricted
    $beforePrototype=Get-KRVisualCentroid $ordinaryBefore
    $afterPrototype=Get-KRVisualCentroid $ordinaryAfter
    $between=Get-KRVisualVectorDistance $ordinaryPrototype $restrictedPrototype
    $roundTrip=Get-KRVisualVectorDistance $beforePrototype $afterPrototype
    $spatial=Get-KRVisualSpatialSeparation $ordinaryPrototype $restrictedPrototype $GridWidth $GridHeight
    $restrictedWindow=@($PhaseWindows|Where-Object{$_.Name -eq 'RESTRICTED'})[0]
    $temporal=Get-KRVisualTemporalMetrics $restricted $restrictedWindow $Frequency
    $hashGroups=@($Frames|Group-Object Sha256)
    $repeated=@($hashGroups|Where-Object{$_.Count -gt 1}|ForEach-Object{$_.Count-1}|Measure-Object -Sum).Sum
    if($null -eq $repeated){$repeated=0}
    if($between -lt 0.025 -or $spatial.ChangedTileFraction -lt 0.05 -or $spatial.HorizontalSpan -lt 0.50 -or $spatial.VerticalSpan -lt 0.30){
        return New-KRVisualResult 'INVALID' 'SURFACE_SEPARATION_INSUFFICIENT' $Frames $temporal $spatial @() $between $roundTrip $repeated
    }
    if($roundTrip -gt [Math]::Max(0.08,$between*0.65)){
        return New-KRVisualResult 'INVALID' 'ORDINARY_REFERENCE_NOT_REPEATABLE' $Frames $temporal $spatial @() $between $roundTrip $repeated
    }
    if($temporal.WindowMillis -lt 10000 -or $temporal.SpanCoverageRatio -lt 0.90 -or $temporal.WorstCaseSamplingGapMillis -gt 1500){
        return New-KRVisualResult 'INVALID' 'TEMPORAL_COVERAGE_INSUFFICIENT' $Frames $temporal $spatial @() $between $roundTrip $repeated
    }
    $minimumMargin=[Math]::Max(0.008,$between*0.15)
    $classifications=@();$ambiguous=$false;$contradiction=$null
    foreach($frame in @($Frames|Where-Object{$_.Phase -in $required}|Sort-Object Index)){
        $ordinaryDistance=Get-KRVisualVectorDistance $frame.Feature $ordinaryPrototype
        $restrictedDistance=Get-KRVisualVectorDistance $frame.Feature $restrictedPrototype
        $margin=[Math]::Abs($ordinaryDistance-$restrictedDistance)
        $classification=if($margin -lt $minimumMargin){'AMBIGUOUS'}elseif($ordinaryDistance -lt $restrictedDistance){'ORDINARY'}else{'RESTRICTED'}
        $classifications+=[PSCustomObject]@{Index=[int]$frame.Index;Phase=[string]$frame.Phase;Classification=$classification;Margin=[Math]::Round($margin,6);Sha256=[string]$frame.Sha256}
        if($classification -eq 'AMBIGUOUS'){$ambiguous=$true;continue}
        $expected=if($frame.Phase -eq 'RESTRICTED'){'RESTRICTED'}else{'ORDINARY'}
        if($classification -ne $expected -and $null -eq $contradiction){$contradiction=$frame}
    }
    if($ambiguous){return New-KRVisualResult 'INVALID' 'VISUAL_CLASSIFICATION_UNCERTAIN' $Frames $temporal $spatial $classifications $between $roundTrip $repeated}
    if($null -ne $contradiction){
        $reason=if($contradiction.Phase -eq 'RESTRICTED'){'VISUAL_RESTRICTION_DISAPPEARANCE_DECODED'}elseif($contradiction.Phase -eq 'ORDINARY_AFTER'){'VISUAL_RESTRICTION_REMAINS_AFTER_CLEAR'}else{'VISUAL_FIXTURE_DISAGREEMENT'}
        return New-KRVisualResult 'FAIL' $reason $Frames $temporal $spatial $classifications $between $roundTrip $repeated
    }
    return New-KRVisualResult 'PASS' 'ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED' $Frames $temporal $spatial $classifications $between $roundTrip $repeated
}

function Get-KRVisualPngFeature {
    param([string]$Path,[int]$GridWidth=24,[int]$GridHeight=24)
    Add-Type -AssemblyName System.Drawing
    $source=$null;$scaled=$null;$graphics=$null
    try{
        $source=[Drawing.Bitmap]::FromFile($Path)
        if($source.Width -lt 64 -or $source.Height -lt 64){throw 'INVALID:VISUAL_FRAME_DIMENSIONS'}
        $scaled=New-Object Drawing.Bitmap -ArgumentList $GridWidth,$GridHeight
        $graphics=[Drawing.Graphics]::FromImage($scaled)
        $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
        $graphics.DrawImage($source,0,0,$GridWidth,$GridHeight)
        $feature=New-Object Collections.Generic.List[double]
        $luma=New-Object Collections.Generic.List[double]
        for($y=0;$y -lt $GridHeight;$y++){
            for($x=0;$x -lt $GridWidth;$x++){
                $pixel=$scaled.GetPixel($x,$y)
                $feature.Add($pixel.R/255.0);$feature.Add($pixel.G/255.0);$feature.Add($pixel.B/255.0)
                $luma.Add((0.2126*$pixel.R+0.7152*$pixel.G+0.0722*$pixel.B)/255.0)
            }
        }
        $mean=($luma|Measure-Object -Average).Average;$variance=0.0
        foreach($value in $luma){$variance+=($value-$mean)*($value-$mean)}
        $standardDeviation=[Math]::Sqrt($variance/$luma.Count)
        $blank=($standardDeviation -lt 0.004 -and ($mean -lt 0.02 -or $mean -gt 0.98))
        return [PSCustomObject]@{Width=[int]$source.Width;Height=[int]$source.Height;Feature=[double[]]$feature.ToArray();Blank=[bool]$blank}
    }catch{
        if($_.Exception.Message -like 'INVALID:*'){throw}
        throw 'INVALID:VISUAL_FRAME_DECODE'
    }finally{
        if($null -ne $graphics){$graphics.Dispose()};if($null -ne $scaled){$scaled.Dispose()};if($null -ne $source){$source.Dispose()}
    }
}

function Invoke-KRVisualAnalysis {
    param([string]$RunDirectory)
    $journalPath=Join-Path $RunDirectory 'frame-journal.jsonl';$phasesPath=Join-Path $RunDirectory 'visual-phases.json'
    if(-not (Test-Path -LiteralPath $journalPath) -or -not (Test-Path -LiteralPath $phasesPath)){throw 'INVALID:VISUAL_EVIDENCE_MISSING'}
    $phaseRecord=Get-Content -LiteralPath $phasesPath -Raw|ConvertFrom-Json
    if($phaseRecord.Schema -ne 1 -or $phaseRecord.Frequency -le 0){throw 'INVALID:VISUAL_PHASE_SCHEMA'}
    $entries=@(Get-Content -LiteralPath $journalPath|Where-Object{-not [string]::IsNullOrWhiteSpace($_)}|ForEach-Object{$_|ConvertFrom-Json})
    $frames=@();$lastIndex=0
    foreach($entry in $entries){
        if($entry.Index -ne $lastIndex+1 -or $entry.FileName -notmatch '^frame-[0-9]{6}\.png$' -or $entry.ExitCode -ne 0 -or $entry.StderrClass -ne 'NONE' -or $entry.Sha256 -notmatch '^[a-f0-9]{64}$' -or $entry.EndTicks -lt $entry.StartTicks){throw 'INVALID:VISUAL_CAPTURE_JOURNAL'}
        $lastIndex=[int]$entry.Index;$path=Join-Path (Join-Path $RunDirectory 'raw-frames') $entry.FileName
        if(-not (Test-Path -LiteralPath $path) -or (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() -cne $entry.Sha256){throw 'INVALID:VISUAL_FRAME_HASH'}
        $feature=Get-KRVisualPngFeature $path
        $phase=@($phaseRecord.Phases|Where-Object{$entry.StartTicks -ge $_.StartTicks -and $entry.EndTicks -le $_.EndTicks})
        $phaseName=if($phase.Count -eq 1){[string]$phase[0].Name}else{'TRANSITION_OR_UNASSIGNED'}
        $frames+=[PSCustomObject]@{Index=[int]$entry.Index;StartTicks=[long]$entry.StartTicks;EndTicks=[long]$entry.EndTicks;Sha256=[string]$entry.Sha256;Phase=$phaseName;Width=$feature.Width;Height=$feature.Height;Feature=$feature.Feature;Blank=$feature.Blank}
    }
    $dimensions=@($frames|ForEach-Object{"$($_.Width)x$($_.Height)"}|Select-Object -Unique)
    if($dimensions.Count -ne 1){throw 'INVALID:VISUAL_FRAME_DIMENSIONS_CHANGED'}
    return Get-KRVisualClassification -Frames $frames -PhaseWindows @($phaseRecord.Phases) -Frequency ([long]$phaseRecord.Frequency)
}

function Get-KRVisualFinalResult {
    param([string]$PrimaryStatus,[string]$PrimaryReason,[string]$CleanupStatus,[string]$StayAwakeRestoration,[string]$CaptureStatus)
    if($PrimaryStatus -eq 'FAIL'){return [PSCustomObject]@{Status='FAIL';Reason=$PrimaryReason}}
    if($PrimaryStatus -eq 'INVALID'){return [PSCustomObject]@{Status='INVALID';Reason=$PrimaryReason}}
    if($PrimaryStatus -ne 'PASS'){return [PSCustomObject]@{Status='INVALID';Reason='VISUAL_PRIMARY_RESULT_UNKNOWN'}}
    if($CaptureStatus -ne 'COMPLETED'){return [PSCustomObject]@{Status='INVALID';Reason='VISUAL_CAPTURE_INCOMPLETE'}}
    if($CleanupStatus -ne 'VERIFIED'){return [PSCustomObject]@{Status='INVALID';Reason='VISUAL_CLEANUP_UNVERIFIED'}}
    if($StayAwakeRestoration -ne 'RESTORED_AND_SETTING_VERIFIED'){return [PSCustomObject]@{Status='INVALID';Reason='STAY_AWAKE_RESTORE_FAILED'}}
    return [PSCustomObject]@{Status='PASS';Reason='ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED'}
}

Export-ModuleMember -Function Get-KRVisualVectorDistance,Get-KRVisualTemporalMetrics,Get-KRVisualSpatialSeparation,Get-KRVisualClassification,Get-KRVisualPngFeature,Invoke-KRVisualAnalysis,Get-KRVisualFinalResult
