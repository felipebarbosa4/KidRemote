Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-KRConfigurationQualificationBundle {
    param($Bundle)
    if ($null -eq $Bundle -or $Bundle.schema -ne 1 -or
        $Bundle.protocol -ne 'KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION' -or
        $Bundle.runnerVersion -ne 9 -or $Bundle.diagnosticOnly -or -not $Bundle.requiresOffline -or
        $Bundle.networkCapabilityModel -ne 'ANDROID_SYSTEM_FEATURES_WIFI_AND_TELEPHONY_DATA' -or
        $Bundle.oracleModel -ne 'ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS' -or
        $Bundle.humanCheckpointMaximum -ne 3 -or $Bundle.physicalExecution -ne 'NOT_RUN') {
        throw 'INVALID:BUNDLE_SCHEMA'
    }
    $configuration=$Bundle.approvedConfiguration
    $configurationNames=@('schema','manufacturer','model','androidVersion','apiLevel','securityPatch','buildId')
    if ($null -eq $configuration -or $configuration.schema -ne 1 -or
        @($configuration.PSObject.Properties.Name).Count -ne $configurationNames.Count -or
        @($configuration.PSObject.Properties.Name | Where-Object { $_ -notin $configurationNames }).Count) {
        throw 'INVALID:BUNDLE_CONFIGURATION_SCHEMA'
    }
    foreach($name in @('manufacturer','model','androidVersion','apiLevel','securityPatch','buildId')) {
        $value=[string]$configuration.$name
        if ([string]::IsNullOrWhiteSpace($value) -or $value -eq 'UNSPECIFIED' -or
            $value.Length -gt 120 -or $value -notmatch '^[A-Za-z0-9][A-Za-z0-9 ._+()/:,-]*$') {
            throw 'INVALID:BUNDLE_CONFIGURATION_SCHEMA'
        }
    }
    $calibration=$Bundle.calibratedBy
    $calibrationNames=@('protocol','sourceCommit','runDirectory','status','reason','summarySha256','deviceSha256','transportDeviceEvidenceSha256','calibrationSamples','qualificationSamples','physicalAgreement','candidateSha256','fixtureSha256')
    if ($null -eq $calibration -or
        @($calibration.PSObject.Properties.Name).Count -ne $calibrationNames.Count -or
        @($calibration.PSObject.Properties.Name | Where-Object { $_ -notin $calibrationNames }).Count -or
        $calibration.protocol -ne 'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION' -or
        $calibration.status -ne 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY' -or
        $calibration.reason -ne 'COMPLETED' -or $calibration.calibrationSamples -ne 1 -or
        $calibration.qualificationSamples -ne 0 -or $calibration.physicalAgreement -ne 'PASS' -or
        $calibration.sourceCommit -notmatch '^[a-f0-9]{40}$' -or
        $calibration.runDirectory -notmatch '^calibration-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$') {
        throw 'INVALID:BUNDLE_CALIBRATION_SCHEMA'
    }
    foreach($name in @('summarySha256','deviceSha256','transportDeviceEvidenceSha256','candidateSha256','fixtureSha256')) {
        if ($calibration.$name -notmatch '^[a-f0-9]{64}$') { throw 'INVALID:BUNDLE_CALIBRATION_SCHEMA' }
    }
    if ($Bundle.candidateSha256 -cne $calibration.candidateSha256 -or
        $Bundle.fixtureSha256 -cne $calibration.fixtureSha256) {
        throw 'INVALID:BUNDLE_CALIBRATION_APK_MISMATCH'
    }
}

function Convert-KRSystemFeatureProbe {
    param($Probe)
    if ($null -eq $Probe -or
        $Probe.PSObject.Properties.Name -notcontains 'ExitCode' -or
        $Probe.PSObject.Properties.Name -notcontains 'Stdout' -or
        $Probe.PSObject.Properties.Name -notcontains 'StderrClass' -or
        $Probe.StderrClass -ne 'NONE') { return 'UNKNOWN' }
    $value=([string]$Probe.Stdout).Trim().ToLowerInvariant()
    if ([int]$Probe.ExitCode -eq 0 -and $value -eq 'true') { return 'PRESENT' }
    if ([int]$Probe.ExitCode -eq 1 -and $value -eq 'false') { return 'ABSENT' }
    return 'UNKNOWN'
}

function Get-KRNetworkIsolationPlan {
    param($Capabilities,$Device)
    if ($null -eq $Capabilities -or $null -eq $Device) { throw 'INVALID:NETWORK_CAPABILITY_UNKNOWN' }
    $plan=@()
    foreach($entry in @(
        [PSCustomObject]@{Capability='Wifi';Setting='wifi_on';Service='wifi'},
        [PSCustomObject]@{Capability='MobileData';Setting='mobile_data';Service='data'}
    )) {
        if($Capabilities.PSObject.Properties.Name -notcontains $entry.Capability -or
            $Device.PSObject.Properties.Name -notcontains $entry.Setting) { throw 'INVALID:NETWORK_CAPABILITY_UNKNOWN' }
        $capability=[string]$Capabilities.($entry.Capability)
        if ($capability -eq 'UNKNOWN' -or $capability -notin @('PRESENT','ABSENT')) { throw 'INVALID:NETWORK_CAPABILITY_UNKNOWN' }
        $initial=if($capability -eq 'ABSENT'){'NOT_APPLICABLE'}else{[string]$Device.($entry.Setting)}
        if ($capability -eq 'PRESENT' -and $initial -notin @('0','1')) { throw 'INVALID:RADIO_INITIAL_STATE_UNKNOWN' }
        $plan += [PSCustomObject]@{
            Capability=$entry.Capability; Setting=$entry.Setting; Service=$entry.Service
            Presence=$capability; Initial=$initial
        }
    }
    return @($plan)
}

function Assert-KRNetworkOffline {
    param($Capabilities,$Device)
    $plan=@(Get-KRNetworkIsolationPlan $Capabilities $Device)
    if(@($plan | Where-Object { $_.Presence -eq 'PRESENT' -and $_.Initial -ne '0' }).Count) {
        throw 'INVALID:OFFLINE_RADIOS_NOT_DISABLED'
    }
}

function Assert-KRBoundDeviceConfiguration {
    param($ObservedDevice,$ExpectedConfiguration)
    if ($null -eq $ObservedDevice -or $null -eq $ExpectedConfiguration) { throw 'INVALID:DEVICE_CONFIGURATION_CHANGED' }
    $mapping=[ordered]@{
        Manufacturer='manufacturer'; Model='model'; Android='androidVersion'; Api='apiLevel'; Patch='securityPatch'; BuildId='buildId'
    }
    foreach($observedName in $mapping.Keys) {
        $expectedName=$mapping[$observedName]
        if ($ObservedDevice.PSObject.Properties.Name -notcontains $observedName -or
            $ExpectedConfiguration.PSObject.Properties.Name -notcontains $expectedName -or
            ([string]$ObservedDevice.$observedName) -cne ([string]$ExpectedConfiguration.$expectedName)) {
            throw 'INVALID:DEVICE_CONFIGURATION_CHANGED'
        }
    }
}

function Get-KRStatistics {
    param([long[]]$Values = @())
    if ($Values.Count -eq 0) { return [PSCustomObject]@{ Count = 0; P50 = $null; P95 = $null; Max = $null } }
    if (@($Values | Where-Object { $_ -lt 0 }).Count) { throw 'INVALID:NEGATIVE_LATENCY' }
    $sorted = @($Values | Sort-Object)
    return [PSCustomObject]@{
        Count = $sorted.Count
        P50 = $sorted[[int][Math]::Ceiling(0.50 * $sorted.Count) - 1]
        P95 = $sorted[[int][Math]::Ceiling(0.95 * $sorted.Count) - 1]
        Max = $sorted[-1]
    }
}

function Convert-KRReply {
    param([string]$Raw, [long]$Request, [switch]$Fixture)
    $matchesFound = [regex]::Matches($Raw, 'KR003:([A-Za-z0-9+/=]+)')
    if ($matchesFound.Count -ne 1) { throw 'INVALID:MISSING_OR_AMBIGUOUS_REPLY' }
    try {
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($matchesFound[0].Groups[1].Value))
        $data = $json | ConvertFrom-Json
    } catch { throw 'INVALID:MALFORMED_REPLY' }
    if ($data.schema -notin @(1,2) -or $data.request -ne $Request) { throw 'INVALID:STALE_REPLY' }
    if ($data.PSObject.Properties.Name -contains 'error') { throw 'INVALID:DEBUG_CONTROL_REJECTED' }
    if ($Fixture) {
        $numbers = @('schema','request','elapsed','instance','taps')
        $booleans = @('focused','resumed')
        $extra = @()
        if ($data.schema -eq 2) {
            $numbers += @('focusGains','focusLosses','lastFocusChange','probeX','probeY')
            $booleans += 'probeReady'
        }
    } else {
        $numbers = @('schema','request','elapsed','versionCode','api','revision','remaining','sampledAt','sampledRevision','firstAttachedAt','removals','recordedRevision','sampleCount','p50','p95','max','traceHead')
        $booleans = @('armed','restriction','uncertain','usage','accessibility','heartbeat','eligible','attached','eligibilityLost','traceLost')
        $extra = @('versionName','adapter','disposition','samples','events')
        if ($data.schema -eq 2) {
            $numbers += 'windowVisibility'
            $booleans += @('windowFocused','viewAttached')
        }
    }
    $allowed = $numbers + $booleans + $extra
    if (@($data.PSObject.Properties.Name).Count -ne $allowed.Count -or @($data.PSObject.Properties.Name | Where-Object { $_ -notin $allowed }).Count) { throw 'INVALID:REPLY_SCHEMA' }
    foreach ($key in $numbers) {
        $value = $data.$key
        if ($value -isnot [long] -and $value -isnot [int] -and $value -isnot [bigint]) { throw 'INVALID:REPLY_NUMBER' }
        if ($value -lt -1 -or $value -gt 9007199254740991) { throw 'INVALID:REPLY_RANGE' }
    }
    foreach ($key in $booleans) { if ($data.$key -isnot [bool]) { throw 'INVALID:REPLY_BOOLEAN' } }
    if (-not $Fixture) {
        if ($data.disposition -notin @('ORDINARY_APP','SAFE_SYSTEM','UNKNOWN_FAIL_OPEN')) { throw 'INVALID:DISPOSITION' }
        if ($data.schema -eq 2 -and $data.windowVisibility -notin @(-1,0,4,8)) { throw 'INVALID:WINDOW_VISIBILITY' }
        if ($data.adapter -notin @('APPLIED','NOT_REQUIRED','SAFE_SURFACE_AVAILABLE','UNKNOWN_SURFACE_FAIL_OPEN','OVERLAY_FAILED')) { throw 'INVALID:ADAPTER' }
        if ($data.versionName -notmatch '^[0-9a-zA-Z.-]{1,50}$') { throw 'INVALID:VERSION' }
        if ($data.samples -isnot [Array] -or $data.events -isnot [Array] -or $data.samples.Count -gt 500 -or $data.events.Count -gt 32) { throw 'INVALID:REPLY_BOUNDS' }
        foreach ($sample in $data.samples) {
            if (($sample -isnot [long] -and $sample -isnot [int]) -or $sample -lt 0) { throw 'INVALID:LATENCY_TYPE' }
        }
        foreach ($entry in $data.events) {
            if (@($entry.PSObject.Properties.Name).Count -ne 2 -or $null -eq $entry.sequence -or $null -eq $entry.line) { throw 'INVALID:TRACE_SCHEMA' }
            if (($entry.sequence -isnot [long] -and $entry.sequence -isnot [int]) -or $entry.sequence -lt 1 -or $entry.sequence -gt $data.traceHead) { throw 'INVALID:TRACE_SEQUENCE' }
            if ($entry.line -notmatch '^t=\d+ kind=[a-z_]+ trigger=[a-z_]+ eventType=-?\d+ identity=(NONE|MISSING|OWN_PACKAGE|KNOWN_SAFE_SYSTEM|ORDINARY_APP) disposition=(SAFE_SYSTEM|ORDINARY_APP|UNKNOWN_FAIL_OPEN) nextDisposition=(SAFE_SYSTEM|ORDINARY_APP|UNKNOWN_FAIL_OPEN) restriction=(true|false) overlay=(ATTACHED|DETACHED) adapter=[A-Z_]+ nextAdapter=[A-Z_]+ revision=\d+$') { throw 'INVALID:UNSANITIZED_TRACE' }
        }
    }
    return $data
}

function Assert-KRHealth {
    param($Snapshot, [long]$PreviousElapsed = -1)
    if (-not $Snapshot.usage -or -not $Snapshot.accessibility -or -not $Snapshot.heartbeat) { throw 'FAIL:PERMISSION_OR_SERVICE_LOST' }
    if ($Snapshot.uncertain) { throw 'FAIL:ACCOUNTING_UNCERTAIN' }
    if ($Snapshot.elapsed -lt $PreviousElapsed) { throw 'FAIL:CLOCK_DISCONTINUITY' }
    if ($Snapshot.sampledAt -lt 0 -or $Snapshot.sampledAt -gt $Snapshot.elapsed -or $Snapshot.elapsed - $Snapshot.sampledAt -gt 3000) { throw 'FAIL:STALE_SERVICE_SAMPLE' }
    if (-not $Snapshot.eligible) { throw 'INVALID:SCREEN_OR_KEYGUARD' }
}

function Assert-KRHold {
    param($Snapshot, [long]$Revision, [long]$FixtureTaps, $FixtureState)
    Assert-KRHealth $Snapshot
    if ($Snapshot.revision -ne $Revision -or $Snapshot.sampledRevision -ne $Revision) { throw 'FAIL:REVISION_CHANGED' }
    if ($Snapshot.eligibilityLost) { throw 'INVALID:ELIGIBILITY_INTERRUPTED' }
    if (-not $Snapshot.restriction -or -not $Snapshot.attached -or $Snapshot.adapter -ne 'APPLIED' -or $Snapshot.disposition -ne 'ORDINARY_APP' -or $Snapshot.removals -ne 0) { throw 'FAIL:RESTRICTION_LOST' }
    if ($FixtureState.focused -or $FixtureState.taps -ne $FixtureTaps) { throw 'FAIL:ORDINARY_FIXTURE_ACTIVE' }
}

function Assert-KRIndependentFixtureBlock {
    param($Baseline, $Current)
    if ($Baseline.schema -ne 2 -or $Current.schema -ne 2 -or -not $Baseline.probeReady -or -not $Current.probeReady) {
        throw 'INVALID:FIXTURE_INPUT_ORACLE_UNAVAILABLE'
    }
    if ($Baseline.instance -ne $Current.instance) { throw 'INVALID:FIXTURE_RESTARTED' }
    if ($Baseline.probeX -ne $Current.probeX -or $Baseline.probeY -ne $Current.probeY) {
        throw 'INVALID:FIXTURE_PROBE_MOVED'
    }
    if (-not $Current.resumed) { throw 'INVALID:FIXTURE_NOT_UNDER_TEST' }
    if ($Current.focused -or $Current.focusGains -ne $Baseline.focusGains) {
        throw 'FAIL:FIXTURE_REGAINED_FOCUS'
    }
    if ($Current.taps -ne $Baseline.taps) { throw 'FAIL:RESTRICTION_LEAKED_INPUT' }
}

function Get-KRAutomatedRunVerdict {
    param([object[]]$Rows, [object[]]$HumanCheckpoints, [bool]$Offline)
    if (@($Rows | Where-Object { $_.AutomatedOracle -eq 'FAIL' -or $_.InputOracle -eq 'FAIL' }).Count) { return 'FAILED' }
    if ($Rows.Count -ne 100) { return 'INCOMPLETE' }
    if (@($Rows | Where-Object {
        $_.AutomatedOracle -ne 'PASS' -or $_.InputOracle -ne 'PASS' -or
        $null -eq $_.LatencyMs -or $_.HoldMillis -lt 10000 -or $_.InjectedBlockedTaps -lt 20
    }).Count) { return 'INCOMPLETE' }
    if (@($Rows | ForEach-Object { $_.Revision } | Select-Object -Unique).Count -ne 100) { return 'INCOMPLETE' }
    $requiredCheckpoints = @('PREFLIGHT_NORMAL_PASS','PREFLIGHT_NEGATIVE_CONTROL','POST_RUN_SAFETY')
    if ($HumanCheckpoints.Count -ne 3 -or
        @($HumanCheckpoints | Where-Object { $_.Result -ne 'PASS' }).Count -or
        (($HumanCheckpoints | ForEach-Object { $_.Name }) -join ',') -cne ($requiredCheckpoints -join ',')) {
        return 'INCOMPLETE'
    }
    $stats = Get-KRStatistics -Values @($Rows | ForEach-Object { $_.LatencyMs })
    if ($stats.P95 -gt 2000) { return 'FAILED_P95' }
    if (-not $Offline) { return 'ONLINE_ONLY_OFFLINE_GATE_OPEN' }
    return 'PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY'
}

function Get-KRValidAutomatedRows {
    param([object[]]$Rows = @())
    foreach ($row in $Rows) {
        if ($row.Phase -eq 'QUALIFICATION' -and $row.AutomatedOracle -eq 'PASS' -and
            $row.InputOracle -eq 'PASS' -and $null -ne $row.LatencyMs -and
            $row.HoldMillis -ge 10000 -and $row.InjectedBlockedTaps -ge 20) { $row }
    }
}

function Get-KRPairedLatency {
    param($Snapshot, [long]$Revision, [long[]]$Before = @())
    if ($Snapshot.recordedRevision -ne $Revision -or $Snapshot.sampleCount -ne $Before.Count + 1 -or $Snapshot.samples.Count -ne $Snapshot.sampleCount) { throw 'INVALID:UNPAIRED_LATENCY' }
    for ($i = 0; $i -lt $Before.Count; $i++) {
        if ($Snapshot.samples[$i] -ne $Before[$i]) { throw 'FAIL:LATENCY_HISTORY_CHANGED' }
    }
    return [long]$Snapshot.samples[-1]
}

function Get-KRRunVerdict {
    param([object[]]$Rows, [bool]$SafetyPassed, [bool]$Offline)
    if (@($Rows | Where-Object { $_.Observer -eq 'FAIL' -or $_.Automated -eq 'FAIL' }).Count) { return 'FAILED' }
    if ($Rows.Count -ne 100 -or -not $SafetyPassed) { return 'INCOMPLETE' }
    if (@($Rows | Where-Object { $_.Observer -ne 'PASS' -or $_.Automated -ne 'PASS' -or $null -eq $_.LatencyMs }).Count) { return 'INCOMPLETE' }
    if (@($Rows | ForEach-Object { $_.Revision } | Select-Object -Unique).Count -ne 100) { return 'INCOMPLETE' }
    $stats = Get-KRStatistics -Values @($Rows | ForEach-Object { $_.LatencyMs })
    if ($stats.P95 -gt 2000) { return 'FAILED_P95' }
    if (-not $Offline) { return 'ONLINE_ONLY_OFFLINE_GATE_OPEN' }
    return 'PASSED_THIS_CONFIGURATION_ONLY'
}

function Get-KRValidRows {
    param([object[]]$Rows = @())
    foreach ($row in $Rows) {
        if ($row.Phase -eq 'QUALIFICATION' -and $row.Observer -eq 'PASS' -and $row.Automated -eq 'PASS' -and $null -ne $row.LatencyMs -and $row.HoldMillis -ge 10000) { $row }
    }
}

function New-KRRecoveryEvidence {
    param([string]$Phase, $Snapshot)
    [PSCustomObject]@{
        Phase=$Phase; Revision=[long]$Snapshot.revision; StartedElapsed=[long]$Snapshot.elapsed
        AfterSequence=[long]$Snapshot.traceHead; StartedUtc=[DateTime]::UtcNow.ToString('o')
        LastElapsed=[long]$Snapshot.elapsed; OwnerConfirmedUtc=$null; EndedUtc=$null
        PhysicalHome='UNRECORDED'; HomeObservedUtc=$null
        PhysicalSettings='UNRECORDED'; SettingsObservedUtc=$null
        PhysicalHomeAndSettings='UNRECORDED'; Reentry='UNRECORDED'; ClearTouch='UNRECORDED'
        OpenRequested=$false; OpenDispatched=$false; SafeSample=$false; SafeTransition=$false; Removed=$false
        OpenRequestedSequence=-1L; OpenDispatchedElapsed=-1L; SafeTransitionElapsed=-1L
        OrdinaryAfterSafe=$false; AttachedAfterSafe=$false
        Oracle='PENDING'; Reason=$null; IndependentExpirySamples=0
    }
}

function Update-KRRecoveryEvidence {
    param($Evidence, $Snapshot)
    Assert-KRHealth $Snapshot -PreviousElapsed $Evidence.LastElapsed
    if ($Snapshot.revision -ne $Evidence.Revision -or $Snapshot.sampledRevision -ne $Evidence.Revision) { throw 'FAIL:RECOVERY_REVISION_CHANGED' }
    if ($Snapshot.traceLost) { throw 'INVALID:RECOVERY_TRACE_GAP' }
    $Evidence.LastElapsed=[long]$Snapshot.elapsed
    foreach ($entry in $Snapshot.events) {
        if ($entry.sequence -le $Evidence.AfterSequence) { continue }
        if ($entry.line -notmatch '^t=(\d+) .* revision=(\d+)$') { throw 'INVALID:RECOVERY_TRACE_SCHEMA' }
        $eventTime=[long]$Matches[1]; $eventRevision=[long]$Matches[2]
        if ($eventTime -lt $Evidence.StartedElapsed -or $eventRevision -ne $Evidence.Revision) { continue }
        if ($eventTime -gt $Snapshot.elapsed) { throw 'INVALID:RECOVERY_TRACE_TIME' }
        if ($entry.line -match ' kind=recovery_open_requested ') {
            $Evidence.OpenRequested=$true; $Evidence.OpenRequestedSequence=[long]$entry.sequence
        }
        if ($Evidence.OpenRequested -and $entry.sequence -gt $Evidence.OpenRequestedSequence -and $entry.line -match ' kind=recovery_open_dispatched ') {
            $Evidence.OpenDispatched=$true; $Evidence.OpenDispatchedElapsed=$eventTime
        }
        if ($Evidence.OpenDispatched -and $eventTime -ge $Evidence.OpenDispatchedElapsed) {
            if ($entry.line -match ' kind=surface_transition .*identity=KNOWN_SAFE_SYSTEM .*nextDisposition=SAFE_SYSTEM restriction=true ') {
                $Evidence.SafeTransition=$true
                if ($Evidence.SafeTransitionElapsed -lt 0) { $Evidence.SafeTransitionElapsed=$eventTime }
            }
            if ($entry.line -match ' kind=overlay_removed trigger=safe_surface .*restriction=true ') { $Evidence.Removed=$true }
            if ($Evidence.SafeTransition -and $eventTime -ge $Evidence.SafeTransitionElapsed -and
                $entry.line -match ' kind=surface_transition .*nextDisposition=ORDINARY_APP restriction=true ') {
                $Evidence.OrdinaryAfterSafe=$true
            }
            if ($Evidence.SafeTransition -and $eventTime -ge $Evidence.SafeTransitionElapsed -and
                $entry.line -match ' kind=overlay_attached .*restriction=true ') {
                $Evidence.AttachedAfterSafe=$true
            }
        }
    }
    if ($Evidence.OpenDispatched -and $Snapshot.sampledAt -ge $Evidence.OpenDispatchedElapsed -and $Snapshot.restriction -and -not $Snapshot.attached -and $Snapshot.disposition -eq 'SAFE_SYSTEM') {
        $Evidence.SafeSample=$true
        if ($Evidence.SafeTransitionElapsed -lt 0) { $Evidence.SafeTransitionElapsed=[long]$Snapshot.sampledAt }
    }
    if ($Evidence.SafeTransitionElapsed -ge 0 -and $Snapshot.sampledAt -ge $Evidence.SafeTransitionElapsed -and
        $Snapshot.restriction -and $Snapshot.attached -and $Snapshot.disposition -eq 'ORDINARY_APP') {
        $Evidence.OrdinaryAfterSafe=$true
        $Evidence.AttachedAfterSafe=$true
    }
    if ($Evidence.OrdinaryAfterSafe -and $Evidence.AttachedAfterSafe) {
        $Evidence.Oracle='REGRESSED_TO_ORDINARY'
        $Evidence.Reason='SAFE_TRANSITION_DID_NOT_PERSIST'
    } elseif ($Evidence.OpenRequested -and $Evidence.OpenDispatched -and ($Evidence.SafeSample -or ($Evidence.SafeTransition -and $Evidence.Removed))) {
        $Evidence.Oracle='CORROBORATED'
    }
}

function Test-KRRecoveryStableSafe {
    param($Evidence, [long]$RequiredMillis = 10000)
    return $Evidence.Oracle -eq 'CORROBORATED' -and $Evidence.SafeTransitionElapsed -ge 0 -and
        $Evidence.LastElapsed - $Evidence.SafeTransitionElapsed -ge $RequiredMillis -and
        -not $Evidence.OrdinaryAfterSafe -and -not $Evidence.AttachedAfterSafe
}

function New-KRDiagnosticPhase {
    param(
        [ValidateSet('SETTINGS_ROOT','DIGITAL_WELLBEING_ATTEMPT','RECOVERY_BUTTON_ATTEMPT','POST_RECOVERY_STATE')]
        [string]$Name,
        $Snapshot
    )
    [PSCustomObject]@{
        Name=$Name; Revision=[long]$Snapshot.revision
        StartedUtc=[DateTime]::UtcNow.ToString('o'); EndedUtc=$null
        StartedElapsed=[long]$Snapshot.elapsed; LastElapsed=[long]$Snapshot.elapsed
        AfterSequence=[long]$Snapshot.traceHead; LastSequence=[long]$Snapshot.traceHead
        StartedDisposition=[string]$Snapshot.disposition; StartedAttached=[bool]$Snapshot.attached
        LastDisposition=[string]$Snapshot.disposition; LastAttached=[bool]$Snapshot.attached
        PhysicalResult='UNRECORDED'; PhysicalObservedUtc=$null
        OpenRequested=$false; OpenRequestCount=0; OpenRequestedSequence=-1L
        OpenDispatched=$false; OpenDispatchCount=0; OpenDispatchedSequence=-1L; OpenDispatchedElapsed=-1L
        SafeTransition=$false; SafeTransitionSequence=-1L; SafeTransitionElapsed=-1L
        OrdinaryTransition=$false; OrdinaryTransitionSequence=-1L
        UnknownTransition=$false; UnknownTransitionSequence=-1L
        UnknownAfterSafe=$false
        OverlayAttached=$false; OverlayAttachedSequence=-1L
        ReattachedAfterSafe=$false
        OverlayRemoved=$false; OverlayRemovedSequence=-1L
        SafeSample=$false; OrdinaryAttachedSample=$false; UnknownSample=$false
        Oracle='PENDING'; Reason=$null
    }
}

function Update-KRDiagnosticPhase {
    param($Evidence, $Snapshot)
    Assert-KRHealth $Snapshot -PreviousElapsed $Evidence.LastElapsed
    if ($Snapshot.revision -ne $Evidence.Revision -or $Snapshot.sampledRevision -ne $Evidence.Revision) { throw 'FAIL:DIAGNOSTIC_REVISION_CHANGED' }
    if ($Snapshot.traceLost) { throw 'INVALID:DIAGNOSTIC_TRACE_GAP' }
    $Evidence.LastElapsed=[long]$Snapshot.elapsed
    $Evidence.LastSequence=[long]$Snapshot.traceHead
    $Evidence.LastDisposition=[string]$Snapshot.disposition
    $Evidence.LastAttached=[bool]$Snapshot.attached
    foreach ($entry in $Snapshot.events) {
        if ($entry.sequence -le $Evidence.AfterSequence) { continue }
        if ($entry.line -notmatch '^t=(\d+) .* revision=(\d+)$') { throw 'INVALID:DIAGNOSTIC_TRACE_SCHEMA' }
        $eventTime=[long]$Matches[1]; $eventRevision=[long]$Matches[2]
        if ($eventTime -lt $Evidence.StartedElapsed -or $eventRevision -ne $Evidence.Revision) { continue }
        if ($eventTime -gt $Snapshot.elapsed) { throw 'INVALID:DIAGNOSTIC_TRACE_TIME' }
        if ($entry.line -match ' kind=recovery_open_requested ') {
            $Evidence.OpenRequested=$true
            $Evidence.OpenRequestCount++
            $Evidence.OpenRequestedSequence=[long]$entry.sequence
        }
        if ($Evidence.OpenRequested -and $entry.sequence -gt $Evidence.OpenRequestedSequence -and $entry.line -match ' kind=recovery_open_dispatched ') {
            $Evidence.OpenDispatched=$true
            $Evidence.OpenDispatchCount++
            $Evidence.OpenDispatchedSequence=[long]$entry.sequence
            $Evidence.OpenDispatchedElapsed=$eventTime
        }
        if ($entry.line -match ' kind=surface_transition .*identity=KNOWN_SAFE_SYSTEM .*nextDisposition=SAFE_SYSTEM restriction=true ') {
            $Evidence.SafeTransition=$true; $Evidence.SafeTransitionSequence=[long]$entry.sequence
            if ($Evidence.SafeTransitionElapsed -lt 0) { $Evidence.SafeTransitionElapsed=$eventTime }
        }
        if ($entry.line -match ' kind=surface_transition .*identity=ORDINARY_APP .*nextDisposition=ORDINARY_APP restriction=true ') {
            $Evidence.OrdinaryTransition=$true; $Evidence.OrdinaryTransitionSequence=[long]$entry.sequence
        }
        if ($entry.line -match ' kind=surface_transition .*nextDisposition=UNKNOWN_FAIL_OPEN restriction=true ') {
            $Evidence.UnknownTransition=$true; $Evidence.UnknownTransitionSequence=[long]$entry.sequence
            if ($Evidence.SafeTransition -and $entry.sequence -gt $Evidence.SafeTransitionSequence) {
                $Evidence.UnknownAfterSafe=$true
            }
        }
        if ($entry.line -match ' kind=overlay_attached .*restriction=true ') {
            $Evidence.OverlayAttached=$true; $Evidence.OverlayAttachedSequence=[long]$entry.sequence
            if ($Evidence.SafeTransition -and $entry.sequence -gt $Evidence.SafeTransitionSequence) {
                $Evidence.ReattachedAfterSafe=$true
            }
        }
        if ($entry.line -match ' kind=overlay_removed trigger=safe_surface .*restriction=true ') {
            $Evidence.OverlayRemoved=$true; $Evidence.OverlayRemovedSequence=[long]$entry.sequence
        }
    }
    if ($Snapshot.sampledAt -ge $Evidence.StartedElapsed -and $Snapshot.restriction) {
        if (-not $Snapshot.attached -and $Snapshot.disposition -eq 'SAFE_SYSTEM') {
            if ($Evidence.Name -notin @('SETTINGS_ROOT','RECOVERY_BUTTON_ATTEMPT') -or
                ($Evidence.OpenDispatched -and $Snapshot.sampledAt -ge $Evidence.OpenDispatchedElapsed)) {
                $Evidence.SafeSample=$true
            }
        }
        if ($Snapshot.attached -and $Snapshot.disposition -eq 'ORDINARY_APP') { $Evidence.OrdinaryAttachedSample=$true }
        if (-not $Snapshot.attached -and $Snapshot.disposition -eq 'UNKNOWN_FAIL_OPEN') { $Evidence.UnknownSample=$true }
    }
    if ($Evidence.OpenRequestCount -gt 1 -or $Evidence.OpenDispatchCount -gt 1) {
        $Evidence.Oracle='INVALID_MULTIPLE_RECOVERY_ATTEMPTS'
        $Evidence.Reason='MORE_THAN_ONE_BUTTON_ATTEMPT_IN_PHASE'
        return
    }
    switch ($Evidence.Name) {
        'SETTINGS_ROOT' {
            $correlatedTrace=$Evidence.SafeTransition -and $Evidence.OverlayRemoved -and
                $Evidence.SafeTransitionSequence -gt $Evidence.OpenDispatchedSequence -and
                $Evidence.OverlayRemovedSequence -gt $Evidence.OpenDispatchedSequence
            $correlatedSample=$Evidence.SafeSample -and $Evidence.OpenDispatchedElapsed -ge 0 -and
                $Snapshot.sampledAt -ge $Evidence.OpenDispatchedElapsed
            if ($Evidence.OpenDispatched -and ($correlatedTrace -or $correlatedSample)) {
                $Evidence.Oracle='SAFE_TRANSITION_CORROBORATED'
            }
        }
        'DIGITAL_WELLBEING_ATTEMPT' {
            if (($Evidence.OrdinaryTransition -and $Evidence.OverlayAttached) -or $Evidence.OrdinaryAttachedSample) {
                $Evidence.Oracle='ORDINARY_REATTACHMENT_CORROBORATED'
            } elseif ($Evidence.UnknownTransition -or $Evidence.UnknownSample) {
                $Evidence.Oracle='UNKNOWN_FAIL_OPEN_OBSERVED'
            } elseif ($Evidence.SafeTransition -or $Evidence.SafeSample) {
                $Evidence.Oracle='SAFE_SYSTEM_OBSERVED'
            }
        }
        'RECOVERY_BUTTON_ATTEMPT' {
            $correlatedTrace=$Evidence.SafeTransition -and $Evidence.OverlayRemoved -and
                $Evidence.SafeTransitionSequence -gt $Evidence.OpenDispatchedSequence -and
                $Evidence.OverlayRemovedSequence -gt $Evidence.OpenDispatchedSequence
            $correlatedSample=$Evidence.SafeSample -and $Evidence.OpenDispatchedElapsed -ge 0 -and
                $Snapshot.sampledAt -ge $Evidence.OpenDispatchedElapsed
            $regressed=$Evidence.SafeTransition -and $Evidence.OrdinaryTransition -and
                $Evidence.OrdinaryTransitionSequence -gt $Evidence.SafeTransitionSequence -and
                (($Evidence.OverlayAttached -and $Evidence.OverlayAttachedSequence -gt $Evidence.SafeTransitionSequence) -or
                    $Evidence.OrdinaryAttachedSample)
            if ($regressed) {
                $Evidence.Oracle='RECOVERY_REGRESSED_TO_ORDINARY'
                $Evidence.Reason='SAFE_TRANSITION_DID_NOT_PERSIST'
            } elseif ($Evidence.UnknownAfterSafe) {
                $Evidence.Oracle='RECOVERY_REGRESSED_TO_UNKNOWN'
                $Evidence.Reason='UNKNOWN_SURFACE_AFTER_SAFE_TRANSITION'
            } elseif ($Evidence.ReattachedAfterSafe) {
                $Evidence.Oracle='RECOVERY_OVERLAY_REATTACHED'
                $Evidence.Reason='OVERLAY_REATTACHED_AFTER_SAFE_TRANSITION'
            } elseif ($Evidence.OpenDispatched -and ($correlatedTrace -or $correlatedSample)) {
                $Evidence.Oracle='FRESH_SAFE_TRANSITION_CORROBORATED'
            }
        }
        'POST_RECOVERY_STATE' {
            if ($Evidence.OrdinaryAttachedSample) { $Evidence.Oracle='ORDINARY_ATTACHED_OBSERVED' }
            elseif ($Evidence.SafeSample) { $Evidence.Oracle='SAFE_STATE_OBSERVED' }
            elseif ($Evidence.UnknownSample) { $Evidence.Oracle='UNKNOWN_FAIL_OPEN_OBSERVED' }
        }
    }
}

function Test-KRDiagnosticStableSafe {
    param($Evidence, [long]$RequiredMillis = 10000)
    return $Evidence.Name -eq 'RECOVERY_BUTTON_ATTEMPT' -and
        $Evidence.Oracle -eq 'FRESH_SAFE_TRANSITION_CORROBORATED' -and
        $Evidence.SafeTransitionElapsed -ge 0 -and
        $Evidence.LastElapsed - $Evidence.SafeTransitionElapsed -ge $RequiredMillis -and
        $Evidence.LastDisposition -eq 'SAFE_SYSTEM' -and -not $Evidence.LastAttached -and
        -not $Evidence.ReattachedAfterSafe -and -not $Evidence.UnknownAfterSafe
}

function Get-KRFocusedDiagnosticReason {
    param([object[]]$Phases)
    $expected=@('SETTINGS_ROOT','DIGITAL_WELLBEING_ATTEMPT','RECOVERY_BUTTON_ATTEMPT','POST_RECOVERY_STATE')
    if ($Phases.Count -ne $expected.Count) { return 'SOFTWARE_INVALID_RECORDED' }
    $byName=@{}
    foreach ($phase in $Phases) {
        if ($phase.Name -notin $expected -or $byName.ContainsKey($phase.Name)) { return 'SOFTWARE_INVALID_RECORDED' }
        $byName[$phase.Name]=$phase
    }
    foreach ($name in $expected) { if (-not $byName.ContainsKey($name)) { return 'SOFTWARE_INVALID_RECORDED' } }

    $root=$byName['SETTINGS_ROOT']
    $digital=$byName['DIGITAL_WELLBEING_ATTEMPT']
    $recovery=$byName['RECOVERY_BUTTON_ATTEMPT']
    $post=$byName['POST_RECOVERY_STATE']
    $physicalPhases=@($root,$digital,$recovery)

    if (@($physicalPhases | Where-Object { $_.PhysicalResult -eq 'INVALID' }).Count) { return 'PHYSICAL_INVALID_RECORDED' }
    if ($root.PhysicalResult -ne 'PASS' -or $digital.PhysicalResult -ne 'FAIL' -or $recovery.PhysicalResult -ne 'PASS') {
        return 'PHYSICAL_FAILURE_RECORDED'
    }
    if (@($physicalPhases | Where-Object { $_.Oracle -like 'INVALID_*' -or $_.Oracle -eq 'PENDING' }).Count) {
        return 'SOFTWARE_INVALID_RECORDED'
    }
    if ($root.Oracle -ne 'SAFE_TRANSITION_CORROBORATED' -or
        $digital.Oracle -ne 'ORDINARY_REATTACHMENT_CORROBORATED' -or
        $recovery.Oracle -ne 'FRESH_SAFE_TRANSITION_CORROBORATED' -or
        $post.Oracle -ne 'SAFE_STATE_OBSERVED') {
        return 'SOFTWARE_FAILURE_RECORDED'
    }
    return 'PHYSICAL_PASS_RECORDED'
}

function Get-KRSafetyCheckpointReason {
    param([string]$HomeResult, [string]$Recovery, [string]$Reentry, [string]$ClearTouch)
    if ($HomeResult -eq 'INVALID' -or $Reentry -eq 'INVALID' -or $Recovery -eq 'PHYSICAL_INVALID_RECORDED') {
        return 'PHYSICAL_INVALID_RECORDED'
    }
    if ($HomeResult -ne 'PASS' -or $Reentry -ne 'PASS' -or $Recovery -eq 'PHYSICAL_FAILURE_RECORDED') {
        return 'PHYSICAL_FAILURE_RECORDED'
    }
    if ($Recovery -ne 'PHYSICAL_PASS_RECORDED' -or $ClearTouch -ne 'FIXTURE_COUNTER_INCREMENT') {
        return 'SOFTWARE_FAILURE_RECORDED'
    }
    return 'PHYSICAL_PASS_RECORDED'
}

Export-ModuleMember -Function Assert-KRConfigurationQualificationBundle, Assert-KRBoundDeviceConfiguration, Convert-KRSystemFeatureProbe, Get-KRNetworkIsolationPlan, Assert-KRNetworkOffline, Get-KRStatistics, Convert-KRReply, Assert-KRHealth, Assert-KRHold, Get-KRPairedLatency, Get-KRRunVerdict, Get-KRValidRows, Assert-KRIndependentFixtureBlock, Get-KRAutomatedRunVerdict, Get-KRValidAutomatedRows, New-KRRecoveryEvidence, Update-KRRecoveryEvidence, Test-KRRecoveryStableSafe, New-KRDiagnosticPhase, Update-KRDiagnosticPhase, Test-KRDiagnosticStableSafe, Get-KRFocusedDiagnosticReason, Get-KRSafetyCheckpointReason
