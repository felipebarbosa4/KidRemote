Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Assert-KRReferenceEnrollment {
    param($Enrollment,[string]$ConfigurationHash,[string]$CandidateHash,[string]$FixtureHash,[long]$HeldOutStart)
    if($null -eq $Enrollment){throw 'INVALID:REFERENCE_PROVENANCE'}
    foreach($field in @('ConfigurationHash','CandidateHash','FixtureHash','FrozenTicks','ClassifierVersion','References')){
        if($Enrollment.PSObject.Properties.Name -notcontains $field){throw 'INVALID:REFERENCE_PROVENANCE'}
    }
    if($Enrollment.ConfigurationHash -cne $ConfigurationHash -or $Enrollment.CandidateHash -cne $CandidateHash -or
        $Enrollment.FixtureHash -cne $FixtureHash -or $null -eq $Enrollment.FrozenTicks -or $Enrollment.FrozenTicks -le 0 -or $Enrollment.FrozenTicks -ge $HeldOutStart -or
        $Enrollment.ClassifierVersion -cne 'EXACT_FULL_PIXEL_REFERENCE_V1' -or @($Enrollment.References).Count -ne 2){throw 'INVALID:REFERENCE_PROVENANCE'}
    foreach($role in @('ORDINARY','RESTRICTED')){
        foreach($reference in $Enrollment.References){
            foreach($field in @('Role','OwnerConfirmation','ConfirmedTicks','CapturedTicks','Sha256','CaptureConfiguration')){
                if($null -eq $reference -or $reference.PSObject.Properties.Name -notcontains $field){throw 'INVALID:REFERENCE_NOT_INDEPENDENTLY_CONFIRMED'}
            }
        }
        $roleReferences=@($Enrollment.References|Where-Object{$_.Role -ceq $role})
        if($roleReferences.Count -ne 1 -or $roleReferences[0].OwnerConfirmation -cne 'MATCHES_DISPLAYED_SURFACE' -or
            $null -eq $roleReferences[0].ConfirmedTicks -or $null -eq $roleReferences[0].CapturedTicks -or
            $roleReferences[0].CapturedTicks -le 0 -or
            $roleReferences[0].ConfirmedTicks -gt $Enrollment.FrozenTicks -or $roleReferences[0].CapturedTicks -gt $roleReferences[0].ConfirmedTicks -or
            $roleReferences[0].Sha256 -cnotmatch '^[a-f0-9]{64}$' -or $roleReferences[0].CaptureConfiguration -cne 'NATIVE_PNG_UNSCALED'){
            throw 'INVALID:REFERENCE_NOT_INDEPENDENTLY_CONFIRMED'
        }
    }
}

function Get-KRVideoTimestampCharacterization {
    param([object[]]$Frames,[long]$TimeBaseNumerator,[long]$TimeBaseDenominator)
    if($Frames.Count -lt 2 -or $TimeBaseNumerator -le 0 -or $TimeBaseDenominator -le 0){throw 'INVALID:VIDEO_TIMESTAMP_UNVERIFIED'}
    $intervals=@();$prior=$null
    foreach($frame in $Frames){
        $parsedPts=0L
        if($null -eq $frame -or $frame.PSObject.Properties.Name -notcontains 'Pts' -or
            -not [long]::TryParse([string]$frame.Pts,[ref]$parsedPts)){throw 'INVALID:VIDEO_TIMESTAMP_UNVERIFIED'}
        if($null -ne $prior){
            $delta=[long]$frame.Pts-[long]$prior.Pts
            if($delta -le 0){throw 'INVALID:VIDEO_TIMESTAMP_ORDER'}
            $intervals+=$delta*1000.0*$TimeBaseNumerator/$TimeBaseDenominator
        }
        $prior=$frame
    }
    [PSCustomObject]@{TimestampProvenance='DECODED_FRAME_ORIGINAL_PTS_AND_STREAM_TIME_BASE';FrameCount=$Frames.Count;
        TimeBaseNumerator=$TimeBaseNumerator;TimeBaseDenominator=$TimeBaseDenominator;
        OriginalFramePts=@($Frames|ForEach-Object{$_.Pts});
        FirstPts=$Frames[0].Pts;LastPts=$Frames[-1].Pts;FrameIntervalsMillis=$intervals;
        MaximumFrameIntervalMillis=($intervals|Measure-Object -Maximum).Maximum;
        NativeSampleSpanMillis=([long]$Frames[-1].Pts-[long]$Frames[0].Pts)*1000.0*$TimeBaseNumerator/$TimeBaseDenominator;
        HostAlignmentUncertaintyMillis=$null;HostAlignment='UNSPECIFIED_NO_VERIFIED_CLOCK_ANCHOR';
        StaticCaptureFreshness='UNSPECIFIED';PhysicalInterruptionDetectionGuarantee='UNSPECIFIED';
        AcceptableMissedInterruptionMillis=$null;CheckpointReplacementAuthorized=$false;
        QualificationRows=0;Time04Rows=0;MatrixContribution='NONE'}
}

Export-ModuleMember -Function Assert-KRReferenceEnrollment,Get-KRVideoTimestampCharacterization

function Initialize-KRVideoCore {
    if(-not ('KR003.ReferenceVideoCore' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ReferenceVideoCore.cs')}
}

function Invoke-KRVideoTool {
    param([string]$Executable,[string[]]$Arguments,[int]$TimeoutSeconds=30)
    $process=New-Object Diagnostics.Process
    $process.StartInfo=New-Object Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName=$Executable;$process.StartInfo.UseShellExecute=$false;$process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true
    foreach($argument in $Arguments){if($argument -match '["\r\n]'){throw 'INVALID:VIDEO_TOOL_ARGUMENT'}}
    $process.StartInfo.Arguments=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
    $started=$false
    try{
        [void]$process.Start();$started=$true;$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit($TimeoutSeconds*1000)){throw 'INVALID:VIDEO_TOOL_TIMEOUT'}
        $null=$stderr.Result
        if($process.ExitCode -ne 0){throw 'INVALID:VIDEO_TOOL_REJECTED'}
        return [string]$stdout.Result
    }finally{if($started -and -not $process.HasExited){$process.Kill();$null=$process.WaitForExit(5000)};$process.Dispose()}
}

function Get-KRVideoProbe {
    param([string]$Ffprobe,[string]$Path)
    try{$raw=Invoke-KRVideoTool $Ffprobe @('-v','error','-select_streams','v:0','-show_entries','stream=codec_name,width,height,pix_fmt,color_range,color_space,color_transfer,color_primaries:stream_side_data=rotation','-of','json',$Path);$data=$raw|ConvertFrom-Json}catch{throw 'INVALID:VIDEO_PROBE'}
    if(@($data.streams).Count -ne 1){throw 'INVALID:VIDEO_STREAM'}
    $stream=$data.streams[0]
    if($stream.width -lt 16 -or $stream.height -lt 16 -or $stream.width -gt 4096 -or $stream.height -gt 4096){throw 'INVALID:VIDEO_DIMENSIONS'}
    $rotation=0
    if($stream.PSObject.Properties.Name -contains 'side_data_list'){
        foreach($side in $stream.side_data_list){if($side.PSObject.Properties.Name -contains 'rotation'){$rotation=[int]$side.rotation}}
    }
    if($rotation -ne 0){throw 'INVALID:VIDEO_ORIENTATION_UNSUPPORTED'}
    $result=[ordered]@{Width=[int]$stream.width;Height=[int]$stream.height;Rotation=$rotation;Normalization='NATIVE_SIZE_NO_AUTOROTATE_BT709_LIMITED_TO_FULL_RGB24';Codec=[string]$stream.codec_name;PixelFormat=[string]$stream.pix_fmt}
    foreach($field in @('color_range','color_space','color_transfer','color_primaries')){
        $result[$field]=if($stream.PSObject.Properties.Name -contains $field){[string]$stream.$field}else{'UNSPECIFIED'}
    }
    [PSCustomObject]$result
}

function Get-KRVideoFramePhase {
    param([long]$Pts,[long]$Numerator,[long]$Denominator,$Recorder,[object[]]$Phases)
    # Recorder lifetime is an independently journalled outer bound. Without a
    # verified PTS-to-host clock anchor it cannot yield phase-specific PASS.
    [PSCustomObject]@{Pts=$Pts;TimeBaseNumerator=$Numerator;TimeBaseDenominator=$Denominator;
        Phase='UNASSIGNED';PhaseVerdict='INVALID_ALIGNMENT_UNVERIFIED';
        CaptureOuterStartTicks=$Recorder.StartTicks;CaptureOuterEndTicks=$Recorder.EndTicks;
        AlignmentUncertaintyMillis=$null;AlignmentSource='RECORDER_LIFETIME_ONLY_NO_CLOCK_ANCHOR'}
}

function Invoke-KRReferenceVideoSequence {
    param([hashtable]$Operations)
    $primary='CHARACTERIZED';$reason='COMPLETED_NO_CHECKPOINT_AUTHORIZATION';$cleanup=@();$journal=@();$primaryStage='COMPLETED'
    try{
        foreach($stage in @('Preflight','EnrollOrdinary','EnrollRestricted','Freeze','ReturnOrdinary','StartHeldOut','OrdinaryBefore','Arm','Hold','Clear','OrdinaryAfter','StopCapture','Analyze')){
            & $Operations[$stage]|Out-Null
            $journal+=$stage
        }
    }catch{
        $message=$_.Exception.Message
        $primaryStage=$stage
        if($message -match '^(FAIL|INVALID|INTERRUPTED):([A-Z0-9_]+)$'){$primary=$Matches[1];$reason=$Matches[2]}
        else{$primary='INVALID';$reason='REFERENCE_VIDEO_HOST_EXCEPTION'}
    }finally{
        # Cleanup steps are independent: a recorder failure cannot suppress CLEAR
        # or restoration, and cleanup never overwrites an established primary.
        foreach($stage in @('BailoutClear','FinalizeCapture','RestoreAwake')){
            try{& $Operations[$stage]|Out-Null;$cleanup+=[PSCustomObject]@{Step=$stage;Status='VERIFIED'}}
            catch{$cleanup+=[PSCustomObject]@{Step=$stage;Status='UNVERIFIED'}}
        }
    }
    if($primary -eq 'CHARACTERIZED' -and @($cleanup|Where-Object{$_.Status -ne 'VERIFIED'}).Count){$primary='INVALID';$reason='CLEANUP_UNVERIFIED'}
    [PSCustomObject]@{Status=$primary;Reason=$reason;HostStage=$primaryStage;CompletedStages=$journal;Cleanup=$cleanup;CheckpointReplacementAuthorized=$false;
        QualificationRows=0;Time04Rows=0;MatrixContribution='NONE';HumanObservationSerialized=$false}
}

Export-ModuleMember -Function Initialize-KRVideoCore,Invoke-KRVideoTool,Get-KRVideoProbe,Get-KRVideoFramePhase,Invoke-KRReferenceVideoSequence

function Get-KRVideoLabelVerdict {
    param([string]$Label,[string]$Phase)
    if($Label -notin @('ORDINARY','RESTRICTED') -or $Phase -notin @('ORDINARY_BEFORE','RESTRICTED','ORDINARY_AFTER')){return 'INVALID'}
    $expected=if($Phase -eq 'RESTRICTED'){'RESTRICTED'}else{'ORDINARY'}
    if($Label -ceq $expected){return 'PASS'}else{return 'FAIL'}
}
Export-ModuleMember -Function Get-KRVideoLabelVerdict
