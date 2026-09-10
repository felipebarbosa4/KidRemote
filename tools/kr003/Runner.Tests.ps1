# Goal: test real finalization/recovery orchestration with synthetic evidence and no device execution.
# Context: Q7 extends the hardened finalizer into active-oracle qualification. Constraints: temporary directories only; ADB is stubbed.
# Done when: empty/partial/100-row paths, safety journalling, cleanup faults and phase disagreement preserve evidence.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'DevicePreflight.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected) {
    $script:Checks++
    if ($Actual -cne $Expected) {
        $caller=(Get-PSCallStack)[1]
        throw ("Expected {0}; got {1} at test line {2}" -f $Expected,$Actual,$caller.ScriptLineNumber)
    }
}
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
    [PSCustomObject]@{ Attempt=$Number; Phase='QUALIFICATION'; StartedUtc='2026-09-06T00:00:00Z'; EndedUtc='2026-09-06T00:00:30Z'; Revision=$Number+100; PhysicalObserver='NOT_SAMPLED'; AutomatedOracle='PASS'; InputOracle='PASS'; LatencyMs=100+$Number; InternalSampleCount=$Number; HoldMillis=10000; InjectedBlockedTaps=20; PositiveControlTap='REACHED_FIXTURE'; FixtureFocusGainsBaseline=2; ServiceConnectionBaseline=1; Reason=$null }
}
function Reset-Run([string]$Name) {
    $script:runDirectory=Join-Path $temporaryRoot $Name
    New-Item -ItemType Directory -Path $runDirectory | Out-Null
    $script:Rows=@(); $script:CurrentRow=$null; $script:Calibration=$null; $script:Recovery=$null
    $script:Manifest=[PSCustomObject]@{EndedUtc=$null}
    $script:Terminal='FAIL'; $script:Reason='SETTINGS_RECOVERY'; $script:StartedAt='2026-09-06T00:00:00Z'
    $script:RadioOriginal=$null; $script:RadioTouched=@(); $script:RadioRestoreStatus='NOT_CHANGED'; $script:RadioResults=@()
    $script:StayAwakeOriginal=$null;$script:StayAwakeApplied=$null;$script:StayAwakeTouched=$false;$script:StayAwakeEvidence=$null
    $script:StayAwakeRestoreStatus='NOT_CHANGED';$script:StayAwakeRestoration=$null
    $script:NavigationMode='GESTURE';$script:NavigationModeEvidence=[PSCustomObject]@{Mode='GESTURE'}
    $script:HomeKeyOperations=@();$script:HomeKeyTransport=$null;$script:RestrictedHomeStimulus=$null
    $script:DualHomeRestriction=$null;$script:DualHomeCleanup=$null;$script:IsDualHomeDiagnostic=$false;$script:IsVisualCalibration=$false
    $script:VisualRestriction=$null;$script:VisualCleanup=$null;$script:VisualCaptureProcess=$null;$script:VisualCaptureStatus='NOT_STARTED'
    $script:VisualAnalysis=$null;$script:VisualPhases=@();$script:VisualCurrentPhase=$null
    $script:NetworkCapabilities=[PSCustomObject]@{Wifi='PRESENT';MobileData='PRESENT'};$script:NetworkOperations=@()
    $script:FinalizationErrors=@(); $script:SafetyPassed=$false; $script:Offline=$true; $script:CalibrationOnly=$true; $script:HumanCheckpoints=@()
    $script:RecoveryDiagnostic=$false; $script:LabControlReady=$false; $script:Diagnostic=$null; $script:DiagnosticBailout=$null
    $script:DiagnosticFileName='recovery-diagnostic.json'; $script:Safety=$null; $script:SafetyFileName='safety-incomplete.json'
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
    $script:CurrentRow=New-Row 0; $script:CurrentRow.Phase='CALIBRATION'; $script:CurrentRow.AutomatedOracle='FAIL'
    Check-Summary 0 'SETTINGS_RECOVERY'
    Assert-Equal @((Read-Json 'attempts.json')).Count 1
    Assert-Equal (Read-Json 'summary.json').InternalPairedStatistics.P95 $null

    Reset-Run 'interrupted-before-qualification'
    $script:Terminal='INTERRUPTED'; $script:Reason='OPERATOR_STOP'
    Check-Summary 0 'OPERATOR_STOP'
    Assert-Equal @((Read-Json 'attempts.json')).Count 0
    Assert-Equal @(Import-Csv -LiteralPath (Join-Path $runDirectory 'attempts.csv')).Count 0

    Reset-Run 'failure-sample-one'
    $script:CurrentRow=New-Row 1; $script:CurrentRow.AutomatedOracle='FAIL'; $script:CurrentRow.PhysicalObserver='NOT_SAMPLED'; $script:CurrentRow.LatencyMs=$null
    Check-Summary 0 'SETTINGS_RECOVERY'
    Assert-Equal @((Read-Json 'attempts.json')).Count 1

    Reset-Run 'partial-seven'
    $script:Rows=@(1..7 | ForEach-Object { New-Row $_ })
    $script:CurrentRow=New-Row 8; $script:CurrentRow.AutomatedOracle='FAIL'
    Check-Summary 7 'SETTINGS_RECOVERY'
    Assert-Equal @((Read-Json 'attempts.json')).Count 8
    Assert-Equal (Read-Json 'summary.json').InternalPairedStatistics.P95 107

    Reset-Run 'full-one-hundred'
    $script:Rows=@(1..100 | ForEach-Object { New-Row $_ })
    $script:Calibration=New-Row 0; $script:Calibration.Phase='CALIBRATION'
    $script:Terminal='PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY'; $script:Reason='COMPLETED'; $script:SafetyPassed=$true
    $script:HumanCheckpoints=@(
        [PSCustomObject]@{Name='PREFLIGHT_NORMAL_PASS';Result='PASS'},
        [PSCustomObject]@{Name='PREFLIGHT_NEGATIVE_CONTROL';Result='PASS'},
        [PSCustomObject]@{Name='POST_RUN_SAFETY';Result='PASS'}
    )
    $script:CalibrationOnly=$false
    Check-Summary 100 'COMPLETED'
    Assert-Equal @((Read-Json 'attempts.json')).Count 101
    Assert-Equal (Read-Json 'summary.json').InternalPairedStatistics.P95 195
    Assert-Equal (Read-Json 'summary.json').QualificationRequested $true

    # One hundred valid automated rows cannot be pooled/resumed around an invalid third checkpoint.
    Reset-Run 'full-one-hundred-checkpoint-invalid'
    $script:Rows=@(1..100 | ForEach-Object { New-Row $_ })
    $script:Terminal='INVALID';$script:Reason='SCREEN_OR_KEYGUARD';$script:CalibrationOnly=$false
    $script:HumanCheckpoints=@(
        [PSCustomObject]@{Name='PREFLIGHT_NORMAL_PASS';Result='PASS'},
        [PSCustomObject]@{Name='PREFLIGHT_NEGATIVE_CONTROL';Result='PASS'},
        [PSCustomObject]@{Name='POST_RUN_SAFETY';Result='INVALID'}
    )
    Check-Summary 100 'SCREEN_OR_KEYGUARD'
    Assert-Equal (Read-Json 'summary.json').Status 'INVALID'
    Assert-Equal (Read-Json 'summary.json').HumanCheckpointSessions 2
    Assert-Equal (Get-KRAutomatedRunVerdict $script:Rows $script:HumanCheckpoints $true) 'INCOMPLETE'

    Reset-Run 'partial-safety-checkpoint'
    $script:SafetyFileName='safety-calibration.json'
    $script:Safety=[PSCustomObject]@{Phase='calibration';Result='INCOMPLETE';Reason=$null;EndedUtc=$null;HomePhysical='PASS';RecoveryReason='UNRECORDED';ReentryPhysical='UNRECORDED';ClearTouch='UNRECORDED'}
    $script:Reason='SAFETY_CALIBRATION_RECOVERY'
    Check-Summary 0 'SAFETY_CALIBRATION_RECOVERY'
    Assert-Equal (Read-Json 'safety-calibration.json').HomePhysical 'PASS'
    Assert-Equal (Read-Json 'safety-calibration.json').Reason 'SAFETY_CALIBRATION_RECOVERY'

    Reset-Run 'post-observer-oracle-disagreement'
    $script:Calibration=New-Row 0; $script:Calibration.Phase='CALIBRATION'
    $script:Recovery=[PSCustomObject]@{Phase='calibration';PhysicalHomeAndSettings='OWNER_PASS';Oracle='UNCORROBORATED';Reason=$null;EndedUtc=$null}
    $script:Terminal='INVALID'; $script:Reason='SETTINGS_RECOVERY_ORACLE_UNCORROBORATED'
    Check-Summary 0 'SETTINGS_RECOVERY_ORACLE_UNCORROBORATED'
    Assert-Equal (Read-Json 'safety-calibration.json').PhysicalHomeAndSettings 'OWNER_PASS'
    Assert-Equal @(Import-Csv -LiteralPath (Join-Path $runDirectory 'attempts.csv'))[0].PhysicalObserver 'NOT_SAMPLED'

    # A broken higher-level JSON writer cannot block cleanup, CSV, either summary, or alter the primary reason.
    Reset-Run 'writer-failure'
    function Write-JsonFile { param($Name,$Value) throw 'SYNTHETIC_WRITER_FAILURE' }
    $script:CurrentRow=New-Row 1; $script:CurrentRow.AutomatedOracle='FAIL'
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
    function Invoke-LabAdbResult {
        param($Arguments)
        $command=$Arguments -join ' '; $script:Commands+=$command
        if ($command -eq 'shell svc wifi enable') { return [PSCustomObject]@{Stdout='';ExitCode=1;StderrClass='OTHER'} }
        return [PSCustomObject]@{Stdout='1';ExitCode=0;StderrClass='NONE'}
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
    function Invoke-LabAdbResult { param($Arguments) [PSCustomObject]@{Stdout=$(if ($Arguments[-1] -eq 'mobile_data'){'0'}else{'1'});ExitCode=0;StderrClass='NONE'} }
    Complete-LabRun 6>$null
    Assert-Equal (Read-Json 'network-restoration.json').Status 'RESTORED_AND_FLAGS_VERIFIED'
    Assert-Equal (Read-Json 'network-restoration.json').Settings[1].Observed '0'

    # Navigation mode is read-only, current-user scoped and persisted only as a coarse enum.
    Reset-Run 'navigation-mode-gesture'
    $script:SyntheticNavigationMode='2'
    function Invoke-LabAdbResult { param($Arguments) [PSCustomObject]@{Stdout=$script:SyntheticNavigationMode;ExitCode=0;StderrClass='NONE'} }
    Capture-NavigationMode
    Assert-Equal $script:NavigationMode 'GESTURE'
    Assert-Equal (Read-Json 'navigation-mode.json').ParseResult 'VALUE_2'
    Assert-NavigationMode
    Assert-Equal (Read-Json 'navigation-mode.json').VerificationCount 2

    Reset-Run 'navigation-mode-three-button'
    $script:SyntheticNavigationMode='0'
    Capture-NavigationMode
    Assert-Equal $script:NavigationMode 'THREE_BUTTON'
    Assert-Equal (Read-Json 'navigation-mode.json').ParseResult 'VALUE_0'

    Reset-Run 'navigation-mode-unknown'
    $script:SyntheticNavigationMode='unexpected'
    $navigationFailure=$null;try{Capture-NavigationMode}catch{$navigationFailure=$_.Exception.Message}
    Assert-Equal $navigationFailure $null
    Assert-Equal (Read-Json 'navigation-mode.json').Mode 'UNKNOWN'
    Assert-Equal (Read-Json 'navigation-mode.json').ParseResult 'UNPARSEABLE'
    Assert-NavigationMode
    Assert-Equal (Read-Json 'navigation-mode.json').VerificationCount 2

    # The actual host KEYCODE_HOME calibration injects once, requires independent displacement, and returns the fixture.
    $homeBefore=[PSCustomObject]@{schema=2;instance=9;probeReady=$true;probeX=540;probeY=1900;focused=$true;resumed=$true;taps=2;focusGains=3;focusLosses=2}
    $homeAfter=[PSCustomObject]@{schema=2;instance=9;probeReady=$true;probeX=540;probeY=1900;focused=$false;resumed=$false;taps=2;focusGains=3;focusLosses=3}
    $homeReturned=[PSCustomObject]@{schema=2;instance=9;probeReady=$true;probeX=540;probeY=1900;focused=$true;resumed=$true;taps=2;focusGains=4;focusLosses=3}
    Reset-Run 'home-key-positive-control-success'
    $script:HomeFixture=$homeBefore;$script:HomeOpenCount=0;$script:HomeCommandCount=0
    function Open-Fixture { $script:HomeOpenCount++;if($script:HomeOpenCount -gt 1){$script:HomeFixture=$homeReturned} }
    function Wait-FixtureFocus { param($Focused) return $script:HomeFixture }
    function Wait-FixtureDisplacedByHome { return $script:HomeFixture }
    function Get-FixtureState { return $script:HomeFixture }
    function Invoke-LabAdbResult { param($Arguments);$script:HomeCommandCount++;$script:HomeFixture=$homeAfter;return [PSCustomObject]@{Stdout='';ExitCode=0;StderrClass='NONE'} }
    $transport=Invoke-HomeKeyPositiveControl
    Assert-Equal $transport.Status 'CALIBRATED'
    Assert-Equal $transport.Effect 'FIXTURE_DISPLACED_FROM_FOREGROUND_AND_FOCUS'
    Assert-Equal $transport.InvocationCount 1
    Assert-Equal $transport.ReturnToFixture 'VERIFIED'
    Assert-Equal $script:HomeCommandCount 1
    Assert-Equal @($script:HomeKeyOperations).Count 1

    Reset-Run 'home-key-positive-control-rejected'
    $script:HomeFixture=$homeBefore;$script:HomeOpenCount=0;$script:HomeCommandCount=0
    function Open-Fixture { $script:HomeOpenCount++;if($script:HomeOpenCount -gt 1){$script:HomeFixture=$homeReturned} }
    function Invoke-LabAdbResult { param($Arguments);$script:HomeCommandCount++;return [PSCustomObject]@{Stdout='';ExitCode=1;StderrClass='SECURITY_EXCEPTION'} }
    $transport=Invoke-HomeKeyPositiveControl
    Assert-Equal $transport.Status 'REJECTED'
    Assert-Equal $transport.InvocationCount 1
    Assert-Equal $transport.ReturnToFixture 'VERIFIED'
    Assert-Equal (Read-Json 'home-key-operations.json').Result 'REJECTED'

    Reset-Run 'home-key-positive-control-no-effect'
    $script:HomeFixture=$homeBefore;$script:HomeOpenCount=0;$script:HomeCommandCount=0
    function Open-Fixture { $script:HomeOpenCount++;if($script:HomeOpenCount -gt 1){$script:HomeFixture=$homeReturned} }
    function Wait-FixtureDisplacedByHome { throw 'INVALID:HOME_KEY_POSITIVE_CONTROL_NO_EFFECT' }
    function Invoke-LabAdbResult { param($Arguments);$script:HomeCommandCount++;return [PSCustomObject]@{Stdout='';ExitCode=0;StderrClass='NONE'} }
    $transport=Invoke-HomeKeyPositiveControl
    Assert-Equal $transport.Status 'NO_EFFECT'
    Assert-Equal $transport.Effect 'FIXTURE_NOT_DISPLACED'
    Assert-Equal $transport.ReturnToFixture 'VERIFIED'

    # The short diagnostic separately proves shell tap transport and retains only a typed one-count result.
    Reset-Run 'dual-home-shell-input-precondition'
    $script:InputFixture=$homeBefore
    function Open-Fixture {}
    function Wait-FixtureFocus { param($Focused);return $script:InputFixture }
    function Get-FixtureState { return $script:InputFixture }
    function Assert-FixturePositiveControl { param($Before,$FailureCode);$after=$Before.PSObject.Copy();$after.taps=[long]$Before.taps+1;return $after }
    $inputPrecondition=Invoke-DualHomeShellInputPrecondition
    Assert-Equal $inputPrecondition.Result 'FIXTURE_COUNTER_INCREMENTED_ONCE'
    Assert-Equal $inputPrecondition.SameFixture $true
    Assert-Equal $inputPrecondition.TapDelta 1
    Assert-Equal (Read-Json 'shell-input-precondition.json').FixtureRole 'INDEPENDENT_ORDINARY_FIXTURE'

    # Stay-awake setup uses only sanitized setting/power state, verifies each cycle boundary, and restores the exact original value.
    Reset-Run 'stay-awake-restored'
    $script:SyntheticStayAwake=0;$script:SyntheticPowerSource='USB';$script:StayCommands=@();$script:RejectStayEnable=$false;$script:RejectStayRestore=$false
    function Invoke-LabAdbResult {
        param($Arguments)
        $command=$Arguments -join ' ';$script:StayCommands+=$command
        if($command -eq 'shell settings get global stay_on_while_plugged_in'){return [PSCustomObject]@{Stdout=[string]$script:SyntheticStayAwake;ExitCode=0;StderrClass='NONE'}}
        if($command -eq 'shell dumpsys battery'){
            $usb=if($script:SyntheticPowerSource -eq 'USB'){'true'}else{'false'}
            return [PSCustomObject]@{Stdout="AC powered: false`nUSB powered: $usb`nWireless powered: false`nDock powered: false";ExitCode=0;StderrClass='NONE'}
        }
        if($command -eq 'shell svc power stayon true'){
            if($script:RejectStayEnable){return [PSCustomObject]@{Stdout='';ExitCode=1;StderrClass='PERMISSION_DENIAL'}}
            $script:SyntheticStayAwake=15;return [PSCustomObject]@{Stdout='';ExitCode=0;StderrClass='NONE'}
        }
        if($command -like 'shell settings put global stay_on_while_plugged_in *'){
            if($script:RejectStayRestore){return [PSCustomObject]@{Stdout='';ExitCode=1;StderrClass='PERMISSION_DENIAL'}}
            $script:SyntheticStayAwake=[int]$Arguments[-1];return [PSCustomObject]@{Stdout='';ExitCode=0;StderrClass='NONE'}
        }
        throw 'UNEXPECTED_DEVICE_COMMAND_IN_UNIT_TEST'
    }
    Enter-StayAwake
    Assert-Equal $script:StayAwakeEvidence.Establishment 'VERIFIED'
    Assert-Equal $script:StayAwakeEvidence.PowerSourceAfter 'USB'
    Assert-StayAwake
    Assert-Equal $script:StayAwakeEvidence.VerificationCount 2
    Restore-StayAwake
    Assert-Equal $script:SyntheticStayAwake 0
    Assert-Equal $script:StayAwakeRestoreStatus 'RESTORED_AND_SETTING_VERIFIED'

    # An already-enabled/awake device is verified without an unnecessary mutation.
    Reset-Run 'stay-awake-already-enabled'
    $script:SyntheticStayAwake=15;$script:SyntheticPowerSource='USB';$script:StayCommands=@();$script:RejectStayEnable=$false;$script:RejectStayRestore=$false
    Enter-StayAwake
    Assert-Equal $script:StayAwakeTouched $false
    Assert-Equal ($script:StayCommands -contains 'shell svc power stayon true') $false

    # Enable rejection, post-enable mismatch, unplug/timeout and restoration rejection all remain fail closed.
    Reset-Run 'stay-awake-enable-rejected'
    $script:SyntheticStayAwake=0;$script:SyntheticPowerSource='USB';$script:RejectStayEnable=$true;$script:RejectStayRestore=$false
    $stayFailure=$null;try{Enter-StayAwake}catch{$stayFailure=$_.Exception.Message}
    Assert-Equal $stayFailure 'INVALID:STAY_AWAKE_ENABLE_FAILED'
    Restore-StayAwake
    Assert-Equal $script:StayAwakeRestoreStatus 'RESTORED_AND_SETTING_VERIFIED'

    Reset-Run 'stay-awake-verification-failed'
    $script:SyntheticStayAwake=0;$script:SyntheticPowerSource='USB';$script:RejectStayEnable=$false;$script:RejectStayRestore=$false
    function Invoke-LabAdbResult {
        param($Arguments)
        $command=$Arguments -join ' '
        if($command -eq 'shell settings get global stay_on_while_plugged_in'){return [PSCustomObject]@{Stdout='0';ExitCode=0;StderrClass='NONE'}}
        if($command -eq 'shell dumpsys battery'){return [PSCustomObject]@{Stdout="AC powered: false`nUSB powered: true`nWireless powered: false`nDock powered: false";ExitCode=0;StderrClass='NONE'}}
        return [PSCustomObject]@{Stdout='';ExitCode=0;StderrClass='NONE'}
    }
    $stayFailure=$null;try{Enter-StayAwake}catch{$stayFailure=$_.Exception.Message}
    Assert-Equal $stayFailure 'INVALID:STAY_AWAKE_VERIFICATION_FAILED'

    $state=[PSCustomObject]@{Setting=15;PowerSource='UNPLUGGED';PlugMask=0}
    $stayFailure=$null;try{Assert-KRStayAwakeState $state}catch{$stayFailure=$_.Exception.Message}
    Assert-Equal $stayFailure 'INVALID:STAY_AWAKE_VERIFICATION_FAILED'

    Reset-Run 'stay-awake-restore-failed'
    $script:SyntheticStayAwake=0;$script:SyntheticPowerSource='USB';$script:RejectStayEnable=$false;$script:RejectStayRestore=$true
    # Replace only the external process boundary for this synthetic restoration test.
    function Invoke-LabAdbResult {
        param($Arguments)
        $command=$Arguments -join ' '
        if($command -eq 'shell settings get global stay_on_while_plugged_in'){return [PSCustomObject]@{Stdout=[string]$script:SyntheticStayAwake;ExitCode=0;StderrClass='NONE'}}
        if($command -eq 'shell dumpsys battery'){return [PSCustomObject]@{Stdout="AC powered: false`nUSB powered: true`nWireless powered: false`nDock powered: false";ExitCode=0;StderrClass='NONE'}}
        if($command -eq 'shell svc power stayon true'){$script:SyntheticStayAwake=15;return [PSCustomObject]@{Stdout='';ExitCode=0;StderrClass='NONE'}}
        if($command -like 'shell settings put global stay_on_while_plugged_in *'){return [PSCustomObject]@{Stdout='';ExitCode=1;StderrClass='PERMISSION_DENIAL'}}
    }
    Enter-StayAwake;Restore-StayAwake
    Assert-Equal $script:StayAwakeRestoreStatus 'RESTORE_FAILED_OWNER_ACTION_REQUIRED'
    $script:Terminal='INVALID';$script:Reason='SCREEN_OR_KEYGUARD';Complete-LabRun 6>$null
    Assert-Equal (Read-Json 'summary.json').Status 'INVALID'
    Assert-Equal (Read-Json 'summary.json').Reason 'SCREEN_OR_KEYGUARD'
    Assert-Equal ((Read-Json 'summary.json').FinalizationErrors -contains 'STAY_AWAKE_UNVERIFIED') $true

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

    # A correlated SAFE_SYSTEM/removal is invalidated by later ordinary-app reattachment.
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
    Assert-Equal $phase.Oracle 'REGRESSED_TO_ORDINARY'
    Assert-Equal $phase.Reason 'SAFE_TRANSITION_DID_NOT_PERSIST'
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

    # Control-unavailable cannot proceed without the separate successful host Home calibration.
    Reset-Run 'home-control-unavailable-without-calibration'
    $script:SafetyFileName='safety-final.json'
    $script:Safety=[PSCustomObject]@{Phase='final';HomeGateResult='UNRECORDED';HomeActionResult='UNRECORDED';HomeResultSource='NONE'}
    $script:HomeKeyTransport=[PSCustomObject]@{Status='NO_EFFECT';InvocationCount=1;ReturnToFixture='VERIFIED'}
    $homeCalibrationFailure=$null;try{Invoke-RestrictedHomeKeyStimulus}catch{$homeCalibrationFailure=$_.Exception.Message}
    Assert-Equal $homeCalibrationFailure 'INVALID:HOME_KEY_TRANSPORT_NOT_CALIBRATED'
    Assert-Equal $script:Safety.HomeGateResult 'INVALID'
    Assert-Equal $script:Safety.HomeActionResult 'HOME_CONTROL_UNAVAILABLE_WITHOUT_CALIBRATED_STIMULUS'

    # Restricted-stimulus failures are preserved as automated Path B failures, not owner responses.
    $restrictedFrame=[PSCustomObject]@{elapsed=20000;sampledAt=19990;revision=42;sampledRevision=42;restriction=$true;attached=$true;adapter='APPLIED';disposition='ORDINARY_APP';removals=0;heartbeat=$true;usage=$true;accessibility=$true;uncertain=$false;eligible=$true;eligibilityLost=$false}
    $restrictedBaseline=[PSCustomObject]@{schema=2;instance=1;probeReady=$true;probeX=540;probeY=1900;focused=$false;resumed=$true;taps=0;focusGains=1;focusLosses=1}
    Reset-Run 'home-restricted-focus-regain'
    $script:SafetyFileName='safety-final.json';$script:Safety=[PSCustomObject]@{Revision=42;LastElapsed=0;HoldOracle='PENDING';HomeGateResult='UNRECORDED';HomeActionResult='UNRECORDED';HomeResultSource='OWNER_CONTROL_UNAVAILABLE'}
    $script:RestrictedHomeStimulus=[PSCustomObject]@{FixtureTapsBefore=0;FixtureBaseline=$restrictedBaseline;ObservationCount=0;Status='AUTOMATED_HOLD_VERIFIED'}
    function Get-LabState { return $restrictedFrame }
    function Get-FixtureState { $current=$restrictedBaseline.PSObject.Copy();$current.focused=$true;$current.focusGains=2;return $current }
    $restrictedFailure=$null;try{Poll-RestrictedHomeStimulusHold}catch{$restrictedFailure=$_.Exception.Message}
    Assert-Equal $restrictedFailure 'FAIL:HOME_STIMULUS_FIXTURE_FOCUS_REGAIN'
    Assert-Equal $script:Safety.HomeGateResult 'FAIL'
    Assert-Equal $script:Safety.HomeResultSource 'AUTOMATED_HOLD_ORACLE_AFTER_HOST_STIMULUS'

    Reset-Run 'home-restricted-restriction-loss'
    $script:SafetyFileName='safety-final.json';$script:Safety=[PSCustomObject]@{Revision=42;LastElapsed=0;HoldOracle='PENDING';HomeGateResult='UNRECORDED';HomeActionResult='UNRECORDED';HomeResultSource='OWNER_CONTROL_UNAVAILABLE'}
    $script:RestrictedHomeStimulus=[PSCustomObject]@{FixtureTapsBefore=0;FixtureBaseline=$restrictedBaseline;ObservationCount=0;Status='AUTOMATED_HOLD_VERIFIED'}
    $restrictedFrame.attached=$false
    function Get-FixtureState { return $restrictedBaseline }
    $restrictedFailure=$null;try{Poll-RestrictedHomeStimulusHold}catch{$restrictedFailure=$_.Exception.Message}
    Assert-Equal $restrictedFailure 'FAIL:RESTRICTION_LOST'
    Assert-Equal $script:Safety.HomeActionResult 'HOME_ESCAPE_PATH_ESTABLISHED_WITH_CONTROL_UNAVAILABLE'

    # Q7 final safety orchestration remains one human checkpoint session and adds zero expiry samples.
    Reset-Run 'q7-safety-checkpoint'
    $script:Bundle=[PSCustomObject]@{protocol='KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION'}
    $script:ClearMode=$false; $script:OpenCount=0; $script:FixtureReadAfterClear=0
    function New-SafetyFrame([bool]$Restricted) {
        [PSCustomObject]@{
            elapsed=20000;sampledAt=19990;revision=42;sampledRevision=42;restriction=$Restricted;armed=$Restricted
            attached=$Restricted;disposition=$(if($Restricted){'ORDINARY_APP'}else{'ORDINARY_APP'});heartbeat=$true;usage=$true
            accessibility=$true;uncertain=$false;eligible=$true;eligibilityLost=$false;adapter=$(if($Restricted){'APPLIED'}else{'NOT_REQUIRED'})
            removals=0;samples=@(123);sampleCount=1;traceHead=20;traceLost=$false;events=@()
        }
    }
    function Get-LabState { param($Operation='SNAPSHOT') if($Operation -eq 'CLEAR'){$script:ClearMode=$true}; return New-SafetyFrame (-not $script:ClearMode) }
    function Get-FixtureState {
        if($script:ClearMode -and $script:OpenCount -ge 2) { $script:FixtureReadAfterClear++; $taps=$(if($script:FixtureReadAfterClear -gt 1){1}else{0}) } else { $taps=0 }
        [PSCustomObject]@{schema=2;focused=$false;resumed=$true;taps=$taps;instance=1;probeReady=$true;probeX=540;probeY=1900;focusGains=1;focusLosses=1;lastFocusChange=1}
    }
    function Open-Fixture { $script:OpenCount++ }
    function Wait-FixtureFocus { param($Focused) }
    function Assert-FixturePositiveControl { param($Before,$FailureCode); $copy=$Before.PSObject.Copy(); $copy.taps=$Before.taps+1; return $copy }
    function Wait-LabCondition { param($Condition,$FailureCode,$TimeoutSeconds) return New-SafetyFrame (-not $script:ClearMode) }
    $script:DelayedPromptPolls=0
    $script:HomeControlPrompts=@();$script:HomeActionPrompts=@()
    function Read-HomeControlExercisability { param($Prompt,$Poll,$OnObserved); $script:HomeControlPrompts+=$Prompt;if($null -ne $Poll){& $Poll|Out-Null};if($null -ne $OnObserved){& $OnObserved 'AVAILABLE'};return 'AVAILABLE' }
    function Read-DiagnosticResult { param($Prompt,$Poll,$OnObserved,$MinimumPassSeconds,$PassReady); $script:HomeActionPrompts+=$Prompt;if($null -ne $Poll){1..3|ForEach-Object{$script:DelayedPromptPolls++;& $Poll | Out-Null}}; if($null -ne $OnObserved){& $OnObserved 'PASS'}; return 'PASS' }
    function Invoke-FocusedRecoveryDiagnostic { param($OutputName); $script:Diagnostic=[PSCustomObject]@{Result='EVIDENCE_CAPTURED';Reason='PHYSICAL_PASS_RECORDED'} }
    function Check-EarlyStop {}
    function Start-Sleep {}
    function Assert-StayAwake {}
    function Assert-NavigationMode {}
    Invoke-QualificationSafetyCheckpoint -Phase 'final' 6>$null
    $safety=Read-Json 'safety-final.json'
    Assert-Equal $safety.FinalVisibilityPhysical 'PASS'
    Assert-Equal $safety.HomePhysical 'PASS'
    Assert-Equal $safety.NavigationMode 'GESTURE'
    Assert-Equal $safety.NavigationModeClassification 'NAV_MODE_GESTURE'
    Assert-Equal $safety.HomeControlExercisability 'AVAILABLE'
    Assert-Equal $safety.HomeControlSource 'OWNER_RESPONSE'
    Assert-Equal $safety.HomeActionState 'HOME_ACTION_EXERCISED'
    Assert-Equal $safety.HomeActionOutcome 'HOME_ACTION_RESISTED'
    Assert-Equal $safety.HomeActionResult 'HOME_ACTION_EXERCISED_AND_RESISTED'
    Assert-Equal $safety.HomeEvidencePath 'PATH_A_PHYSICAL_HOME_ACTION'
    Assert-Equal $safety.HomeGateResult 'PASS'
    Assert-Equal $safety.HomeResultSource 'OWNER_RESPONSE'
    Assert-Equal $safety.RecoveryReason 'PHYSICAL_PASS_RECORDED'
    Assert-Equal $safety.ReentryPhysical 'PASS'
    Assert-Equal $safety.ClearTouch 'FIXTURE_COUNTER_INCREMENT'
    Assert-Equal $safety.IndependentExpirySamples 0
    Assert-Equal $safety.Result 'PHYSICAL_PASS_RECORDED'
    Assert-Equal ($script:DelayedPromptPolls -ge 3) $true
    Assert-Equal $script:HomeControlPrompts.Count 1
    Assert-Equal ([bool]($script:HomeControlPrompts[0] -match 'navigation mode is context only')) $true
    Assert-Equal @($script:HomeActionPrompts | Where-Object { $_ -match 'PHYSICAL HOME ACTION.*swipe up once' }).Count 1
    Assert-Equal $script:HumanCheckpoints.Count 1
    Assert-Equal $script:HumanCheckpoints[0].Name 'POST_RUN_SAFETY'

    # The excluded diagnostic invokes the same Path A checkpoint code but stops before recovery and creates no rows.
    Reset-Run 'dual-home-diagnostic-path-a'
    $script:IsDualHomeDiagnostic=$true
    $script:Bundle=[PSCustomObject]@{protocol='KR003-DUAL-HOME-CALIBRATION-DIAGNOSTIC'}
    $script:NavigationMode='GESTURE';$script:ClearMode=$false;$script:OpenCount=0;$script:FixtureReadAfterClear=0
    $script:HomeControlPrompts=@();$script:HomeActionPrompts=@()
    function Read-HomeControlExercisability { param($Prompt,$Poll,$OnObserved);$script:HomeControlPrompts+=$Prompt;if($null -ne $Poll){&$Poll|Out-Null};if($null -ne $OnObserved){&$OnObserved 'AVAILABLE'};return 'AVAILABLE' }
    Invoke-QualificationSafetyCheckpoint -Phase 'diagnostic' -HomeOnly 6>$null
    $diagnosticSafety=Read-Json 'safety-diagnostic.json'
    Assert-Equal $diagnosticSafety.Phase 'diagnostic'
    Assert-Equal $diagnosticSafety.Result 'HOME_DIAGNOSTIC_PASS_RECORDED'
    Assert-Equal $diagnosticSafety.HomeActionResult 'HOME_ACTION_EXERCISED_AND_RESISTED'
    Assert-Equal $diagnosticSafety.RecoveryReason 'UNRECORDED'
    Assert-Equal $script:Rows.Count 0
    Assert-Equal $script:HumanCheckpoints.Count 0

    # The same Path A orchestration gives a button instruction only after THREE_BUTTON is physically available.
    Reset-Run 'q7-three-button-control-available'
    $script:Bundle=[PSCustomObject]@{protocol='KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION'}
    $script:NavigationMode='THREE_BUTTON';$script:ClearMode=$false;$script:OpenCount=0;$script:FixtureReadAfterClear=0
    $script:HomeControlPrompts=@();$script:HomeActionPrompts=@()
    function Read-HomeControlExercisability { param($Prompt,$Poll,$OnObserved);$script:HomeControlPrompts+=$Prompt;if($null -ne $Poll){&$Poll|Out-Null};if($null -ne $OnObserved){&$OnObserved 'AVAILABLE'};return 'AVAILABLE' }
    Invoke-QualificationSafetyCheckpoint -Phase 'final' 6>$null
    Assert-Equal @($script:HomeActionPrompts | Where-Object { $_ -match 'PHYSICAL HOME ACTION.*tap the on-screen Home button once' }).Count 1
    Assert-Equal (Read-Json 'safety-final.json').HomeActionResult 'HOME_ACTION_EXERCISED_AND_RESISTED'

    # Unknown exercisability fails closed before either Home path starts.
    Reset-Run 'q7-home-control-unknown'
    $script:Bundle=[PSCustomObject]@{protocol='KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION'}
    $script:NavigationMode='THREE_BUTTON';$script:ClearMode=$false;$script:OpenCount=0;$script:FixtureReadAfterClear=0
    $script:HomeControlPrompts=@();$script:HomeActionPrompts=@()
    function Read-HomeControlExercisability { param($Prompt,$Poll,$OnObserved);$script:HomeControlPrompts+=$Prompt;if($null -ne $Poll){&$Poll|Out-Null};if($null -ne $OnObserved){&$OnObserved 'UNKNOWN'};return 'UNKNOWN' }
    $controlFailure=$null;try{Invoke-QualificationSafetyCheckpoint -Phase 'final' 6>$null}catch{$controlFailure=$_.Exception.Message}
    Assert-Equal $controlFailure 'INVALID:SAFETY_FINAL_HOME_CONTROL_UNKNOWN'
    Assert-Equal (Read-Json 'safety-final.json').HomeGateResult 'INVALID'
    Assert-Equal @($script:HomeActionPrompts | Where-Object { $_ -match 'PHYSICAL HOME ACTION|HOME CONTROL UNAVAILABLE CHECK' }).Count 0

    # THREE_BUTTON is a mode signal only: unavailable control takes the distinct calibrated host-stimulus path.
    Reset-Run 'q7-three-button-control-unavailable'
    $script:Bundle=[PSCustomObject]@{protocol='KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION'}
    $script:NavigationMode='THREE_BUTTON';$script:ClearMode=$false;$script:OpenCount=0;$script:FixtureReadAfterClear=0
    $script:HomeKeyTransport=[PSCustomObject]@{Status='CALIBRATED';InvocationCount=1;ReturnToFixture='VERIFIED'}
    $script:HomeControlPrompts=@();$script:HomeActionPrompts=@()
    function Read-HomeControlExercisability { param($Prompt,$Poll,$OnObserved);$script:HomeControlPrompts+=$Prompt;if($null -ne $Poll){&$Poll|Out-Null};if($null -ne $OnObserved){&$OnObserved 'UNAVAILABLE'};return 'UNAVAILABLE' }
    function Read-DiagnosticResult { param($Prompt,$Poll,$OnObserved,$MinimumPassSeconds,$PassReady);$script:HomeActionPrompts+=$Prompt;if($null -ne $Poll){&$Poll|Out-Null};if($null -ne $OnObserved){&$OnObserved 'PASS'};return 'PASS' }
    function Invoke-RestrictedHomeKeyStimulus {
        $script:RestrictedHomeStimulus=[PSCustomObject]@{Status='AUTOMATED_HOLD_VERIFIED';OwnerObservation='UNRECORDED';OwnerObservedUtc=$null}
    }
    function Poll-RestrictedHomeStimulusHold { return New-SafetyFrame $true }
    Invoke-QualificationSafetyCheckpoint -Phase 'final' 6>$null
    $safety=Read-Json 'safety-final.json'
    Assert-Equal $safety.NavigationModeClassification 'NAV_MODE_THREE_BUTTON'
    Assert-Equal $safety.HomeControlExercisability 'UNAVAILABLE'
    Assert-Equal $safety.HomeActionState 'HOME_ACTION_NOT_EXERCISABLE'
    Assert-Equal $safety.HomeActionOutcome 'UNRECORDED'
    Assert-Equal $safety.HomePhysical 'CONTROL_UNAVAILABLE'
    Assert-Equal $safety.HomeStimulusPhysical 'PASS'
    Assert-Equal $safety.HomeGateResult 'PASS'
    Assert-Equal $safety.HomeActionResult 'HOME_ESCAPE_PATH_BLOCKED_WITH_CONTROL_UNAVAILABLE'
    Assert-Equal $safety.HomeResultSource 'OWNER_RESPONSE_PLUS_INDEPENDENT_HOST_STIMULUS'
    Assert-Equal @($script:HomeActionPrompts | Where-Object { $_ -match 'PHYSICAL HOME ACTION' }).Count 0
    Assert-Equal @($script:HomeActionPrompts | Where-Object { $_ -match 'HOME CONTROL UNAVAILABLE CHECK' }).Count 1

    # The excluded diagnostic invokes the exact same Path B code and retains its distinct non-physical result.
    Reset-Run 'dual-home-diagnostic-path-b'
    $script:IsDualHomeDiagnostic=$true
    $script:Bundle=[PSCustomObject]@{protocol='KR003-DUAL-HOME-CALIBRATION-DIAGNOSTIC'}
    $script:NavigationMode='THREE_BUTTON';$script:ClearMode=$false;$script:OpenCount=0;$script:FixtureReadAfterClear=0
    $script:HomeKeyTransport=[PSCustomObject]@{Status='CALIBRATED';InvocationCount=1;ReturnToFixture='VERIFIED'}
    $script:HomeControlPrompts=@();$script:HomeActionPrompts=@()
    function Read-HomeControlExercisability { param($Prompt,$Poll,$OnObserved);$script:HomeControlPrompts+=$Prompt;if($null -ne $Poll){&$Poll|Out-Null};if($null -ne $OnObserved){&$OnObserved 'UNAVAILABLE'};return 'UNAVAILABLE' }
    Invoke-QualificationSafetyCheckpoint -Phase 'diagnostic' -HomeOnly 6>$null
    $diagnosticSafety=Read-Json 'safety-diagnostic.json'
    Assert-Equal $diagnosticSafety.HomeEvidencePath 'PATH_B_CONTROL_UNAVAILABLE_HOST_STIMULUS'
    Assert-Equal $diagnosticSafety.HomePhysical 'CONTROL_UNAVAILABLE'
    Assert-Equal $diagnosticSafety.HomeActionResult 'HOME_ESCAPE_PATH_BLOCKED_WITH_CONTROL_UNAVAILABLE'
    Assert-Equal $diagnosticSafety.HomeActionOutcome 'UNRECORDED'
    Assert-Equal $script:Rows.Count 0

    # Owner outcomes remain distinct from an automated hold-oracle failure and from no exercisable Home action.
    Reset-Run 'home-owner-outcomes'
    $script:SafetyFileName='safety-final.json'
    $script:Safety=[PSCustomObject]@{NavigationModeClassification='NAV_MODE_THREE_BUTTON';HomeControlExercisability='UNKNOWN';HomeControlSource='NONE';HomeControlObservedUtc=$null;HomeEvidencePath='UNRESOLVED';HomeGateResult='UNRECORDED';HomePhysical='UNRECORDED';HomeActionResult='UNRECORDED';HomeActionState='HOME_ACTION_NOT_EXERCISED';HomeActionOutcome='UNRECORDED';HomeResultSource='NONE';HomeObservedUtc=$null}
    Set-HomeControlObservation 'AVAILABLE'
    Assert-Equal $script:Safety.HomeControlExercisability 'AVAILABLE'
    Assert-Equal $script:Safety.HomeActionState 'HOME_ACTION_NOT_EXERCISED'
    Set-HomeActionObservation 'PASS'
    Assert-Equal $script:Safety.HomeActionState 'HOME_ACTION_EXERCISED'
    Assert-Equal $script:Safety.HomeActionOutcome 'HOME_ACTION_RESISTED'
    $script:Safety.HomePhysical='UNRECORDED';$script:Safety.HomeActionResult='UNRECORDED';$script:Safety.HomeActionState='HOME_ACTION_NOT_EXERCISED';$script:Safety.HomeActionOutcome='UNRECORDED';$script:Safety.HomeResultSource='NONE'
    Set-HomeActionObservation 'FAIL'
    Assert-Equal $script:Safety.HomePhysical 'FAIL'
    Assert-Equal $script:Safety.HomeActionResult 'HOME_ACTION_EXERCISED_AND_ESCAPED'
    Assert-Equal $script:Safety.HomeActionState 'HOME_ACTION_EXERCISED'
    Assert-Equal $script:Safety.HomeActionOutcome 'HOME_ACTION_ESCAPED'
    Assert-Equal $script:Safety.HomeResultSource 'OWNER_RESPONSE'
    $script:Safety.HomePhysical='UNRECORDED';$script:Safety.HomeActionResult='UNRECORDED';$script:Safety.HomeResultSource='NONE'
    Set-HomeActionObservation 'INVALID'
    Assert-Equal $script:Safety.HomeActionResult 'HOME_ACTION_RESULT_UNCERTAIN'
    Assert-Equal $script:Safety.HomeActionState 'HOME_ACTION_UNKNOWN'

    # A known navigation mode never establishes control availability. Unavailable and unknown stop before an action.
    Reset-Run 'home-control-exercisability'
    $script:SafetyFileName='safety-final.json'
    $script:Safety=[PSCustomObject]@{HomeControlExercisability='UNKNOWN';HomeControlSource='NONE';HomeControlObservedUtc=$null;HomeEvidencePath='UNRESOLVED';HomeGateResult='UNRECORDED';HomePhysical='UNRECORDED';HomeActionResult='UNRECORDED';HomeActionState='HOME_ACTION_NOT_EXERCISED';HomeActionOutcome='UNRECORDED';HomeResultSource='NONE';HomeObservedUtc=$null}
    Set-HomeControlObservation 'UNAVAILABLE'
    Assert-Equal $script:Safety.HomeControlExercisability 'UNAVAILABLE'
    Assert-Equal $script:Safety.HomeActionState 'HOME_ACTION_NOT_EXERCISABLE'
    Assert-Equal $script:Safety.HomeActionOutcome 'UNRECORDED'
    Assert-Equal $script:Safety.HomePhysical 'CONTROL_UNAVAILABLE'
    Assert-Equal $script:Safety.HomeEvidencePath 'PATH_B_CONTROL_UNAVAILABLE_HOST_STIMULUS'
    $script:Safety.HomePhysical='UNRECORDED';$script:Safety.HomeActionResult='UNRECORDED';$script:Safety.HomeActionState='HOME_ACTION_NOT_EXERCISED';$script:Safety.HomeResultSource='NONE'
    Set-HomeControlObservation 'UNKNOWN'
    Assert-Equal $script:Safety.HomeControlExercisability 'UNKNOWN'
    Assert-Equal $script:Safety.HomeActionState 'HOME_ACTION_UNKNOWN'

    Reset-Run 'home-automated-loss-before-response'
    $script:SafetyFileName='safety-final.json'
    $script:Safety=[PSCustomObject]@{CurrentStep='HOME_ACTION';Revision=42;FixtureTaps=0;LastElapsed=0;HoldOracle='PENDING';HomePhysical='UNRECORDED';HomeActionResult='UNRECORDED';HomeActionState='HOME_ACTION_NOT_EXERCISED';HomeActionOutcome='UNRECORDED';HomeResultSource='NONE';HomeObservedUtc=$null}
    function Get-LabState {
        $frame=New-SafetyFrame $true;$frame.revision=42;$frame.sampledRevision=42;$frame.attached=$false;$frame.removals=1
        return $frame
    }
    function Get-FixtureState { [PSCustomObject]@{focused=$false;resumed=$true;taps=0} }
    $homeFailure=$null;try{Poll-SafetyHold}catch{$homeFailure=$_.Exception.Message}
    Assert-Equal $homeFailure 'FAIL:RESTRICTION_LOST'
    Assert-Equal $script:Safety.HomePhysical 'UNRECORDED'
    Assert-Equal $script:Safety.HomeActionResult 'UNRECORDED'
    Assert-Equal $script:Safety.HomeResultSource 'AUTOMATED_HOLD_ORACLE'

    Reset-Run 'home-out-of-sequence-settings-action'
    $script:SafetyFileName='safety-final.json'
    $script:Safety=[PSCustomObject]@{CurrentStep='HOME_ACTION';Revision=42;FixtureTaps=0;LastElapsed=0;HoldOracle='PENDING';HomePhysical='UNRECORDED';HomeActionResult='UNRECORDED';HomeActionState='HOME_ACTION_NOT_EXERCISED';HomeActionOutcome='UNRECORDED';HomeResultSource='NONE';HomeObservedUtc=$null}
    function Get-LabState {
        $frame=New-SafetyFrame $true
        $frame.events=@([PSCustomObject]@{line='t=21000 kind=recovery_open_requested trigger=settings_button eventType=-1 identity=NONE disposition=ORDINARY_APP nextDisposition=ORDINARY_APP restriction=true overlay=ATTACHED adapter=APPLIED nextAdapter=APPLIED revision=42'})
        return $frame
    }
    $homeFailure=$null;try{Poll-SafetyHold}catch{$homeFailure=$_.Exception.Message}
    Assert-Equal $homeFailure 'INVALID:HOME_ACTION_NOT_EXERCISED'
    Assert-Equal $script:Safety.HomePhysical 'UNRECORDED'
    Assert-Equal $script:Safety.HomeActionResult 'HOME_ACTION_RESULT_UNCERTAIN'
    Assert-Equal $script:Safety.HomeResultSource 'OUT_OF_SEQUENCE_SETTINGS_ACTION'

    # Diagnostic CLEAR changes only timer state and preserves the complete latency sample array.
    Reset-Run 'diagnostic-bailout'
    $script:RecoveryDiagnostic=$false; $script:LabControlReady=$true; $script:BailoutCleared=$false
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

    # One excluded diagnostic restriction establishes the ordinary-surface hold without creating a row.
    Reset-Run 'dual-home-restriction-zero-rows'
    $script:IsDualHomeDiagnostic=$true;$script:LastRevision=-1;$script:ServiceConnections=0
    function New-DualHomeFrame([bool]$Restricted,[bool]$Attached,[int]$SampleCount) {
        [PSCustomObject]@{
            elapsed=20000;sampledAt=19990;revision=42;sampledRevision=$(if($Attached){42}else{41});recordedRevision=$(if($Attached){42}else{41})
            remaining=$(if($Restricted -and -not $Attached){10000}else{0});restriction=$Restricted;armed=$Restricted;attached=$Attached
            disposition='ORDINARY_APP';heartbeat=$true;usage=$true;accessibility=$true;uncertain=$false;eligible=$true;eligibilityLost=$false
            adapter=$(if($Attached){'APPLIED'}else{'NOT_REQUIRED'});removals=0;samples=$(if($SampleCount -eq 2){@(123,234)}else{@(123)});sampleCount=$SampleCount
            traceHead=20;traceLost=$false;events=@()
        }
    }
    $normalFixture=[PSCustomObject]@{schema=2;instance=1;probeReady=$true;probeX=540;probeY=1900;focused=$true;resumed=$true;taps=7;focusGains=2;focusLosses=1;lastFocusChange=1}
    $blockedFixture=$normalFixture.PSObject.Copy();$blockedFixture.focused=$false;$blockedFixture.focusLosses=2
    function Clear-ToOrdinary {}
    function Get-LabState { param($Operation='SNAPSHOT');if($Operation -eq 'ARM'){return New-DualHomeFrame $true $false 1};return New-DualHomeFrame $false $false 1 }
    function Wait-LabCondition { param($Condition,$FailureCode,$TimeoutSeconds);return New-DualHomeFrame $true $true 2 }
    function Get-FixtureState { return $normalFixture }
    function Wait-FixtureFocus { param($Focused);if($Focused){return $normalFixture};return $blockedFixture }
    function Assert-QualificationPermissionState { param($Snapshot) }
    $restriction=Invoke-DualHomeDiagnosticRestriction
    Assert-Equal $restriction.Status 'RESTRICTION_ESTABLISHED'
    Assert-Equal $restriction.QualificationRows 0
    Assert-Equal $restriction.Time04Rows 0
    Assert-Equal $restriction.AttachmentLatencyMs 234
    Assert-Equal $restriction.FixtureFocused $false
    Assert-Equal $script:Rows.Count 0
    Assert-Equal @((Read-Json 'attempts.json')).Count 0

    # Diagnostic cleanup verifies candidate release, healthy permissions and ordinary fixture input without uninstall/clear-data.
    Reset-Run 'dual-home-cleanup'
    $script:IsDualHomeDiagnostic=$true;$script:LabControlReady=$true
    $released=New-DualHomeFrame $false $false 1
    function Get-LabState { param($Operation='SNAPSHOT');return $released }
    function Wait-LabCondition { param($Condition,$FailureCode,$TimeoutSeconds);return $released }
    function Open-Fixture {}
    function Wait-FixtureFocus { param($Focused);return $normalFixture }
    function Assert-FixturePositiveControl { param($Before,$FailureCode);$after=$Before.PSObject.Copy();$after.taps=[long]$Before.taps+1;return $after }
    Invoke-DualHomeDiagnosticCleanup
    $cleanup=Read-Json 'dual-home-cleanup.json'
    Assert-Equal $cleanup.Status 'VERIFIED'
    Assert-Equal $cleanup.CandidateState 'UNARMED_UNRESTRICTED_UNATTACHED'
    Assert-Equal $cleanup.CandidateHealth 'HEALTHY_ELIGIBLE'
    Assert-Equal $cleanup.FixtureOrdinaryUse 'FOCUSED_RESUMED_TAP_VERIFIED'
    $permissionFunction=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-QualificationPermissionState'},$true)
    Invoke-Expression $permissionFunction.Extent.Text

    # The version-compatible shell verifier agrees with healthy telemetry, then treats revocation after establishment as FAIL.
    Reset-Run 'qualification-permission-verification'
    $script:candidatePackage='dev.kidremote.spike.enforcement'
    $script:candidateService='dev.kidremote.spike.enforcement/.EnforcementAccessibilityService'
    $script:RequiredPermissionsEstablished=$false
    $permissionSnapshot=New-SafetyFrame $false
    function Invoke-LabAdb {
        param($Arguments)
        $command=$Arguments -join ' '
        if($command -like '*appops*'){return 'GET_USAGE_STATS: allow'}
        if($command -like '*enabled_accessibility_services*'){return 'dev.kidremote.spike.enforcement/dev.kidremote.spike.enforcement.EnforcementAccessibilityService'}
        if($command -like '*accessibility_enabled*'){return '1'}
        throw 'UNEXPECTED_DEVICE_COMMAND_IN_UNIT_TEST'
    }
    Assert-QualificationPermissionState $permissionSnapshot
    Assert-Equal $script:RequiredPermissionsEstablished $true
    Assert-Equal (Read-Json 'permission-verification.json').CandidateHealth 'HEALTHY'
    function Invoke-LabAdb {
        param($Arguments)
        $command=$Arguments -join ' '
        if($command -like '*appops*'){return 'GET_USAGE_STATS: ignore'}
        if($command -like '*enabled_accessibility_services*'){return 'null'}
        if($command -like '*accessibility_enabled*'){return '0'}
        throw 'UNEXPECTED_DEVICE_COMMAND_IN_UNIT_TEST'
    }
    $permissionFailure=$null
    try{Assert-QualificationPermissionState $permissionSnapshot}catch{$permissionFailure=$_.Exception.Message}
    Assert-Equal $permissionFailure 'FAIL:PERMISSION_OR_SERVICE_LOST'

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
    Assert-Equal ([bool]($bailoutSource -match 'KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION')) $true
    Assert-Equal ([bool]($bailoutSource -match 'KR003-VISUAL-CHANNEL-CALIBRATION')) $true
    Assert-Equal ([bool]($bailoutSource -match "Invoke-BailoutAdb @\('(?:uninstall|root|reboot)'|shell','pm','clear|enabled_accessibility_services|appops','set|svc','(?:wifi|data)','disable")) $false
    $runnerSource=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Start-KR003.ps1') -Raw
    Assert-Equal ([bool]($runnerSource -match '\[string\]::IsNullOrEmpty\(\$PhysicalResult\)')) $true
    $qualificationModuleSource=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Qualification.psm1') -Raw
    Assert-Equal ([bool]($qualificationModuleSource -match 'KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION')) $true
    Assert-Equal ([bool]($runnerSource -match 'Assert-KRBoundDeviceConfiguration')) $true
    Assert-Equal ([bool]($runnerSource -match 'Assert-QualificationPermissionState')) $true
    Assert-Equal ([bool]($runnerSource -match 'BuildFingerprint|MiuiOwnerSupplied')) $false
    Assert-Equal ([bool]($runnerSource -match 'for \(\$attempt=1; \$attempt -le 100; \$attempt\+\+\)')) $true
    Assert-Equal ([bool]($runnerSource -match 'Invoke-NegativeControlCheckpoint')) $true
    Assert-Equal ([bool]($runnerSource -match "Invoke-QualificationSafetyCheckpoint -Phase 'final'")) $true
    Assert-Equal ([bool]($runnerSource -match 'Test-KRDiagnosticStableSafe')) $true
    Assert-Equal ([bool]($runnerSource -match 'OFFLINE_QUALIFICATION_MODE_REQUIRED')) $true
} finally {
    # Only this test-created unique temporary tree; no real run directory is used or touched.
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
}
Write-Host "$script:Checks finalization assertions passed; all device calls were stubs."
Write-Host ('PowerShell runtime: ' + $PSVersionTable.PSVersion.ToString())
