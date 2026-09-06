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
    if ($data.schema -ne 1 -or $data.request -ne $Request) { throw 'INVALID:STALE_REPLY' }
    if ($data.PSObject.Properties.Name -contains 'error') { throw 'INVALID:DEBUG_CONTROL_REJECTED' }
    if ($Fixture) {
        $numbers = @('schema','request','elapsed','instance','taps')
        $booleans = @('focused','resumed')
        $extra = @()
    } else {
        $numbers = @('schema','request','elapsed','versionCode','api','revision','remaining','sampledAt','sampledRevision','firstAttachedAt','removals','recordedRevision','sampleCount','p50','p95','max','traceHead')
        $booleans = @('armed','restriction','uncertain','usage','accessibility','heartbeat','eligible','attached','eligibilityLost','traceLost')
        $extra = @('versionName','adapter','disposition','samples','events')
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
    if (@($Rows.Revision | Select-Object -Unique).Count -ne 100) { return 'INCOMPLETE' }
    $stats = Get-KRStatistics -Values @($Rows.LatencyMs)
    if ($stats.P95 -gt 2000) { return 'FAILED_P95' }
    if (-not $Offline) { return 'ONLINE_ONLY_OFFLINE_GATE_OPEN' }
    return 'PASSED_THIS_CONFIGURATION_ONLY'
}

Export-ModuleMember -Function Get-KRStatistics, Convert-KRReply, Assert-KRHealth, Assert-KRHold, Get-KRPairedLatency, Get-KRRunVerdict
