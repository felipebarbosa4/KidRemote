Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
$script:Checks = 0
function Assert-Equal($Actual, $Expected) {
    $script:Checks++
    if ($Actual -cne $Expected) { throw "Expected $Expected; received $Actual" }
}
function Assert-Reject([scriptblock]$Action, [string]$Expected) {
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-Equal $caught $Expected
}
function Encode-Reply($Value) {
    'Broadcast completed: result=0, data="KR003:' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Value | ConvertTo-Json -Depth 8 -Compress))) + '"'
}
function New-Snapshot {
    [PSCustomObject]@{
        schema=1; request=1; elapsed=20000; versionCode=1; versionName='0.0.1-spike'; api=29
        revision=2; remaining=0; armed=$true; restriction=$true; uncertain=$false
        usage=$true; accessibility=$true; heartbeat=$true; eligible=$true; adapter='APPLIED'
        sampledAt=19990; sampledRevision=2; disposition='ORDINARY_APP'; attached=$true
        eligibilityLost=$false; firstAttachedAt=10100; removals=0; recordedRevision=2
        samples=@(123); sampleCount=1; p50=123; p95=123; max=123; traceHead=0; traceLost=$false; events=@()
    }
}

$approvedConfiguration=[PSCustomObject]@{schema=1;manufacturer='samsung';model='SM-X400';androidVersion='16';apiLevel='36';securityPatch='2026-07-05';buildId='BP4A.251205.006'}
$calibratedBy=[PSCustomObject]@{
    protocol='KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION';sourceCommit=('a'*40);runDirectory='calibration-20260908-231756-97a0855b'
    status='PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY';reason='COMPLETED';summarySha256=('b'*64);deviceSha256=('c'*64)
    transportDeviceEvidenceSha256=('d'*64);calibrationSamples=1;qualificationSamples=0;physicalAgreement='PASS'
    candidateSha256=('e'*64);fixtureSha256=('f'*64)
}
$configurationBundle=[PSCustomObject]@{
    schema=1;protocol='KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION';runnerVersion=11;diagnosticOnly=$false;requiresOffline=$true
    networkCapabilityModel='ANDROID_SYSTEM_FEATURES_WIFI_AND_TELEPHONY_DATA'
    awakeStateModel='ANDROID_STAY_ON_WHILE_PLUGGED_IN_PLUS_POWER_SOURCE'
    navigationModeModel='SECURE_SETTINGS_CURRENT_USER_COARSE_ENUM'
    oracleModel='ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS';humanCheckpointMaximum=3;physicalExecution='NOT_RUN'
    approvedConfiguration=$approvedConfiguration;calibratedBy=$calibratedBy;candidateSha256=('e'*64);fixtureSha256=('f'*64)
}
Assert-KRConfigurationQualificationBundle $configurationBundle
$observedConfiguration=[PSCustomObject]@{Manufacturer='samsung';Model='SM-X400';Android='16';Api='36';Patch='2026-07-05';BuildId='BP4A.251205.006'}
Assert-KRBoundDeviceConfiguration $observedConfiguration $approvedConfiguration
$wrongDevice=$observedConfiguration.PSObject.Copy();$wrongDevice.BuildId='DIFFERENT'
Assert-Reject { Assert-KRBoundDeviceConfiguration $wrongDevice $approvedConfiguration } 'INVALID:DEVICE_CONFIGURATION_CHANGED'
$wrongCalibration=$calibratedBy.PSObject.Copy();$wrongCalibration.physicalAgreement='INVALID'
$wrongBundle=$configurationBundle.PSObject.Copy();$wrongBundle.calibratedBy=$wrongCalibration
Assert-Reject { Assert-KRConfigurationQualificationBundle $wrongBundle } 'INVALID:BUNDLE_CALIBRATION_SCHEMA'
$arrayReplyBundle=$configurationBundle.PSObject.Copy();$arrayReplyBundle.approvedConfiguration=@($approvedConfiguration,$approvedConfiguration)
Assert-Reject { Assert-KRConfigurationQualificationBundle $arrayReplyBundle } 'INVALID:BUNDLE_CONFIGURATION_SCHEMA'

$presentProbe=[PSCustomObject]@{ExitCode=0;Stdout="true`r`n";StderrClass='NONE'}
$absentProbe=[PSCustomObject]@{ExitCode=1;Stdout='false';StderrClass='NONE'}
Assert-Equal (Convert-KRSystemFeatureProbe $presentProbe) 'PRESENT'
Assert-Equal (Convert-KRSystemFeatureProbe $absentProbe) 'ABSENT'
foreach($unknownProbe in @(
    [PSCustomObject]@{ExitCode=0;Stdout='false';StderrClass='NONE'},
    [PSCustomObject]@{ExitCode=1;Stdout='true';StderrClass='NONE'},
    [PSCustomObject]@{ExitCode=0;Stdout='unexpected';StderrClass='NONE'},
    [PSCustomObject]@{ExitCode=0;Stdout='true';StderrClass='OTHER'},
    [PSCustomObject]@{ExitCode=2;Stdout='';StderrClass='SECURITY_EXCEPTION'}
)){Assert-Equal (Convert-KRSystemFeatureProbe $unknownProbe) 'UNKNOWN'}
$wifiOnly=Get-KRNetworkIsolationPlan ([PSCustomObject]@{Wifi='PRESENT';MobileData='ABSENT'}) ([PSCustomObject]@{wifi_on='1';mobile_data='1'})
Assert-Equal $wifiOnly.Count 2
Assert-Equal $wifiOnly[0].Initial '1'
Assert-Equal $wifiOnly[1].Initial 'NOT_APPLICABLE'
$cellular=Get-KRNetworkIsolationPlan ([PSCustomObject]@{Wifi='PRESENT';MobileData='PRESENT'}) ([PSCustomObject]@{wifi_on='0';mobile_data='1'})
Assert-Equal $cellular[0].Initial '0'
Assert-Equal $cellular[1].Initial '1'
Assert-KRNetworkOffline ([PSCustomObject]@{Wifi='PRESENT';MobileData='ABSENT'}) ([PSCustomObject]@{wifi_on='0';mobile_data='1'})
Assert-Reject { Assert-KRNetworkOffline ([PSCustomObject]@{Wifi='PRESENT';MobileData='PRESENT'}) ([PSCustomObject]@{wifi_on='0';mobile_data='1'}) } 'INVALID:OFFLINE_RADIOS_NOT_DISABLED'
Assert-Reject { Get-KRNetworkIsolationPlan ([PSCustomObject]@{Wifi='PRESENT';MobileData='UNKNOWN'}) ([PSCustomObject]@{wifi_on='1';mobile_data='1'}) } 'INVALID:NETWORK_CAPABILITY_UNKNOWN'
Assert-Reject { Get-KRNetworkIsolationPlan ([PSCustomObject]@{Wifi='PRESENT'}) ([PSCustomObject]@{wifi_on='1';mobile_data='1'}) } 'INVALID:NETWORK_CAPABILITY_UNKNOWN'
Assert-Reject { Get-KRNetworkIsolationPlan ([PSCustomObject]@{Wifi='PRESENT';MobileData='PRESENT'}) ([PSCustomObject]@{wifi_on='1';mobile_data='UNSPECIFIED'}) } 'INVALID:RADIO_INITIAL_STATE_UNKNOWN'

# Android's public plugged-source bitmask and sanitized battery dump are sufficient to verify the lab stay-awake condition.
Assert-Equal (Convert-KRStayAwakeSetting "15`r`n") 15
Assert-Reject { Convert-KRStayAwakeSetting 'null' } 'INVALID:STAY_AWAKE_STATE_UNKNOWN'
Assert-Reject { Convert-KRStayAwakeSetting '16' } 'INVALID:STAY_AWAKE_STATE_UNKNOWN'
$android10Power=Convert-KRPowerSourceProbe "Current Battery Service state:`n AC powered: false`n USB powered: true`n Wireless powered: false`n"
Assert-Equal $android10Power.PowerSource 'USB'
Assert-Equal $android10Power.PlugMask 2
$android16Power=Convert-KRPowerSourceProbe "Current Battery Service state:`n AC powered: false`n USB powered: true`n Wireless powered: false`n Dock powered: false`n"
Assert-Equal $android16Power.PowerSource 'USB'
$unpluggedPower=Convert-KRPowerSourceProbe "AC powered: false`nUSB powered: false`nWireless powered: false`nDock powered: false"
Assert-Equal $unpluggedPower.PowerSource 'UNPLUGGED'
Assert-Reject { Convert-KRPowerSourceProbe "AC powered: false`nUSB powered: true" } 'INVALID:STAY_AWAKE_STATE_UNKNOWN'
Assert-KRStayAwakeState ([PSCustomObject]@{Setting=15;PowerSource='USB';PlugMask=2}) 15
Assert-Reject { Assert-KRStayAwakeState ([PSCustomObject]@{Setting=1;PowerSource='USB';PlugMask=2}) } 'INVALID:STAY_AWAKE_VERIFICATION_FAILED'
Assert-Reject { Assert-KRStayAwakeState ([PSCustomObject]@{Setting=15;PowerSource='UNPLUGGED';PlugMask=0}) } 'INVALID:STAY_AWAKE_VERIFICATION_FAILED'

# Android's current-user navigation setting is reduced to a coarse instruction enum; unknown values fail closed.
Assert-Equal (Convert-KRNavigationMode '0') 'THREE_BUTTON'
Assert-Equal (Convert-KRNavigationMode "1`r`n") 'TWO_BUTTON'
Assert-Equal (Convert-KRNavigationMode '2') 'GESTURE'
Assert-Equal (Convert-KRNavigationMode 'null') 'UNKNOWN'
Assert-Equal (Convert-KRNavigationMode '3') 'UNKNOWN'
Assert-Equal (Get-KRHomeActionInstruction 'THREE_BUTTON') 'tap the on-screen Home button once'
Assert-Equal (Get-KRHomeActionInstruction 'GESTURE') 'swipe up once from the bottom edge to go Home; do not swipe and hold'
Assert-Reject { Get-KRHomeActionInstruction 'UNKNOWN' } 'INVALID:NAVIGATION_MODE_UNKNOWN'
Assert-Equal (Get-KRHomeActionResult 'PASS') 'HOME_ACTION_EXERCISED_AND_RESISTED'
Assert-Equal (Get-KRHomeActionResult 'FAIL') 'HOME_ACTION_EXERCISED_AND_ESCAPED'
Assert-Equal (Get-KRHomeActionResult 'INVALID') 'HOME_ACTION_NOT_EXERCISABLE_OR_UNKNOWN'
$settingsAction=New-Snapshot
$settingsAction.traceHead=1
$settingsAction.events=@([PSCustomObject]@{sequence=1;line='t=21000 kind=recovery_open_requested trigger=settings_button eventType=-1 identity=NONE disposition=ORDINARY_APP nextDisposition=ORDINARY_APP restriction=true overlay=ATTACHED adapter=APPLIED nextAdapter=APPLIED revision=2'})
Assert-Equal (Test-KRRecoveryButtonAction $settingsAction) $true
Assert-Equal (Test-KRRecoveryButtonAction (New-Snapshot)) $false

Assert-Equal (Get-KRStatistics @()).Count 0
Assert-Equal (Get-KRStatistics @(1..100)).P95 95
Assert-Equal (Get-KRStatistics @(263,1,123)).P50 123
Assert-Reject { Get-KRStatistics @(-1) } 'INVALID:NEGATIVE_LATENCY'
$s = New-Snapshot
Assert-Equal (Convert-KRReply (Encode-Reply $s) 1).sampleCount 1
$v2 = New-Snapshot
$v2.schema=2
$v2 | Add-Member NoteProperty windowVisibility 4
$v2 | Add-Member NoteProperty windowFocused $false
$v2 | Add-Member NoteProperty viewAttached $true
Assert-Equal (Convert-KRReply (Encode-Reply $v2) 1).windowVisibility 4
$fixtureReply=[PSCustomObject]@{schema=2;request=1;elapsed=100;instance=7;taps=2;focusGains=3;focusLosses=2;lastFocusChange=90;probeX=540;probeY=1900;focused=$true;resumed=$true;probeReady=$true}
Assert-Equal (Convert-KRReply (Encode-Reply $fixtureReply) 1 -Fixture).probeY 1900
$fixtureReply | Add-Member NoteProperty rawPackage 'forbidden'
Assert-Reject { Convert-KRReply (Encode-Reply $fixtureReply) 1 -Fixture } 'INVALID:REPLY_SCHEMA'
$v2.windowVisibility=123
Assert-Reject { Convert-KRReply (Encode-Reply $v2) 1 } 'INVALID:WINDOW_VISIBILITY'
Assert-Reject { Convert-KRReply (Encode-Reply $s) 2 } 'INVALID:STALE_REPLY'
Assert-Reject { Convert-KRReply '--------- beginning of main' 1 } 'INVALID:MISSING_OR_AMBIGUOUS_REPLY'
Assert-Reject { Convert-KRReply ((Encode-Reply $s) + (Encode-Reply $s)) 1 } 'INVALID:MISSING_OR_AMBIGUOUS_REPLY'
$s | Add-Member NoteProperty personalText 'should be rejected'
Assert-Reject { Convert-KRReply (Encode-Reply $s) 1 } 'INVALID:REPLY_SCHEMA'
$s = New-Snapshot
$s.events=@([PSCustomObject]@{sequence=1;line='personal app text'})
$s.traceHead=1
Assert-Reject { Convert-KRReply (Encode-Reply $s) 1 } 'INVALID:UNSANITIZED_TRACE'
$s = New-Snapshot
$s.samples=@('123')
Assert-Reject { Convert-KRReply (Encode-Reply $s) 1 } 'INVALID:LATENCY_TYPE'
$s = New-Snapshot
Assert-Equal (Get-KRPairedLatency $s 2 @()) 123
Assert-Reject { Get-KRPairedLatency $s 4 @() } 'INVALID:UNPAIRED_LATENCY'
$s.samples=@(5,123); $s.sampleCount=2
Assert-Reject { Get-KRPairedLatency $s 2 @(6) } 'FAIL:LATENCY_HISTORY_CHANGED'
$s = New-Snapshot
$f = [PSCustomObject]@{focused=$false;taps=0}
Assert-KRHold $s 2 0 $f
$s.removals=1
Assert-Reject { Assert-KRHold $s 2 0 $f } 'FAIL:RESTRICTION_LOST'
$s = New-Snapshot; $s.heartbeat=$false
Assert-Reject { Assert-KRHold $s 2 0 $f } 'FAIL:PERMISSION_OR_SERVICE_LOST'
$s = New-Snapshot; $s.eligible=$false
Assert-Reject { Assert-KRHealth $s } 'INVALID:SCREEN_OR_KEYGUARD'
$s = New-Snapshot; $s.eligible=$false; $s.eligibilityLost=$true
Assert-Reject { Assert-KRHold $s 2 0 $f } 'INVALID:SCREEN_OR_KEYGUARD'
$s = New-Snapshot; $s.eligibilityLost=$true
Assert-Reject { Assert-KRHold $s 2 0 $f } 'INVALID:ELIGIBILITY_INTERRUPTED'
$s = New-Snapshot; $f.focused=$true
Assert-Reject { Assert-KRHold $s 2 0 $f } 'FAIL:ORDINARY_FIXTURE_ACTIVE'
Assert-Reject { Assert-KRHealth $s 20001 } 'FAIL:CLOCK_DISCONTINUITY'

$fixtureBaseline=[PSCustomObject]@{schema=2;instance=7;probeReady=$true;probeX=540;probeY=1900;focused=$false;resumed=$true;taps=4;focusGains=3;focusLosses=3}
$fixtureBlocked=[PSCustomObject]@{schema=2;instance=7;probeReady=$true;probeX=540;probeY=1900;focused=$false;resumed=$true;taps=4;focusGains=3;focusLosses=3}
Assert-KRIndependentFixtureBlock $fixtureBaseline $fixtureBlocked
$fixtureBlocked.taps=5
Assert-Reject { Assert-KRIndependentFixtureBlock $fixtureBaseline $fixtureBlocked } 'FAIL:RESTRICTION_LEAKED_INPUT'
$fixtureBlocked.taps=4; $fixtureBlocked.focusGains=4
Assert-Reject { Assert-KRIndependentFixtureBlock $fixtureBaseline $fixtureBlocked } 'FAIL:FIXTURE_REGAINED_FOCUS'
$fixtureBlocked.focusGains=3; $fixtureBlocked.instance=8
Assert-Reject { Assert-KRIndependentFixtureBlock $fixtureBaseline $fixtureBlocked } 'INVALID:FIXTURE_RESTARTED'
$fixtureBlocked.instance=7; $fixtureBlocked.probeX=541
Assert-Reject { Assert-KRIndependentFixtureBlock $fixtureBaseline $fixtureBlocked } 'INVALID:FIXTURE_PROBE_MOVED'

# Focused recovery phases use their own trace floor; an earlier phase's safe event cannot satisfy a later phase.
$rootStart=New-Snapshot
$rootStart.elapsed=30000; $rootStart.sampledAt=29990; $rootStart.traceHead=10
$root=New-KRDiagnosticPhase 'SETTINGS_ROOT' $rootStart
$rootFrame=New-Snapshot
$rootFrame.elapsed=30400; $rootFrame.sampledAt=30390; $rootFrame.traceHead=14; $rootFrame.attached=$false; $rootFrame.disposition='SAFE_SYSTEM'
$rootFrame.events=@(
    [PSCustomObject]@{sequence=11;line='t=30100 kind=recovery_open_requested trigger=settings_button revision=2'},
    [PSCustomObject]@{sequence=12;line='t=30110 kind=recovery_open_dispatched trigger=settings_button revision=2'},
    [PSCustomObject]@{sequence=13;line='t=30200 kind=surface_transition trigger=event identity=KNOWN_SAFE_SYSTEM disposition=ORDINARY_APP nextDisposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=2'},
    [PSCustomObject]@{sequence=14;line='t=30210 kind=overlay_removed trigger=safe_surface disposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=2'}
)
Update-KRDiagnosticPhase $root $rootFrame
Assert-Equal $root.Oracle 'SAFE_TRANSITION_CORROBORATED'

$digital=New-KRDiagnosticPhase 'DIGITAL_WELLBEING_ATTEMPT' $rootFrame
$digitalFrame=New-Snapshot
$digitalFrame.elapsed=30800; $digitalFrame.sampledAt=30790; $digitalFrame.traceHead=16
$digitalFrame.events=@(
    [PSCustomObject]@{sequence=15;line='t=30700 kind=surface_transition trigger=event identity=ORDINARY_APP disposition=SAFE_SYSTEM nextDisposition=ORDINARY_APP restriction=true overlay=DETACHED revision=2'},
    [PSCustomObject]@{sequence=16;line='t=30710 kind=overlay_attached trigger=accessibility_event disposition=ORDINARY_APP nextDisposition=ORDINARY_APP restriction=true overlay=ATTACHED revision=2'}
)
Update-KRDiagnosticPhase $digital $digitalFrame
Assert-Equal $digital.Oracle 'ORDINARY_REATTACHMENT_CORROBORATED'
Assert-Equal $digital.SafeTransition $false

$recovery=New-KRDiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT' $digitalFrame
$oldSafe=New-Snapshot
$oldSafe.elapsed=30900; $oldSafe.sampledAt=30890; $oldSafe.traceHead=16; $oldSafe.events=$rootFrame.events
Update-KRDiagnosticPhase $recovery $oldSafe
Assert-Equal $recovery.Oracle 'PENDING'
$requestOnly=New-Snapshot
$requestOnly.elapsed=31200; $requestOnly.sampledAt=31190; $requestOnly.traceHead=18
$requestOnly.events=@(
    [PSCustomObject]@{sequence=17;line='t=31000 kind=recovery_open_requested trigger=settings_button revision=2'},
    [PSCustomObject]@{sequence=18;line='t=31010 kind=recovery_open_dispatched trigger=settings_button revision=2'}
)
Update-KRDiagnosticPhase $recovery $requestOnly
Assert-Equal $recovery.Oracle 'PENDING'
$preDispatch=New-KRDiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT' $rootStart
$earlySafe=New-Snapshot
$earlySafe.elapsed=30100; $earlySafe.sampledAt=30090; $earlySafe.traceHead=11; $earlySafe.attached=$false; $earlySafe.disposition='SAFE_SYSTEM'
$earlySafe.events=@([PSCustomObject]@{sequence=11;line='t=30050 kind=surface_transition trigger=event identity=KNOWN_SAFE_SYSTEM disposition=ORDINARY_APP nextDisposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=2'})
Update-KRDiagnosticPhase $preDispatch $earlySafe
$lateDispatch=New-Snapshot
$lateDispatch.elapsed=30300; $lateDispatch.sampledAt=30290; $lateDispatch.traceHead=13
$lateDispatch.events=@(
    [PSCustomObject]@{sequence=12;line='t=30200 kind=recovery_open_requested trigger=settings_button revision=2'},
    [PSCustomObject]@{sequence=13;line='t=30210 kind=recovery_open_dispatched trigger=settings_button revision=2'}
)
Update-KRDiagnosticPhase $preDispatch $lateDispatch
Assert-Equal $preDispatch.Oracle 'PENDING'
$recovered=New-Snapshot
$recovered.elapsed=31500; $recovered.sampledAt=31490; $recovered.traceHead=20; $recovered.attached=$false; $recovered.disposition='SAFE_SYSTEM'
$recovered.events=@(
    [PSCustomObject]@{sequence=19;line='t=31300 kind=surface_transition trigger=event identity=KNOWN_SAFE_SYSTEM disposition=ORDINARY_APP nextDisposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=2'},
    [PSCustomObject]@{sequence=20;line='t=31310 kind=overlay_removed trigger=safe_surface disposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=2'}
)
Update-KRDiagnosticPhase $recovery $recovered
Assert-Equal $recovery.Oracle 'FRESH_SAFE_TRANSITION_CORROBORATED'
Assert-Equal (Test-KRDiagnosticStableSafe $recovery) $false
$stable=New-Snapshot
$stable.elapsed=41400; $stable.sampledAt=41390; $stable.traceHead=20; $stable.attached=$false; $stable.disposition='SAFE_SYSTEM'; $stable.events=@()
Update-KRDiagnosticPhase $recovery $stable
Assert-Equal (Test-KRDiagnosticStableSafe $recovery) $true
$regressed=New-Snapshot
$regressed.elapsed=41800; $regressed.sampledAt=41790; $regressed.traceHead=22; $regressed.attached=$true; $regressed.disposition='ORDINARY_APP'
$regressed.events=@(
    [PSCustomObject]@{sequence=21;line='t=31600 kind=surface_transition trigger=event identity=ORDINARY_APP disposition=SAFE_SYSTEM nextDisposition=ORDINARY_APP restriction=true overlay=DETACHED revision=2'},
    [PSCustomObject]@{sequence=22;line='t=31610 kind=overlay_attached trigger=accessibility_event disposition=ORDINARY_APP nextDisposition=ORDINARY_APP restriction=true overlay=ATTACHED revision=2'}
)
Update-KRDiagnosticPhase $recovery $regressed
Assert-Equal $recovery.Oracle 'RECOVERY_REGRESSED_TO_ORDINARY'
Assert-Equal $recovery.Reason 'SAFE_TRANSITION_DID_NOT_PERSIST'
Assert-Equal (Test-KRDiagnosticStableSafe $recovery) $false
$reattached=New-KRDiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT' $digitalFrame
Update-KRDiagnosticPhase $reattached $requestOnly
Update-KRDiagnosticPhase $reattached $recovered
$attachOnly=New-Snapshot
$attachOnly.elapsed=41800; $attachOnly.sampledAt=41790; $attachOnly.traceHead=21; $attachOnly.attached=$false; $attachOnly.disposition='SAFE_SYSTEM'
$attachOnly.events=@([PSCustomObject]@{sequence=21;line='t=41600 kind=overlay_attached trigger=accessibility_event disposition=SAFE_SYSTEM nextDisposition=SAFE_SYSTEM restriction=true overlay=ATTACHED revision=2'})
Update-KRDiagnosticPhase $reattached $attachOnly
Assert-Equal $reattached.Oracle 'RECOVERY_OVERLAY_REATTACHED'
Assert-Equal (Test-KRDiagnosticStableSafe $reattached) $false
$unknownAfterSafe=New-KRDiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT' $digitalFrame
Update-KRDiagnosticPhase $unknownAfterSafe $requestOnly
Update-KRDiagnosticPhase $unknownAfterSafe $recovered
$unknownFrame=New-Snapshot
$unknownFrame.elapsed=41800; $unknownFrame.sampledAt=41790; $unknownFrame.traceHead=21; $unknownFrame.attached=$false; $unknownFrame.disposition='UNKNOWN_FAIL_OPEN'
$unknownFrame.events=@([PSCustomObject]@{sequence=21;line='t=41600 kind=surface_transition trigger=event identity=MISSING disposition=SAFE_SYSTEM nextDisposition=UNKNOWN_FAIL_OPEN restriction=true overlay=DETACHED revision=2'})
Update-KRDiagnosticPhase $unknownAfterSafe $unknownFrame
Assert-Equal $unknownAfterSafe.Oracle 'RECOVERY_REGRESSED_TO_UNKNOWN'
Assert-Equal (Test-KRDiagnosticStableSafe $unknownAfterSafe) $false
$duplicate=New-KRDiagnosticPhase 'RECOVERY_BUTTON_ATTEMPT' $digitalFrame
$duplicateFrame=New-Snapshot
$duplicateFrame.elapsed=31500; $duplicateFrame.sampledAt=31490; $duplicateFrame.traceHead=20
$duplicateFrame.events=@(
    [PSCustomObject]@{sequence=17;line='t=31000 kind=recovery_open_requested trigger=settings_button revision=2'},
    [PSCustomObject]@{sequence=18;line='t=31010 kind=recovery_open_dispatched trigger=settings_button revision=2'},
    [PSCustomObject]@{sequence=19;line='t=31100 kind=recovery_open_requested trigger=settings_button revision=2'},
    [PSCustomObject]@{sequence=20;line='t=31110 kind=recovery_open_dispatched trigger=settings_button revision=2'}
)
Update-KRDiagnosticPhase $duplicate $duplicateFrame
Assert-Equal $duplicate.Oracle 'INVALID_MULTIPLE_RECOVERY_ATTEMPTS'
$post=New-KRDiagnosticPhase 'POST_RECOVERY_STATE' $recovered
$postFrame=New-Snapshot
$postFrame.elapsed=31700; $postFrame.sampledAt=31690; $postFrame.traceHead=20; $postFrame.attached=$false; $postFrame.disposition='SAFE_SYSTEM'
Update-KRDiagnosticPhase $post $postFrame
Assert-Equal $post.Oracle 'SAFE_STATE_OBSERVED'

$verdictRoot=[PSCustomObject]@{Name='SETTINGS_ROOT';PhysicalResult='PASS';Oracle='SAFE_TRANSITION_CORROBORATED'}
$verdictDigital=[PSCustomObject]@{Name='DIGITAL_WELLBEING_ATTEMPT';PhysicalResult='FAIL';Oracle='ORDINARY_REATTACHMENT_CORROBORATED'}
$verdictRecovery=[PSCustomObject]@{Name='RECOVERY_BUTTON_ATTEMPT';PhysicalResult='PASS';Oracle='FRESH_SAFE_TRANSITION_CORROBORATED'}
$verdictPost=[PSCustomObject]@{Name='POST_RECOVERY_STATE';PhysicalResult='UNRECORDED';Oracle='SAFE_STATE_OBSERVED'}
Assert-Equal (Get-KRFocusedDiagnosticReason @($verdictRoot,$verdictDigital,$verdictRecovery,$verdictPost)) 'PHYSICAL_PASS_RECORDED'
$verdictRecovery.Oracle='RECOVERY_REGRESSED_TO_ORDINARY'
Assert-Equal (Get-KRFocusedDiagnosticReason @($verdictRoot,$verdictDigital,$verdictRecovery,$verdictPost)) 'SOFTWARE_FAILURE_RECORDED'
$verdictRecovery.PhysicalResult='FAIL'
Assert-Equal (Get-KRFocusedDiagnosticReason @($verdictRoot,$verdictDigital,$verdictRecovery,$verdictPost)) 'PHYSICAL_FAILURE_RECORDED'
$verdictRecovery.PhysicalResult='PASS'; $verdictRecovery.Oracle='FRESH_SAFE_TRANSITION_CORROBORATED'; $verdictDigital.PhysicalResult='PASS'
Assert-Equal (Get-KRFocusedDiagnosticReason @($verdictRoot,$verdictDigital,$verdictRecovery,$verdictPost)) 'PHYSICAL_FAILURE_RECORDED'
$verdictDigital.PhysicalResult='INVALID'
Assert-Equal (Get-KRFocusedDiagnosticReason @($verdictRoot,$verdictDigital,$verdictRecovery,$verdictPost)) 'PHYSICAL_INVALID_RECORDED'

Assert-Equal (Get-KRSafetyCheckpointReason 'PASS' 'PHYSICAL_PASS_RECORDED' 'PASS' 'FIXTURE_COUNTER_INCREMENT') 'PHYSICAL_PASS_RECORDED'
Assert-Equal (Get-KRSafetyCheckpointReason 'FAIL' 'PHYSICAL_PASS_RECORDED' 'PASS' 'FIXTURE_COUNTER_INCREMENT') 'PHYSICAL_FAILURE_RECORDED'
Assert-Equal (Get-KRSafetyCheckpointReason 'INVALID' 'PHYSICAL_PASS_RECORDED' 'PASS' 'FIXTURE_COUNTER_INCREMENT') 'PHYSICAL_INVALID_RECORDED'
Assert-Equal (Get-KRSafetyCheckpointReason 'PASS' 'SOFTWARE_FAILURE_RECORDED' 'PASS' 'FIXTURE_COUNTER_INCREMENT') 'SOFTWARE_FAILURE_RECORDED'

$rows = @(1..100 | ForEach-Object { [PSCustomObject]@{Revision=$_;Observer='UNRECORDED';Automated='PASS';LatencyMs=123} })
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'INCOMPLETE'
$rows | ForEach-Object { $_.Observer='PASS' }
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'PASSED_THIS_CONFIGURATION_ONLY'
Assert-Equal (Get-KRRunVerdict $rows $true $false) 'ONLINE_ONLY_OFFLINE_GATE_OPEN'
Assert-Equal (Get-KRRunVerdict $rows[0..98] $true $true) 'INCOMPLETE'
Assert-Equal (Get-KRRunVerdict $rows $false $true) 'INCOMPLETE'
$rows[99].Revision=1
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'INCOMPLETE'
$rows[99].Revision=100
$rows[99].Observer='FAIL'
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'FAILED'
$rows[99].Observer='PASS'
# Five slow valid samples leave nearest rank 95 at 123. Six slow samples exceed the gate.
94..99 | ForEach-Object { $rows[$_].LatencyMs=2001 }
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'FAILED_P95'
$rows[94].LatencyMs=123
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'PASSED_THIS_CONFIGURATION_ONLY'

$automatedRows=@(1..100 | ForEach-Object {
    [PSCustomObject]@{Phase='QUALIFICATION';Revision=$_;AutomatedOracle='PASS';InputOracle='PASS';LatencyMs=123;HoldMillis=10000;InjectedBlockedTaps=20}
})
$checkpoints=@(
    [PSCustomObject]@{Name='PREFLIGHT_NORMAL_PASS';Result='PASS'},
    [PSCustomObject]@{Name='PREFLIGHT_NEGATIVE_CONTROL';Result='PASS'},
    [PSCustomObject]@{Name='POST_RUN_SAFETY';Result='PASS'}
)
Assert-Equal (Get-KRAutomatedRunVerdict $automatedRows $checkpoints $true) 'PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY'
$automatedRows[50].InputOracle='FAIL'
Assert-Equal (Get-KRAutomatedRunVerdict $automatedRows $checkpoints $true) 'FAILED'
$automatedRows[50].InputOracle='PASS'; $automatedRows[50].AutomatedOracle='FAIL'
Assert-Equal (Get-KRAutomatedRunVerdict $automatedRows $checkpoints $true) 'FAILED'
$automatedRows[50].AutomatedOracle='PASS'; $automatedRows[50].InjectedBlockedTaps=19
Assert-Equal (Get-KRAutomatedRunVerdict $automatedRows $checkpoints $true) 'INCOMPLETE'
$automatedRows[50].InjectedBlockedTaps=20; $checkpoints[1].Result='FAIL'
Assert-Equal (Get-KRAutomatedRunVerdict $automatedRows $checkpoints $true) 'INCOMPLETE'
$checkpoints[1].Result='PASS'

# Parse the actual operator script without executing any device commands.
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Start-KR003.ps1'),[ref]$tokens,[ref]$parseErrors)
Assert-Equal $parseErrors.Count 0
$topLevelExits=@($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.ExitStatementAst] })
Assert-Equal $topLevelExits.Count 1
Assert-Equal ($topLevelExits[0].Extent.StartOffset -gt ($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.TryStatementAst] })[-1].Extent.EndOffset) $true
$mainTry=($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.TryStatementAst] })[-1].Body.Extent.Text
Assert-Equal ($mainTry.IndexOf('Enter-OfflineNetwork') -lt $mainTry.IndexOf('Invoke-Expiry -Attempt 0')) $true
Assert-Equal ($mainTry.IndexOf('Enter-StayAwake') -lt $mainTry.IndexOf('Enter-OfflineNetwork')) $true

# Exercise actual process argument binding with portable PowerShell as a harmless subprocess, never ADB.
foreach($name in @('Invoke-LabAdbResult','Invoke-LabAdb')) {
    $processAst=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    Invoke-Expression $processAst.Extent.Text
}
$Adb=Join-Path $PSHOME $(if($PSVersionTable.PSEdition -eq 'Core'){'pwsh'}else{'powershell.exe'})
Assert-Equal (Invoke-LabAdb @('-NoProfile','-Command','Write-Output synthetic')).Trim() 'synthetic'
Assert-Reject { Invoke-LabAdb @('unsafe"argument') } 'INVALID:ADB_ARGUMENT'

# Reversible network setup is tested only with in-memory command stubs, never a device.
foreach($name in @('Add-NetworkOperation','Invoke-NetworkAdb','Wait-RadioFlag','Enter-OfflineNetwork','Restore-Network')) {
    $fn=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    Invoke-Expression $fn.Extent.Text
}
$script:NetworkCommands=@();$script:NetworkOperations=@();$script:SyntheticWifi='1';$script:SyntheticMobile='1';$script:RejectNetworkOperation=''
function Invoke-LabAdbResult {
    param($Arguments)
    $command=$Arguments -join ' ';$script:NetworkCommands+=$command
    $operation=switch($command){
        'shell svc wifi disable'{'DISABLE_WIFI'};'shell svc data disable'{'DISABLE_MOBILE_DATA'}
        'shell svc wifi enable'{'RESTORE_WIFI'};'shell svc data enable'{'RESTORE_MOBILE_DATA'}
        default{''}
    }
    if($script:RejectNetworkOperation -and $operation -eq $script:RejectNetworkOperation){return [PSCustomObject]@{Stdout='';ExitCode=1;StderrClass='PERMISSION_DENIAL'}}
    switch($command){
        'shell svc wifi disable'{$script:SyntheticWifi='0'}
        'shell svc data disable'{$script:SyntheticMobile='0'}
        'shell svc wifi enable'{$script:SyntheticWifi='1'}
        'shell svc data enable'{$script:SyntheticMobile='1'}
    }
    $stdout=switch($command){
        'shell settings get global wifi_on'{$script:SyntheticWifi}
        'shell settings get global mobile_data'{$script:SyntheticMobile}
        default{''}
    }
    [PSCustomObject]@{Stdout=$stdout;ExitCode=0;StderrClass='NONE'}
}
function Write-JsonFile { param($Name,$Value) }
function Read-DeviceConfiguration { [PSCustomObject]@{wifi_on=$script:SyntheticWifi;mobile_data=$script:SyntheticMobile} }
$script:NetworkCapabilities=[PSCustomObject]@{Wifi='PRESENT';MobileData='ABSENT'}
$script:RadioTouched=@();$script:RadioRestoreStatus='NOT_CHANGED';$script:RadioResults=@()
$script:Device=[PSCustomObject]@{wifi_on='1';mobile_data='0'}
Enter-OfflineNetwork
Restore-Network
Assert-Equal ($script:NetworkCommands -join ',') 'shell svc wifi disable,shell settings get global wifi_on,shell svc wifi enable,shell settings get global wifi_on,shell settings get global wifi_on'
Assert-Equal $script:RadioRestoreStatus 'RESTORED_AND_FLAGS_VERIFIED'
Assert-Equal $script:RadioResults[1].Status 'NOT_APPLICABLE_VERIFIED'
Assert-Equal ([bool](($script:NetworkCommands -join ',') -match 'svc data')) $false

# Both declared transports are isolated and restored; already-off paths are verified but never mutated.
$script:NetworkCommands=@();$script:NetworkOperations=@();$script:SyntheticWifi='0';$script:SyntheticMobile='1';$script:RejectNetworkOperation=''
$script:NetworkCapabilities=[PSCustomObject]@{Wifi='PRESENT';MobileData='PRESENT'}
$script:RadioTouched=@();$script:RadioResults=@();$script:Device=[PSCustomObject]@{wifi_on='0';mobile_data='1'}
Enter-OfflineNetwork
Assert-Equal ([bool](($script:NetworkCommands -join ',') -match 'svc wifi disable')) $false
Assert-Equal $script:SyntheticMobile '0'
Restore-Network
Assert-Equal $script:SyntheticWifi '0'
Assert-Equal $script:SyntheticMobile '1'
Assert-Equal $script:RadioRestoreStatus 'RESTORED_AND_FLAGS_VERIFIED'

# A rejected disable is typed, fails before cycles, and a prior partial mutation is still restored.
$script:NetworkCommands=@();$script:NetworkOperations=@();$script:SyntheticWifi='1';$script:SyntheticMobile='1';$script:RejectNetworkOperation='DISABLE_WIFI'
$script:RadioTouched=@();$script:RadioOriginal=$null;$script:Device=[PSCustomObject]@{wifi_on='1';mobile_data='1'}
Assert-Reject { Enter-OfflineNetwork } 'INVALID:ADB_REJECTED'
Assert-Equal $script:NetworkOperations[-1].Operation 'DISABLE_WIFI'
Assert-Equal $script:NetworkOperations[-1].StderrClass 'PERMISSION_DENIAL'
Assert-Equal (($script:NetworkOperations[-1].PSObject.Properties.Name) -join ',') 'Sequence,Operation,Phase,Result,ExitCode,StderrClass,AtUtc'

$script:NetworkCommands=@();$script:NetworkOperations=@();$script:SyntheticWifi='1';$script:SyntheticMobile='1';$script:RejectNetworkOperation='DISABLE_MOBILE_DATA'
$script:RadioTouched=@();$script:RadioOriginal=$null;$script:Device=[PSCustomObject]@{wifi_on='1';mobile_data='1'}
Assert-Reject { Enter-OfflineNetwork } 'INVALID:ADB_REJECTED'
Assert-Equal $script:SyntheticWifi '0'
Assert-Equal $script:NetworkOperations[-1].Operation 'DISABLE_MOBILE_DATA'
$script:RejectNetworkOperation='';Restore-Network
Assert-Equal $script:SyntheticWifi '1'
Assert-Equal $script:SyntheticMobile '1'
Assert-Equal $script:RadioRestoreStatus 'RESTORED_AND_FLAGS_VERIFIED'

# Verification failures and restoration failures remain fail closed without changing the primary result.
$script:NetworkCommands=@();$script:NetworkOperations=@();$script:SyntheticWifi='1';$script:SyntheticMobile='0';$script:RejectNetworkOperation=''
$script:RadioTouched=@();$script:Device=[PSCustomObject]@{wifi_on='1';mobile_data='0'}
function Invoke-LabAdbResult {
    param($Arguments)
    $command=$Arguments -join ' ';$script:NetworkCommands+=$command
    if($command -eq 'shell svc wifi disable'){return [PSCustomObject]@{Stdout='';ExitCode=0;StderrClass='NONE'}}
    if($command -eq 'shell settings get global wifi_on'){return [PSCustomObject]@{Stdout='';ExitCode=1;StderrClass='OTHER'}}
    [PSCustomObject]@{Stdout='0';ExitCode=0;StderrClass='NONE'}
}
Assert-Reject { Enter-OfflineNetwork } 'INVALID:ADB_REJECTED'
Assert-Equal $script:NetworkOperations[-1].Operation 'VERIFY_WIFI_OFF'
$script:PrimaryResult='INVALID:ADB_REJECTED';Restore-Network
Assert-Equal $script:RadioRestoreStatus 'RESTORE_FAILED_OWNER_ACTION_REQUIRED'
Assert-Equal $script:PrimaryResult 'INVALID:ADB_REJECTED'

$focusAst=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Wait-FixtureFocus'},$true)
Invoke-Expression $focusAst.Extent.Text
$script:FocusQueries=0
function Get-FixtureState { $script:FocusQueries++; [PSCustomObject]@{focused=($script:FocusQueries -gt 1);resumed=$true} }
function Check-EarlyStop {}
function Start-Sleep {}
Assert-Equal (Wait-FixtureFocus -Focused $true).focused $true
Assert-Equal $script:FocusQueries 2

# Exercise actual cycle orchestration with deterministic synthetic snapshots and an independent observer stub.
# These tests do not write a physical evidence manifest or use ADB.
$functionAst=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Expiry'},$true)
Invoke-Expression $functionAst.Extent.Text
function Save-Progress {}
function Clear-ToOrdinary {}
function Assert-FixedSettings {}
function Assert-StayAwake {}
function Assert-QualificationPermissionState { param($Snapshot) }
function Check-EarlyStop {}
function Start-Sleep {}
function New-FixtureFrame { [PSCustomObject]@{schema=2;instance=1;probeReady=$true;probeX=540;probeY=1900;focused=$false;resumed=$true;taps=0;focusGains=1;focusLosses=1} }
function Get-FixtureState { New-FixtureFrame }
function Assert-FixturePositiveControl { param($Before,$FailureCode); return $Before }
function Assert-KRIndependentFixtureBlock { param($Baseline,$Current) }
function Invoke-FixtureProbeTap { param($Fixture) }
function Wait-FixtureFocus { param($Focused); return New-FixtureFrame }
function Wait-LabCondition {
    param($Condition,$FailureCode,$TimeoutSeconds)
    $s=New-Snapshot
    $s.revision=$script:SimRevision
    $s.sampledRevision=$script:SimRevision
    $s.recordedRevision=$script:SimRevision
    $s.samples=@($script:SimSamples)
    $s.sampleCount=$s.samples.Count
    $script:SimElapsed=20000
    return $s
}
function Get-LabState {
    param($Operation='SNAPSHOT')
    $s=New-Snapshot
    if($Operation -eq 'ARM') {
        $script:SimRevision++; $script:SimSamples+=123; $s.remaining=10000
        $script:AttachmentRevisions[[string]$script:SimRevision]=1
    }
    $s.revision=$script:SimRevision; $s.sampledRevision=$script:SimRevision; $s.recordedRevision=$script:SimRevision
    $s.samples=@($script:SimSamples); $s.sampleCount=$s.samples.Count
    $script:SimElapsed+=5000; $s.elapsed=$script:SimElapsed; $s.sampledAt=$s.elapsed-10
    return $s
}
function Read-Result {
    param($Prompt)
    if($script:SimObserver -ne 'PASS') { throw 'FAIL:OBSERVER_1' }
    return 'PASS'
}
$script:SimRevision=1; $script:SimSamples=@(); $script:SimElapsed=0
$script:LastRevision=-1; $script:Rows=@(); $script:CurrentRow=$null; $script:SimObserver='PASS'; $script:ServiceConnections=0
$script:AttachmentRevisions=@{}
1..100 | ForEach-Object { Invoke-Expiry -Attempt $_ 6>$null }
Assert-Equal $script:Rows.Count 100
Assert-Equal (Get-KRAutomatedRunVerdict $script:Rows $checkpoints $true) 'PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY'
Assert-Equal $script:Rows[0].PhysicalObserver 'NOT_SAMPLED'
Assert-Equal $script:Rows[0].InjectedBlockedTaps 20
Write-Host "$script:Checks PowerShell assertions passed; orchestration used synthetic state, never a device."
