<#
Goal: Owner-operated KR-003 calibration and 100 observed expiries with reproducible evidence.
Context: Run only from an integrity-checked bundle produced by package.mjs.
Constraints: No host changes; no input injection, uninstall, data clear, permission or reboot commands; explicit radio-change opt-in only.
Done when: Every attempt is journalled; qualification requires 100 paired physical observations.
#>
param(
    [string]$Adb = 'C:\platform-tools\adb.exe',
    [string]$OutputRoot = 'C:\platform-tools\kr003-qualification',
    [switch]$OfflineNetwork
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
    foreach ($pair in @(@('wifi_on','wifi'),@('mobile_data','data'))) {
        if ($pair[0] -in $script:RadioTouched) {
            $null = Invoke-LabAdb @('shell','svc',$pair[1],'enable')
            Wait-RadioFlag -Key $pair[0] -Expected '1'
        }
    }
    if ($script:RadioTouched.Count) { $script:RadioRestoreStatus = 'RESTORED_AND_FLAGS_VERIFIED' }
}

function Open-Fixture {
    $null = Invoke-LabAdb @('shell','am','start','-n',$fixtureActivity)
}

function Read-Result {
    param([string]$Prompt)
    Check-EarlyStop
    Write-Host $Prompt -ForegroundColor Cyan
    Write-Host '[P] observed success  [F] failure  [I] invalid/missed observation  [Q] stop'
    while ($true) {
        $key = [Console]::ReadKey($true).KeyChar.ToString().ToUpperInvariant()
        if ($key -eq 'P') { return 'PASS' }
        if ($key -eq 'Q') { throw 'INTERRUPTED:OPERATOR_STOP' }
        if ($key -eq 'F' -or $key -eq 'I') {
            $class = if ($key -eq 'F') { 'FAIL' } else { 'INVALID' }
            Write-Host 'Reason: [1] flicker  [2] disappearance/no-block  [3] escape  [4] recovery/clear  [5] missed/ineligible  [6] other'
            do { $reasonKey = [Console]::ReadKey($true).KeyChar.ToString() } while ($reasonKey -notin @('1','2','3','4','5','6'))
            throw ($class + ':OBSERVER_' + $reasonKey)
        }
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
    $journal = @($script:Rows)
    if ($null -ne $script:CurrentRow) { $journal += $script:CurrentRow }
    Write-JsonFile 'attempts.json' @($journal)
    if ($journal.Count) { $journal | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runDirectory 'attempts.csv') -Encoding UTF8 }
}

function Clear-ToOrdinary {
    $null = Get-LabState 'CLEAR'
    $null = Wait-LabCondition -Condition { param($s) -not $s.armed -and -not $s.attached -and -not $s.restriction } -FailureCode 'FAIL:CLEAR_DID_NOT_RELEASE'
    Open-Fixture
    $null = Wait-LabCondition -Condition { param($s) $s.disposition -eq 'ORDINARY_APP' } -FailureCode 'INVALID:FIXTURE_NOT_ORDINARY'
    $fixture = Get-FixtureState
    if (-not $fixture.focused -or -not $fixture.resumed) { throw 'FAIL:ORDINARY_FOCUS_NOT_RESTORED' }
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
    $startHold = $attached.elapsed
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
    $script:CurrentRow.Observer = Read-Result 'Did the restriction stay visibly continuous for the entire 10 seconds, with no flicker or ordinary use?'
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
    param([string]$Phase)
    Write-Host 'Press Home PHYSICALLY once. Watch that restriction remains. Then tap the overlay Open device settings button and verify Settings is usable.'
    $null = Read-Result 'Confirm BOTH physical Home resistance and usable designated Settings (F if either failed).'
    $null = Wait-LabCondition -Condition { param($s) $s.restriction -and -not $s.attached -and $s.disposition -eq 'SAFE_SYSTEM' } -FailureCode 'FAIL:SETTINGS_RECOVERY'
    Open-Fixture
    $null = Wait-LabCondition -Condition { param($s) $s.attached -and $s.restriction -and $s.disposition -eq 'ORDINARY_APP' } -FailureCode 'FAIL:REENTRY'
    $null = Read-Result 'Confirm ordinary re-entry is visibly restricted again.'
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
    Write-JsonFile ("safety-" + $Phase + '.json') ([PSCustomObject]@{
        Phase = $Phase; ObservedUtc = [DateTime]::UtcNow.ToString('o')
        PhysicalHomeAndSettings = 'OWNER_PASS'; Reentry = 'OWNER_PASS'; ClearTouch = 'FIXTURE_COUNTER_INCREMENT'
        IndependentExpirySamples = 0
    })
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

try {
    if ([Console]::IsInputRedirected) { throw 'INVALID:INTERACTIVE_OPERATOR_REQUIRED' }
    if (-not (Test-Path -LiteralPath $Adb)) { throw 'INVALID:ADB_MISSING' }
    New-Item -ItemType Directory -Path $runDirectory | Out-Null
    $script:Bundle = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle.json') -Raw | ConvertFrom-Json
    if ($script:Bundle.schema -ne 1 -or $script:Bundle.protocol -ne 'KR003-Q1') { throw 'INVALID:BUNDLE_SCHEMA' }
    foreach ($entry in $script:Bundle.files) {
        if ($entry.name -notmatch '^[A-Za-z0-9_.-]+$') { throw 'INVALID:BUNDLE_PATH' }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $entry.name)).Hash.ToLowerInvariant() -ne $entry.sha256) { throw 'INVALID:BUNDLE_INTEGRITY' }
    }
    $script:Manifest = [PSCustomObject]@{ Schema = 1; RunId = $runId; StartedUtc = $script:StartedAt; EndedUtc = $null; Bundle = $script:Bundle; Device = $null; InitialDevice = $null; OfflineNetworkRequested = [bool]$OfflineNetwork; OfflineOwnerConfirmed = $false; PhysicalRun = $true }
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
    Write-JsonFile 'prior-metrics.json' $prior
    $null = Get-LabState 'CLEAR'
    $ready = Wait-LabCondition -Condition { param($s) $s.usage -and $s.accessibility -and $s.heartbeat -and $s.eligible -and -not $s.uncertain } -FailureCode 'INVALID:MANUAL_PERMISSION_OR_UNLOCK_SETUP_REQUIRED'
    Assert-KRHealth $ready
    if ($OfflineNetwork) {
        Write-Host 'Temporarily disabling Wi-Fi/mobile data for this authorized offline lab run; original settings will be restored on normal exit.'
        Enter-OfflineNetwork
        $script:Manifest.Device = $script:Device
    }
    if ($script:Device.wifi_on -eq '0' -and $script:Device.mobile_data -eq '0') {
        $null = Read-Result 'Wi-Fi and mobile data settings are off. Confirm this lab has no other Internet connection for this run.'
        $script:Offline = $true
    } else {
        Write-Host 'Current radios are enabled: this run can establish online performance only; offline AC-3 will remain open.' -ForegroundColor Yellow
    }
    $script:Manifest.OfflineOwnerConfirmed = $script:Offline
    Write-JsonFile 'manifest.json' $script:Manifest
    $null = Get-LabState 'RESET_METRICS'
    Invoke-Expiry -Attempt 0 -Calibration
    Invoke-RecoveryObservation -Phase 'calibration'
    $null = Get-LabState 'RESET_METRICS'
    $zero = Get-LabState
    if ($zero.sampleCount -ne 0) { throw 'INVALID:METRICS_RESET_FAILED' }
    for ($attempt = 1; $attempt -le 100; $attempt++) {
        Invoke-Expiry -Attempt $attempt
    }
    Invoke-RecoveryObservation -Phase 'final'
    $script:SafetyPassed = $true
    $final = Get-LabState
    Write-JsonFile 'final-metrics.json' $final
    $stats = Get-KRStatistics -Values @($script:Rows.LatencyMs)
    if ($final.sampleCount -ne 100 -or $final.p50 -ne $stats.P50 -or $final.p95 -ne $stats.P95 -or $final.max -ne $stats.Max) { throw 'INVALID:AGGREGATE_MISMATCH' }
    $endDevice = Read-DeviceConfiguration
    Write-JsonFile 'end-device.json' $endDevice
    if (($endDevice | ConvertTo-Json -Compress) -cne ($script:Device | ConvertTo-Json -Compress)) { throw 'INVALID:DEVICE_CONFIGURATION_CHANGED' }
    Verify-InstalledApk -Package $candidatePackage -File 'candidate.apk' -Hash $script:Bundle.candidateSha256 -NoInstall
    Verify-InstalledApk -Package $fixturePackage -File 'ordinary-fixture.apk' -Hash $script:Bundle.fixtureSha256 -NoInstall
    $script:Terminal = Get-KRRunVerdict -Rows $script:Rows -SafetyPassed $script:SafetyPassed -Offline $script:Offline
    $script:Reason = 'COMPLETED'
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
    if (Test-Path -LiteralPath $runDirectory) {
        try { Restore-Network } catch {
            $script:RadioRestoreStatus = 'RESTORE_FAILED_OWNER_ACTION_REQUIRED'
            $script:Terminal = 'INVALID'
            $script:Reason = 'RADIO_RESTORE_REQUIRES_OWNER'
            Write-Host 'Radio restoration failed. Preserve this directory; network-original.json records the settings to restore.' -ForegroundColor Yellow
        }
        if ($null -ne $script:Manifest) {
            $script:Manifest.EndedUtc = [DateTime]::UtcNow.ToString('o')
            Write-JsonFile 'manifest.json' $script:Manifest
        }
        Save-Progress
        $validRows = @($script:Rows | Where-Object { $_.Phase -eq 'QUALIFICATION' -and $_.Observer -eq 'PASS' -and $_.Automated -eq 'PASS' })
        $stats = Get-KRStatistics -Values @($validRows.LatencyMs)
        $summary = [PSCustomObject]@{
            Status = $script:Terminal; Reason = $script:Reason; StartUtc = $script:StartedAt; EndUtc = [DateTime]::UtcNow.ToString('o')
            ValidPairedObservations = $validRows.Count; InternalPairedStatistics = $stats
            CalibrationExcluded = $true; SafetyChecksPassed = $script:SafetyPassed; Offline = $script:Offline
            Kr003Complete = $false; ProductionApproved = $false
            NetworkRestoration = $script:RadioRestoreStatus
        }
        Write-JsonFile 'summary.json' $summary
        @(
            '# KR-003 qualification result'
            ''
            ("Status: **" + $script:Terminal + "**; reason: " + $script:Reason)
            ("Valid paired physical observations: " + $validRows.Count + '/100.')
            ("Internal paired attachment timing: " + ($stats | ConvertTo-Json -Compress))
            'Calibration and safety observations are not additional expiry samples.'
            'Unpaired/failed/interrupted attempts remain in attempts.json and telemetry.jsonl.'
            'This result does not close KR-003, validate other devices, or establish Play acceptance.'
        ) | Set-Content -LiteralPath (Join-Path $runDirectory 'SUMMARY.md') -Encoding UTF8
        Write-Host ("Evidence saved: " + $runDirectory)
        Write-Host 'The agent can read this directory directly from mounted Windows storage.'
        Write-Host 'On a stopped run the current restriction is preserved for investigation; use Open device settings for recovery.'
    }
}

# Machine callers must not interpret a stopped or online-only run as offline qualification.
if ($script:Terminal -eq 'PASSED_THIS_CONFIGURATION_ONLY') { exit 0 }
exit 2
