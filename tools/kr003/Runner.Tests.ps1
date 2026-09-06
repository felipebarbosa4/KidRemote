# Goal: test real finalization/recovery orchestration with synthetic evidence and no device execution.
# Context: d81f19a calibration incident. Constraints: temporary directories only, every ADB call is a stub.
# Done when: empty/partial/100-row paths, reporting/cleanup faults and phase disagreement preserve evidence.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected) { $script:Checks++; if ($Actual -cne $Expected) { throw "Expected $Expected; got $Actual" } }
function Assert-True($Value) { Assert-Equal ([bool]$Value) $true }
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Start-KR003.ps1'),[ref]$tokens,[ref]$parseErrors)
Assert-Equal $parseErrors.Count 0
foreach($fn in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) { Invoke-Expression $fn.Extent.Text }
# No test below can invoke the owner's ADB executable.
function Invoke-LabAdb { param($Arguments) throw 'UNEXPECTED_DEVICE_COMMAND_IN_UNIT_TEST' }
$temporaryRoot=Join-Path ([IO.Path]::GetTempPath()) ('kr003-finalizer-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
function New-Row([int]$Number) {
    [PSCustomObject]@{ Attempt=$Number; Phase='QUALIFICATION'; StartedUtc='2026-09-06T00:00:00Z'; EndedUtc='2026-09-06T00:00:30Z'; Revision=$Number+100; Observer='PASS'; Automated='PASS'; LatencyMs=100+$Number; InternalSampleCount=$Number; HoldMillis=10000; Reason=$null }
}
function Reset-Run([string]$Name) {
    $script:runDirectory=Join-Path $temporaryRoot $Name
    New-Item -ItemType Directory -Path $runDirectory | Out-Null
    $script:Rows=@(); $script:CurrentRow=$null; $script:Calibration=$null; $script:Recovery=$null
    $script:Manifest=[PSCustomObject]@{EndedUtc=$null}
    $script:Terminal='FAIL'; $script:Reason='SETTINGS_RECOVERY'; $script:StartedAt='2026-09-06T00:00:00Z'
    $script:RadioOriginal=$null; $script:RadioTouched=@(); $script:RadioRestoreStatus='NOT_CHANGED'; $script:RadioResults=@()
    $script:FinalizationErrors=@(); $script:SafetyPassed=$false; $script:Offline=$true; $script:CalibrationOnly=$true
    $script:RecoveryDiagnostic=$false; $script:LabControlReady=$false; $script:Diagnostic=$null; $script:DiagnosticBailout=$null
}
function Read-Json([string]$Name) { Get-Content -LiteralPath (Join-Path $runDirectory $Name) -Raw | ConvertFrom-Json }
function Check-Summary([int]$Count,[string]$Reason) {
    Complete-LabRun 6>$null
    $summary=Read-Json 'summary.json'
    Assert-Equal $summary.ValidPairedObservations $Count
    Assert-Equal $summary.InternalPairedStatistics.Count $Count
    Assert-Equal $summary.Reason $Reason
    Assert-True (Test-Path -LiteralPath (Join-Path $runDirectory 'SUMMARY.md'))
    Assert-True (Test-Path -LiteralPath (Join-Path $runDirectory 'network-restoration.json'))
}
try {
    Reset-Run 'calibration-failure'
    $script:CurrentRow=New-Row 0; $script:CurrentRow.Phase='CALIBRATION'; $script:CurrentRow.Automated='FAIL'
    Check-Summary 0 'SETTINGS_RECOVERY'
    Assert-Equal @((Read-Json 'attempts.json')).Count 1
    Assert-Equal (Read-Json 'summary.json').InternalPairedStatistics.P95 $null

    Reset-Run 'interrupted-before-qualification'
    $script:Terminal='INTERRUPTED'; $script:Reason='OPERATOR_STOP'
    Check-Summary 0 'OPERATOR_STOP'
    Assert-Equal @((Read-Json 'attempts.json')).Count 0
    Assert-Equal @(Import-Csv -LiteralPath (Join-Path $runDirectory 'attempts.csv')).Count 0

    Reset-Run 'failure-sample-one'
    $script:CurrentRow=New-Row 1; $script:CurrentRow.Automated='FAIL'; $script:CurrentRow.Observer='UNRECORDED'; $script:CurrentRow.LatencyMs=$null
    Check-Summary 0 'SETTINGS_RECOVERY'
    Assert-Equal @((Read-Json 'attempts.json')).Count 1

    Reset-Run 'partial-seven'
    $script:Rows=@(1..7 | ForEach-Object { New-Row $_ })
    $script:CurrentRow=New-Row 8; $script:CurrentRow.Automated='FAIL'
    Check-Summary 7 'SETTINGS_RECOVERY'
    Assert-Equal @((Read-Json 'attempts.json')).Count 8
    Assert-Equal (Read-Json 'summary.json').InternalPairedStatistics.P95 107

    Reset-Run 'full-one-hundred'
    $script:Rows=@(1..100 | ForEach-Object { New-Row $_ })
    $script:Calibration=New-Row 0; $script:Calibration.Phase='CALIBRATION'
    $script:Terminal='PASSED_THIS_CONFIGURATION_ONLY'; $script:Reason='COMPLETED'; $script:SafetyPassed=$true
    $script:CalibrationOnly=$false
    Check-Summary 100 'COMPLETED'
    Assert-Equal @((Read-Json 'attempts.json')).Count 101
    Assert-Equal (Read-Json 'summary.json').InternalPairedStatistics.P95 195
    Assert-Equal (Read-Json 'summary.json').QualificationRequested $true

    Reset-Run 'post-observer-oracle-disagreement'
    $script:Calibration=New-Row 0; $script:Calibration.Phase='CALIBRATION'
    $script:Recovery=[PSCustomObject]@{Phase='calibration';PhysicalHomeAndSettings='OWNER_PASS';Oracle='UNCORROBORATED';Reason=$null;EndedUtc=$null}
    $script:Terminal='INVALID'; $script:Reason='SETTINGS_RECOVERY_ORACLE_UNCORROBORATED'
    Check-Summary 0 'SETTINGS_RECOVERY_ORACLE_UNCORROBORATED'
    Assert-Equal (Read-Json 'safety-calibration.json').PhysicalHomeAndSettings 'OWNER_PASS'
    Assert-Equal @(Import-Csv -LiteralPath (Join-Path $runDirectory 'attempts.csv'))[0].Observer 'PASS'

    # A broken higher-level JSON writer cannot block cleanup, CSV, either summary, or alter the primary reason.
    Reset-Run 'writer-failure'
    function Write-JsonFile { param($Name,$Value) throw 'SYNTHETIC_WRITER_FAILURE' }
    $script:CurrentRow=New-Row 1; $script:CurrentRow.Automated='FAIL'
    Complete-LabRun 6>$null
    Assert-Equal (Read-Json 'summary.json').Reason 'SETTINGS_RECOVERY'
    Assert-Equal (Read-Json 'summary.json').InternalPairedStatistics.Count 0
    Assert-True (Test-Path -LiteralPath (Join-Path $runDirectory 'SUMMARY.md'))
    Assert-Equal @(Import-Csv -LiteralPath (Join-Path $runDirectory 'attempts.csv')).Count 1
    Assert-True ((Read-Json 'summary.json').FinalizationErrors -contains 'SUMMARY_JSON_PRIMARY_WRITE')
    $writer=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-JsonFile'},$true)
    Invoke-Expression $writer.Extent.Text

    # Per-radio isolation: a Wi-Fi restore failure cannot prevent mobile-data restoration/verification.
    Reset-Run 'radio-partial-failure'
    $script:RadioOriginal=[PSCustomObject]@{wifi_on='1';mobile_data='1'}; $script:RadioTouched=@('wifi_on','mobile_data')
    $script:Commands=@()
    function Invoke-LabAdb {
        param($Arguments)
        $command=$Arguments -join ' '; $script:Commands+=$command
        if ($command -eq 'shell svc wifi enable') { throw 'SYNTHETIC_WIFI_FAILURE' }
        return '1'
    }
    Complete-LabRun 6>$null
    Assert-True ($script:Commands -contains 'shell svc data enable')
    Assert-Equal (Read-Json 'network-restoration.json').Settings[1].Status 'VERIFIED'
    Assert-Equal (Read-Json 'summary.json').Reason 'SETTINGS_RECOVERY'
    Assert-Equal (Read-Json 'summary.json').Status 'FAIL'
    Assert-True ((Read-Json 'summary.json').FinalizationErrors -contains 'NETWORK_UNVERIFIED')

    # Genuine success path persists both observed restored flags, including an untouched mobile-data flag.
    Reset-Run 'radio-restored'
    $script:RadioOriginal=[PSCustomObject]@{wifi_on='1';mobile_data='0'}; $script:RadioTouched=@('wifi_on')
    function Invoke-LabAdb { param($Arguments) if ($Arguments[-1] -eq 'mobile_data') { return '0' }; return '1' }
    Complete-LabRun 6>$null
    Assert-Equal (Read-Json 'network-restoration.json').Status 'RESTORED_AND_FLAGS_VERIFIED'
    Assert-Equal (Read-Json 'network-restoration.json').Settings[1].Observed '0'

    # Exercise the real post-observer oracle path against the incident's fresh-but-blocked signal pattern.
    Reset-Run 'recovery-oracle-disagreement'
    function New-Frame([long]$Elapsed=1000) {
        [PSCustomObject]@{elapsed=$Elapsed; sampledAt=$Elapsed-10; revision=42; sampledRevision=42; restriction=$true; attached=$true; disposition='ORDINARY_APP'; heartbeat=$true; usage=$true; accessibility=$true; uncertain=$false; eligible=$true; traceHead=14; traceLost=$false; events=@()}
    }
    function Get-LabState { New-Frame 1000 }
    function Get-FixtureState { [PSCustomObject]@{focused=$false;resumed=$true;taps=0} }
    function Read-Result { param($Prompt,$Poll,$OnObserved) if ($null -ne $Poll) { & $Poll }; if ($null -ne $OnObserved) { & $OnObserved 'PASS' }; return 'PASS' }
    function Start-Sleep {}
    $reason=$null
    try { Invoke-RecoveryObservation -Phase 'calibration' -CorroborationTimeoutSeconds 0 6>$null } catch { $reason=$_.Exception.Message }
    Assert-Equal $reason 'INVALID:SETTINGS_RECOVERY_ORACLE_UNCORROBORATED'
    Assert-Equal (Read-Json 'safety-calibration.json').PhysicalHomeAndSettings 'OWNER_PASS'
    Assert-Equal (Read-Json 'safety-calibration.json').Oracle 'UNCORROBORATED'

    # A correlated transient SAFE_SYSTEM/removal remains evidence after a later ordinary-app snapshot.
    $phase=New-KRRecoveryEvidence 'calibration' (New-Frame 1000)
    $safe=New-Frame 1200
    $safe.traceHead=18
    $safe.events=@(
        [PSCustomObject]@{sequence=15;line='t=1100 kind=recovery_open_requested trigger=settings_button revision=42'},
        [PSCustomObject]@{sequence=16;line='t=1110 kind=recovery_open_dispatched trigger=settings_button revision=42'},
        [PSCustomObject]@{sequence=17;line='t=1120 kind=surface_transition trigger=event identity=KNOWN_SAFE_SYSTEM disposition=ORDINARY_APP nextDisposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=42'},
        [PSCustomObject]@{sequence=18;line='t=1130 kind=overlay_removed trigger=safe_surface disposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=42'}
    )
    Update-KRRecoveryEvidence $phase $safe
    Update-KRRecoveryEvidence $phase (New-Frame 1300)
    Assert-Equal $phase.Oracle 'CORROBORATED'
    Assert-Equal $phase.PhysicalHomeAndSettings 'UNRECORDED'
    # A safe event before the actual Settings-button dispatch cannot satisfy the phase oracle.
    $unrelated=New-KRRecoveryEvidence 'calibration' (New-Frame 1000)
    $preButton=New-Frame 1200
    $preButton.events=@(
        [PSCustomObject]@{sequence=15;line='t=1100 kind=surface_transition trigger=event identity=KNOWN_SAFE_SYSTEM disposition=ORDINARY_APP nextDisposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=42'},
        [PSCustomObject]@{sequence=16;line='t=1110 kind=overlay_removed trigger=safe_surface disposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=42'},
        [PSCustomObject]@{sequence=17;line='t=1120 kind=recovery_open_requested trigger=settings_button revision=42'},
        [PSCustomObject]@{sequence=18;line='t=1130 kind=recovery_open_dispatched trigger=settings_button revision=42'}
    )
    Update-KRRecoveryEvidence $unrelated $preButton
    Assert-Equal $unrelated.Oracle 'PENDING'
    $safeSample=New-Frame 1250; $safeSample.attached=$false; $safeSample.disposition='SAFE_SYSTEM'
    Update-KRRecoveryEvidence $unrelated $safeSample
    Assert-Equal $unrelated.Oracle 'CORROBORATED'
    Assert-Equal $unrelated.PhysicalHomeAndSettings 'UNRECORDED'
    $stale=New-KRRecoveryEvidence 'calibration' (New-Frame 2000)
    $safe.elapsed=2100; $safe.sampledAt=2090
    Update-KRRecoveryEvidence $stale $safe
    Assert-Equal $stale.Oracle 'PENDING'
    $safe.revision=43
    $reason=$null
    try { Update-KRRecoveryEvidence $stale $safe } catch { $reason=$_.Exception.Message }
    Assert-Equal $reason 'FAIL:RECOVERY_REVISION_CHANGED'

    # Diagnostic CLEAR changes only timer state and preserves the complete latency sample array.
    Reset-Run 'diagnostic-bailout'
    $script:RecoveryDiagnostic=$true; $script:LabControlReady=$true; $script:BailoutCleared=$false
    function New-BailoutFrame([bool]$Restricted) {
        [PSCustomObject]@{revision=$(if($Restricted){42}else{43});sampleCount=2;samples=@(123,263);armed=$Restricted;restriction=$Restricted;attached=$Restricted}
    }
    function Get-LabState {
        param($Operation='SNAPSHOT')
        if($Operation -eq 'CLEAR') { $script:BailoutCleared=$true }
        return New-BailoutFrame (-not $script:BailoutCleared)
    }
    function Wait-LabCondition { param($Condition,$FailureCode,$TimeoutSeconds) return Get-LabState }
    Invoke-DiagnosticBailout
    Assert-Equal $script:DiagnosticBailout.Status 'VERIFIED'
    Assert-Equal $script:DiagnosticBailout.RestrictionReleased $true
    Assert-Equal $script:DiagnosticBailout.LatencySamplesPreserved $true
    Assert-Equal $script:DiagnosticBailout.AppDataCleared $false
    Assert-Equal $script:DiagnosticBailout.Uninstalled $false
    Assert-Equal $script:DiagnosticBailout.PermissionsAltered $false
    Assert-Equal $script:DiagnosticBailout.ConsumerRecoveryEvidence $false
    Assert-Equal (Read-Json 'diagnostic-bailout.json').AfterSampleCount 2

    # Finalization invokes diagnostic bailout before reporting and retains a physical-failure diagnostic journal.
    Reset-Run 'diagnostic-finalization'
    $script:RecoveryDiagnostic=$true; $script:LabControlReady=$true
    $script:Diagnostic=[PSCustomObject]@{Result='EVIDENCE_CAPTURED';Reason='PHYSICAL_FAILURE_RECORDED';Phases=@([PSCustomObject]@{Name='DIGITAL_WELLBEING_ATTEMPT';PhysicalResult='FAIL'})}
    $script:Terminal='DIAGNOSTIC_COMPLETED_ONLY'; $script:Reason='PHYSICAL_FAILURE_RECORDED'; $script:BailoutCalled=0
    function Invoke-DiagnosticBailout {
        $script:BailoutCalled++
        $script:DiagnosticBailout=[PSCustomObject]@{Status='VERIFIED'}
    }
    Complete-LabRun 6>$null
    Assert-Equal $script:BailoutCalled 1
    Assert-Equal (Read-Json 'summary.json').DiagnosticResult 'EVIDENCE_CAPTURED'
    Assert-Equal (Read-Json 'summary.json').DiagnosticReason 'PHYSICAL_FAILURE_RECORDED'
    Assert-Equal (Read-Json 'summary.json').QualificationRequested $false

    # Bailout entry point is syntactically valid and contains no destructive/device-permission actions.
    $bailoutPath=Join-Path $PSScriptRoot 'Clear-KR003-Lab.ps1'
    $bailoutTokens=$null; $bailoutErrors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($bailoutPath,[ref]$bailoutTokens,[ref]$bailoutErrors)
    Assert-Equal $bailoutErrors.Count 0
    $bailoutSource=Get-Content -LiteralPath $bailoutPath -Raw
    Assert-Equal ([bool]($bailoutSource -match "Get-BailoutState 'CLEAR'")) $true
    Assert-Equal ([bool]($bailoutSource -match "Invoke-BailoutAdb @\('(?:uninstall|root|reboot)'|shell','pm','clear|enabled_accessibility_services|appops','set|svc','(?:wifi|data)','disable")) $false
    $runnerSource=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Start-KR003.ps1') -Raw
    Assert-Equal ([bool]($runnerSource -match '\[string\]::IsNullOrEmpty\(\$PhysicalResult\)')) $true
    Assert-Equal ([bool]($runnerSource -match 'KR003-Q5-RECOVERY-TASK-RESET-CALIBRATION')) $true
    Assert-Equal ([bool]($runnerSource -match 'MinimumPassSeconds 10')) $true
} finally {
    # Only this test-created unique temporary tree; no real run directory is used or touched.
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
}
Write-Host "$script:Checks finalization assertions passed; all device calls were stubs."
Write-Host ('PowerShell runtime: ' + $PSVersionTable.PSVersion.ToString())
