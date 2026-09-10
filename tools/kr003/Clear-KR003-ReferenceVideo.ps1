<# Standalone local bailout: no uninstall, network mutation or broad process kill. #>
param([Parameter(Mandatory=$true)][string]$RunDirectory,[string]$Adb='C:\platform-tools\adb.exe')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$requestedDirectory=$RunDirectory
. (Join-Path $PSScriptRoot 'Start-KR003.ps1') -Adb $Adb -VisualCalibration -FunctionsOnly
. (Join-Path $PSScriptRoot 'ReferenceVideo.Runner.ps1')
$runDirectory=Assert-RVLocalPath $requestedDirectory
$runId=Split-Path -Leaf $runDirectory
$script:RVProcesses=@{};$script:RVStderr=@{};$script:RVRecorders=@()
$script:RVMedia=Join-Path $runDirectory 'local-media'
$steps=@()
$bailoutLock=$null
try{
    if($runId -notmatch '^video-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$'){throw 'INVALID:BAILOUT_RUN_PATH'}
    $script:Bundle=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle.json') -Raw|ConvertFrom-Json
    Assert-KRReferenceVideoBundle $script:Bundle
    foreach($entry in $script:Bundle.files){
        if($entry.name -notmatch '^[A-Za-z0-9_.-]+$' -or
            (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $entry.name)).Hash.ToLowerInvariant() -cne $entry.sha256){throw 'INVALID:BUNDLE_INTEGRITY'}
    }
    # No device operation until the same immutable source and exact run are verified.
    $manifest=Get-Content -LiteralPath (Join-Path $runDirectory 'manifest.json') -Raw|ConvertFrom-Json
    if($manifest.RunId -cne $runId -or $manifest.Bundle.sourceCommit -cne $script:Bundle.sourceCommit){throw 'INVALID:BAILOUT_PROVENANCE'}
    [IO.File]::WriteAllText((Join-Path $runDirectory 'cancel.stop'),'STOP_REQUESTED')
    $wait=[Diagnostics.Stopwatch]::StartNew()
    while($null -eq $bailoutLock){
        try{$bailoutLock=[IO.File]::Open((Join-Path $runDirectory 'active.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch{if($wait.Elapsed.TotalSeconds -gt 30){throw 'INVALID:MAIN_STILL_FINALIZING_RETRY_BAILOUT_AFTER_EXIT'};Start-Sleep -Milliseconds 250}
    }
    if((Invoke-LabAdb @('get-state')).Trim() -cne 'device'){throw 'INVALID:DEVICE_UNAVAILABLE'}
    $script:Device=Read-DeviceConfiguration -IdentityOnly;Assert-KRBoundDeviceConfiguration $script:Device $script:Bundle.approvedConfiguration
    Verify-InstalledApk $candidatePackage 'candidate.apk' $script:Bundle.candidateSha256 -NoInstall
    Verify-InstalledApk $fixturePackage 'ordinary-fixture.apk' $script:Bundle.fixtureSha256 -NoInstall
    $recorderPath=Join-Path $runDirectory 'recorders.json'
    if(Test-Path -LiteralPath $recorderPath){$script:RVRecorders=@(Get-Content -LiteralPath $recorderPath -Raw|ConvertFrom-Json)}
    $awakePath=Join-Path $runDirectory 'stay-awake.json'
    if(Test-Path -LiteralPath $awakePath){
        $awake=Get-Content -LiteralPath $awakePath -Raw|ConvertFrom-Json
        if($awake.OriginalSetting -notin 0..15){throw 'INVALID:STAY_AWAKE_JOURNAL'}
        $script:StayAwakeOriginal=[int]$awake.OriginalSetting;$script:StayAwakeTouched=[bool]$awake.Changed
    }
    try{$null=Get-LabState;$script:LabControlReady=$true;$null=Invoke-ExcludedDiagnosticCleanup 'bailout-clear.json' 'INVALID:BAILOUT_CLEAR';$steps+='CLEAR_VERIFIED'}catch{$steps+='CLEAR_UNVERIFIED'}
    foreach($record in $script:RVRecorders){try{Stop-RVRecording $record;$steps+='RECORDER_VERIFIED'}catch{$steps+='RECORDER_UNVERIFIED'}}
    Restore-StayAwake
    Write-JsonFile 'bailout-stay-awake.json' $script:StayAwakeRestoration
    if($null -ne $script:StayAwakeOriginal -and $script:StayAwakeRestoreStatus -ne 'RESTORED_AND_SETTING_VERIFIED'){$steps+='STAY_AWAKE_UNVERIFIED'}else{$steps+='STAY_AWAKE_VERIFIED_OR_UNCHANGED'}
    Write-JsonFile 'video-bailout.json' ([PSCustomObject]@{Steps=$steps;PrimaryResultModified=$false;DeviceFiles='RETAINED_OWNER_EXPLICIT_CLEANUP_REQUIRED'})
    if(@($steps|Where-Object{$_ -like '*_UNVERIFIED'}).Count){throw 'INVALID:BAILOUT_CLEANUP_UNVERIFIED'}
    Write-Host 'BAILOUT_VERIFIED: local and device media retained; original primary result unchanged.'
}catch{
    $reason=if($_.Exception.Message -match '^INVALID:[A-Z0-9_]+$'){$_.Exception.Message}else{'INVALID:BAILOUT_HOST_EXCEPTION'}
    Write-Host $reason;exit 1
}finally{if($null -ne $bailoutLock){$bailoutLock.Dispose()}}
