<#
Goal: Identify one authorized Android configuration and test one shell tap against the independent fixture.
Context: New-device transport must be known before the enforcement candidate is installed or configured.
Constraints: Fixture only; no timer, candidate install, network/permission/configuration change, serial/account/content/history capture or destructive action.
Done when: Sanitized metadata and exact hashes are preserved and one tap increments the fixture counter exactly once, or a typed stop result is preserved.
#>
param([string]$Adb='C:\platform-tools\adb.exe',[string]$OutputRoot='C:\platform-tools\kr003-device-preflight')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'OracleTransport.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'DevicePreflight.psm1') -Force

$fixturePackage='dev.kidremote.spike.ordinary'
$fixtureReceiver="$fixturePackage/.FixtureReceiver"
$fixtureActivity="$fixturePackage/.FixtureActivity"
$candidatePackage='dev.kidremote.spike.enforcement'
$candidateService="$candidatePackage/.EnforcementAccessibilityService"
$runDirectory=Join-Path $OutputRoot ('device-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
$script:Operations=@(); $script:Request=0L; $script:Bundle=$null; $script:Device=$null
$script:DeviceEvidenceSha256=$null
$script:Authorized=$false; $script:MetadataComplete=$false; $script:BundleVerified=$false; $script:InstalledHashVerified=$false; $script:FixtureReady=$false
$script:BeforeTaps=$null; $script:AfterTaps=$null; $script:RejectedOperation=$null; $script:RejectedExitCode=$null; $script:RejectedStderrClass=$null
$script:Status='INVALID'; $script:Reason='NOT_STARTED'; $startedUtc=[DateTime]::UtcNow.ToString('o')

function Write-DeviceJson([string]$Name,$Value) {
    [IO.File]::WriteAllText((Join-Path $runDirectory $Name),(ConvertTo-Json -InputObject $Value -Depth 12),(New-Object Text.UTF8Encoding($false)))
}
function Save-DeviceOperations { Write-DeviceJson 'operations.json' @($script:Operations) }

function Invoke-DeviceAdb {
    param([string]$Category,[string[]]$Arguments,[switch]$Optional)
    $process=New-Object Diagnostics.Process
    $process.StartInfo=New-Object Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName=$Adb; $process.StartInfo.UseShellExecute=$false
    $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true; $process.StartInfo.CreateNoWindow=$true
    $quoted=foreach($argument in $Arguments) {
        if ($argument.Contains('"') -or $argument.Contains([string][char]13) -or $argument.Contains([string][char]10) -or $argument.EndsWith('\')) { throw 'INVALID:ADB_ARGUMENT' }
        '"' + $argument + '"'
    }
    $process.StartInfo.Arguments=$quoted -join ' '
    try {
        [void]$process.Start(); $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill(); $script:Operations += New-KRDeviceOperationRecord $Category -1 'OTHER'; Save-DeviceOperations
            $script:RejectedOperation=$Category; $script:RejectedExitCode=-1; $script:RejectedStderrClass='OTHER'; throw 'INVALID:ADB_TIMEOUT'
        }
        $stdout=$stdoutTask.GetAwaiter().GetResult(); $stderr=$stderrTask.GetAwaiter().GetResult(); $stderrClass=Get-KRTransportStderrClass $stderr
        $script:Operations += New-KRDeviceOperationRecord $Category $process.ExitCode $stderrClass; Save-DeviceOperations
        if ($process.ExitCode -ne 0 -or $stderrClass -in @('SECURITY_EXCEPTION','PERMISSION_DENIAL')) {
            if ($Optional) { return $null }
            $script:RejectedOperation=$Category; $script:RejectedExitCode=$process.ExitCode; $script:RejectedStderrClass=$stderrClass
            throw 'INVALID:ADB_OPERATION_REJECTED'
        }
        return $stdout
    } finally { $process.Dispose() }
}

function Read-DeviceMetadata {
    $manufacturer=Invoke-DeviceAdb 'DEVICE_METADATA' @('shell','getprop','ro.product.manufacturer')
    $model=Invoke-DeviceAdb 'DEVICE_METADATA' @('shell','getprop','ro.product.model')
    $android=Invoke-DeviceAdb 'DEVICE_METADATA' @('shell','getprop','ro.build.version.release')
    $api=Invoke-DeviceAdb 'DEVICE_METADATA' @('shell','getprop','ro.build.version.sdk')
    $patch=Invoke-DeviceAdb 'DEVICE_METADATA' @('shell','getprop','ro.build.version.security_patch')
    $build=Invoke-DeviceAdb 'DEVICE_METADATA' @('shell','getprop','ro.build.id')
    $batterySaver=Invoke-DeviceAdb 'BATTERY_STATE' @('shell','settings','get','global','low_power') -Optional
    $adaptiveBattery=Invoke-DeviceAdb 'BATTERY_STATE' @('shell','settings','get','global','adaptive_battery_management_enabled') -Optional
    $appStandby=Invoke-DeviceAdb 'BATTERY_STATE' @('shell','settings','get','global','app_standby_enabled') -Optional
    $candidatePath=Invoke-DeviceAdb 'CANDIDATE_INSTALL_STATE' @('shell','pm','path',$candidatePackage) -Optional
    $candidateInstalled=(-not [string]::IsNullOrWhiteSpace($candidatePath))
    $usage=$null; $services=$null; $accessibility=$null
    if($candidateInstalled) {
        $usage=Invoke-DeviceAdb 'USAGE_ACCESS_STATE' @('shell','cmd','appops','get',$candidatePackage,'GET_USAGE_STATS') -Optional
        $services=Invoke-DeviceAdb 'ACCESSIBILITY_STATE' @('shell','settings','get','secure','enabled_accessibility_services') -Optional
        $accessibility=Invoke-DeviceAdb 'ACCESSIBILITY_STATE' @('shell','settings','get','secure','accessibility_enabled') -Optional
    }
    $result=New-KRDeviceMetadataRecord $manufacturer $model $android $api $patch $build $batterySaver $adaptiveBattery $appStandby $candidateInstalled $usage $services $accessibility $candidateService
    $script:MetadataComplete=Test-KRDeviceMetadataComplete $result
    return $result
}

function Get-FixtureState {
    $script:Request++
    $raw=Invoke-DeviceAdb 'FIXTURE_STATE' @('shell','am','broadcast','--receiver-foreground','-n',$fixtureReceiver,'--el','request',"$script:Request")
    $state=Convert-KRReply -Raw $raw -Request $script:Request -Fixture
    if($state.schema -ne 2){throw 'INVALID:FIXTURE_SCHEMA'}
    return $state
}

try {
    New-Item -ItemType Directory -Path $runDirectory | Out-Null
    if(-not (Test-Path -LiteralPath $Adb)){throw 'INVALID:ADB_MISSING'}
    $script:Bundle=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle.json') -Raw | ConvertFrom-Json
    if($script:Bundle.schema -ne 1 -or $script:Bundle.protocol -ne 'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT' -or $script:Bundle.runnerVersion -ne 1 -or -not $script:Bundle.fixtureOnly){throw 'INVALID:BUNDLE_SCHEMA'}
    foreach($entry in $script:Bundle.files){
        if($entry.name -notmatch '^[A-Za-z0-9_.-]+$'){throw 'INVALID:BUNDLE_PATH'}
        if((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $entry.name)).Hash.ToLowerInvariant() -cne $entry.sha256){throw 'INVALID:BUNDLE_INTEGRITY'}
    }
    $script:BundleVerified=$true
    if((Invoke-DeviceAdb 'ADB_STATE' @('get-state')).Trim() -cne 'device'){throw 'INVALID:ADB_NOT_AUTHORIZED_OR_UNAVAILABLE'}
    $script:Authorized=$true
    $script:Device=Read-DeviceMetadata; Write-DeviceJson 'device.json' $script:Device
    $script:DeviceEvidenceSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $runDirectory 'device.json')).Hash.ToLowerInvariant()
    if(-not $script:MetadataComplete){throw 'INVALID:DEVICE_METADATA_INCOMPLETE'}
    $fixtureFile=Join-Path $PSScriptRoot 'ordinary-fixture.apk'
    if((Get-FileHash -Algorithm SHA256 -LiteralPath $fixtureFile).Hash.ToLowerInvariant() -cne $script:Bundle.fixtureSha256){throw 'INVALID:APK_HASH'}
    $install=Invoke-DeviceAdb 'FIXTURE_INSTALL' @('install','-r',$fixtureFile)
    if($install -notmatch '(?m)^Success\s*$'){throw 'INVALID:INSTALL_FAILED_NO_UNINSTALL_FALLBACK'}
    $path=(Invoke-DeviceAdb 'FIXTURE_PATH' @('shell','pm','path',$fixturePackage)).Trim()
    if($path -notmatch '^package:(/data/app/[A-Za-z0-9_~+/=.-]+/base\.apk)$'){throw 'INVALID:INSTALLED_PATH_OR_SPLIT_APK'}
    $pulled=Join-Path $runDirectory 'installed-ordinary-fixture.apk'
    $null=Invoke-DeviceAdb 'FIXTURE_PULL' @('pull',$Matches[1],$pulled)
    if((Get-FileHash -Algorithm SHA256 -LiteralPath $pulled).Hash.ToLowerInvariant() -cne $script:Bundle.fixtureSha256){throw 'INVALID:INSTALLED_APK_MISMATCH'}
    $script:InstalledHashVerified=$true
    $null=Invoke-DeviceAdb 'FIXTURE_OPEN' @('shell','am','start','-n',$fixtureActivity)
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do { $before=Get-FixtureState; if($before.probeReady -and $before.focused -and $before.resumed){break}; Start-Sleep -Milliseconds 100 } while($watch.Elapsed.TotalSeconds -lt 5)
    if(-not $before.probeReady -or -not $before.focused -or -not $before.resumed){throw 'INVALID:FIXTURE_NOT_READY'}
    $script:FixtureReady=$true; $script:BeforeTaps=[long]$before.taps
    $null=Invoke-DeviceAdb 'INPUT_TAP' @('shell','input','tap',([string]$before.probeX),([string]$before.probeY))
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do {
        $after=Get-FixtureState
        if($after.instance -ne $before.instance -or $after.probeX -ne $before.probeX -or $after.probeY -ne $before.probeY -or -not $after.focused -or -not $after.resumed){throw 'INVALID:FIXTURE_CHANGED'}
        $script:AfterTaps=[long]$after.taps; if($script:AfterTaps -ne $script:BeforeTaps){break}; Start-Sleep -Milliseconds 100
    } while($watch.Elapsed.TotalSeconds -lt 3)
    $script:Status=Get-KRDeviceTransportVerdict $script:Authorized $script:MetadataComplete $script:BundleVerified $script:InstalledHashVerified $script:FixtureReady $script:BeforeTaps $script:AfterTaps $script:RejectedOperation
    if($script:Status -ne 'PASSED_TRANSPORT_PREFLIGHT'){throw 'FAIL:INPUT_NOT_DELIVERED'}
    $script:Reason='FIXTURE_COUNTER_INCREMENTED_ONCE'
} catch {
    $message=$_.Exception.Message; if($message -notmatch '^(FAIL|INVALID):[A-Z0-9_]+$'){$message='INVALID:HOST_EXCEPTION'}
    $parts=$message.Split(':'); $script:Status=$parts[0]; $script:Reason=$parts[1]
} finally {
    if(Test-Path -LiteralPath $runDirectory){
        try{Save-DeviceOperations}catch{}
        $summary=[PSCustomObject]@{
            Protocol='KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT';Status=$script:Status;Reason=$script:Reason
            SourceCommit=$(if($null -eq $script:Bundle){$null}else{$script:Bundle.sourceCommit});FixtureSha256=$(if($null -eq $script:Bundle){$null}else{$script:Bundle.fixtureSha256})
            DeviceEvidenceSha256=$script:DeviceEvidenceSha256
            StartedUtc=$startedUtc;EndedUtc=[DateTime]::UtcNow.ToString('o');AdbAuthorized=$script:Authorized;MetadataComplete=$script:MetadataComplete
            BundleVerified=$script:BundleVerified;InstalledFixtureHashVerified=$script:InstalledHashVerified;FixtureReady=$script:FixtureReady
            BeforeTaps=$script:BeforeTaps;AfterTaps=$script:AfterTaps;CounterIncremented=$(if($null -eq $script:BeforeTaps -or $null -eq $script:AfterTaps){$false}else{$script:AfterTaps -eq $script:BeforeTaps+1})
            RejectedOperation=$script:RejectedOperation;RejectedExitCode=$script:RejectedExitCode;RejectedStderrClass=$script:RejectedStderrClass
            CandidateInstalledByRunner=$false;TimerUsed=$false;RestrictionChanged=$false;RadiosChanged=$false;PermissionsChanged=$false;DestructiveAction=$false;QualificationSamples=0
        }
        try{Write-DeviceJson 'summary.json' $summary}catch{}
        Write-Host ('Evidence saved: '+$runDirectory);Write-Host ('Primary result: '+$script:Status+':'+$script:Reason)
    }
}
if($script:Status -eq 'PASSED_TRANSPORT_PREFLIGHT'){exit 0};exit 2
