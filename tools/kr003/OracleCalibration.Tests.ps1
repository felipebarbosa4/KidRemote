Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
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
Assert-Equal ([bool]($source -match 'for\([^\r\n]+-le 100|attempt.+100|RESET_METRICS|OfflineNetwork|svc[^\r\n]+(?:disable|enable)|\buninstall\b|\breboot\b|pm[^\r\n]+clear|appops[^\r\n]+set|screencap|uiautomator|dumpsys\s+window|ro\.build\.fingerprint|ro\.serialno|ANDROID_ID')) $false
Assert-Equal ([bool]($source -match 'getRootInActiveWindow|getWindows\(|getText\(|getContentDescription|takeScreenshot')) $false
Write-Host "$script:Checks oracle-calibration assertions passed; no device command was executed."
