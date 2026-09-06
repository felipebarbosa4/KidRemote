Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
    param([string]$Home, [string]$Recovery, [string]$Reentry, [string]$ClearTouch)
    if ($Home -eq 'INVALID' -or $Reentry -eq 'INVALID' -or $Recovery -eq 'PHYSICAL_INVALID_RECORDED') {
        return 'PHYSICAL_INVALID_RECORDED'
    }
    if ($Home -ne 'PASS' -or $Reentry -ne 'PASS' -or $Recovery -eq 'PHYSICAL_FAILURE_RECORDED') {
        return 'PHYSICAL_FAILURE_RECORDED'
    }
    if ($Recovery -ne 'PHYSICAL_PASS_RECORDED' -or $ClearTouch -ne 'FIXTURE_COUNTER_INCREMENT') {
        return 'SOFTWARE_FAILURE_RECORDED'
    }
    return 'PHYSICAL_PASS_RECORDED'
}

Export-ModuleMember -Function Get-KRStatistics, Convert-KRReply, Assert-KRHealth, Assert-KRHold, Get-KRPairedLatency, Get-KRRunVerdict, Get-KRValidRows, New-KRRecoveryEvidence, Update-KRRecoveryEvidence, Test-KRRecoveryStableSafe, New-KRDiagnosticPhase, Update-KRDiagnosticPhase, Test-KRDiagnosticStableSafe, Get-KRFocusedDiagnosticReason, Get-KRSafetyCheckpointReason
