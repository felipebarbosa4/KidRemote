Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ReferenceVideo.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
$stages=@('Preflight','EnrollOrdinary','EnrollRestricted','Freeze','ReturnOrdinary','StartHeldOut','OrdinaryBefore','Arm','Hold','Clear','OrdinaryAfter','StopCapture','Analyze','BailoutClear','FinalizeCapture','RestoreAwake')
foreach($failure in @('NONE','Preflight','EnrollOrdinary','EnrollRestricted','StartHeldOut','Hold','StopCapture','Analyze')){
    $visited=New-Object 'Collections.Generic.List[string]';$operations=@{}
    foreach($stage in $stages){$operations[$stage]={$visited.Add($stage);if($stage -eq $failure){throw 'INVALID:INJECTED_FAILURE'}}.GetNewClosure()}
    $result=Invoke-KRReferenceVideoSequence $operations
    Assert-Equal $result.Status $(if($failure -eq 'NONE'){'CHARACTERIZED'}else{'INVALID'})
    Assert-Equal ($visited.ToArray()[-3..-1] -join ',') 'BailoutClear,FinalizeCapture,RestoreAwake'
    Assert-Equal $result.QualificationRows 0;Assert-Equal $result.Time04Rows 0
    Assert-Equal $result.CheckpointReplacementAuthorized $false;Assert-Equal $result.MatrixContribution 'NONE'
}
$operations=@{};foreach($stage in $stages){$operations[$stage]={}}
$operations.Hold={throw 'FAIL:RESTRICTION_LOST'};$operations.BailoutClear={throw 'INVALID:CLEAR_FAILED'}
$result=Invoke-KRReferenceVideoSequence $operations
Assert-Equal $result.Status 'FAIL';Assert-Equal $result.Reason 'RESTRICTION_LOST'
Assert-Equal $result.Cleanup[1].Status 'VERIFIED';Assert-Equal $result.Cleanup[2].Status 'VERIFIED'
foreach($reason in @('INVALID:REFERENCE_OWNER_REJECTED','INVALID:RECORDER_TIMEOUT','INTERRUPTED:OPERATOR_STOP','INVALID:VIDEO_TOOL_REJECTED','INVALID:VIDEO_COPY_EXISTS_PRESERVE_PARTIAL')){
    $operations.Analyze={throw $reason}.GetNewClosure();$operations.Hold={}
    $result=Invoke-KRReferenceVideoSequence $operations
    Assert-Equal $result.Reason $reason.Split(':')[1]
    Assert-Equal $result.Cleanup.Count 3
}
$frame=Get-KRVideoFramePhase 0 1 90000 ([PSCustomObject]@{StartTicks=100;EndTicks=900}) @()
Assert-Equal $frame.Phase 'UNASSIGNED';Assert-Equal $frame.AlignmentUncertaintyMillis $null
Assert-Equal (Get-KRVideoLabelVerdict 'ORDINARY' 'RESTRICTED') 'FAIL'
Assert-Equal (Get-KRVideoLabelVerdict 'RESTRICTED' 'UNASSIGNED') 'INVALID'
Write-Host ($script:Checks.ToString()+' reference-video orchestration assertions passed; fake operations only.')
