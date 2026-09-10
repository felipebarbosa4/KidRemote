Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ReferenceVideo.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
function Assert-Invalid([scriptblock]$Action,[string]$Expected){$actual='NO_ERROR';try{& $Action|Out-Null}catch{$actual=$_.Exception.Message};Assert-Equal $actual $Expected}
function New-Enrollment {
    [PSCustomObject]@{ConfigurationHash='a'*64;CandidateHash='b'*64;FixtureHash='c'*64;FrozenTicks=30;
        ClassifierVersion='EXACT_FULL_PIXEL_REFERENCE_V1';References=@(
            [PSCustomObject]@{Role='ORDINARY';OwnerConfirmation='MATCHES_DISPLAYED_SURFACE';CapturedTicks=10;ConfirmedTicks=15;Sha256='d'*64;CaptureConfiguration='NATIVE_PNG_UNSCALED'},
            [PSCustomObject]@{Role='RESTRICTED';OwnerConfirmation='MATCHES_DISPLAYED_SURFACE';CapturedTicks=20;ConfirmedTicks=25;Sha256='e'*64;CaptureConfiguration='NATIVE_PNG_UNSCALED'})}
}
$enrollment=New-Enrollment
Assert-Invalid {Assert-KRReferenceEnrollment $null ('a'*64) ('b'*64) ('c'*64) 40} 'INVALID:REFERENCE_PROVENANCE'
Assert-KRReferenceEnrollment $enrollment ('a'*64) ('b'*64) ('c'*64) 40
Assert-Invalid {Assert-KRReferenceEnrollment $enrollment ('f'*64) ('b'*64) ('c'*64) 40} 'INVALID:REFERENCE_PROVENANCE'
Assert-Invalid {Assert-KRReferenceEnrollment $enrollment ('a'*64) ('b'*64) ('c'*64) 30} 'INVALID:REFERENCE_PROVENANCE'
$enrollment.References[1].OwnerConfirmation='CANDIDATE_ATTACHED'
Assert-Invalid {Assert-KRReferenceEnrollment $enrollment ('a'*64) ('b'*64) ('c'*64) 40} 'INVALID:REFERENCE_NOT_INDEPENDENTLY_CONFIRMED'
$enrollment=New-Enrollment;$enrollment.References=$enrollment.References[0]
Assert-Invalid {Assert-KRReferenceEnrollment $enrollment ('a'*64) ('b'*64) ('c'*64) 40} 'INVALID:REFERENCE_PROVENANCE'
$enrollment=New-Enrollment;$enrollment.References[1].PSObject.Properties.Remove('OwnerConfirmation')
Assert-Invalid {Assert-KRReferenceEnrollment $enrollment ('a'*64) ('b'*64) ('c'*64) 40} 'INVALID:REFERENCE_NOT_INDEPENDENTLY_CONFIRMED'
$enrollment=New-Enrollment;$enrollment.FrozenTicks=$null
Assert-Invalid {Assert-KRReferenceEnrollment $enrollment ('a'*64) ('b'*64) ('c'*64) 40} 'INVALID:REFERENCE_PROVENANCE'
$frames=@([PSCustomObject]@{Pts=9000},[PSCustomObject]@{Pts=12000},[PSCustomObject]@{Pts=21000})
$timing=Get-KRVideoTimestampCharacterization $frames 1 90000
Assert-Equal $timing.FirstPts 9000;Assert-Equal $timing.LastPts 21000
Assert-Equal ($timing.OriginalFramePts -join ',') '9000,12000,21000'
Assert-Equal $timing.MaximumFrameIntervalMillis 100
Assert-Equal $timing.HostAlignmentUncertaintyMillis $null
Assert-Equal $timing.CheckpointReplacementAuthorized $false
Assert-Equal $timing.PhysicalInterruptionDetectionGuarantee 'UNSPECIFIED'
Assert-Equal $timing.QualificationRows 0;Assert-Equal $timing.Time04Rows 0;Assert-Equal $timing.MatrixContribution 'NONE'
$frames[1].Pts=9000
Assert-Invalid {Get-KRVideoTimestampCharacterization $frames 1 90000} 'INVALID:VIDEO_TIMESTAMP_ORDER'
$frames[1].Pts=$null
Assert-Invalid {Get-KRVideoTimestampCharacterization $frames 1 90000} 'INVALID:VIDEO_TIMESTAMP_UNVERIFIED'
Write-Host ($script:Checks.ToString()+' reference-provenance/timestamp assertions passed; synthetic metadata only.')
