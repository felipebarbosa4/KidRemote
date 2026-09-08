<#
Goal: Calibrate the independent active oracle once on an exact transport-capable Android configuration.
Context: Transport PASS is necessary but does not prove candidate blocking, service continuity or visible agreement.
Constraints: One excluded calibration only; no qualification loop, network/configuration mutation, raw identity/content/history or destructive action.
Done when: Positive/blocked/service/physical controls and sample-preserving cleanup are recorded, then execution stops with zero qualification rows.
#>
param(
    [Parameter(Mandatory=$true)][string]$TransportEvidence,
    [string]$Adb='C:\platform-tools\adb.exe',
    [string]$OutputRoot='C:\platform-tools\kr003-oracle-calibration'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'OracleTransport.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'DevicePreflight.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'CalibrationHost.psm1') -Force

$candidatePackage='dev.kidremote.spike.enforcement';$fixturePackage='dev.kidremote.spike.ordinary'
$candidateReceiver="$candidatePackage/.LabControlReceiver";$fixtureReceiver="$fixturePackage/.FixtureReceiver"
$candidateActivity="$candidatePackage/.MainActivity";$fixtureActivity="$fixturePackage/.FixtureActivity"
$candidateService="$candidatePackage/.EnforcementAccessibilityService"
$runDirectory=Join-Path $OutputRoot ('calibration-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
$script:Operations=@();$script:Request=0L;$script:Cursor=0L;$script:LastElapsed=-1L;$script:ServiceConnections=0L
$script:AttachmentRevisions=@{};$script:FixtureInstance=-1L;$script:Bundle=$null;$script:LabReady=$false;$script:Armed=$false
$script:PositiveControl=$false;$script:BlockedControl=$false;$script:ServiceContinuous=$false;$script:PhysicalAgreement='UNRECORDED'
$script:CleanupVerified=$false;$script:LatencyMs=$null;$script:Revision=$null;$script:HoldMillis=0L;$script:BlockedTaps=0
$script:Status='INVALID';$script:Reason='NOT_STARTED';$script:TransportSummary=$null;$script:TransportDevice=$null
$script:PermissionVerification=New-KRCalibrationPermissionDiagnostic $null $null
$script:Host=New-KRCalibrationHostState
$startedUtc=[DateTime]::UtcNow.ToString('o')

function Write-CalibrationJson([string]$Name,$Value){[IO.File]::WriteAllText((Join-Path $runDirectory $Name),(ConvertTo-Json -InputObject $Value -Depth 14),(New-Object Text.UTF8Encoding($false)))}
function Save-CalibrationOperations{Write-CalibrationJson 'operations.json' @($script:Operations)}

function Invoke-CalibrationAdb{
    param([string]$Category,[string[]]$Arguments,[switch]$Optional)
    $process=New-Object Diagnostics.Process;$process.StartInfo=New-Object Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName=$Adb;$process.StartInfo.UseShellExecute=$false;$process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true;$process.StartInfo.CreateNoWindow=$true
    $quoted=foreach($argument in $Arguments){
        if($argument.Contains('"') -or $argument.Contains([string][char]13) -or $argument.Contains([string][char]10) -or $argument.EndsWith('\')){throw 'INVALID:ADB_ARGUMENT'}
        '"'+$argument+'"'
    }
    $process.StartInfo.Arguments=$quoted -join ' '
    try{
        [void]$process.Start();$stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(30000)){$process.Kill();$script:Operations+=New-KRDeviceOperationRecord $Category -1 'OTHER';Save-CalibrationOperations;throw 'INVALID:ADB_TIMEOUT'}
        $stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult();$stderrClass=Get-KRTransportStderrClass $stderr
        $script:Operations+=New-KRDeviceOperationRecord $Category $process.ExitCode $stderrClass;Save-CalibrationOperations
        if($process.ExitCode -ne 0 -or $stderrClass -in @('SECURITY_EXCEPTION','PERMISSION_DENIAL')){if($Optional){return $null};throw 'INVALID:ADB_OPERATION_REJECTED'}
        return $stdout
    }finally{$process.Dispose()}
}

function Read-CalibrationDevice{
    $manufacturer=Invoke-CalibrationAdb 'DEVICE_METADATA' @('shell','getprop','ro.product.manufacturer')
    $model=Invoke-CalibrationAdb 'DEVICE_METADATA' @('shell','getprop','ro.product.model')
    $android=Invoke-CalibrationAdb 'DEVICE_METADATA' @('shell','getprop','ro.build.version.release')
    $api=Invoke-CalibrationAdb 'DEVICE_METADATA' @('shell','getprop','ro.build.version.sdk')
    $patch=Invoke-CalibrationAdb 'DEVICE_METADATA' @('shell','getprop','ro.build.version.security_patch')
    $build=Invoke-CalibrationAdb 'DEVICE_METADATA' @('shell','getprop','ro.build.id')
    $batterySaver=Invoke-CalibrationAdb 'BATTERY_STATE' @('shell','settings','get','global','low_power') -Optional
    $adaptiveBattery=Invoke-CalibrationAdb 'BATTERY_STATE' @('shell','settings','get','global','adaptive_battery_management_enabled') -Optional
    $appStandby=Invoke-CalibrationAdb 'BATTERY_STATE' @('shell','settings','get','global','app_standby_enabled') -Optional
    $candidatePath=Invoke-CalibrationAdb 'CANDIDATE_INSTALL_STATE' @('shell','pm','path',$candidatePackage) -Optional
    $installed=(-not [string]::IsNullOrWhiteSpace($candidatePath));$usage=$null;$services=$null;$accessibility=$null
    if($installed){
        $usage=Invoke-CalibrationAdb 'USAGE_ACCESS_STATE' @('shell','cmd','appops','get',$candidatePackage,'GET_USAGE_STATS') -Optional
        $services=Invoke-CalibrationAdb 'ACCESSIBILITY_STATE' @('shell','settings','--user','current','get','secure','enabled_accessibility_services') -Optional
        $accessibility=Invoke-CalibrationAdb 'ACCESSIBILITY_STATE' @('shell','settings','--user','current','get','secure','accessibility_enabled') -Optional
    }
    New-KRDeviceMetadataRecord $manufacturer $model $android $api $patch $build $batterySaver $adaptiveBattery $appStandby $installed $usage $services $accessibility $candidateService
}

function Assert-CalibrationPermissionVerification($Device,$Snapshot,[bool]$PreviouslyEstablished){
    $script:PermissionVerification=New-KRCalibrationPermissionDiagnostic $Device.RunnerPermissionVerification $Snapshot
    Write-CalibrationJson 'permission-verification.json' $script:PermissionVerification
    $failure=Get-KRRequiredPermissionFailure $script:PermissionVerification $PreviouslyEstablished
    if($null -ne $failure){throw $failure}
}

function Assert-SameConfiguration($Expected,$Actual){
    foreach($name in @('Manufacturer','Model','AndroidVersion','ApiLevel','SecurityPatch','BuildId')){if($Expected.$name -cne $Actual.$name){throw 'INVALID:DEVICE_CONFIGURATION_CHANGED'}}
    foreach($name in @('BatterySaver','AdaptiveBattery','AppStandby','OemBatteryManagement')){if($Expected.BatteryManagement.$name -cne $Actual.BatteryManagement.$name){throw 'INVALID:DEVICE_CONFIGURATION_CHANGED'}}
}

function Get-CandidateState([string]$Operation='SNAPSHOT'){
    $category=switch($Operation){'CLEAR'{'CANDIDATE_CLEAR'}'ARM'{'CANDIDATE_ARM'}default{'CANDIDATE_STATE'}}
    $script:Request++
    $raw=Invoke-CalibrationAdb $category @('shell','am','broadcast','--receiver-foreground','-n',$candidateReceiver,'--es','operation',$Operation,'--el','request',"$script:Request",'--el','after',"$script:Cursor")
    $state=Convert-KRReply -Raw $raw -Request $script:Request
    if($state.schema -ne 2 -or $state.traceLost -or $state.traceHead -lt $script:Cursor){throw 'INVALID:TRACE_GAP_OR_PROCESS_REPLACED'}
    foreach($entry in $state.events){
        if($entry.sequence -ne $script:Cursor+1){throw 'INVALID:TRACE_SEQUENCE'}
        $entry|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $runDirectory 'trace.jsonl') -Encoding UTF8
        $script:Cursor=[long]$entry.sequence
        if($entry.line -match ' kind=service_connected '){$script:ServiceConnections++}
        if($entry.line -match ' kind=overlay_attached .* revision=(\d+)$'){$script:AttachmentRevisions[$Matches[1]]=$entry.sequence}
    }
    $state|ConvertTo-Json -Depth 8 -Compress|Add-Content -LiteralPath (Join-Path $runDirectory 'telemetry.jsonl') -Encoding UTF8
    if($script:LastElapsed -gt $state.elapsed){throw 'FAIL:CLOCK_DISCONTINUITY'};$script:LastElapsed=[long]$state.elapsed
    return $state
}

function Get-FixtureState{
    $script:Request++
    $raw=Invoke-CalibrationAdb 'FIXTURE_STATE' @('shell','am','broadcast','--receiver-foreground','-n',$fixtureReceiver,'--el','request',"$script:Request")
    $state=Convert-KRReply -Raw $raw -Request $script:Request -Fixture
    if($state.schema -ne 2){throw 'INVALID:FIXTURE_SCHEMA'}
    if($script:FixtureInstance -ge 0 -and $script:FixtureInstance -ne $state.instance){throw 'INVALID:FIXTURE_RESTARTED'}
    $script:FixtureInstance=[long]$state.instance;$state|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $runDirectory 'fixture.jsonl') -Encoding UTF8
    return $state
}

function Wait-Candidate([scriptblock]$Condition,[int]$Seconds,[string]$Failure){
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do{$state=Get-CandidateState;if(& $Condition $state){return $state};Start-Sleep -Milliseconds 200}while($watch.Elapsed.TotalSeconds -lt $Seconds)
    throw $Failure
}

function Wait-Fixture([bool]$Focused){
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do{$state=Get-FixtureState;if($state.probeReady -and $state.focused -eq $Focused -and (-not $Focused -or $state.resumed)){return $state};Start-Sleep -Milliseconds 100}while($watch.Elapsed.TotalSeconds -lt 5)
    throw 'INVALID:FIXTURE_NOT_READY'
}

function Invoke-FixtureTap($Fixture){
    if(-not $Fixture.probeReady -or $Fixture.probeX -lt 1 -or $Fixture.probeX -gt 10000 -or $Fixture.probeY -lt 1 -or $Fixture.probeY -gt 10000){throw 'INVALID:FIXTURE_INPUT_ORACLE_UNAVAILABLE'}
    $null=Invoke-CalibrationAdb 'INPUT_TAP' @('shell','input','tap',([string]$Fixture.probeX),([string]$Fixture.probeY))
}

function Assert-PositiveControl($Before){
    if(-not $Before.focused -or -not $Before.resumed){throw 'INVALID:FIXTURE_POSITIVE_CONTROL_FAILED'}
    Invoke-FixtureTap $Before;$watch=[Diagnostics.Stopwatch]::StartNew()
    do{$after=Get-FixtureState;if($after.instance -ne $Before.instance -or $after.probeX -ne $Before.probeX -or $after.probeY -ne $Before.probeY -or -not $after.focused -or -not $after.resumed){throw 'INVALID:FIXTURE_CHANGED'}
        if($after.taps -eq $Before.taps+1){return $after};if($after.taps -ne $Before.taps){throw 'FAIL:POSITIVE_CONTROL_WRONG_INCREMENT'};Start-Sleep -Milliseconds 100
    }while($watch.Elapsed.TotalSeconds -lt 3)
    throw 'FAIL:POSITIVE_CONTROL_NOT_DELIVERED'
}

function Verify-Apk([string]$Package,[string]$Name,[string]$Expected){
    $local=Join-Path $PSScriptRoot $Name;if((Get-FileHash -Algorithm SHA256 -LiteralPath $local).Hash.ToLowerInvariant() -cne $Expected){throw 'INVALID:APK_HASH'}
    $install=Invoke-CalibrationAdb $(if($Package -eq $candidatePackage){'CANDIDATE_INSTALL'}else{'FIXTURE_INSTALL'}) @('install','-r',$local)
    if($install -notmatch '(?m)^Success\s*$'){throw 'INVALID:INSTALL_FAILED_NO_UNINSTALL_FALLBACK'}
    $path=(Invoke-CalibrationAdb $(if($Package -eq $candidatePackage){'CANDIDATE_PATH'}else{'FIXTURE_PATH'}) @('shell','pm','path',$Package)).Trim()
    if($path -notmatch '^package:(/data/app/[A-Za-z0-9_~+/=.-]+/base\.apk)$'){throw 'INVALID:INSTALLED_PATH_OR_SPLIT_APK'}
    $pulled=Join-Path $runDirectory ('verified-'+$Name);$null=Invoke-CalibrationAdb $(if($Package -eq $candidatePackage){'CANDIDATE_PULL'}else{'FIXTURE_PULL'}) @('pull',$Matches[1],$pulled)
    if((Get-FileHash -Algorithm SHA256 -LiteralPath $pulled).Hash.ToLowerInvariant() -cne $Expected){throw 'INVALID:INSTALLED_APK_MISMATCH'}
}

function Read-PhysicalAgreement{
    Write-Host 'PHYSICAL AGREEMENT CHECK: did the restriction remain visibly continuous for the full blocked hold, with no flicker or ordinary use?' -ForegroundColor Cyan
    Write-Host '[P] pass  [F] visible failure  [I] uncertain/missed  [Q] stop'
    while($true){
        if(-not [Console]::KeyAvailable){
            $candidate=Get-CandidateState;$fixture=Get-FixtureState;Assert-KRHold $candidate $script:Revision $script:PositiveFixtureTaps $fixture;Assert-KRIndependentFixtureBlock $script:BlockedBaseline $fixture
            if($script:ServiceConnections -ne $script:ConnectionBaseline){throw 'INVALID:ENFORCEMENT_SERVICE_RESTARTED'};Start-Sleep -Milliseconds 100;continue
        }
        $key=[Console]::ReadKey($true).KeyChar.ToString().ToUpperInvariant()
        if($key -eq 'P'){return 'PASS'};if($key -eq 'F'){return 'FAIL'};if($key -eq 'I'){return 'INVALID'};if($key -eq 'Q'){throw 'INVALID:OPERATOR_STOP'}
    }
}

function Invoke-Cleanup{
    if(-not $script:LabReady){return}
    $before=Get-CandidateState;$samples=@($before.samples);$released=Get-CandidateState 'CLEAR'
    if($released.armed -or $released.restriction -or $released.attached){$released=Wait-Candidate {param($s)-not $s.armed -and -not $s.restriction -and -not $s.attached} 8 'FAIL:CLEANUP_RESTRICTION_NOT_RELEASED'}
    if($released.samples.Count -ne $samples.Count -or (($released.samples -join ',') -cne ($samples -join ','))){throw 'FAIL:CLEANUP_CHANGED_SAMPLES'}
    $script:CleanupVerified=$true
}

try{
    if([Console]::IsInputRedirected){throw 'INVALID:INTERACTIVE_OPERATOR_REQUIRED'}
    New-Item -ItemType Directory -Path $runDirectory|Out-Null
    if(-not (Test-Path -LiteralPath $Adb)){throw 'INVALID:ADB_MISSING'}
    Set-KRCalibrationHostStage $script:Host 'BUNDLE_HASH_VERIFICATION'
    $script:Bundle=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle.json') -Raw|ConvertFrom-Json
    if($script:Bundle.schema -ne 1 -or $script:Bundle.protocol -ne 'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION' -or $script:Bundle.runnerVersion -ne 3 -or -not $script:Bundle.calibrationOnly){throw 'INVALID:BUNDLE_SCHEMA'}
    foreach($entry in $script:Bundle.files){if($entry.name -notmatch '^[A-Za-z0-9_.-]+$'){throw 'INVALID:BUNDLE_PATH'};if((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $entry.name)).Hash.ToLowerInvariant() -cne $entry.sha256){throw 'INVALID:BUNDLE_INTEGRITY'}}
    Set-KRCalibrationHostStage $script:Host 'TRANSPORT_EVIDENCE_INGESTION'
    $script:TransportSummary=Get-Content -LiteralPath (Join-Path $TransportEvidence 'summary.json') -Raw|ConvertFrom-Json
    $script:TransportDevice=Get-Content -LiteralPath (Join-Path $TransportEvidence 'device.json') -Raw|ConvertFrom-Json
    if($script:TransportSummary.Protocol -ne 'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT' -or $script:TransportSummary.Status -ne 'PASSED_TRANSPORT_PREFLIGHT' -or -not $script:TransportSummary.CounterIncremented -or -not $script:TransportSummary.InstalledFixtureHashVerified -or $script:TransportSummary.FixtureSha256 -cne $script:Bundle.fixtureSha256){throw 'INVALID:TRANSPORT_PREREQUISITE'}
    Set-KRCalibrationHostStage $script:Host 'ADB_PREFLIGHT'
    if((Invoke-CalibrationAdb 'ADB_STATE' @('get-state')).Trim() -cne 'device'){throw 'INVALID:ADB_NOT_AUTHORIZED_OR_UNAVAILABLE'}
    Set-KRCalibrationHostStage $script:Host 'DEVICE_METADATA'
    $initial=Read-CalibrationDevice;if(-not (Test-KRDeviceMetadataComplete $initial)){throw 'INVALID:DEVICE_METADATA_INCOMPLETE'};Assert-SameConfiguration $script:TransportDevice $initial
    Set-KRCalibrationHostStage $script:Host 'APK_VERIFICATION'
    Verify-Apk $candidatePackage 'candidate.apk' $script:Bundle.candidateSha256;Verify-Apk $fixturePackage 'ordinary-fixture.apk' $script:Bundle.fixtureSha256
    Set-KRCalibrationHostStage $script:Host 'CANDIDATE_INITIALIZATION'
    $null=Invoke-CalibrationAdb 'CANDIDATE_OPEN' @('shell','am','start','-n',$candidateActivity)
    $first=Get-CandidateState;$script:LabReady=$true;$null=Get-CandidateState 'CLEAR'
    Write-Host 'Enable Usage Access and the disposable Accessibility service on the device if requested. The runner changes neither permission.' -ForegroundColor Cyan
    Set-KRCalibrationHostStage $script:Host 'PERMISSION_VERIFICATION'
    $ready=Wait-Candidate {param($s)$s.usage -and $s.accessibility -and $s.heartbeat -and $s.eligible -and -not $s.uncertain} 300 'INVALID:REQUIRED_PERMISSION_OR_UNLOCK_SETUP'
    Assert-KRHealth $ready
    $configured=Read-CalibrationDevice;Assert-SameConfiguration $script:TransportDevice $configured;Write-CalibrationJson 'device.json' $configured
    Assert-CalibrationPermissionVerification $configured $ready $false
    Set-KRCalibrationHostStage $script:Host 'FIXTURE_POSITIVE_CONTROL'
    $null=Invoke-CalibrationAdb 'FIXTURE_OPEN' @('shell','am','start','-n',$fixtureActivity);$fixture=Wait-Fixture $true
    $fixture=Assert-PositiveControl $fixture;$script:PositiveControl=$true;$script:PositiveFixtureTaps=[long]$fixture.taps
    Set-KRCalibrationHostStage $script:Host 'CANDIDATE_STATE_QUERY'
    $before=Get-CandidateState;Assert-KRHealth $before;$beforeSamples=@($before.samples);$script:ConnectionBaseline=$script:ServiceConnections
    Set-KRCalibrationHostStage $script:Host 'PRE_ARM_PERMISSION_VERIFICATION'
    $preArmDevice=Read-CalibrationDevice;Assert-SameConfiguration $script:TransportDevice $preArmDevice
    Assert-CalibrationPermissionVerification $preArmDevice $before $true
    Set-KRCalibrationHostStage $script:Host 'ARM'
    $armed=Get-CandidateState 'ARM';$script:Armed=$true;$script:Revision=[long]$armed.revision
    if(-not $armed.armed -or $armed.remaining -ne 10000){throw 'FAIL:FRESH_ARM_FAILED'}
    Set-KRCalibrationHostStage $script:Host 'WAIT_FOR_ATTACHMENT'
    $attached=Wait-Candidate {param($s)Assert-KRHealth $s;if($script:ServiceConnections -ne $script:ConnectionBaseline){throw 'INVALID:ENFORCEMENT_SERVICE_RESTARTED'};return $s.attached -and $s.restriction -and $s.sampledRevision -eq $script:Revision} 22 'FAIL:NO_ATTACHMENT'
    $script:LatencyMs=Get-KRPairedLatency $attached $script:Revision $beforeSamples
    if(-not $script:AttachmentRevisions.ContainsKey([string]$script:Revision)){throw 'INVALID:MISSING_ATTACHMENT_TRACE'}
    Set-KRCalibrationHostStage $script:Host 'FIXTURE_ORACLE_QUERY'
    $script:BlockedBaseline=Wait-Fixture $false;if(-not $script:BlockedBaseline.resumed){throw 'INVALID:FIXTURE_NOT_UNDER_TEST'}
    Set-KRCalibrationHostStage $script:Host 'BLOCKED_HOLD'
    $holdStart=(Get-CandidateState).elapsed
    for($probe=1;$probe -le 20;$probe++){
        if($script:ServiceConnections -ne $script:ConnectionBaseline){throw 'INVALID:ENFORCEMENT_SERVICE_RESTARTED'}
        $candidate=Get-CandidateState;$fixtureNow=Get-FixtureState;Assert-KRHold $candidate $script:Revision $script:PositiveFixtureTaps $fixtureNow;Assert-KRIndependentFixtureBlock $script:BlockedBaseline $fixtureNow
        Invoke-FixtureTap $script:BlockedBaseline;$script:BlockedTaps=$probe;Start-Sleep -Milliseconds 500
        $fixtureAfter=Get-FixtureState;$candidate=Get-CandidateState;Assert-KRIndependentFixtureBlock $script:BlockedBaseline $fixtureAfter;Assert-KRHold $candidate $script:Revision $script:PositiveFixtureTaps $fixtureAfter
        $script:HoldMillis=[long]$candidate.elapsed-$holdStart
    }
    if($script:HoldMillis -lt 10000){$candidate=Wait-Candidate {param($s)$fixtureNow=Get-FixtureState;Assert-KRHold $s $script:Revision $script:PositiveFixtureTaps $fixtureNow;Assert-KRIndependentFixtureBlock $script:BlockedBaseline $fixtureNow;$script:HoldMillis=[long]$s.elapsed-$holdStart;return $script:HoldMillis -ge 10000} 3 'INVALID:AUTOMATED_HOLD_TOO_SHORT'}
    Set-KRCalibrationHostStage $script:Host 'POST_HOLD_PERMISSION_VERIFICATION'
    $postHold=Get-CandidateState;Assert-KRHealth $postHold
    $postHoldDevice=Read-CalibrationDevice;Assert-SameConfiguration $script:TransportDevice $postHoldDevice
    Assert-CalibrationPermissionVerification $postHoldDevice $postHold $true
    $script:BlockedControl=$true;$script:ServiceContinuous=($script:ServiceConnections -eq $script:ConnectionBaseline)
    Set-KRCalibrationHostStage $script:Host 'OWNER_PROMPT'
    $script:PhysicalAgreement=Read-PhysicalAgreement
    if($script:PhysicalAgreement -eq 'FAIL'){throw 'FAIL:PHYSICAL_ORACLE_DISAGREEMENT'};if($script:PhysicalAgreement -ne 'PASS'){throw 'INVALID:PHYSICAL_OBSERVATION_UNCERTAIN'}
    $script:Status='PENDING_SUCCESS';$script:Reason='CONTROLS_PASSED_PENDING_CLEANUP'
}catch{
    Set-KRCalibrationHostFailure $script:Host $_
    $message=$script:Host.PrimaryReason
    $parts=$message.Split(':');$script:Status=$parts[0];$script:Reason=$parts[1]
}finally{
    if(Test-Path -LiteralPath $runDirectory){
        if($script:LabReady){
            Set-KRCalibrationCleanupStatus $script:Host 'IN_PROGRESS'
            try{Invoke-Cleanup;Set-KRCalibrationCleanupStatus $script:Host $(if($script:CleanupVerified){'VERIFIED'}else{'FAILED'})}
            catch{
                Set-KRCalibrationCleanupFailure $script:Host $_ ($script:Status -ne 'PENDING_SUCCESS')
                if($script:Status -eq 'PENDING_SUCCESS'){
                    $script:Status='FAIL';$script:Reason='CLEANUP_NOT_VERIFIED'
                }
            }
        }else{Set-KRCalibrationCleanupStatus $script:Host 'NOT_REQUIRED'}
        if($script:Status -eq 'PENDING_SUCCESS'){
            $script:Status=Get-KROracleCalibrationVerdict $script:PositiveControl $script:BlockedControl $script:ServiceContinuous $script:PhysicalAgreement $script:CleanupVerified 0
            $script:Reason=$(if($script:Status -eq 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY'){'COMPLETED'}else{'VERDICT_REJECTED'})
            $script:Host.HostStage=$(if($script:Status -eq 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY'){'COMPLETED'}else{$script:Host.CurrentStage})
            $script:Host.ExceptionClass='NONE';$script:Host.PrimaryReason=$script:Status+':'+$script:Reason
        }
        function New-CalibrationSummary{
          [PSCustomObject]@{
            Protocol='KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION';Status=$script:Status;Reason=$script:Reason;SourceCommit=$(if($null -eq $script:Bundle){$null}else{$script:Bundle.sourceCommit})
            CandidateSha256=$(if($null -eq $script:Bundle){$null}else{$script:Bundle.candidateSha256});FixtureSha256=$(if($null -eq $script:Bundle){$null}else{$script:Bundle.fixtureSha256})
            TransportEvidenceProtocol=$(if($null -eq $script:TransportSummary){$null}else{$script:TransportSummary.Protocol});StartedUtc=$startedUtc;EndedUtc=[DateTime]::UtcNow.ToString('o')
            TransportDeviceEvidenceSha256=$(if($null -eq $script:TransportSummary){$null}else{$script:TransportSummary.DeviceEvidenceSha256})
            PositiveControl=$script:PositiveControl;BlockedControl=$script:BlockedControl;ServiceContinuous=$script:ServiceContinuous;PhysicalAgreement=$script:PhysicalAgreement
            PermissionVerification=$script:PermissionVerification
            CleanupVerified=$script:CleanupVerified;Revision=$script:Revision;LatencyMs=$script:LatencyMs;HoldMillis=$script:HoldMillis;InjectedBlockedTaps=$script:BlockedTaps
            CalibrationSamples=$(if($null -eq $script:LatencyMs){0}else{1});QualificationSamples=0;CandidateTelemetryCorroboratingOnly=$true
            FixtureIndependentPackageAndUid=$true;SharedState=$false;NodeTextContentAccess=$false;Screenshots=$false;NetworkChanged=$false;PermissionsChangedByRunner=$false;DestructiveAction=$false
            HostDiagnostic=Get-KRCalibrationHostDiagnostic $script:Host
          }
        }
        Set-KRCalibrationFinalizationStatus $script:Host 'IN_PROGRESS'
        try{
            Save-CalibrationOperations;Write-CalibrationJson 'permission-verification.json' $script:PermissionVerification
            Set-KRCalibrationFinalizationStatus $script:Host 'COMPLETED';Write-CalibrationJson 'summary.json' (New-CalibrationSummary)
        }catch{
            $wasComplete=$script:Status -eq 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY'
            Set-KRCalibrationFinalizationFailure $script:Host $_ (-not $wasComplete)
            if($wasComplete){
                $parts=$script:Host.PrimaryReason.Split(':');$script:Status=$parts[0];$script:Reason=$parts[1]
            }
            try{Write-CalibrationJson 'summary.json' (New-CalibrationSummary)}catch{}
        }
        Write-Host ('Evidence saved: '+$runDirectory);Write-Host ('Primary result: '+$script:Status+':'+$script:Reason)
    }
}
if($script:Status -eq 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY'){exit 0};exit 2
