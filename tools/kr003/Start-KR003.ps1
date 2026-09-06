<#
Goal: Owner-operated KR-003 focused Settings recovery diagnosis with reproducible, phase-local evidence.
Context: Run only in RecoveryDiagnostic mode from an integrity-checked Q3 bundle produced by package.mjs.
Constraints: No enforcement change, raw identity, host/network/permission change, input injection, uninstall, data clear or reboot command.
Done when: One labelled case is journalled and lab-only CLEAR releases the restriction without changing latency samples.
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

$candidatePackage = 'dev.kidremote.spike.enforcement'
$fixturePackage = 'dev.kidremote.spike.ordinary'
$candidateReceiver = "$candidatePackage/.LabControlReceiver"
$fixtureReceiver = "$fixturePackage/.FixtureReceiver"
$fixtureActivity = "$fixturePackage/.FixtureActivity"
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
$script:Manifest = $null
$script:RadioOriginal = $null
$script:RadioTouched = @()
$script:RadioRestoreStatus = 'NOT_CHANGED'
$script:RadioResults = @()
$script:FinalizationErrors = @()
$script:Recovery = $null
$script:Diagnostic = $null
$script:DiagnosticPhase = $null
$script:DiagnosticBailout = $null
$script:LabControlReady = $false
$script:StartedAt = [DateTime]::UtcNow.ToString('o')
$script:Terminal = 'INCOMPLETE'
$script:Reason = 'NOT_STARTED'

function Write-JsonFile {
    param([string]$Name, $Value)
    ConvertTo-Json -InputObject $Value -Depth 20 | Set-Content -LiteralPath (Join-Path $runDirectory $Name) -Encoding UTF8
}

function Invoke-LabAdb {
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
        if ($process.ExitCode -ne 0 -or $stderr -match 'SecurityException|Permission Denial') { throw 'INVALID:ADB_REJECTED' }
        return $stdout
    } finally { $process.Dispose() }
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
    if ($script:FixtureInstance -ge 0 -and $script:FixtureInstance -ne $snapshot.instance) { throw 'INVALID:FIXTURE_RESTARTED' }
    $script:FixtureInstance = $snapshot.instance
    $snapshot | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $runDirectory 'fixture.jsonl') -Encoding UTF8
    return $snapshot
}

function Assert-FixedSettings {
    foreach ($key in @('wifi_on','mobile_data','airplane_mode_on','auto_time','auto_time_zone','low_power')) {
        $value = (Invoke-LabAdb @('shell','settings','get','global',$key)).Trim()
        if ($value -notmatch '^[0-9]+$') { $value = 'UNSPECIFIED' }
        if ($value -cne $script:Device.$key) { throw 'INVALID:DEVICE_CONFIGURATION_CHANGED' }
    }
}

function Wait-RadioFlag {
    param([string]$Key, [string]$Expected)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        $actual = (Invoke-LabAdb @('shell','settings','get','global',$Key)).Trim()
        if ($actual -ceq $Expected) { return }
        Start-Sleep -Milliseconds 250
    } while ($watch.Elapsed.TotalSeconds -lt 8)
    throw 'INVALID:RADIO_SETTING_NOT_CONFIRMED'
}

function Enter-OfflineNetwork {
    # Calling the runner with -OfflineNetwork explicitly opts into this reversible device action.
    if ($script:Device.wifi_on -notin @('0','1') -or $script:Device.mobile_data -notin @('0','1')) { throw 'INVALID:RADIO_INITIAL_STATE_UNKNOWN' }
    $script:RadioOriginal = [PSCustomObject]@{wifi_on=$script:Device.wifi_on;mobile_data=$script:Device.mobile_data}
    Write-JsonFile 'network-original.json' $script:RadioOriginal
    foreach ($pair in @(@('wifi_on','wifi'),@('mobile_data','data'))) {
        if ($script:RadioOriginal.($pair[0]) -eq '1') {
            # Journal before changing anything, including a partially failed command.
            $script:RadioTouched += $pair[0]
            Write-JsonFile 'network-touched.json' @($script:RadioTouched)
            $null = Invoke-LabAdb @('shell','svc',$pair[1],'disable')
            Wait-RadioFlag -Key $pair[0] -Expected '0'
        }
    }
    $script:Device = Read-DeviceConfiguration
}

function Restore-Network {
    $script:RadioResults = @()
    if ($null -eq $script:RadioOriginal) { return }
    foreach ($pair in @(@('wifi_on','wifi'),@('mobile_data','data'))) {
        $result = [PSCustomObject]@{ Setting=$pair[0]; Original=$script:RadioOriginal.($pair[0]); Changed=($pair[0] -in $script:RadioTouched); Observed='UNSPECIFIED'; Status='UNVERIFIED'; AtUtc=$null }
        try {
            if ($result.Changed) {
                $null = Invoke-LabAdb @('shell','svc',$pair[1],'enable')
                Wait-RadioFlag -Key $pair[0] -Expected '1'
            }
            $flag = (Invoke-LabAdb @('shell','settings','get','global',$pair[0])).Trim()
            if ($flag -match '^[01]$') { $result.Observed=$flag }
            $result.Status = if ($result.Observed -ceq $result.Original) { 'VERIFIED' } else { 'MISMATCH' }
        } catch { $result.Status='RESTORE_OR_READ_FAILED' }
        finally {
            $result.AtUtc=[DateTime]::UtcNow.ToString('o')
            $script:RadioResults += $result
        }
    }
    $script:RadioRestoreStatus = if (@($script:RadioResults | Where-Object { $_.Status -ne 'VERIFIED' }).Count) { 'RESTORE_FAILED_OWNER_ACTION_REQUIRED' } else { 'RESTORED_AND_FLAGS_VERIFIED' }
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
    param([string]$Prompt, [scriptblock]$Poll, [scriptblock]$OnObserved)
    Check-EarlyStop
    Write-Host $Prompt -ForegroundColor Cyan
    Write-Host '[P] usable/success  [F] blocked/failure  [I] invalid/uncertain  [Q] stop and run cleanup'
    while ($true) {
        if (-not [Console]::KeyAvailable) {
            if ($null -ne $Poll) { & $Poll | Out-Null }
            Start-Sleep -Milliseconds 100
            continue
        }
        $key = [Console]::ReadKey($true).KeyChar.ToString().ToUpperInvariant()
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
            '"Attempt","Phase","StartedUtc","EndedUtc","Revision","Observer","Automated","LatencyMs","InternalSampleCount","HoldMillis","Reason"' | Set-Content -LiteralPath (Join-Path $runDirectory 'attempts.csv') -Encoding UTF8
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
    if (-not $RecoveryDiagnostic -or -not $script:LabControlReady) { return }
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
    param([int]$Attempt, [switch]$Calibration)
    $script:CurrentRow = [PSCustomObject]@{
        Attempt = $Attempt; Phase = $(if ($Calibration) { 'CALIBRATION' } else { 'QUALIFICATION' })
        StartedUtc = [DateTime]::UtcNow.ToString('o'); EndedUtc = $null
        Revision = $null; Observer = 'UNRECORDED'; Automated = 'UNRECORDED'
        LatencyMs = $null; InternalSampleCount = $null; HoldMillis = $null; Reason = $null
    }
    Save-Progress
    Assert-FixedSettings
    Clear-ToOrdinary
    $before = Get-LabState
    Assert-KRHealth $before
    $fixture = Get-FixtureState
    $armed = Get-LabState 'ARM'
    $revision = [long]$armed.revision
    $script:CurrentRow.Revision = $revision
    Save-Progress
    if (-not $armed.armed -or $armed.remaining -ne 10000 -or $revision -le $script:LastRevision) { throw 'FAIL:FRESH_ARM_FAILED' }
    $script:LastRevision = $revision
    Write-Host ("Expiry {0}: watch the device. F/I/Q can stop at any time." -f $Attempt)
    $attached = Wait-LabCondition -TimeoutSeconds 22 -FailureCode 'FAIL:NO_ATTACHMENT' -Condition {
        param($s)
        Assert-KRHealth $s
        if ($s.revision -ne $revision) { throw 'FAIL:REVISION_CHANGED' }
        if ($s.eligibilityLost) { throw 'INVALID:ELIGIBILITY_INTERRUPTED' }
        if (-not $s.attached -and $s.elapsed - $armed.elapsed -ge 20000) { throw 'FAIL:NO_ATTACHMENT' }
        return $s.attached -and $s.sampledRevision -eq $revision -and $s.restriction
    }
    $latency = Get-KRPairedLatency -Snapshot $attached -Revision $revision -Before @($before.samples)
    if (-not $script:AttachmentRevisions.ContainsKey([string]$revision)) { throw 'INVALID:MISSING_ATTACHMENT_TRACE' }
    $script:CurrentRow.LatencyMs = $latency
    $script:CurrentRow.InternalSampleCount = $attached.sampleCount
    $null = Wait-FixtureFocus -Focused $false
    $startHold = (Get-LabState).elapsed
    do {
        Check-EarlyStop
        $snapshot = Get-LabState
        $fixtureNow = Get-FixtureState
        Assert-KRHold -Snapshot $snapshot -Revision $revision -FixtureTaps $fixture.taps -FixtureState $fixtureNow
        $script:CurrentRow.HoldMillis = $snapshot.elapsed - $startHold
        Start-Sleep -Milliseconds 250
    } while ($script:CurrentRow.HoldMillis -lt 10000)
    $script:CurrentRow.Automated = 'PASS'
    Save-Progress
    $script:CurrentRow.Observer = Read-Result 'Did the restriction stay visibly continuous for the entire 10 seconds, with no flicker or ordinary use?' -OnObserved {
        param($result)
        $script:CurrentRow.Observer=$result
        Save-Progress
    }
    # Check again after the owner response; do not trust a stale pre-prompt sample.
    $snapshot = Get-LabState
    Assert-KRHold -Snapshot $snapshot -Revision $revision -FixtureTaps $fixture.taps -FixtureState (Get-FixtureState)
    $script:CurrentRow.EndedUtc = [DateTime]::UtcNow.ToString('o')
    if ($Calibration) {
        $script:Calibration = $script:CurrentRow
        Write-JsonFile 'calibration.json' $script:Calibration
    } else { $script:Rows += $script:CurrentRow }
    $script:CurrentRow = $null
    Save-Progress
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
    if ($null -ne $script:Diagnostic) { Write-JsonFile 'recovery-diagnostic.json' $script:Diagnostic }
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
    if ($null -ne $PhysicalResult) {
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
    $start=Get-LabState
    Assert-KRHealth $start
    if (-not $start.restriction -or -not $start.attached -or $start.disposition -ne 'ORDINARY_APP') {
        throw 'INVALID:DIAGNOSTIC_START_NOT_BLOCKED'
    }
    $script:Diagnostic=[PSCustomObject]@{
        Schema=1; Protocol='KR003-Q3-RECOVERY-DIAGNOSTIC'; StartedUtc=[DateTime]::UtcNow.ToString('o'); EndedUtc=$null
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

    Start-DiagnosticPhase 'DIGITAL_WELLBEING_ATTEMPT'
    $digital=Read-DiagnosticResult 'DIGITAL_WELLBEING_ATTEMPT: from Settings, tap Digital Wellbeing & parental controls ONCE. P=destination usable, F=blocked/restriction returned, I=uncertain. Do not try other destinations.' -Poll { Poll-DiagnosticPhase } -OnObserved {
        param($result)
        $script:DiagnosticPhase.PhysicalResult=$result
        $script:DiagnosticPhase.PhysicalObservedUtc=[DateTime]::UtcNow.ToString('o')
        Save-Diagnostic
    }
    Complete-DiagnosticPhase $digital

    $beforeRecovery=Get-LabState
    if (-not $beforeRecovery.restriction -or -not $beforeRecovery.attached) {
        Start-DiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT'
        $script:DiagnosticPhase.PhysicalResult='INVALID'
        $script:DiagnosticPhase.PhysicalObservedUtc=[DateTime]::UtcNow.ToString('o')
        $script:DiagnosticPhase.Reason='OVERLAY_NOT_AVAILABLE_AFTER_DESTINATION'
        Complete-DiagnosticPhase 'INVALID' 1
    } else {
        Start-DiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT'
        $recovery=Read-DiagnosticResult 'RECOVERY_BUTTON_ATTEMPT: tap the overlay Open device settings button ONCE. P=top-level Settings becomes usable, F=restriction remains/no usable recovery, I=uncertain.' -Poll { Poll-DiagnosticPhase } -OnObserved {
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
    $invalid=@($script:Diagnostic.Phases | Where-Object { $_.Name -ne 'POST_RECOVERY_STATE' -and $_.PhysicalResult -eq 'INVALID' }).Count
    $softwareInvalid=@($script:Diagnostic.Phases | Where-Object { $_.Oracle -like 'INVALID_*' }).Count
    $fail=@($script:Diagnostic.Phases | Where-Object { $_.PhysicalResult -eq 'FAIL' }).Count
    $script:Diagnostic.Reason=if ($softwareInvalid) { 'SOFTWARE_INVALID_RECORDED' } elseif ($invalid) { 'PHYSICAL_INVALID_RECORDED' } elseif ($fail) { 'PHYSICAL_FAILURE_RECORDED' } else { 'PHYSICAL_PASS_RECORDED' }
    $script:Diagnostic.EndedUtc=[DateTime]::UtcNow.ToString('o')
    Save-Diagnostic
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
        Manufacturer = 'ro.product.manufacturer'; Model = 'ro.product.model'; Codename = 'ro.product.device'
        Android = 'ro.build.version.release'; Api = 'ro.build.version.sdk'; Patch = 'ro.build.version.security_patch'
        BuildFingerprint = 'ro.build.fingerprint'
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
    $record['MiuiOwnerSupplied'] = 'MIUI Global 12.0.3'
    $record['OemBatterySettings'] = 'UNSPECIFIED'
    $record['Launcher'] = 'UNSPECIFIED'
    $record['GooglePlaySystem'] = 'UNSPECIFIED'
    $record['User'] = (Invoke-LabAdb @('shell','am','get-current-user')).Trim()
    if ($record['User'] -notmatch '^\d+$') { throw 'INVALID:ANDROID_USER_UNKNOWN' }
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
        ('Valid paired qualification observations: ' + $Summary.ValidPairedObservations + '/100.')
        ('Internal paired statistics: ' + ($Summary.InternalPairedStatistics | ConvertTo-Json -Compress))
        ('Focused diagnostic result: ' + $Summary.DiagnosticResult + '; reason: ' + $Summary.DiagnosticReason)
        ('Lab-only bailout: ' + $Summary.DiagnosticBailoutStatus + '; never consumer recovery evidence.')
        ('Network restoration: ' + $Summary.NetworkRestoration)
        ('Finalization errors: ' + ($script:FinalizationErrors -join ', '))
        'Calibration, Home and recovery observations are separate; they are not extra qualification samples.'
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
    if ($RecoveryDiagnostic -and $script:LabControlReady) {
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
    Invoke-FinalStep 'RECOVERY_REPORT' {
        if ($null -ne $script:Recovery) {
            if ($null -eq $script:Recovery.Reason -and $script:Reason -ne 'COMPLETED') { $script:Recovery.Reason=$script:Reason }
            $script:Recovery.EndedUtc=[DateTime]::UtcNow.ToString('o')
            Save-Recovery
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
    }
    Invoke-FinalStep 'STATISTICS' {
        $validRows = @(Get-KRValidRows -Rows @($script:Rows))
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
    if ($script:Bundle.schema -ne 1 -or $script:Bundle.protocol -ne 'KR003-Q3-RECOVERY-DIAGNOSTIC' -or -not $script:Bundle.diagnosticOnly) { throw 'INVALID:BUNDLE_SCHEMA' }
    if (-not $RecoveryDiagnostic -or $CalibrationOnly -or $OfflineNetwork) { throw 'INVALID:DIAGNOSTIC_MODE_REQUIRED' }
    foreach ($entry in $script:Bundle.files) {
        if ($entry.name -notmatch '^[A-Za-z0-9_.-]+$') { throw 'INVALID:BUNDLE_PATH' }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $entry.name)).Hash.ToLowerInvariant() -ne $entry.sha256) { throw 'INVALID:BUNDLE_INTEGRITY' }
    }
    $script:Manifest = [PSCustomObject]@{ Schema = 1; RunId = $runId; StartedUtc = $script:StartedAt; EndedUtc = $null; Bundle = $script:Bundle; Device = $null; InitialDevice = $null; OfflineNetworkRequested = $false; OfflineOwnerConfirmed = $false; CalibrationOnly = $false; RecoveryDiagnostic = $true; PhysicalRun = $true }
    Write-JsonFile 'manifest.json' $script:Manifest
    if ((Invoke-LabAdb @('get-state')).Trim() -ne 'device') { throw 'INVALID:DEVICE_UNAVAILABLE' }
    $script:Device = Read-DeviceConfiguration
    $script:Manifest.Device = $script:Device
    $script:Manifest.InitialDevice = $script:Device
    Write-JsonFile 'manifest.json' $script:Manifest
    if ($script:Device.Codename -ne 'dipper' -or $script:Device.Api -ne '29') { throw 'INVALID:DEVICE_CONFIGURATION_CHANGED' }
    Verify-InstalledApk -Package $candidatePackage -File 'candidate.apk' -Hash $script:Bundle.candidateSha256
    Verify-InstalledApk -Package $fixturePackage -File 'ordinary-fixture.apk' -Hash $script:Bundle.fixtureSha256
    $null = Invoke-LabAdb @('shell','am','start','-n',"$candidatePackage/.MainActivity")
    $prior = Get-LabState
    $script:LabControlReady=$true
    Write-JsonFile 'prior-metrics.json' $prior
    $null = Get-LabState 'CLEAR'
    $ready = Wait-LabCondition -Condition { param($s) $s.usage -and $s.accessibility -and $s.heartbeat -and $s.eligible -and -not $s.uncertain } -FailureCode 'INVALID:MANUAL_PERMISSION_OR_UNLOCK_SETUP_REQUIRED'
    Assert-KRHealth $ready
    Write-JsonFile 'manifest.json' $script:Manifest
    Invoke-Expiry -Attempt 0 -Calibration
    Invoke-FocusedRecoveryDiagnostic
    $script:Terminal='DIAGNOSTIC_COMPLETED_ONLY'
    $script:Reason=$script:Diagnostic.Reason
    $endDevice = Read-DeviceConfiguration
    Write-JsonFile 'end-device.json' $endDevice
    if (($endDevice | ConvertTo-Json -Compress) -cne ($script:Device | ConvertTo-Json -Compress)) { throw 'INVALID:DEVICE_CONFIGURATION_CHANGED' }
    Verify-InstalledApk -Package $candidatePackage -File 'candidate.apk' -Hash $script:Bundle.candidateSha256 -NoInstall
    Verify-InstalledApk -Package $fixturePackage -File 'ordinary-fixture.apk' -Hash $script:Bundle.fixtureSha256 -NoInstall
} catch {
    $message = $_.Exception.Message
    if ($message -notmatch '^(FAIL|INVALID|INTERRUPTED):[A-Z0-9_]+$') { $message = 'INVALID:HOST_EXCEPTION' }
    $parts = $message.Split(':')
    $script:Terminal = $parts[0]
    $script:Reason = $parts[1]
    if ($null -ne $script:CurrentRow) {
        if ($script:Reason.StartsWith('OBSERVER')) { $script:CurrentRow.Observer = $script:Terminal }
        else { $script:CurrentRow.Automated = $script:Terminal }
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

# Machine callers must not interpret a stopped or online-only run as offline qualification.
if ($script:Terminal -eq 'DIAGNOSTIC_COMPLETED_ONLY' -and $script:FinalizationErrors.Count -eq 0 -and $null -ne $script:DiagnosticBailout -and $script:DiagnosticBailout.Status -eq 'VERIFIED') { exit 0 }
exit 2
