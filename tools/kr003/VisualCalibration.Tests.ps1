<#
Goal: Exercise the excluded visual-channel classifier without a device or retained real content.
Context: Synthetic feature grids model ordinary/restricted/ordinary, timing gaps, ambiguity and cleanup precedence.
Constraints: No ADB, raw physical media, upload, OCR or repository artifact creation.
Done when: PASS/FAIL/INVALID boundaries and primary-result preservation behave identically under Windows PowerShell 5.1 and PowerShell 7.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'VisualCalibration.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
function New-Feature([double]$Base,[switch]$Restricted){
    $values=New-Object 'double[]' (24*24*3)
    for($tile=0;$tile -lt 24*24;$tile++){
        $change=$(if($Restricted -and (($tile%24) -le 18) -and ([Math]::Floor($tile/24) -ge 4)) {0.45}else{0.0})
        $values[$tile*3]=$Base+$change;$values[$tile*3+1]=$Base+$change*0.8;$values[$tile*3+2]=$Base+$change*0.6
    }
    return $values
}
function New-Frame([int]$Index,[string]$Phase,[long]$Start,[double[]]$Feature,[string]$Hash,[bool]$Blank=$false){
    [PSCustomObject]@{Index=$Index;Phase=$Phase;StartTicks=$Start;EndTicks=$Start+100;Feature=$Feature;Sha256=$Hash;Blank=$Blank}
}
function New-Fixture([switch]$Gap,[switch]$StaticHashes){
    $ordinary=New-Feature 0.20;$restricted=New-Feature 0.20 -Restricted
    $frames=@();$index=0
    foreach($start in @(0,1000,2500)){$index++;$frames+=New-Frame $index 'ORDINARY_BEFORE' $start $ordinary $(if($StaticHashes){'a'*64}else{('{0:x64}' -f $index)})}
    $restrictedStarts=$(if($Gap){@(4000,7000,10000,14000)}else{@(4000,5000,6000,7000,8000,9000,10000,11000,12000,13000,14000)})
    foreach($start in $restrictedStarts){$index++;$frames+=New-Frame $index 'RESTRICTED' $start $restricted $(if($StaticHashes){'b'*64}else{('{0:x64}' -f $index)})}
    foreach($start in @(15000,16000,17500)){$index++;$frames+=New-Frame $index 'ORDINARY_AFTER' $start $ordinary $(if($StaticHashes){'a'*64}else{('{0:x64}' -f $index)})}
    $windows=@(
        [PSCustomObject]@{Name='ORDINARY_BEFORE';StartTicks=0;EndTicks=3000},
        [PSCustomObject]@{Name='RESTRICTED';StartTicks=3900;EndTicks=14500},
        [PSCustomObject]@{Name='ORDINARY_AFTER';StartTicks=14900;EndTicks=18000}
    )
    return [PSCustomObject]@{Frames=$frames;Windows=$windows;Ordinary=$ordinary;Restricted=$restricted}
}

$valid=New-Fixture
$pass=Get-KRVisualClassification $valid.Frames $valid.Windows 1000
Assert-Equal $pass.Status 'PASS';Assert-Equal $pass.Reason 'ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED'
Assert-Equal $pass.QualificationRows 0;Assert-Equal $pass.Time04Rows 0;Assert-Equal $pass.MatrixContribution 'NONE';Assert-Equal $pass.HumanObservationSerialized $false
Assert-Equal ($pass.ChangedTileFraction -ge 0.05) $true;Assert-Equal ($pass.RestrictedTemporalCoverage.DefensibleInterruptionDetectionBoundMillis -le 1500) $true
Assert-Equal (($pass|ConvertTo-Json -Depth 8) -match 'Feature') $false

$disappearance=New-Fixture
$restrictedFrames=@($disappearance.Frames|Where-Object{$_.Phase -eq 'RESTRICTED'})
$restrictedFrames[5].Feature=$disappearance.Ordinary
$lost=Get-KRVisualClassification $disappearance.Frames $disappearance.Windows 1000
Assert-Equal $lost.Status 'FAIL';Assert-Equal $lost.Reason 'VISUAL_RESTRICTION_DISAPPEARANCE_DECODED'

$ambiguous=New-Fixture
$half=New-Object 'double[]' $ambiguous.Ordinary.Count
for($position=0;$position -lt $half.Count;$position++){$half[$position]=($ambiguous.Ordinary[$position]+$ambiguous.Restricted[$position])/2.0}
$ambiguousFrame=@($ambiguous.Frames|Where-Object{$_.Phase -eq 'RESTRICTED'})[5];$ambiguousFrame.Feature=$half
$uncertain=Get-KRVisualClassification $ambiguous.Frames $ambiguous.Windows 1000
Assert-Equal $uncertain.Status 'INVALID';Assert-Equal $uncertain.Reason 'VISUAL_CLASSIFICATION_UNCERTAIN'

$blank=New-Fixture;$blank.Frames[4].Blank=$true
$blankResult=Get-KRVisualClassification $blank.Frames $blank.Windows 1000
Assert-Equal $blankResult.Status 'INVALID';Assert-Equal $blankResult.Reason 'CAPTURE_BLANK_OR_PROTECTED'

$truncated=New-Fixture
$truncated.Frames=@($truncated.Frames|Where-Object{$_.Phase -ne 'RESTRICTED'})+@($truncated.Frames|Where-Object{$_.Phase -eq 'RESTRICTED'}|Select-Object -First 2)
$short=Get-KRVisualClassification $truncated.Frames $truncated.Windows 1000
Assert-Equal $short.Status 'INVALID';Assert-Equal $short.Reason 'TEMPORAL_COVERAGE_INSUFFICIENT'

$gapped=New-Fixture -Gap
$gapResult=Get-KRVisualClassification $gapped.Frames $gapped.Windows 1000
Assert-Equal $gapResult.Status 'INVALID';Assert-Equal $gapResult.Reason 'TEMPORAL_COVERAGE_INSUFFICIENT'

$static=New-Fixture -StaticHashes
$staticResult=Get-KRVisualClassification $static.Frames $static.Windows 1000
Assert-Equal $staticResult.Status 'PASS';Assert-Equal ($staticResult.RepeatedImageHashes -gt 0) $true

$staleTimestamps=New-Fixture -StaticHashes
$staleRestricted=@($staleTimestamps.Frames|Where-Object{$_.Phase -eq 'RESTRICTED'})
$staleRestricted[4].StartTicks=$staleRestricted[3].StartTicks;$staleRestricted[4].EndTicks=$staleRestricted[3].EndTicks
$staleTimestampResult=Get-KRVisualClassification $staleTimestamps.Frames $staleTimestamps.Windows 1000
Assert-Equal $staleTimestampResult.Status 'INVALID';Assert-Equal $staleTimestampResult.Reason 'CAPTURE_TIMESTAMP_SEQUENCE_UNVERIFIED'

$frozenAcrossTransitions=New-Fixture -StaticHashes
foreach($frame in $frozenAcrossTransitions.Frames){$frame.Feature=$frozenAcrossTransitions.Ordinary;$frame.Sha256='a'*64}
$frozenResult=Get-KRVisualClassification $frozenAcrossTransitions.Frames $frozenAcrossTransitions.Windows 1000
Assert-Equal $frozenResult.Status 'INVALID';Assert-Equal $frozenResult.Reason 'SURFACE_SEPARATION_INSUFFICIENT'

$disagreement=New-Fixture
$disagreementFrame=@($disagreement.Frames|Where-Object{$_.Phase -eq 'ORDINARY_AFTER'})[1];$disagreementFrame.Feature=$disagreement.Restricted
$disagreementResult=Get-KRVisualClassification $disagreement.Frames $disagreement.Windows 1000
Assert-Equal $disagreementResult.Status 'FAIL';Assert-Equal $disagreementResult.Reason 'VISUAL_RESTRICTION_REMAINS_AFTER_CLEAR'

$preserved=Get-KRVisualFinalResult 'FAIL' 'VISUAL_RESTRICTION_DISAPPEARANCE_DECODED' 'FAILED' 'RESTORE_FAILED_OWNER_ACTION_REQUIRED' 'INVALID'
Assert-Equal $preserved.Status 'FAIL';Assert-Equal $preserved.Reason 'VISUAL_RESTRICTION_DISAPPEARANCE_DECODED'
$cleanupInvalid=Get-KRVisualFinalResult 'PASS' 'ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED' 'FAILED' 'RESTORED_AND_SETTING_VERIFIED' 'COMPLETED'
Assert-Equal $cleanupInvalid.Status 'INVALID';Assert-Equal $cleanupInvalid.Reason 'VISUAL_CLEANUP_UNVERIFIED'
$captureInvalid=Get-KRVisualFinalResult 'PASS' 'ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED' 'VERIFIED' 'RESTORED_AND_SETTING_VERIFIED' 'INVALID'
Assert-Equal $captureInvalid.Status 'INVALID';Assert-Equal $captureInvalid.Reason 'VISUAL_CAPTURE_INCOMPLETE'

if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){
    Add-Type -AssemblyName System.Drawing
    $temporary=Join-Path ([IO.Path]::GetTempPath()) ('kr003-visual-png-'+[Guid]::NewGuid().ToString('N')+'.png')
    try{
        $bitmap=New-Object Drawing.Bitmap -ArgumentList 96,96
        $graphics=[Drawing.Graphics]::FromImage($bitmap);$graphics.Clear([Drawing.Color]::White);$graphics.FillRectangle([Drawing.Brushes]::Black,10,10,60,40);$graphics.Dispose()
        $bitmap.Save($temporary,[Drawing.Imaging.ImageFormat]::Png);$bitmap.Dispose()
        $decoded=Get-KRVisualPngFeature $temporary
        Assert-Equal $decoded.Width 96;Assert-Equal $decoded.Height 96;Assert-Equal $decoded.Blank $false;Assert-Equal $decoded.Feature.Count (24*24*3)
    }finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force}}
}

# Validity-review counterexamples: these PASS expectations document limitations
# of the immutable v1 algorithm, NOT acceptable restriction-recognition semantics.
$thirdSurface=New-Fixture
$unrelated=New-Object 'double[]' (24*24*3)
for($tile=0;$tile -lt 24*24;$tile++){
    $unrelated[$tile*3]=0.70
    $unrelated[$tile*3+1]=$(if(($tile%2) -eq 0){0.60}else{0.50})
    $unrelated[$tile*3+2]=0.65
}
foreach($frame in @($thirdSurface.Frames|Where-Object{$_.Phase -eq 'RESTRICTED'})){$frame.Feature=$unrelated}
$thirdResult=Get-KRVisualClassification $thirdSurface.Frames $thirdSurface.Windows 1000
Assert-Equal $thirdResult.Status 'PASS'
Assert-Equal (@($thirdResult.Classifications|Where-Object{$_.Phase -eq 'RESTRICTED' -and $_.Classification -eq 'RESTRICTED'}).Count) 11
Assert-Equal ((Get-KRVisualVectorDistance $unrelated $thirdSurface.Restricted) -gt 0.1) $true

# Sustained wrong imagery replaces 9/11 reference observations; the two original
# expected images also remain closer to the contaminated class than to ordinary.
$contaminated=New-Fixture
$contaminatedFrames=@($contaminated.Frames|Where-Object{$_.Phase -eq 'RESTRICTED'})
for($index=1;$index -lt 10;$index++){$contaminatedFrames[$index].Feature=$unrelated}
$contaminatedResult=Get-KRVisualClassification $contaminated.Frames $contaminated.Windows 1000
Assert-Equal $contaminatedResult.Status 'PASS'

# Same sampled observations for two different ground-truth timelines: a 300ms
# disappearance at 6500..6800 is wholly outside requests 6000..6100/7000..7100.
$hidden=New-Fixture -StaticHashes
$hiddenStart=6500;$hiddenEnd=6800
Assert-Equal (@($hidden.Frames|Where-Object{$_.StartTicks -lt $hiddenEnd -and $_.EndTicks -gt $hiddenStart}).Count) 0
$hiddenResult=Get-KRVisualClassification $hidden.Frames $hidden.Windows 1000
Assert-Equal $hiddenResult.Status 'PASS'
Assert-Equal $hiddenResult.RestrictedTemporalCoverage.ObservedSpanMillis 10100
Assert-Equal $hiddenResult.RestrictedTemporalCoverage.WindowMillis 10600
Assert-Equal $hiddenResult.RestrictedTemporalCoverage.SpanCoverageRatio 0.95283
Assert-Equal $hiddenResult.RestrictedTemporalCoverage.WorstCaseSamplingGapMillis 1100
# Capture request durations themselves are not observed display intervals.
# A freeze confined to the restricted phase is observationally identical to a
# legitimate static surface even with advancing host timestamps and transitions.
Assert-Equal $hiddenResult.CaptureLiveness 'CONTROLLED_ORDINARY_RESTRICTED_ORDINARY_TRANSITIONS_VERIFIED'
Assert-Equal (@($hidden.Frames|Where-Object{$_.Phase -eq 'RESTRICTED'}|Select-Object -ExpandProperty Sha256 -Unique).Count) 1
foreach($reviewResult in @($thirdResult,$contaminatedResult,$hiddenResult)){
    Assert-Equal $reviewResult.QualificationRows 0
    Assert-Equal $reviewResult.Time04Rows 0
    Assert-Equal $reviewResult.MatrixContribution 'NONE'
}

Write-Host ($script:Checks.ToString()+' visual-calibration assertions passed without ADB or physical media; includes known-limit counterexamples, not checkpoint acceptance.')
