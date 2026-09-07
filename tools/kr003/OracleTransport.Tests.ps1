Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'OracleTransport.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected) { $script:Checks++; if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"} }
function Assert-Reject([scriptblock]$Action,[string]$Expected) { $caught=$null; try{&$Action}catch{$caught=$_.Exception.Message}; Assert-Equal $caught $Expected }
Assert-Equal (Get-KRTransportStderrClass '') 'NONE'
Assert-Equal (Get-KRTransportStderrClass 'java.lang.SecurityException: denied') 'SECURITY_EXCEPTION'
Assert-Equal (Get-KRTransportStderrClass 'Permission Denial: inject') 'PERMISSION_DENIAL'
Assert-Equal (Get-KRTransportStderrClass 'daemon notice') 'OTHER'
$record=New-KRTransportOperationRecord 'INPUT_TAP' 255 'SECURITY_EXCEPTION'
Assert-Equal (($record.PSObject.Properties.Name) -join ',') 'OperationCategory,ExitCode,StderrClass'
Assert-Equal $record.OperationCategory 'INPUT_TAP'; Assert-Equal $record.ExitCode 255; Assert-Equal $record.StderrClass 'SECURITY_EXCEPTION'
Assert-Reject { New-KRTransportOperationRecord 'RAW_SHELL' 0 'NONE' } 'INVALID:TRANSPORT_OPERATION_CATEGORY'
Assert-Reject { New-KRTransportOperationRecord 'INPUT_TAP' 0 'RAW' } 'INVALID:TRANSPORT_STDERR_CLASS'
Assert-Equal (Get-KRTransportVerdict $true 4 5 $null) 'PASSED_TRANSPORT_PREFLIGHT'
Assert-Equal (Get-KRTransportVerdict $true 4 4 $null) 'FAILED'
Assert-Equal (Get-KRTransportVerdict $true 4 5 'INPUT_TAP') 'INVALID'
Assert-Equal (Get-KRTransportVerdict $false 0 0 $null) 'INVALID'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Test-KR003-OracleTransport.ps1'),[ref]$tokens,[ref]$errors)
Assert-Equal $errors.Count 0
$source=$ast.Extent.Text
Assert-Equal ([bool]($source -match "Invoke-TransportAdb 'INPUT_TAP' @\('shell','input','tap'")) $true
Assert-Equal ([bool]($source -match 'screencap|uiautomator|dumpsys\s+window|pm[^\r\n]+clear|uninstall|reboot|svc[^\r\n]+disable|appops[^\r\n]+set')) $false
Assert-Equal ([bool]($source -match 'RawStdout|RawStderr|PackageHistory|NodeContent')) $false
Write-Host "$script:Checks oracle-transport assertions passed; no device command was executed."
