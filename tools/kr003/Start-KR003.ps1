<#
Goal: KR-003 offline qualification with 100 active-oracle cycles on one calibration-approved configuration and no more than three human checkpoint sessions.
Context: The manifest binds this reusable Q7 evidence model to one exact captured device configuration and calibration PASS.
Constraints: Debug fixture input only; no raw identity, host/permission change, uninstall, data clear or reboot; reversible radio opt-in only.
Done when: The independent input/focus oracle passes 100 cycles, all three human checkpoints pass, and cleanup restores state.
#>
param(
    [string]$Adb = 'C:\platform-tools\adb.exe',
    [string]$OutputRoot = 'C:\platform-tools\kr003-qualification',
    [switch]$OfflineNetwork,
    [switch]$CalibrationOnly,
    [switch]$RecoveryDiagnostic
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'DevicePreflight.psm1') -Force

$candidatePackage = 'dev.kidremote.spike.enforcement'
$fixturePackage = 'dev.kidremote.spike.ordinary'
$candidateReceiver = "$candidatePackage/.LabControlReceiver"
$fixtureReceiver = "$fixturePackage/.FixtureReceiver"
$fixtureActivity = "$fixturePackage/.FixtureActivity"
$candidateService = "$candidatePackage/.EnforcementAccessibilityService"
$runId = 'run-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$runDirectory = Join-Path $OutputRoot $runId
$script:Request = 0L
$script:Cursor = 0L
$script:LastElapsed = -1L
$script:LastRevision = -1L
$script:Rows = @()
$script:CurrentRow = $null
$script:SafetyPassed = $false
$script:Offline = $false
$script:Calibration = $null
$script:FixtureInstance = -1L
$script:Bundle = $null
$script:Device = $null
$script:LastSnapshot = $null
$script:AttachmentRevisions = @{}
$script:ServiceConnections = 0L
$script:Manifest = $null
$script:RadioOriginal = $null
$script:RadioTouched = @()
$script:RadioRestoreStatus = 'NOT_CHANGED'
$script:RadioResults = @()
$script:NetworkCapabilities = $null
$script:NetworkOperations = @()
$script:FinalizationErrors = @()
$script:Recovery = $null
$script:Diagnostic = $null
$script:DiagnosticPhase = $null
$script:DiagnosticFileName = 'recovery-diagnostic.json'
$script:Safety = $null
$script:SafetyFileName = 'safety-incomplete.json'
$script:HumanCheckpoints = @()
$script:DiagnosticBailout = $null
$script:LabControlReady = $false
$script:StartedAt = [DateTime]::UtcNow.ToString('o')
$script:Terminal = 'INCOMPLETE'
$script:Reason = 'NOT_STARTED'
$script:RequiredPermissionsEstablished = $false

function Write-JsonFile {
    param([string]$Name, $Value)
    ConvertTo-Json -InputObject $Value -Depth 20 | Set-Content -LiteralPath (Join-Path $runDirectory $Name) -Encoding UTF8
}

function Invoke-LabAdbResult {
    param([string[]]$Arguments)
    # Raw stdout/stderr may contain shell diagnostics. Keep it in memory and never export it.
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName = $Adb
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.CreateNoWindow = $true
    # All call sites use fixed commands and validated paths. Quote each Windows argument.
    $quoted = foreach ($argument in $Arguments) {
        if ($argument.Contains('"') -or $argument.Contains([string][char]13) -or $argument.Contains([string][char]10) -or $argument.EndsWith('\')) { throw 'INVALID:ADB_ARGUMENT' }
        '"' + $argument + '"'
    }
    $process.StartInfo.Arguments = $quoted -join ' '
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            throw 'INVALID:ADB_TIMEOUT'
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $stderrClass=if($stderr -match 'SecurityException'){'SECURITY_EXCEPTION'}elseif($stderr -match 'Permission Denial'){'PERMISSION_DENIAL'}elseif([string]::IsNullOrWhiteSpace($stderr)){'NONE'}else{'OTHER'}
        return [PSCustomObject]@{Stdout=$stdout;ExitCode=[int]$process.ExitCode;StderrClass=$stderrClass}
    } finally { $process.Dispose() }
}

function Invoke-LabAdb {
    param([string[]]$Arguments)
    $result=Invoke-LabAdbResult -Arguments $Arguments
    if ($result.ExitCode -ne 0 -or $result.StderrClass -in @('SECURITY_EXCEPTION','PERMISSION_DENIAL')) { throw 'INVALID:ADB_REJECTED' }
    return $result.Stdout
}

function Add-NetworkOperation {
    param([string]$Operation,[string]$Phase,[string]$Result,[int]$ExitCode,[string]$StderrClass)
    $allowed=@('PROBE_WIFI_CAPABILITY','PROBE_MOBILE_DATA_CAPABILITY','DISABLE_WIFI','DISABLE_MOBILE_DATA','VERIFY_WIFI_OFF','VERIFY_MOBILE_DATA_OFF','RESTORE_WIFI','RESTORE_MOBILE_DATA','VERIFY_WIFI_RESTORED','VERIFY_MOBILE_DATA_RESTORED')
    if($Operation -notin $allowed -or $Phase -notin @('PREFLIGHT','ISOLATION','FINALIZATION') -or
        $Result -notin @('ACCEPTED','REJECTED','TIMEOUT') -or
        $StderrClass -notin @('NONE','SECURITY_EXCEPTION','PERMISSION_DENIAL','OTHER','UNAVAILABLE')) { throw 'INVALID:NETWORK_OPERATION_SCHEMA' }
    $script:NetworkOperations += [PSCustomObject]@{
        Sequence=$script:NetworkOperations.Count + 1; Operation=$Operation; Phase=$Phase; Result=$Result
        ExitCode=$ExitCode; StderrClass=$StderrClass; AtUtc=[DateTime]::UtcNow.ToString('o')
    }
    Write-JsonFile 'network-operations.json' @($script:NetworkOperations)
}

function Invoke-NetworkAdb {
    param([string[]]$Arguments,[string]$Operation,[string]$Phase,[int[]]$AcceptedExitCodes=@(0))
    try { $result=Invoke-LabAdbResult -Arguments $Arguments } catch {
        if($_.Exception.Message -eq 'INVALID:ADB_TIMEOUT') { Add-NetworkOperation $Operation $Phase 'TIMEOUT' -1 'UNAVAILABLE' }
        throw
    }
    $accepted=$result.ExitCode -in $AcceptedExitCodes -and $result.StderrClass -notin @('SECURITY_EXCEPTION','PERMISSION_DENIAL')
    Add-NetworkOperation $Operation $Phase $(if($accepted){'ACCEPTED'}else{'REJECTED'}) $result.ExitCode $result.StderrClass
    if(-not $accepted) { throw 'INVALID:ADB_REJECTED' }
    return $result
}

function Get-NetworkCapabilities {
    $wifiProbe=Invoke-NetworkAdb @('shell','pm','has-feature','android.hardware.wifi') 'PROBE_WIFI_CAPABILITY' 'PREFLIGHT' @(0,1)
    $mobileProbe=Invoke-NetworkAdb @('shell','pm','has-feature','android.hardware.telephony.data') 'PROBE_MOBILE_DATA_CAPABILITY' 'PREFLIGHT' @(0,1)
    $capabilities=[PSCustomObject]@{
        Schema=1; Wifi=Convert-KRSystemFeatureProbe $wifiProbe; MobileData=Convert-KRSystemFeatureProbe $mobileProbe
        VerificationSource='PM_HAS_FEATURE'; AtUtc=[DateTime]::UtcNow.ToString('o')
    }
    Write-JsonFile 'network-capabilities.json' $capabilities
    if($capabilities.Wifi -eq 'UNKNOWN' -or $capabilities.MobileData -eq 'UNKNOWN') { throw 'INVALID:NETWORK_CAPABILITY_UNKNOWN' }
    return $capabilities
}

function Get-LabState {
    param([string]$Operation = 'SNAPSHOT')
    if ($Operation -notin @('SNAPSHOT','CLEAR','ARM','RESET_METRICS')) { throw 'INVALID:OPERATION' }
    $script:Request++
    $raw = Invoke-LabAdb @('shell','am','broadcast','--receiver-foreground','-n',$candidateReceiver,'--es','operation',$Operation,'--el','request',"$script:Request",'--el','after',"$script:Cursor")
    $snapshot = Convert-KRReply -Raw $raw -Request $script:Request
    if ($snapshot.schema -ne 2) { throw 'INVALID:DEBUG_SCHEMA_UPDATE_REQUIRED' }
    if ($snapshot.traceLost -or $snapshot.traceHead -lt $script:Cursor) { throw 'INVALID:TRACE_GAP_OR_PROCESS_REPLACED' }
    foreach ($entry in $snapshot.events) {
        if ($entry.sequence -ne $script:Cursor + 1) { throw 'INVALID:TRACE_SEQUENCE' }
        $entry | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $runDirectory 'trace.jsonl') -Encoding UTF8
        $script:Cursor = [long]$entry.sequence
        if ($entry.line -match ' kind=overlay_attached .* revision=(\d+)$') { $script:AttachmentRevisions[$Matches[1]] = $entry.sequence }
        if ($entry.line -match ' kind=service_connected ') { $script:ServiceConnections++ }
    }
    $snapshot | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath (Join-Path $runDirectory 'telemetry.jsonl') -Encoding UTF8
    if ($script:LastElapsed -gt $snapshot.elapsed) { throw 'FAIL:CLOCK_DISCONTINUITY' }
    $script:LastElapsed = $snapshot.elapsed
    $script:LastSnapshot = $snapshot
    return $snapshot
}

function Get-FixtureState {
    $script:Request++
    $raw = Invoke-LabAdb @('shell','am','broadcast','--receiver-foreground','-n',$fixtureReceiver,'--el','request',"$script:Request")
    $snapshot = Convert-KRReply -Raw $raw -Request $script:Request -Fixture
    if ($snapshot.schema -ne 2) { throw 'INVALID:FIXTURE_INPUT_ORACLE_SCHEMA' }
    if ($script:FixtureInstance -ge 0 -and $script:FixtureInstance -ne $snapshot.instance) { throw 'INVALID:FIXTURE_RESTARTED' }
    $script:FixtureInstance = $snapshot.instance
    $snapshot | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $runDirectory 'fixture.jsonl') -Encoding UTF8
    return $snapshot
}

function Save-HumanCheckpoints {
    Write-JsonFile 'human-checkpoints.json' @($script:HumanCheckpoints)
}

function Add-HumanCheckpoint {
    param([string]$Name, [string]$Result, [string]$Evidence)
    if ($Name -notin @('PREFLIGHT_NORMAL_PASS','PREFLIGHT_NEGATIVE_CONTROL','POST_RUN_SAFETY')) { throw 'INVALID:HUMAN_CHECKPOINT_NAME' }
    if ($Result -notin @('PASS','FAIL','INVALID')) { throw 'INVALID:HUMAN_CHECKPOINT_RESULT' }
    if (@($script:HumanCheckpoints | Where-Object { $_.Name -eq $Name }).Count) { throw 'INVALID:DUPLICATE_HUMAN_CHECKPOINT' }
    $script:HumanCheckpoints += [PSCustomObject]@{
        Name=$Name; Result=$Result; Evidence=$Evidence; ObservedUtc=[DateTime]::UtcNow.ToString('o')
    }
    Save-HumanCheckpoints
}

function Invoke-FixtureProbeTap {
    param($Fixture)
    if ($Fixture.schema -ne 2 -or -not $Fixture.probeReady -or $Fixture.probeX -lt 1 -or $Fixture.probeX -gt 10000 -or
        $Fixture.probeY -lt 1 -or $Fixture.probeY -gt 10000) { throw 'INVALID:FIXTURE_INPUT_ORACLE_UNAVAILABLE' }
    $null=Invoke-LabAdb @('shell','input','tap',([string]$Fixture.probeX),([string]$Fixture.probeY))
}

function Assert-FixturePositiveControl {
    param($Before, [string]$FailureCode='INVALID:FIXTURE_POSITIVE_CONTROL_FAILED')
    if ($Before.schema -ne 2 -or -not $Before.probeReady -or -not $Before.focused -or -not $Before.resumed) { throw $FailureCode }
    Invoke-FixtureProbeTap $Before
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do {
        $after=Get-FixtureState
        if ($after.instance -ne $Before.instance) { throw 'INVALID:FIXTURE_RESTARTED' }
        if (-not $after.probeReady -or $after.probeX -ne $Before.probeX -or $after.probeY -ne $Before.probeY -or -not $after.focused -or -not $after.resumed) { throw $FailureCode }
        if ($after.taps -eq $Before.taps + 1) { return $after }
        if ($after.taps -ne $Before.taps) { throw $FailureCode }
        Start-Sleep -Milliseconds 100
    } while ($watch.Elapsed.TotalSeconds -lt 3)
    throw $FailureCode
}

function Assert-FixedSettings {
    $keys=@('airplane_mode_on','auto_time','auto_time_zone','low_power')
    if($script:NetworkCapabilities.Wifi -eq 'PRESENT'){$keys+='wifi_on'}
    if($script:NetworkCapabilities.MobileData -eq 'PRESENT'){$keys+='mobile_data'}
    foreach ($key in $keys) {
        $value = (Invoke-LabAdb @('shell','settings','get','global',$key)).Trim()
        if ($value -notmatch '^[0-9]+$') { $value = 'UNSPECIFIED' }
        if ($value -cne $script:Device.$key) { throw 'INVALID:DEVICE_CONFIGURATION_CHANGED' }
    }
}

function Assert-QualificationPermissionState {
    param($Snapshot)
    $usageOutput=Invoke-LabAdb @('shell','cmd','appops','get',$candidatePackage,'GET_USAGE_STATS')
    $servicesOutput=Invoke-LabAdb @('shell','settings','--user','current','get','secure','enabled_accessibility_services')
    $accessibilityOutput=Invoke-LabAdb @('shell','settings','--user','current','get','secure','accessibility_enabled')
    $runnerVerification=Get-KRRequiredPermissionVerification $true $usageOutput $servicesOutput $accessibilityOutput $candidateService
    $diagnostic=New-KRCalibrationPermissionDiagnostic $runnerVerification $Snapshot
    Write-JsonFile 'permission-verification.json' $diagnostic
    $failure=Get-KRRequiredPermissionFailure $diagnostic $script:RequiredPermissionsEstablished
    if ($null -ne $failure) { throw $failure }
    $script:RequiredPermissionsEstablished=$true
}

function Wait-RadioFlag {
    param([string]$Key,[string]$Expected,[string]$Operation,[string]$Phase)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        $response=Invoke-NetworkAdb @('shell','settings','get','global',$Key) $Operation $Phase
        $actual = ([string]$response.Stdout).Trim()
        if ($actual -ceq $Expected) { return }
        Start-Sleep -Milliseconds 250
    } while ($watch.Elapsed.TotalSeconds -lt 8)
    throw 'INVALID:RADIO_SETTING_NOT_CONFIRMED'
}

function Enter-OfflineNetwork {
    # Calling the runner with -OfflineNetwork explicitly opts into this reversible device action.
    $plan=@(Get-KRNetworkIsolationPlan $script:NetworkCapabilities $script:Device)
    $script:RadioOriginal = [PSCustomObject]@{
        wifi_on=($plan | Where-Object Setting -eq 'wifi_on').Initial
        mobile_data=($plan | Where-Object Setting -eq 'mobile_data').Initial
    }
    Write-JsonFile 'network-original.json' $script:RadioOriginal
    foreach ($target in $plan) {
        if ($target.Presence -eq 'PRESENT' -and $target.Initial -eq '1') {
            # Journal before changing anything, including a partially failed command.
            $script:RadioTouched += $target.Setting
            Write-JsonFile 'network-touched.json' @($script:RadioTouched)
            $operation=if($target.Setting -eq 'wifi_on'){'DISABLE_WIFI'}else{'DISABLE_MOBILE_DATA'}
            $verify=if($target.Setting -eq 'wifi_on'){'VERIFY_WIFI_OFF'}else{'VERIFY_MOBILE_DATA_OFF'}
            $null = Invoke-NetworkAdb @('shell','svc',$target.Service,'disable') $operation 'ISOLATION'
            Wait-RadioFlag $target.Setting '0' $verify 'ISOLATION'
        }
    }
    $script:Device = Read-DeviceConfiguration
}

function Restore-Network {
    $script:RadioResults = @()
    if ($null -eq $script:RadioOriginal) { return }
    $plan=@(Get-KRNetworkIsolationPlan $script:NetworkCapabilities $script:RadioOriginal)
    foreach ($target in $plan) {
        $result = [PSCustomObject]@{ Setting=$target.Setting; Presence=$target.Presence; Original=$target.Initial; Changed=($target.Setting -in $script:RadioTouched); Observed='UNSPECIFIED'; Status='UNVERIFIED'; AtUtc=$null }
        try {
            if($target.Presence -eq 'ABSENT') {
                $result.Observed='NOT_APPLICABLE';$result.Status='NOT_APPLICABLE_VERIFIED'
            } else {
                $restore=if($target.Setting -eq 'wifi_on'){'RESTORE_WIFI'}else{'RESTORE_MOBILE_DATA'}
                $verify=if($target.Setting -eq 'wifi_on'){'VERIFY_WIFI_RESTORED'}else{'VERIFY_MOBILE_DATA_RESTORED'}
                if ($result.Changed -and $result.Original -eq '1') {
                    $null = Invoke-NetworkAdb @('shell','svc',$target.Service,'enable') $restore 'FINALIZATION'
                    Wait-RadioFlag $target.Setting '1' $verify 'FINALIZATION'
                }
                $response=Invoke-NetworkAdb @('shell','settings','get','global',$target.Setting) $verify 'FINALIZATION'
                $flag = ([string]$response.Stdout).Trim()
                if ($flag -match '^[01]$') { $result.Observed=$flag }
                $result.Status = if ($result.Observed -ceq $result.Original) { 'VERIFIED' } else { 'MISMATCH' }
            }
        } catch { $result.Status='RESTORE_OR_READ_FAILED' }
        finally {
            $result.AtUtc=[DateTime]::UtcNow.ToString('o')
            $script:RadioResults += $result
        }
    }
    $script:RadioRestoreStatus = if (@($script:RadioResults | Where-Object { $_.Status -notin @('VERIFIED','NOT_APPLICABLE_VERIFIED') }).Count) { 'RESTORE_FAILED_OWNER_ACTION_REQUIRED' } else { 'RESTORED_AND_FLAGS_VERIFIED' }
}

function Open-Fixture {
    $null = Invoke-LabAdb @('shell','am','start','-n',$fixtureActivity)
}

function Wait-FixtureFocus {
    param([bool]$Focused)
    # Activity focus callbacks are asynchronous. Calibrate their arrival, not an assumed zero-delay callback.
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        Check-EarlyStop
        $fixture = Get-FixtureState
        if ($fixture.focused -eq $Focused -and (-not $Focused -or $fixture.resumed)) { return $fixture }
        Start-Sleep -Milliseconds 100
    } while ($watch.Elapsed.TotalSeconds -lt 3)
    throw 'INVALID:FIXTURE_FOCUS_ORACLE_UNAVAILABLE'
}

function Read-Result {
    param([string]$Prompt, [scriptblock]$Poll, [scriptblock]$OnObserved)
    Check-EarlyStop
    Write-Host $Prompt -ForegroundColor Cyan
    Write-Host '[P] observed success  [F] failure  [I] invalid/missed observation  [Q] stop'
    while ($true) {
        if (-not [Console]::KeyAvailable) {
            if ($null -ne $Poll) { & $Poll | Out-Null }
            Start-Sleep -Milliseconds 100
            continue
        }
        $key = [Console]::ReadKey($true).KeyChar.ToString().ToUpperInvariant()
        if ($key -eq 'P') {
            if ($null -ne $OnObserved) { & $OnObserved 'PASS' }
            return 'PASS'
        }
        if ($key -eq 'Q') {
            if ($null -ne $OnObserved) { & $OnObserved 'INTERRUPTED' }
            throw 'INTERRUPTED:OPERATOR_STOP'
        }
        if ($key -eq 'F' -or $key -eq 'I') {
            $class = if ($key -eq 'F') { 'FAIL' } else { 'INVALID' }
            if ($null -ne $OnObserved) { & $OnObserved $class }
            Write-Host 'Reason: [1] flicker  [2] disappearance/no-block  [3] escape  [4] recovery/clear  [5] missed/ineligible  [6] other'
            do { $reasonKey = [Console]::ReadKey($true).KeyChar.ToString() } while ($reasonKey -notin @('1','2','3','4','5','6'))
            throw ($class + ':OBSERVER_' + $reasonKey)
        }
    }
}

function Read-DiagnosticResult {
    param(
        [string]$Prompt,
        [scriptblock]$Poll,
        [scriptblock]$OnObserved,
        [int]$MinimumPassSeconds = 0,
        [scriptblock]$PassReady
    )
    Check-EarlyStop
    Write-Host $Prompt -ForegroundColor Cyan
    Write-Host '[P] usable/success  [F] blocked/failure  [I] invalid/uncertain  [Q] stop and run cleanup'
    $observation=[Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if (-not [Console]::KeyAvailable) {
            if ($null -ne $Poll) { & $Poll | Out-Null }
            Start-Sleep -Milliseconds 100
            continue
        }
        $key = [Console]::ReadKey($true).KeyChar.ToString().ToUpperInvariant()
        if ($key -eq 'P') {
            if ($observation.Elapsed.TotalSeconds -lt $MinimumPassSeconds -or ($null -ne $PassReady -and -not (& $PassReady))) {
                Write-Host 'Keep observing; the required stable interval/software state is not complete yet.'
                continue
            }
        }
        if ($key -in @('P','F','I')) {
            $result = switch ($key) { 'P' { 'PASS' }; 'F' { 'FAIL' }; 'I' { 'INVALID' } }
            if ($null -ne $OnObserved) { & $OnObserved $result }
            return $result
        }
        if ($key -eq 'Q') { throw 'INTERRUPTED:OPERATOR_STOP' }
    }
}

function Check-EarlyStop {
    while ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true).KeyChar.ToString().ToUpperInvariant()
        if ($key -eq 'F') { throw 'FAIL:OBSERVER_DURING_EXPIRY' }
        if ($key -eq 'I') { throw 'INVALID:OBSERVER_DURING_EXPIRY' }
        if ($key -eq 'Q') { throw 'INTERRUPTED:OPERATOR_STOP' }
        # Early P keys are discarded; success needs a response after the full observation window.
    }
}

function Wait-LabCondition {
    param([scriptblock]$Condition, [string]$FailureCode, [int]$TimeoutSeconds = 8)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        Check-EarlyStop
        $snapshot = Get-LabState
        if (& $Condition $snapshot) { return $snapshot }
        Start-Sleep -Milliseconds 250
    } while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    throw $FailureCode
}

function Save-Progress {
    $journal = @()
    if ($null -ne $script:Calibration) { $journal += $script:Calibration }
    $journal += @($script:Rows)
    if ($null -ne $script:CurrentRow -and -not [Object]::ReferenceEquals($script:CurrentRow,$script:Calibration)) { $journal += $script:CurrentRow }
    try { Write-JsonFile 'attempts.json' @($journal) } finally {
        if ($journal.Count) { $journal | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runDirectory 'attempts.csv') -Encoding UTF8 }
        else {
            '"Attempt","Phase","StartedUtc","EndedUtc","Revision","PhysicalObserver","AutomatedOracle","InputOracle","LatencyMs","InternalSampleCount","HoldMillis","InjectedBlockedTaps","PositiveControlTap","FixtureFocusGainsBaseline","Reason"' | Set-Content -LiteralPath (Join-Path $runDirectory 'attempts.csv') -Encoding UTF8
        }
    }
}

function Clear-ToOrdinary {
    $null = Get-LabState 'CLEAR'
    $null = Wait-LabCondition -Condition { param($s) -not $s.armed -and -not $s.attached -and -not $s.restriction } -FailureCode 'FAIL:CLEAR_DID_NOT_RELEASE'
    Open-Fixture
    $null = Wait-LabCondition -Condition { param($s) $s.disposition -eq 'ORDINARY_APP' } -FailureCode 'INVALID:FIXTURE_NOT_ORDINARY'
    $null = Wait-FixtureFocus -Focused $true
}

function Invoke-DiagnosticBailout {
    if (-not $script:LabControlReady) { return }
    $record = [PSCustomObject]@{
        Operation='CLEAR_LAB_TIMER_ONLY'; StartedUtc=[DateTime]::UtcNow.ToString('o'); EndedUtc=$null
        Status='STARTED'; BeforeRevision=$null; AfterRevision=$null; BeforeSampleCount=$null; AfterSampleCount=$null
        LatencySamplesPreserved=$false; RestrictionReleased=$false; AppDataCleared=$false
        Uninstalled=$false; PermissionsAltered=$false; ConsumerRecoveryEvidence=$false; Reason=$null
    }
    $script:DiagnosticBailout=$record
    Write-JsonFile 'diagnostic-bailout.json' $record
    try {
        $before = Get-LabState
        $record.BeforeRevision=[long]$before.revision
        $record.BeforeSampleCount=[long]$before.sampleCount
        $beforeSamples=@($before.samples)
        $null = Get-LabState 'CLEAR'
        $watch=[Diagnostics.Stopwatch]::StartNew()
        do {
            $after=Get-LabState
            if (-not $after.armed -and -not $after.restriction -and -not $after.attached) { break }
            Start-Sleep -Milliseconds 250
        } while ($watch.Elapsed.TotalSeconds -lt 8)
        if ($after.armed -or $after.restriction -or $after.attached) { throw 'FAIL:DIAGNOSTIC_BAILOUT_DID_NOT_RELEASE' }
        $record.AfterRevision=[long]$after.revision
        $record.AfterSampleCount=[long]$after.sampleCount
        $afterSamples=@($after.samples)
        if ($beforeSamples.Count -ne $afterSamples.Count -or (($beforeSamples -join ',') -cne ($afterSamples -join ','))) {
            throw 'FAIL:DIAGNOSTIC_BAILOUT_CHANGED_METRICS'
        }
        $record.LatencySamplesPreserved=$true
        $record.RestrictionReleased=$true
        $record.Status='VERIFIED'
    } catch {
        $record.Status='FAILED'
        $message=$_.Exception.Message
        $record.Reason=if ($message -match '^(FAIL|INVALID):[A-Z0-9_]+$') { $message } else { 'INVALID:BAILOUT_HOST_EXCEPTION' }
        throw
    } finally {
        $record.EndedUtc=[DateTime]::UtcNow.ToString('o')
        Write-JsonFile 'diagnostic-bailout.json' $record
    }
}

function Invoke-Expiry {
    param([int]$Attempt, [switch]$Calibration, [switch]$PhysicalObservation)
    $script:CurrentRow = [PSCustomObject]@{
        Attempt = $Attempt; Phase = $(if ($Calibration) { 'CALIBRATION' } else { 'QUALIFICATION' })
        StartedUtc = [DateTime]::UtcNow.ToString('o'); EndedUtc = $null
        Revision = $null; PhysicalObserver = $(if ($PhysicalObservation) { 'UNRECORDED' } else { 'NOT_SAMPLED' })
        AutomatedOracle = 'UNRECORDED'; InputOracle = 'UNRECORDED'
        LatencyMs = $null; InternalSampleCount = $null; HoldMillis = $null
        InjectedBlockedTaps = 0; PositiveControlTap = 'UNRECORDED'; FixtureFocusGainsBaseline = $null; Reason = $null
        ServiceConnectionBaseline = $script:ServiceConnections
    }
    Save-Progress
    Assert-FixedSettings
    Clear-ToOrdinary
    $before = Get-LabState
    Assert-KRHealth $before
    Assert-QualificationPermissionState $before
    $fixtureBeforeControl = Get-FixtureState
    $fixture = Assert-FixturePositiveControl -Before $fixtureBeforeControl
    $script:CurrentRow.PositiveControlTap='REACHED_FIXTURE'
    $armed = Get-LabState 'ARM'
    $revision = [long]$armed.revision
    $script:CurrentRow.Revision = $revision
    Save-Progress
    if (-not $armed.armed -or $armed.remaining -ne 10000 -or $revision -le $script:LastRevision) { throw 'FAIL:FRESH_ARM_FAILED' }
    $script:LastRevision = $revision
    if ($PhysicalObservation) { Write-Host ("Physical checkpoint expiry {0}: watch the device. F/I/Q can stop at any time." -f $Attempt) }
    else { Write-Host ("Automated expiry {0}/100" -f $Attempt) }
    $attached = Wait-LabCondition -TimeoutSeconds 22 -FailureCode 'FAIL:NO_ATTACHMENT' -Condition {
        param($s)
        Assert-KRHealth $s
        if ($script:ServiceConnections -ne $script:CurrentRow.ServiceConnectionBaseline) { throw 'INVALID:ENFORCEMENT_SERVICE_RESTARTED' }
        if ($s.revision -ne $revision) { throw 'FAIL:REVISION_CHANGED' }
        if ($s.eligibilityLost) { throw 'INVALID:ELIGIBILITY_INTERRUPTED' }
        if (-not $s.attached -and $s.elapsed - $armed.elapsed -ge 12000) {
            $unblockedFixture=Get-FixtureState
            if ($unblockedFixture.focused -and $unblockedFixture.resumed) {
                $null=Assert-FixturePositiveControl -Before $unblockedFixture -FailureCode 'INVALID:NO_BLOCK_INPUT_ORACLE_FAILED'
                throw 'FAIL:BLOCK_NEVER_APPEARED'
            }
        }
        if (-not $s.attached -and $s.elapsed - $armed.elapsed -ge 20000) { throw 'FAIL:NO_ATTACHMENT' }
        return $s.attached -and $s.sampledRevision -eq $revision -and $s.restriction
    }
    $latency = Get-KRPairedLatency -Snapshot $attached -Revision $revision -Before @($before.samples)
    if (-not $script:AttachmentRevisions.ContainsKey([string]$revision)) { throw 'INVALID:MISSING_ATTACHMENT_TRACE' }
    $script:CurrentRow.LatencyMs = $latency
    $script:CurrentRow.InternalSampleCount = $attached.sampleCount
    $blockedFixture = Wait-FixtureFocus -Focused $false
    if (-not $blockedFixture.resumed -or -not $blockedFixture.probeReady) { throw 'INVALID:FIXTURE_INPUT_ORACLE_UNAVAILABLE' }
    $script:CurrentRow.FixtureFocusGainsBaseline=[long]$blockedFixture.focusGains
    $startHold = (Get-LabState).elapsed
    for ($probe=1; $probe -le 20; $probe++) {
        Check-EarlyStop
        if ($script:ServiceConnections -ne $script:CurrentRow.ServiceConnectionBaseline) { throw 'INVALID:ENFORCEMENT_SERVICE_RESTARTED' }
        $snapshot = Get-LabState
        $fixtureNow = Get-FixtureState
        Assert-KRHold -Snapshot $snapshot -Revision $revision -FixtureTaps $fixture.taps -FixtureState $fixtureNow
        Assert-KRIndependentFixtureBlock -Baseline $blockedFixture -Current $fixtureNow
        Invoke-FixtureProbeTap $blockedFixture
        $script:CurrentRow.InjectedBlockedTaps=$probe
        Start-Sleep -Milliseconds 500
        $fixtureAfterTap=Get-FixtureState
        Assert-KRIndependentFixtureBlock -Baseline $blockedFixture -Current $fixtureAfterTap
        $snapshot=Get-LabState
        Assert-KRHold -Snapshot $snapshot -Revision $revision -FixtureTaps $fixture.taps -FixtureState $fixtureAfterTap
        $script:CurrentRow.HoldMillis = $snapshot.elapsed - $startHold
        Save-Progress
    }
    if ($script:CurrentRow.HoldMillis -lt 10000) {
        $snapshot=Wait-LabCondition -TimeoutSeconds 3 -FailureCode 'INVALID:AUTOMATED_HOLD_TOO_SHORT' -Condition {
            param($s)
            $fixtureNow=Get-FixtureState
            Assert-KRHold -Snapshot $s -Revision $revision -FixtureTaps $fixture.taps -FixtureState $fixtureNow
            Assert-KRIndependentFixtureBlock -Baseline $blockedFixture -Current $fixtureNow
            $script:CurrentRow.HoldMillis=$s.elapsed-$startHold
            return $script:CurrentRow.HoldMillis -ge 10000
        }
    }
    $script:CurrentRow.InputOracle = 'PASS'
    $script:CurrentRow.AutomatedOracle = 'PASS'
    Save-Progress
    if ($PhysicalObservation) {
        $script:CurrentRow.PhysicalObserver = Read-Result 'Did the restriction stay visibly continuous for the entire 10 seconds, with no flicker or ordinary use? This is a human checkpoint, not an automated inference.' -OnObserved {
            param($result)
            $script:CurrentRow.PhysicalObserver=$result
            Save-Progress
            if ($Calibration) {
                Add-HumanCheckpoint -Name 'PREFLIGHT_NORMAL_PASS' -Result $result -Evidence 'TEN_SECOND_VISIBLE_RESULT_PLUS_ACTIVE_FIXTURE_INPUT_DENIAL'
            }
        }
    }
    # Check again after any owner response; do not trust a stale pre-prompt sample.
    $snapshot = Get-LabState
    $fixtureFinal=Get-FixtureState
    Assert-KRHold -Snapshot $snapshot -Revision $revision -FixtureTaps $fixture.taps -FixtureState $fixtureFinal
    Assert-KRIndependentFixtureBlock -Baseline $blockedFixture -Current $fixtureFinal
    Assert-QualificationPermissionState $snapshot
    $script:CurrentRow.EndedUtc = [DateTime]::UtcNow.ToString('o')
    if ($Calibration) {
        $script:Calibration = $script:CurrentRow
        Write-JsonFile 'calibration.json' $script:Calibration
    } else { $script:Rows += $script:CurrentRow }
    $script:CurrentRow = $null
    Save-Progress
}

function Invoke-NegativeControlCheckpoint {
    $start=Get-LabState
    if (-not $start.restriction -or -not $start.attached) { throw 'INVALID:NEGATIVE_CONTROL_START_NOT_BLOCKED' }
    $beforeSamples=@($start.samples)
    $null=Get-LabState 'CLEAR'
    $released=Wait-LabCondition -Condition { param($s) -not $s.armed -and -not $s.restriction -and -not $s.attached } -FailureCode 'FAIL:NEGATIVE_CONTROL_CLEAR'
    if (($released.samples -join ',') -cne ($beforeSamples -join ',')) { throw 'FAIL:NEGATIVE_CONTROL_CHANGED_METRICS' }
    Open-Fixture
    $null=Wait-LabCondition -Condition { param($s) -not $s.restriction -and -not $s.attached -and $s.disposition -eq 'ORDINARY_APP' } -FailureCode 'INVALID:NEGATIVE_CONTROL_NOT_ORDINARY'
    $null=Wait-FixtureFocus -Focused $true
    $before=Get-FixtureState
    $after=Assert-FixturePositiveControl -Before $before -FailureCode 'FAIL:NEGATIVE_CONTROL_INPUT_NOT_DETECTED'
    $result=Read-DiagnosticResult 'HUMAN CHECKPOINT 2/3 — controlled negative: the runner deliberately cleared only the lab restriction and injected one real tap. P=overlay is absent and the fixture visibly shows ordinary use; F=still blocked/no visible response; I=uncertain.'
    Add-HumanCheckpoint -Name 'PREFLIGHT_NEGATIVE_CONTROL' -Result $result -Evidence 'LAB_CLEAR_PLUS_REAL_ADB_INPUT_REACHED_FIXTURE'
    Stop-ForSafetyResult -Result $result -Step 'NEGATIVE_CONTROL'
    if ($after.taps -ne $before.taps + 1) { throw 'FAIL:NEGATIVE_CONTROL_INPUT_NOT_DETECTED' }
}

function Invoke-RecoveryObservation {
    param([string]$Phase, [int]$CorroborationTimeoutSeconds = 8)
    $start = Get-LabState
    Assert-KRHealth $start
    if (-not $start.restriction -or -not $start.attached) { throw 'INVALID:RECOVERY_START_NOT_RESTRICTED' }
    $script:Recovery = New-KRRecoveryEvidence -Phase $Phase -Snapshot $start
    Save-Recovery
    Write-Host 'Press Home PHYSICALLY once. Watch that restriction remains. Then tap the overlay Open device settings button and verify Settings is usable.'
    $null = Read-Result 'Confirm BOTH physical Home resistance and usable designated Settings (F if either failed). Stay in Settings until the runner continues.' -Poll { Poll-Recovery } -OnObserved {
        param($result)
        $script:Recovery.PhysicalHomeAndSettings= if ($result -eq 'PASS') { 'OWNER_PASS' } else { 'OWNER_' + $result }
        $script:Recovery.OwnerConfirmedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Recovery
    }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        Poll-Recovery
        if ($script:Recovery.Oracle -eq 'CORROBORATED') { break }
        Start-Sleep -Milliseconds 250
    } while ($watch.Elapsed.TotalSeconds -lt $CorroborationTimeoutSeconds)
    if ($script:Recovery.Oracle -ne 'CORROBORATED') {
        $script:Recovery.Oracle='UNCORROBORATED'
        $script:Recovery.Reason='SETTINGS_RECOVERY_ORACLE_UNCORROBORATED'
        Save-Recovery
        throw 'INVALID:SETTINGS_RECOVERY_ORACLE_UNCORROBORATED'
    }
    Open-Fixture
    $null = Wait-LabCondition -Condition { param($s) $s.attached -and $s.restriction -and $s.disposition -eq 'ORDINARY_APP' } -FailureCode 'FAIL:REENTRY'
    $null = Read-Result 'Confirm ordinary re-entry is visibly restricted again.' -OnObserved {
        param($result)
        $script:Recovery.Reentry= if ($result -eq 'PASS') { 'OWNER_PASS' } else { 'OWNER_' + $result }
        Save-Recovery
    }
    Clear-ToOrdinary
    $beforeTap = Get-FixtureState
    Write-Host 'On the now-unblocked ordinary test surface, tap Test ordinary use once.'
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        Check-EarlyStop
        $fixture = Get-FixtureState
        if ($fixture.taps -gt $beforeTap.taps) { break }
        Start-Sleep -Milliseconds 250
    } while ($watch.Elapsed.TotalSeconds -lt 60)
    if ($fixture.taps -le $beforeTap.taps) { throw 'FAIL:CLEAR_USABILITY_NOT_CONFIRMED' }
    $script:Recovery.ClearTouch='FIXTURE_COUNTER_INCREMENT'
    $script:Recovery.EndedUtc=[DateTime]::UtcNow.ToString('o')
    Save-Recovery
}

function Save-Recovery {
    if ($null -ne $script:Recovery) { Write-JsonFile ('safety-' + $script:Recovery.Phase + '.json') $script:Recovery }
}

function Poll-Recovery {
    $snapshot = Get-LabState
    Update-KRRecoveryEvidence -Evidence $script:Recovery -Snapshot $snapshot
    $null = Get-FixtureState
    Save-Recovery
}

function Save-Diagnostic {
    if ($null -ne $script:Diagnostic) { Write-JsonFile $script:DiagnosticFileName $script:Diagnostic }
}

function Start-DiagnosticPhase {
    param([string]$Name)
    $snapshot=Get-LabState
    Assert-KRHealth $snapshot
    if (-not $snapshot.restriction) { throw 'INVALID:DIAGNOSTIC_RESTRICTION_NOT_ACTIVE' }
    $script:DiagnosticPhase=New-KRDiagnosticPhase -Name $Name -Snapshot $snapshot
    $script:Diagnostic.Phases += $script:DiagnosticPhase
    Save-Diagnostic
}

function Poll-DiagnosticPhase {
    $snapshot=Get-LabState
    Update-KRDiagnosticPhase -Evidence $script:DiagnosticPhase -Snapshot $snapshot
    $null=Get-FixtureState
    Save-Diagnostic
    return $snapshot
}

function Complete-DiagnosticPhase {
    param([AllowNull()][string]$PhysicalResult, [int]$SettleSeconds = 2)
    # Windows PowerShell 5.1 binds an explicit $null string argument as an
    # empty string. POST_RECOVERY_STATE has no physical prompt, so retain the
    # constructor's explicit UNRECORDED value instead of serializing "".
    if (-not [string]::IsNullOrEmpty($PhysicalResult)) {
        $script:DiagnosticPhase.PhysicalResult=$PhysicalResult
        $script:DiagnosticPhase.PhysicalObservedUtc=[DateTime]::UtcNow.ToString('o')
    }
    Save-Diagnostic
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do {
        $null=Poll-DiagnosticPhase
        Start-Sleep -Milliseconds 200
    } while ($watch.Elapsed.TotalSeconds -lt $SettleSeconds)
    $script:DiagnosticPhase.EndedUtc=[DateTime]::UtcNow.ToString('o')
    Save-Diagnostic
}

function Invoke-FocusedRecoveryDiagnostic {
    param([string]$OutputName = 'recovery-diagnostic.json')
    if ($OutputName -notmatch '^recovery-(calibration|final|diagnostic)\.json$') { throw 'INVALID:DIAGNOSTIC_OUTPUT_NAME' }
    $script:DiagnosticFileName=$OutputName
    $start=Get-LabState
    Assert-KRHealth $start
    if (-not $start.restriction -or -not $start.attached -or $start.disposition -ne 'ORDINARY_APP') {
        throw 'INVALID:DIAGNOSTIC_START_NOT_BLOCKED'
    }
    $script:Diagnostic=[PSCustomObject]@{
        Schema=1; Protocol=$script:Bundle.protocol; StartedUtc=[DateTime]::UtcNow.ToString('o'); EndedUtc=$null
        Revision=[long]$start.revision; Phases=@(); EqualityDiagnosticImplemented=$false
        UsesRawPackageOrComponentIdentity=$false; Result='INCOMPLETE'; Reason=$null
    }
    Save-Diagnostic

    Start-DiagnosticPhase 'SETTINGS_ROOT'
    $root=Read-DiagnosticResult 'SETTINGS_ROOT: tap Open device settings once. At the top-level Settings screen, briefly verify it responds. P=usable, F=blocked/not usable, I=uncertain.' -Poll { Poll-DiagnosticPhase } -OnObserved {
        param($result)
        $script:DiagnosticPhase.PhysicalResult=$result
        $script:DiagnosticPhase.PhysicalObservedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Diagnostic
    }
    Complete-DiagnosticPhase $root
    if ($root -ne 'PASS') {
        $script:Diagnostic.Result='PARTIAL'
        $script:Diagnostic.Reason='SETTINGS_ROOT_' + $root
        $script:Diagnostic.EndedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Diagnostic
        return
    }
    if ($script:DiagnosticPhase.Oracle -ne 'SAFE_TRANSITION_CORROBORATED') {
        $script:Diagnostic.Result='PARTIAL'
        $script:Diagnostic.Reason='SOFTWARE_INVALID_RECORDED'
        $script:Diagnostic.EndedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Diagnostic
        return
    }

    Start-DiagnosticPhase 'DIGITAL_WELLBEING_ATTEMPT'
    $digital=Read-DiagnosticResult 'DIGITAL_WELLBEING_ATTEMPT: from Settings, tap Digital Wellbeing & parental controls ONCE. P=destination usable, F=blocked/restriction returned, I=uncertain. Do not try other destinations.' -Poll { Poll-DiagnosticPhase } -OnObserved {
        param($result)
        $script:DiagnosticPhase.PhysicalResult=$result
        $script:DiagnosticPhase.PhysicalObservedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Diagnostic
    }
    Complete-DiagnosticPhase $digital
    if ($digital -ne 'FAIL') {
        $script:Diagnostic.Result='PARTIAL'
        $script:Diagnostic.Reason='DIGITAL_WELLBEING_UNEXPECTED_' + $digital
        $script:Diagnostic.EndedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Diagnostic
        return
    }
    if ($script:DiagnosticPhase.Oracle -ne 'ORDINARY_REATTACHMENT_CORROBORATED') {
        $script:Diagnostic.Result='PARTIAL'
        $script:Diagnostic.Reason='SOFTWARE_INVALID_RECORDED'
        $script:Diagnostic.EndedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Diagnostic
        return
    }

    $beforeRecovery=Get-LabState
    if (-not $beforeRecovery.restriction -or -not $beforeRecovery.attached) {
        Start-DiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT'
        $script:DiagnosticPhase.PhysicalResult='INVALID'
        $script:DiagnosticPhase.PhysicalObservedUtc=[DateTime]::UtcNow.ToString('o')
        $script:DiagnosticPhase.Reason='OVERLAY_NOT_AVAILABLE_AFTER_DESTINATION'
        Complete-DiagnosticPhase 'INVALID' 1
    } else {
        Start-DiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT'
        $recovery=Read-DiagnosticResult 'RECOVERY_BUTTON_ATTEMPT: tap the overlay Open device settings button ONCE. Do not tap again. P=top-level Settings remains usable for 10 seconds, F=restriction returns/remains or recovery is unusable, I=uncertain. The runner enables P only after a fresh safe transition remains stable for 10 seconds.' -Poll { Poll-DiagnosticPhase } -PassReady { Test-KRDiagnosticStableSafe -Evidence $script:DiagnosticPhase } -OnObserved {
            param($result)
            $script:DiagnosticPhase.PhysicalResult=$result
            $script:DiagnosticPhase.PhysicalObservedUtc=[DateTime]::UtcNow.ToString('o')
            Save-Diagnostic
        }
        Complete-DiagnosticPhase $recovery 3
    }

    Start-DiagnosticPhase 'POST_RECOVERY_STATE'
    Complete-DiagnosticPhase $null 2
    $script:DiagnosticPhase.Reason='AUTOMATED_STATE_ONLY_NO_PHYSICAL_PROMPT'
    $script:Diagnostic.Result='EVIDENCE_CAPTURED'
    $script:Diagnostic.Reason=Get-KRFocusedDiagnosticReason -Phases @($script:Diagnostic.Phases)
    $script:Diagnostic.EndedUtc=[DateTime]::UtcNow.ToString('o')
    Save-Diagnostic
}

function Save-Safety {
    if ($null -ne $script:Safety) { Write-JsonFile $script:SafetyFileName $script:Safety }
}

function Poll-SafetyHold {
    $snapshot=Get-LabState
    Assert-KRHold -Snapshot $snapshot -Revision $script:Safety.Revision -FixtureTaps $script:Safety.FixtureTaps -FixtureState (Get-FixtureState)
    $script:Safety.LastElapsed=[long]$snapshot.elapsed
    $script:Safety.HoldOracle='RESTRICTION_HELD'
    Save-Safety
    return $snapshot
}

function Stop-ForSafetyResult {
    param([string]$Result, [string]$Step)
    if ($Result -eq 'PASS') { return }
    $class=if ($Result -eq 'FAIL') { 'FAIL' } else { 'INVALID' }
    throw ($class + ':SAFETY_' + $Step)
}

function Invoke-QualificationSafetyCheckpoint {
    param([ValidateSet('calibration','final')][string]$Phase)
    $start=Get-LabState
    Assert-KRHealth $start
    if (-not $start.restriction -or -not $start.attached -or $start.disposition -ne 'ORDINARY_APP') {
        throw ('INVALID:SAFETY_' + $Phase.ToUpperInvariant() + '_START')
    }
    $fixture=Get-FixtureState
    $script:SafetyFileName='safety-' + $Phase + '.json'
    $script:Safety=[PSCustomObject]@{
        Schema=1; Protocol=$script:Bundle.protocol; Phase=$Phase; StartedUtc=[DateTime]::UtcNow.ToString('o'); EndedUtc=$null
        Revision=[long]$start.revision; StartedElapsed=[long]$start.elapsed; LastElapsed=[long]$start.elapsed
        FixtureTaps=[long]$fixture.taps; HomePhysical='UNRECORDED'; HomeObservedUtc=$null; HoldOracle='PENDING'
        FinalVisibilityPhysical='UNRECORDED'; FinalVisibilityObservedUtc=$null
        RecoveryFile=('recovery-' + $Phase + '.json'); RecoveryReason='UNRECORDED'
        ReentryPhysical='UNRECORDED'; ReentryObservedUtc=$null; ReentryOracle='PENDING'
        ClearTouch='UNRECORDED'; ClearRevision=$null; ClearSampleCount=$null
        Result='INCOMPLETE'; Reason=$null; IndependentExpirySamples=0
    }
    Save-Safety

    if ($Phase -eq 'final') {
        $visibleResult=Read-DiagnosticResult 'POST-RUN VISIBLE CHECK: watch the current restriction continuously for 10 seconds. P=no flicker/disappearance/ordinary use; F=visible failure; I=uncertain.' -Poll { Poll-SafetyHold } -MinimumPassSeconds 10 -PassReady { $script:Safety.HoldOracle -eq 'RESTRICTION_HELD' } -OnObserved {
            param($result)
            $script:Safety.FinalVisibilityPhysical=$result
            $script:Safety.FinalVisibilityObservedUtc=[DateTime]::UtcNow.ToString('o')
            Save-Safety
        }
        Stop-ForSafetyResult -Result $visibleResult -Step 'FINAL_VISIBILITY'
    }

    $homeResult=Read-DiagnosticResult 'HOME CHECK: press Home PHYSICALLY once. P=restriction remained continuously visible and Home was not usable; F=escape/flicker/disappearance; I=uncertain.' -Poll { Poll-SafetyHold } -PassReady { $script:Safety.HoldOracle -eq 'RESTRICTION_HELD' } -OnObserved {
        param($result)
        $script:Safety.HomePhysical=$result
        $script:Safety.HomeObservedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Safety
    }
    Stop-ForSafetyResult -Result $homeResult -Step ($Phase.ToUpperInvariant() + '_HOME')
    $null=Poll-SafetyHold

    Invoke-FocusedRecoveryDiagnostic -OutputName $script:Safety.RecoveryFile
    $script:Safety.RecoveryReason=$script:Diagnostic.Reason
    Save-Safety
    if ($script:Diagnostic.Reason -ne 'PHYSICAL_PASS_RECORDED') {
        $hasPhysicalFailure=@($script:Diagnostic.Phases | Where-Object { $_.PhysicalResult -eq 'FAIL' }).Count -gt 0
        $hasPhysicalInvalid=@($script:Diagnostic.Phases | Where-Object { $_.PhysicalResult -eq 'INVALID' }).Count -gt 0
        $class=if ($hasPhysicalFailure -or $script:Diagnostic.Reason -in @('PHYSICAL_FAILURE_RECORDED','SOFTWARE_FAILURE_RECORDED') -or $script:Diagnostic.Reason -like 'DIGITAL_WELLBEING_UNEXPECTED_PASS') { 'FAIL' }
            elseif ($hasPhysicalInvalid -or $script:Diagnostic.Reason -in @('PHYSICAL_INVALID_RECORDED','SOFTWARE_INVALID_RECORDED')) { 'INVALID' }
            else { 'INVALID' }
        throw ($class + ':SAFETY_' + $Phase.ToUpperInvariant() + '_RECOVERY')
    }

    $fixtureBefore=Get-FixtureState
    Open-Fixture
    $reentrySnapshot=Wait-LabCondition -Condition { param($s); Assert-KRHealth $s; return $s.restriction -and $s.attached -and $s.disposition -eq 'ORDINARY_APP' } -FailureCode ('FAIL:SAFETY_' + $Phase.ToUpperInvariant() + '_REENTRY')
    $script:Safety.FixtureTaps=[long]$fixtureBefore.taps
    $script:Safety.Revision=[long]$reentrySnapshot.revision
    $script:Safety.HoldOracle='PENDING'
    Save-Safety
    $reentry=Read-DiagnosticResult 'ORDINARY RE-ENTRY: P=the disposable ordinary app is blocked again; F=ordinary use is possible/flickers; I=uncertain.' -Poll { Poll-SafetyHold } -PassReady { $script:Safety.HoldOracle -eq 'RESTRICTION_HELD' } -OnObserved {
        param($result)
        $script:Safety.ReentryPhysical=$result
        $script:Safety.ReentryObservedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Safety
    }
    Stop-ForSafetyResult -Result $reentry -Step ($Phase.ToUpperInvariant() + '_REENTRY')
    $null=Poll-SafetyHold
    $script:Safety.ReentryOracle='ORDINARY_RESTRICTION_HELD'
    Save-Safety

    $beforeClear=Get-LabState
    $beforeSamples=@($beforeClear.samples)
    $null=Get-LabState 'CLEAR'
    $released=Wait-LabCondition -Condition { param($s) -not $s.armed -and -not $s.restriction -and -not $s.attached } -FailureCode ('FAIL:SAFETY_' + $Phase.ToUpperInvariant() + '_CLEAR')
    if ($released.samples.Count -ne $beforeSamples.Count -or (($released.samples -join ',') -cne ($beforeSamples -join ','))) {
        throw ('FAIL:SAFETY_' + $Phase.ToUpperInvariant() + '_CLEAR_CHANGED_METRICS')
    }
    Open-Fixture
    $null=Wait-LabCondition -Condition { param($s) -not $s.restriction -and -not $s.attached -and $s.disposition -eq 'ORDINARY_APP' } -FailureCode ('FAIL:SAFETY_' + $Phase.ToUpperInvariant() + '_CLEAR_ORDINARY')
    $null=Wait-FixtureFocus -Focused $true
    $beforeTap=Get-FixtureState
    Write-Host 'CLEAR CHECK: injecting one real input-layer tap into the now-unblocked fixture.' -ForegroundColor Cyan
    $afterTap=Assert-FixturePositiveControl -Before $beforeTap -FailureCode ('FAIL:SAFETY_' + $Phase.ToUpperInvariant() + '_CLEAR_TOUCH')
    if ($afterTap.taps -ne $beforeTap.taps + 1) { throw ('FAIL:SAFETY_' + $Phase.ToUpperInvariant() + '_CLEAR_TOUCH') }
    $script:Safety.ClearTouch='FIXTURE_COUNTER_INCREMENT'
    $script:Safety.ClearRevision=[long]$released.revision
    $script:Safety.ClearSampleCount=[long]$released.sampleCount
    $script:Safety.Result=Get-KRSafetyCheckpointReason -HomeResult $script:Safety.HomePhysical -Recovery $script:Safety.RecoveryReason -Reentry $script:Safety.ReentryPhysical -ClearTouch $script:Safety.ClearTouch
    $script:Safety.Reason=$script:Safety.Result
    $script:Safety.EndedUtc=[DateTime]::UtcNow.ToString('o')
    Save-Safety
    if ($script:Safety.Result -ne 'PHYSICAL_PASS_RECORDED') { throw ('FAIL:SAFETY_' + $Phase.ToUpperInvariant() + '_VERDICT') }
    if ($Phase -eq 'final') {
        Add-HumanCheckpoint -Name 'POST_RUN_SAFETY' -Result 'PASS' -Evidence 'GUIDED_HOME_SETTINGS_RECOVERY_REENTRY_PLUS_AUTOMATED_CLEAR_INPUT'
    }
}

function Verify-InstalledApk {
    param([string]$Package, [string]$File, [string]$Hash, [switch]$NoInstall)
    $local = Join-Path $PSScriptRoot $File
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $local).Hash.ToLowerInvariant() -ne $Hash) { throw 'INVALID:APK_HASH' }
    if (-not $NoInstall) {
        $install = Invoke-LabAdb @('install','-r',$local)
        if ($install -notmatch '(?m)^Success\s*$') { throw 'INVALID:INSTALL_FAILED_NO_UNINSTALL_FALLBACK' }
    }
    $paths = (Invoke-LabAdb @('shell','pm','path',$Package)).Trim()
    if ($paths -notmatch '^package:(/data/app/[A-Za-z0-9_~+/=.-]+/base\.apk)$') { throw 'INVALID:INSTALLED_PATH_OR_SPLIT_APK' }
    $devicePath = $Matches[1]
    $pulled = Join-Path $runDirectory ($(if ($NoInstall) { 'final-verified-' } else { 'verified-' }) + $File)
    $null = Invoke-LabAdb @('pull',$devicePath,$pulled)
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $pulled).Hash.ToLowerInvariant() -ne $Hash) { throw 'INVALID:INSTALLED_APK_MISMATCH' }
}

function Read-DeviceConfiguration {
    $properties = [ordered]@{
        Manufacturer = 'ro.product.manufacturer'; Model = 'ro.product.model'
        Android = 'ro.build.version.release'; Api = 'ro.build.version.sdk'; Patch = 'ro.build.version.security_patch'
        BuildId = 'ro.build.id'
    }
    $record = [ordered]@{}
    foreach ($key in $properties.Keys) {
        $value = (Invoke-LabAdb @('shell','getprop',$properties[$key])).Trim()
        if ($value -notmatch '^[A-Za-z0-9_./:; +,-]{1,250}$') { $value = 'UNSPECIFIED' }
        $record[$key] = $value
    }
    foreach ($key in @('wifi_on','mobile_data','airplane_mode_on','auto_time','auto_time_zone','low_power')) {
        $value = (Invoke-LabAdb @('shell','settings','get','global',$key)).Trim()
        $record[$key] = if ($value -match '^[0-9]+$') { $value } else { 'UNSPECIFIED' }
    }
    return [PSCustomObject]$record
}

function Invoke-FinalStep {
    param([string]$Name, [scriptblock]$Action)
    try { & $Action | Out-Null } catch {
        $script:FinalizationErrors += $Name
        Write-Host ('Finalization step needs attention: ' + $Name) -ForegroundColor Yellow
    }
}

function Write-FinalSummary {
    param($Summary)
    # Fallback avoids a broken higher-level writer. An unwritable/full filesystem cannot be guaranteed recoverable.
    $Summary.FinalizationErrors=@($script:FinalizationErrors)
    try { Write-JsonFile 'summary.json' $Summary } catch {
        $script:FinalizationErrors += 'SUMMARY_JSON_PRIMARY_WRITE'
        Invoke-FinalStep 'SUMMARY_JSON_FALLBACK_WRITE' {
            $Summary.FinalizationErrors=@($script:FinalizationErrors)
            [IO.File]::WriteAllText((Join-Path $runDirectory 'summary.json'), (ConvertTo-Json -InputObject $Summary -Depth 20), (New-Object Text.UTF8Encoding($false)))
        }
    }
    $markdown = @(
        $(if ($RecoveryDiagnostic) { '# KR-003 focused recovery diagnostic result' } else { '# KR-003 qualification result' })
        ''
        ('Primary status: ' + $Summary.Status + '; reason: ' + $Summary.Reason)
        ('Valid automated active-oracle cycles: ' + $Summary.ValidPairedObservations + '/100.')
        ('Human checkpoint sessions: ' + $Summary.HumanCheckpointSessions + '/3; physical expiry observations: ' + $Summary.PhysicalExpiryObservations + '.')
        ('Internal paired statistics: ' + ($Summary.InternalPairedStatistics | ConvertTo-Json -Compress))
        ('Focused diagnostic result: ' + $Summary.DiagnosticResult + '; reason: ' + $Summary.DiagnosticReason)
        ('Lab-only bailout: ' + $Summary.DiagnosticBailoutStatus + '; never consumer recovery evidence.')
        ('Network restoration: ' + $Summary.NetworkRestoration)
        ('Finalization errors: ' + ($script:FinalizationErrors -join ', '))
        'The 100 rows are active-oracle cycles, not 100 human observations. Human checkpoints and internal latency remain separate evidence.'
        'Partial/current attempts and physical recovery responses are retained. No KR-003 closure or Play approval is implied.'
    ) -join [Environment]::NewLine
    try { $markdown | Set-Content -LiteralPath (Join-Path $runDirectory 'SUMMARY.md') -Encoding UTF8 } catch {
        $script:FinalizationErrors += 'SUMMARY_MARKDOWN_PRIMARY_WRITE'
        Invoke-FinalStep 'SUMMARY_MARKDOWN_FALLBACK_WRITE' {
            [IO.File]::WriteAllText((Join-Path $runDirectory 'SUMMARY.md'), $markdown, (New-Object Text.UTF8Encoding($false)))
        }
    }
    # Include errors from either writer, without overwriting the primary test status/reason.
    if ($script:FinalizationErrors.Count) {
        Invoke-FinalStep 'SUMMARY_ERROR_INDEX_WRITE' {
            $Summary.FinalizationErrors=@($script:FinalizationErrors)
            [IO.File]::WriteAllText((Join-Path $runDirectory 'summary.json'), (ConvertTo-Json -InputObject $Summary -Depth 20), (New-Object Text.UTF8Encoding($false)))
        }
    }
}

function Complete-LabRun {
    # No reporting failure can prevent restoration, another report attempt, or replace the primary terminal reason.
    if ($script:LabControlReady) {
        Invoke-FinalStep 'DIAGNOSTIC_BAILOUT' { Invoke-DiagnosticBailout }
        if ($null -eq $script:DiagnosticBailout -or $script:DiagnosticBailout.Status -ne 'VERIFIED') {
            $script:FinalizationErrors += 'DIAGNOSTIC_BAILOUT_UNVERIFIED'
        }
    }
    try { Restore-Network } catch {
        $script:RadioRestoreStatus='RESTORE_FAILED_OWNER_ACTION_REQUIRED'
        $script:FinalizationErrors += 'NETWORK_RESTORE'
    }
    if ($script:RadioRestoreStatus -eq 'RESTORE_FAILED_OWNER_ACTION_REQUIRED') { $script:FinalizationErrors += 'NETWORK_UNVERIFIED' }
    if (-not (Test-Path -LiteralPath $runDirectory -ErrorAction SilentlyContinue)) { return }
    Invoke-FinalStep 'NETWORK_REPORT' {
        Write-JsonFile 'network-restoration.json' ([PSCustomObject]@{Status=$script:RadioRestoreStatus; Settings=@($script:RadioResults)})
    }
    Invoke-FinalStep 'MANIFEST_REPORT' {
        if ($null -ne $script:Manifest) {
            $script:Manifest.EndedUtc=[DateTime]::UtcNow.ToString('o')
            Write-JsonFile 'manifest.json' $script:Manifest
        }
    }
    Invoke-FinalStep 'ATTEMPT_REPORT' { Save-Progress }
    Invoke-FinalStep 'HUMAN_CHECKPOINT_REPORT' { Save-HumanCheckpoints }
    Invoke-FinalStep 'RECOVERY_REPORT' {
        if ($null -ne $script:Recovery) {
            if ($null -eq $script:Recovery.Reason -and $script:Reason -ne 'COMPLETED') { $script:Recovery.Reason=$script:Reason }
            $script:Recovery.EndedUtc=[DateTime]::UtcNow.ToString('o')
            Save-Recovery
        }
    }
    Invoke-FinalStep 'SAFETY_REPORT' {
        if ($null -ne $script:Safety) {
            if ($script:Safety.Result -eq 'INCOMPLETE') {
                $script:Safety.Reason=$script:Reason
            }
            if ($null -eq $script:Safety.EndedUtc) { $script:Safety.EndedUtc=[DateTime]::UtcNow.ToString('o') }
            Save-Safety
        }
    }
    Invoke-FinalStep 'DIAGNOSTIC_REPORT' {
        if ($null -ne $script:Diagnostic) {
            if ($null -ne $script:DiagnosticPhase -and $null -eq $script:DiagnosticPhase.EndedUtc) {
                $script:DiagnosticPhase.EndedUtc=[DateTime]::UtcNow.ToString('o')
                if ($null -eq $script:DiagnosticPhase.Reason) { $script:DiagnosticPhase.Reason=$script:Reason }
            }
            if ($script:Diagnostic.Result -eq 'INCOMPLETE') { $script:Diagnostic.Result='PARTIAL' }
            if ($null -eq $script:Diagnostic.Reason) { $script:Diagnostic.Reason=$script:Reason }
            if ($null -eq $script:Diagnostic.EndedUtc) { $script:Diagnostic.EndedUtc=[DateTime]::UtcNow.ToString('o') }
            Save-Diagnostic
        }
    }
    $summary = [PSCustomObject]@{
        Status=$script:Terminal; Reason=$script:Reason; StartUtc=$script:StartedAt; EndUtc=[DateTime]::UtcNow.ToString('o')
        ValidPairedObservations=$null; InternalPairedStatistics=$null; StatisticsAvailable=$false
        CalibrationExcluded=$true; SafetyChecksPassed=$script:SafetyPassed; Offline=$script:Offline
        Kr003Complete=$false; ProductionApproved=$false; NetworkRestoration=$script:RadioRestoreStatus
        FinalizationErrors=@(); QualificationRequested=(-not $CalibrationOnly -and -not $RecoveryDiagnostic)
        RecoveryDiagnosticRequested=[bool]$RecoveryDiagnostic
        DiagnosticResult=$(if ($null -eq $script:Diagnostic) { $null } else { $script:Diagnostic.Result })
        DiagnosticReason=$(if ($null -eq $script:Diagnostic) { $null } else { $script:Diagnostic.Reason })
        DiagnosticBailoutStatus=$(if ($null -eq $script:DiagnosticBailout) { 'NOT_REQUIRED_OR_NOT_STARTED' } else { $script:DiagnosticBailout.Status })
        EvidenceModel='ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS'
        HumanCheckpointSessions=@($script:HumanCheckpoints | Where-Object { $_.Result -eq 'PASS' }).Count
        PhysicalExpiryObservations=@($script:HumanCheckpoints | Where-Object { $_.Name -in @('PREFLIGHT_NORMAL_PASS','POST_RUN_SAFETY') -and $_.Result -eq 'PASS' }).Count
    }
    Invoke-FinalStep 'STATISTICS' {
        $validRows = @(Get-KRValidAutomatedRows -Rows @($script:Rows))
        $summary.InternalPairedStatistics = Get-KRStatistics -Values @($validRows | ForEach-Object { $_.LatencyMs })
        $summary.ValidPairedObservations=$validRows.Count
        $summary.StatisticsAvailable=$true
    }
    Invoke-FinalStep 'SUMMARY_REPORT' { Write-FinalSummary $summary }
    Write-Host ('Evidence saved: ' + $runDirectory)
    Write-Host ('Primary result: ' + $script:Terminal + ':' + $script:Reason)
    Write-Host 'The agent reads this directory directly. If network restoration is unverified, preserve network-original.json for owner-assisted recovery.'
}

try {
    if ([Console]::IsInputRedirected) { throw 'INVALID:INTERACTIVE_OPERATOR_REQUIRED' }
    if (-not (Test-Path -LiteralPath $Adb)) { throw 'INVALID:ADB_MISSING' }
    New-Item -ItemType Directory -Path $runDirectory | Out-Null
    $script:Bundle = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle.json') -Raw | ConvertFrom-Json
    Assert-KRConfigurationQualificationBundle $script:Bundle
    if ($RecoveryDiagnostic -or $CalibrationOnly -or -not $OfflineNetwork) { throw 'INVALID:OFFLINE_QUALIFICATION_MODE_REQUIRED' }
    foreach ($entry in $script:Bundle.files) {
        if ($entry.name -notmatch '^[A-Za-z0-9_.-]+$') { throw 'INVALID:BUNDLE_PATH' }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $entry.name)).Hash.ToLowerInvariant() -ne $entry.sha256) { throw 'INVALID:BUNDLE_INTEGRITY' }
    }
    $script:Manifest = [PSCustomObject]@{ Schema = 1; RunId = $runId; StartedUtc = $script:StartedAt; EndedUtc = $null; Bundle = $script:Bundle; Device = $null; InitialDevice = $null; OfflineNetworkRequested = $true; OfflineOwnerConfirmed = $false; CalibrationOnly = $false; RecoveryDiagnostic = $false; PhysicalRun = $true; EvidenceModel='ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS' }
    Write-JsonFile 'manifest.json' $script:Manifest
    if ((Invoke-LabAdb @('get-state')).Trim() -ne 'device') { throw 'INVALID:DEVICE_UNAVAILABLE' }
    $script:Device = Read-DeviceConfiguration
    $script:Manifest.Device = $script:Device
    $script:Manifest.InitialDevice = $script:Device
    Write-JsonFile 'manifest.json' $script:Manifest
    Assert-KRBoundDeviceConfiguration $script:Device $script:Bundle.approvedConfiguration
    $script:NetworkCapabilities=Get-NetworkCapabilities
    Verify-InstalledApk -Package $candidatePackage -File 'candidate.apk' -Hash $script:Bundle.candidateSha256
    Verify-InstalledApk -Package $fixturePackage -File 'ordinary-fixture.apk' -Hash $script:Bundle.fixtureSha256
    $null = Invoke-LabAdb @('shell','am','start','-n',"$candidatePackage/.MainActivity")
    $prior = Get-LabState
    $script:LabControlReady=$true
    Write-JsonFile 'prior-metrics.json' $prior
    $null = Get-LabState 'CLEAR'
    $ready = Wait-LabCondition -Condition { param($s) $s.usage -and $s.accessibility -and $s.heartbeat -and $s.eligible -and -not $s.uncertain } -FailureCode 'INVALID:MANUAL_PERMISSION_OR_UNLOCK_SETUP_REQUIRED'
    Assert-KRHealth $ready
    Assert-QualificationPermissionState $ready
    Write-Host 'Temporarily disabling Wi-Fi/mobile data for this authorized offline lab run. Original radio flags are journalled and restored during finalization.'
    Enter-OfflineNetwork
    $script:Manifest.Device=$script:Device
    Assert-KRNetworkOffline $script:NetworkCapabilities $script:Device
    $offlineResult=Read-DiagnosticResult 'OFFLINE CHECK: verify every device-reported network transport is off and this lab device has no other Internet path. P=confirmed, F/I=not established.'
    if ($offlineResult -ne 'PASS') { throw 'INVALID:OFFLINE_OWNER_NOT_CONFIRMED' }
    $script:Offline=$true
    $script:Manifest.OfflineOwnerConfirmed=$true
    Write-JsonFile 'manifest.json' $script:Manifest
    $null=Get-LabState 'RESET_METRICS'
    $calibrationZero=Get-LabState
    if ($calibrationZero.sampleCount -ne 0) { throw 'INVALID:CALIBRATION_METRICS_RESET_FAILED' }
    Write-Host 'HUMAN CHECKPOINT 1/3 — normal persistent restriction and active input denial.' -ForegroundColor Cyan
    Invoke-Expiry -Attempt 0 -Calibration -PhysicalObservation
    Invoke-NegativeControlCheckpoint
    $null=Get-LabState 'RESET_METRICS'
    $zero=Get-LabState
    if ($zero.sampleCount -ne 0) { throw 'INVALID:QUALIFICATION_METRICS_RESET_FAILED' }
    for ($attempt=1; $attempt -le 100; $attempt++) {
        Invoke-Expiry -Attempt $attempt
    }
    Write-Host 'HUMAN CHECKPOINT 3/3 — post-run expiry agreement and guided Home/Settings/recovery safety route.' -ForegroundColor Cyan
    try { Invoke-QualificationSafetyCheckpoint -Phase 'final' } catch {
        if (-not @($script:HumanCheckpoints | Where-Object { $_.Name -eq 'POST_RUN_SAFETY' }).Count) {
            $checkpointResult=if ($_.Exception.Message -like 'FAIL:*') { 'FAIL' } else { 'INVALID' }
            Add-HumanCheckpoint -Name 'POST_RUN_SAFETY' -Result $checkpointResult -Evidence 'GUIDED_CHECKPOINT_STOPPED_WITH_PRESERVED_SUBSTEP_EVIDENCE'
        }
        throw
    }
    $script:SafetyPassed=$true
    $final=Get-LabState
    Assert-QualificationPermissionState $final
    Write-JsonFile 'final-metrics.json' $final
    $stats=Get-KRStatistics -Values @($script:Rows | ForEach-Object { $_.LatencyMs })
    if ($final.sampleCount -ne 100 -or $final.samples.Count -ne 100 -or
        (($final.samples -join ',') -cne (($script:Rows | ForEach-Object { $_.LatencyMs }) -join ',')) -or
        $final.p50 -ne $stats.P50 -or $final.p95 -ne $stats.P95 -or $final.max -ne $stats.Max) {
        throw 'INVALID:AGGREGATE_MISMATCH'
    }
    $endDevice = Read-DeviceConfiguration
    Write-JsonFile 'end-device.json' $endDevice
    if (($endDevice | ConvertTo-Json -Compress) -cne ($script:Device | ConvertTo-Json -Compress)) { throw 'INVALID:DEVICE_CONFIGURATION_CHANGED' }
    Verify-InstalledApk -Package $candidatePackage -File 'candidate.apk' -Hash $script:Bundle.candidateSha256 -NoInstall
    Verify-InstalledApk -Package $fixturePackage -File 'ordinary-fixture.apk' -Hash $script:Bundle.fixtureSha256 -NoInstall
    $script:Terminal=Get-KRAutomatedRunVerdict -Rows $script:Rows -HumanCheckpoints $script:HumanCheckpoints -Offline $script:Offline
    $script:Reason='COMPLETED'
} catch {
    $message = $_.Exception.Message
    if ($message -notmatch '^(FAIL|INVALID|INTERRUPTED):[A-Z0-9_]+$') { $message = 'INVALID:HOST_EXCEPTION' }
    $parts = $message.Split(':')
    $script:Terminal = $parts[0]
    $script:Reason = $parts[1]
    if ($null -ne $script:CurrentRow) {
        if ($script:Reason.StartsWith('OBSERVER')) { $script:CurrentRow.PhysicalObserver = $script:Terminal }
        else { $script:CurrentRow.AutomatedOracle = $script:Terminal }
        $script:CurrentRow.Reason = $script:Reason
        $script:CurrentRow.EndedUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-Host ("Stopped: " + $message) -ForegroundColor Yellow
} finally {
    try { Complete-LabRun } catch {
        $script:FinalizationErrors += 'UNEXPECTED_FINALIZER'
        # Last-resort independent writes still preserve the original reason, never the secondary exception text.
        $fallback = [PSCustomObject]@{ Status=$script:Terminal; Reason=$script:Reason; StatisticsAvailable=$false; FinalizationErrors=@($script:FinalizationErrors); NetworkRestoration=$script:RadioRestoreStatus; Kr003Complete=$false }
        try { [IO.File]::WriteAllText((Join-Path $runDirectory 'summary.json'), (ConvertTo-Json -InputObject $fallback -Depth 8), (New-Object Text.UTF8Encoding($false))) } catch { }
        try { [IO.File]::WriteAllText((Join-Path $runDirectory 'SUMMARY.md'), ('Primary result: ' + $script:Terminal + ':' + $script:Reason + [Environment]::NewLine + 'Unexpected finalizer defect; statistics unavailable. Preserve all artefacts.'), (New-Object Text.UTF8Encoding($false))) } catch { }
        Write-Host ('Primary result preserved: ' + $script:Terminal + ':' + $script:Reason + '. Reporting needs review.') -ForegroundColor Yellow
    }
}

# Machine callers must not interpret a stopped, online-only, cleanup-failed or reporting-failed run as qualification.
if ($script:Terminal -eq 'PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY' -and $script:Offline -and $script:SafetyPassed -and
    $script:RadioRestoreStatus -eq 'RESTORED_AND_FLAGS_VERIFIED' -and $script:FinalizationErrors.Count -eq 0 -and
    $null -ne $script:DiagnosticBailout -and $script:DiagnosticBailout.Status -eq 'VERIFIED') { exit 0 }
exit 2
