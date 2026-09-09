Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'CalibrationHost.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Test-KR003-OracleCalibration.ps1'),[ref]$tokens,[ref]$errors)
Assert-Equal $errors.Count 0
$source=$ast.Extent.Text
Assert-Equal ([bool]($source -match 'for\(\$probe=1;\$probe -le 20;\$probe\+\+\)')) $true
Assert-Equal ([bool]($source -match 'QualificationSamples=0')) $true
Assert-Equal ([bool]($source -match 'Read-PhysicalAgreement')) $true
Assert-Equal ([bool]($source -match 'ENFORCEMENT_SERVICE_RESTARTED')) $true
Assert-Equal ([bool]($source -match 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY')) $true
Assert-Equal ([bool]($source -match 'runnerVersion -ne 4')) $true
Assert-Equal ([bool]($source -match "settings','--user','current','get','secure','enabled_accessibility_services")) $true
Assert-Equal ([bool]($source -match "Write-CalibrationJson 'permission-verification.json'")) $true
Assert-Equal ([bool]($source -match 'Get-KRRequiredPermissionFailure')) $true
Assert-Equal $source.Contains("Set-KRCalibrationHostStage `$script:HostState 'WAIT_FOR_ATTACHMENT'") $true
Assert-Equal $source.Contains("Set-KRCalibrationCleanupStatus `$script:HostState 'IN_PROGRESS'") $true
Assert-Equal $source.Contains('Set-KRCalibrationFinalizationFailure $script:HostState $_ (-not $wasComplete)') $true
Assert-Equal ([bool]($source -match '\$script:Host(?:\W|$)')) $false
Assert-Equal ([bool]($source -match 'for\([^\r\n]+-le 100|attempt.+100|RESET_METRICS|OfflineNetwork|svc[^\r\n]+(?:disable|enable)|\buninstall\b|\breboot\b|pm[^\r\n]+clear|appops[^\r\n]+set|screencap|uiautomator|dumpsys\s+window|ro\.build\.fingerprint|ro\.serialno|ANDROID_ID')) $false
Assert-Equal ([bool]($source -match 'getRootInActiveWindow|getWindows\(|getText\(|getContentDescription|takeScreenshot')) $false

# A pre-ARM host exception records the exact phase and a safe class.
$beforeArm=New-KRCalibrationHostState
Set-KRCalibrationHostStage $beforeArm 'PRE_ARM_PERMISSION_VERIFICATION'
try{throw [InvalidOperationException]::new('synthetic detail must not persist')}catch{Set-KRCalibrationHostFailure $beforeArm $_}
$beforeArmDiagnostic=Get-KRCalibrationHostDiagnostic $beforeArm
Assert-Equal $beforeArmDiagnostic.HostStage 'PRE_ARM_PERMISSION_VERIFICATION'
Assert-Equal $beforeArmDiagnostic.ExceptionClass 'INVALID_OPERATION_EXCEPTION'
Assert-Equal $beforeArmDiagnostic.PrimaryReason 'INVALID:HOST_EXCEPTION'

# The historical failure interval is ARM; v3 would retain a safe runtime class there.
$arm=New-KRCalibrationHostState
Set-KRCalibrationHostStage $arm 'ARM'
try{throw [Management.Automation.RuntimeException]::new('synthetic ARM detail')}catch{Set-KRCalibrationHostFailure $arm $_}
Assert-Equal $arm.HostStage 'ARM'
Assert-Equal $arm.ExceptionClass 'POWERSHELL_RUNTIME_EXCEPTION'
Assert-Equal $arm.PrimaryReason 'INVALID:HOST_EXCEPTION'

# A typed failure during the blocked hold remains the primary result.
$hold=New-KRCalibrationHostState
Set-KRCalibrationHostStage $hold 'BLOCKED_HOLD'
try{throw 'FAIL:RESTRICTION_LOST'}catch{Set-KRCalibrationHostFailure $hold $_}
Assert-Equal $hold.HostStage 'BLOCKED_HOLD'
Assert-Equal $hold.ExceptionClass 'TYPED_RUNNER_RESULT'
Assert-Equal $hold.PrimaryReason 'FAIL:RESTRICTION_LOST'

# Cleanup is attempted but cannot overwrite an earlier primary host exception.
$primary=$beforeArm.PrimaryReason;$primaryStage=$beforeArm.HostStage;$primaryClass=$beforeArm.ExceptionClass
Set-KRCalibrationCleanupStatus $beforeArm 'IN_PROGRESS'
try{throw [IO.IOException]::new('secondary cleanup detail')}catch{Set-KRCalibrationCleanupFailure $beforeArm $_ $true}
Assert-Equal $beforeArm.CleanupStatus 'FAILED'
Assert-Equal $beforeArm.PrimaryReason $primary
Assert-Equal $beforeArm.HostStage $primaryStage
Assert-Equal $beforeArm.ExceptionClass $primaryClass

# A finalization exception has its own typed stage/class and no raw message field.
$finalization=New-KRCalibrationHostState
Set-KRCalibrationHostStage $finalization 'FINALIZATION'
Set-KRCalibrationFinalizationStatus $finalization 'IN_PROGRESS'
try{throw [IO.IOException]::new('synthetic path must not persist')}catch{Set-KRCalibrationFinalizationFailure $finalization $_ $false}
$finalDiagnostic=Get-KRCalibrationHostDiagnostic $finalization
Assert-Equal $finalDiagnostic.HostStage 'FINALIZATION'
Assert-Equal $finalDiagnostic.ExceptionClass 'IO_EXCEPTION'
Assert-Equal $finalDiagnostic.FinalizationStatus 'FAILED'
Assert-Equal (($finalDiagnostic.PSObject.Properties.Name)-join ',') 'Schema,HostStage,ExceptionClass,PrimaryReason,FinalizationStatus,CleanupStatus'
Write-Host "$script:Checks oracle-calibration assertions passed; no device command was executed."
