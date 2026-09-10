<# Excluded owner-local reference enrollment and video characterization; never qualification. #>
param([string]$Adb='C:\platform-tools\adb.exe',[string]$Ffmpeg='ffmpeg.exe',[string]$Ffprobe='ffprobe.exe')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Start-KR003.ps1') -Adb $Adb -VisualCalibration -FunctionsOnly
Import-Module (Join-Path $PSScriptRoot 'ReferenceVideo.psm1') -Force
. (Join-Path $PSScriptRoot 'ReferenceVideo.Runner.ps1')
$runId='video-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$runDirectory=Assert-RVLocalPath (Join-Path 'C:\platform-tools\kr003-reference-video' $runId)
$script:RVMedia=Join-Path $runDirectory 'local-media'
$script:RVRecorders=@();$script:RVProcesses=@{};$script:RVStderr=@{};$script:RVProbe=$null
$script:RVEnrollment=$null;$script:RVFrozenHash=$null
$script:RVLock=$null;$script:RVFinalizing=$false
$script:RVOriginalStop=${function:Check-EarlyStop}
function Check-EarlyStop {
    if($script:RVFinalizing){return}
    if(Test-Path -LiteralPath (Join-Path $runDirectory 'cancel.stop')){throw 'INTERRUPTED:OPERATOR_STOP'}
    & $script:RVOriginalStop
}
function Assert-RVOrdinary {
    Assert-RVHealth
    $state=Get-LabState
    if($state.armed -or $state.restriction -or $state.attached){throw 'INVALID:ORDINARY_STATE_UNVERIFIED'}
    $before=Wait-FixtureFocus -Focused $true
    $null=Assert-FixturePositiveControl $before 'INVALID:ORDINARY_INPUT_CONTROL'
}
function Invoke-RVClear {
    if($script:LabControlReady){$null=Invoke-ExcludedDiagnosticCleanup 'video-cleanup.json' 'INVALID:VIDEO_CLEANUP_UNVERIFIED'}
    $script:VisualRestriction=$null
}
$operations=@{
    Preflight={
        if([Console]::IsInputRedirected){throw 'INVALID:INTERACTIVE_OPERATOR_REQUIRED'}
        $script:Bundle=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle.json') -Raw|ConvertFrom-Json
        Assert-KRReferenceVideoBundle $script:Bundle
        foreach($entry in $script:Bundle.files){
            if($entry.name -notmatch '^[A-Za-z0-9_.-]+$' -or
                (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $entry.name)).Hash.ToLowerInvariant() -cne $entry.sha256){throw 'INVALID:BUNDLE_INTEGRITY'}
        }
        $script:RVFfmpeg=(Get-Command $Ffmpeg -CommandType Application -ErrorAction Stop).Source
        $script:RVFfprobe=(Get-Command $Ffprobe -CommandType Application -ErrorAction Stop).Source
        $null=Invoke-KRVideoTool $script:RVFfmpeg @('-version');$null=Invoke-KRVideoTool $script:RVFfprobe @('-version')
        Initialize-KRVideoCore
        New-Item -ItemType Directory -Path $script:RVMedia|Out-Null
        $script:RVLock=[IO.File]::Open((Join-Path $runDirectory 'active.lock'),[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        Write-Host ('Local-only evidence: '+$runDirectory)
        Write-Host 'Keep all media here, outside cloud sync. Two local image confirmations; no checkpoint replacement or qualification.'
        if((Invoke-LabAdb @('get-state')).Trim() -cne 'device'){throw 'INVALID:DEVICE_UNAVAILABLE'}
        $script:Device=Read-DeviceConfiguration -IdentityOnly
        Assert-KRBoundDeviceConfiguration $script:Device $script:Bundle.approvedConfiguration
        Write-JsonFile 'manifest.json' ([PSCustomObject]@{RunId=$runId;Bundle=$script:Bundle;Device=$script:Device;QualificationRows=0;Time04Rows=0;MatrixContribution='NONE';CheckpointReplacementAuthorized=$false})
        Verify-InstalledApk $candidatePackage 'candidate.apk' $script:Bundle.candidateSha256 -NoInstall
        Verify-InstalledApk $fixturePackage 'ordinary-fixture.apk' $script:Bundle.fixtureSha256 -NoInstall
        $capability=Invoke-LabAdbResult @('shell','screenrecord','--help')
        if($capability.ExitCode -ne 0 -or $capability.StderrClass -in @('SECURITY_EXCEPTION','PERMISSION_DENIAL')){throw 'INVALID:SCREENRECORD_CAPABILITY'}
        $null=Invoke-LabAdb @('shell','am','start','-n',"$candidatePackage/.MainActivity")
        $null=Get-LabState;$script:LabControlReady=$true
        Invoke-RVClear;Enter-StayAwake;Assert-RVOrdinary
        $script:RVEnrollment=[PSCustomObject]@{CandidateHash=$script:Bundle.candidateSha256;FixtureHash=$script:Bundle.fixtureSha256;
            Configuration=$script:Device;ClassifierVersion='LOCAL_TILE_MAE_RGB24_V1';ProfileSha256=(Get-FileHash (Join-Path $PSScriptRoot 'reference-comparator.json')).Hash;
            DecoderSha256=(Get-FileHash -Algorithm SHA256 $script:RVFfmpeg).Hash;ProbeToolSha256=(Get-FileHash -Algorithm SHA256 $script:RVFfprobe).Hash;
            CaptureConfiguration='SCREENRECORD_NATIVE_20MBPS_NORMALIZED_RGB24';HostTickFrequency=[Diagnostics.Stopwatch]::Frequency;
            FrozenTicks=$null;References=@()}
    }
    EnrollOrdinary={ $record=Start-RVRecording 'ordinary-reference' 6;Wait-RVRecording $record;Save-RVReference 'ORDINARY' $record }
    EnrollRestricted={
        $script:VisualRestriction=Invoke-ExcludedDiagnosticRestriction 'REFERENCE_ENROLLMENT_EXCLUDED' 'reference-restriction.json'
        $record=Start-RVRecording 'restricted-reference' 6;Wait-RVRecording $record;Save-RVReference 'RESTRICTED' $record
    }
    Freeze={
        $script:RVEnrollment.FrozenTicks=[Diagnostics.Stopwatch]::GetTimestamp()
        Write-JsonFile 'references.json' $script:RVEnrollment
        $script:RVFrozenHash=(Get-FileHash -Algorithm SHA256 (Join-Path $runDirectory 'references.json')).Hash
        Write-JsonFile 'reference-freeze.json' ([PSCustomObject]@{Sha256=$script:RVFrozenHash;FrozenTicks=$script:RVEnrollment.FrozenTicks})
        Assert-RVReferenceFiles
    }
    ReturnOrdinary={Invoke-RVClear;Assert-RVOrdinary}
    StartHeldOut={$null=Start-RVRecording 'held-out' 120}
    OrdinaryBefore={Start-VisualPhase 'ORDINARY_BEFORE';Assert-RVOrdinary;Start-Sleep -Seconds 2;Complete-VisualPhase 'INDEPENDENT_INPUT_CONTROL'}
    Arm={Start-VisualPhase 'EXPIRY_TRANSITION';$script:VisualRestriction=Invoke-ExcludedDiagnosticRestriction 'HELD_OUT_VIDEO_EXCLUDED' 'held-out-restriction.json';Complete-VisualPhase 'ATTACHMENT_VERIFIED'}
    Hold={Start-VisualPhase 'RESTRICTED';$null=Invoke-VisualRestrictedHold;Complete-VisualPhase 'INDEPENDENT_BLOCKED_INPUT_CONTROL'}
    Clear={Start-VisualPhase 'CLEAR_TRANSITION';Invoke-RVClear;Complete-VisualPhase 'CLEAR_VERIFIED'}
    OrdinaryAfter={Start-VisualPhase 'ORDINARY_AFTER';Assert-RVOrdinary;Start-Sleep -Seconds 2;Complete-VisualPhase 'INDEPENDENT_INPUT_CONTROL'}
    StopCapture={Stop-RVRecording @($script:RVRecorders|Where-Object{$_.Name -eq 'held-out'})[0]}
    Analyze={Invoke-RVAnalysis}
    BailoutClear={$script:RVFinalizing=$true;Invoke-RVClear}
    FinalizeCapture={
        $failed=$false
        foreach($record in $script:RVRecorders){try{Stop-RVRecording $record}catch{$failed=$true}}
        if($failed){throw 'INVALID:CAPTURE_FINALIZATION_UNVERIFIED'}
    }
    RestoreAwake={
        Restore-StayAwake
        if($null -ne $script:StayAwakeOriginal){
            Write-JsonFile 'stay-awake-restoration.json' $script:StayAwakeRestoration
            if($script:StayAwakeRestoreStatus -ne 'RESTORED_AND_SETTING_VERIFIED'){throw 'INVALID:STAY_AWAKE_RESTORE_FAILED'}
        }
    }
}
$result=Invoke-KRReferenceVideoSequence $operations
if(Test-Path -LiteralPath $runDirectory){Write-JsonFile 'summary.json' $result}
if($null -ne $script:RVLock){$script:RVLock.Dispose()}
Write-Host ($result.Status+':'+$result.Reason)
if($result.Status -ne 'CHARACTERIZED'){exit 1}
