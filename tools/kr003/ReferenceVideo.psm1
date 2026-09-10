Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Assert-KRReferenceEnrollment {
    param($Enrollment,[string]$ConfigurationHash,[string]$CandidateHash,[string]$FixtureHash,[long]$HeldOutStart)
    if($null -eq $Enrollment){throw 'INVALID:REFERENCE_PROVENANCE'}
    foreach($field in @('ConfigurationHash','CandidateHash','FixtureHash','FrozenTicks','ClassifierVersion','References')){
        if($Enrollment.PSObject.Properties.Name -notcontains $field){throw 'INVALID:REFERENCE_PROVENANCE'}
    }
    if($Enrollment.ConfigurationHash -cne $ConfigurationHash -or $Enrollment.CandidateHash -cne $CandidateHash -or
        $Enrollment.FixtureHash -cne $FixtureHash -or $Enrollment.FrozenTicks -ge $HeldOutStart -or
        $Enrollment.ClassifierVersion -cne 'EXACT_FULL_PIXEL_REFERENCE_V1' -or @($Enrollment.References).Count -ne 2){throw 'INVALID:REFERENCE_PROVENANCE'}
    foreach($role in @('ORDINARY','RESTRICTED')){
        foreach($reference in $Enrollment.References){
            foreach($field in @('Role','OwnerConfirmation','ConfirmedTicks','CapturedTicks','Sha256','CaptureConfiguration')){
                if($null -eq $reference -or $reference.PSObject.Properties.Name -notcontains $field){throw 'INVALID:REFERENCE_NOT_INDEPENDENTLY_CONFIRMED'}
            }
        }
        $roleReferences=@($Enrollment.References|Where-Object{$_.Role -ceq $role})
        if($roleReferences.Count -ne 1 -or $roleReferences[0].OwnerConfirmation -cne 'MATCHES_DISPLAYED_SURFACE' -or
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
        if($null -ne $prior){
            $delta=[long]$frame.Pts-[long]$prior.Pts
            if($delta -le 0){throw 'INVALID:VIDEO_TIMESTAMP_ORDER'}
            $intervals+=$delta*1000.0*$TimeBaseNumerator/$TimeBaseDenominator
        }
        $prior=$frame
    }
    [PSCustomObject]@{TimestampProvenance='DECODED_FRAME_ORIGINAL_PTS_AND_STREAM_TIME_BASE';FrameCount=$Frames.Count;
        TimeBaseNumerator=$TimeBaseNumerator;TimeBaseDenominator=$TimeBaseDenominator;
        FirstPts=$Frames[0].Pts;LastPts=$Frames[-1].Pts;FrameIntervalsMillis=$intervals;
        MaximumFrameIntervalMillis=($intervals|Measure-Object -Maximum).Maximum;
        NativeSampleSpanMillis=([long]$Frames[-1].Pts-[long]$Frames[0].Pts)*1000.0*$TimeBaseNumerator/$TimeBaseDenominator;
        HostAlignmentUncertaintyMillis=$null;HostAlignment='UNSPECIFIED_NO_VERIFIED_CLOCK_ANCHOR';
        StaticCaptureFreshness='UNSPECIFIED';PhysicalInterruptionDetectionGuarantee='UNSPECIFIED';
        AcceptableMissedInterruptionMillis=$null;CheckpointReplacementAuthorized=$false;
        QualificationRows=0;Time04Rows=0;MatrixContribution='NONE'}
}

Export-ModuleMember -Function Assert-KRReferenceEnrollment,Get-KRVideoTimestampCharacterization
