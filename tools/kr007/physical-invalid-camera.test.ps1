# Preparation-only tests: all ADB, viewer, hash/file and owner-input boundaries are fakes.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility
. "$PSScriptRoot\physical-invalid-camera.ps1"
function Test-Path {
    param($LiteralPath,$PathType)
    if ($script:case -eq 'adb-missing' -and $LiteralPath.EndsWith('adb.exe')) { return $false }
    if ($script:case -in @('store-paint','viewer-missing') -and $LiteralPath -eq 'C:\Windows\System32\mspaint.exe') { return $false }
    return $true
}
function Get-AppxPackage {
    param($Name)
    if ($script:case -eq 'viewer-missing') { return }
    return @{PackageFamilyName='Microsoft.Paint_8wekyb3d8bbwe';Status='Ok';SignatureKind='Store';IsDevelopmentMode=$false;InstallLocation='C:\SyntheticPaint'}
}
function Get-FileHash {
    param($LiteralPath,$Algorithm)
    if ($script:case -eq 'bad-hash') { return @{Hash='BAD'} }
    if ($script:case -eq 'unreadable') { throw [UnauthorizedAccessException]::new('SENSITIVE_DO_NOT_OUTPUT') }
    if ($script:case -eq 'qr-hash' -and $LiteralPath.EndsWith('.png')) { return @{Hash='BAD'} }
    if ($LiteralPath.EndsWith('.apk')) { return @{Hash='3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9'} }
    return @{Hash='3c9a84602486d7052346116f0e182527578970f36a894a8a733b6515cd1d5287'}
}
function Start-Process { param($FilePath,$ArgumentList) $script:viewerCalls++ }
function Read-Host {
    param($Prompt)
    if ($Prompt.StartsWith('Conecte')) { return 'SM-X400' }
    if ($Prompt.StartsWith('P=')) { if ($script:case -eq 'unrecognized') { return 'N' }; return 'P' }
    return 'S'
}
function Invoke-KRInvalidAdb {
    param([string[]]$Command)
    $script:calls.Add(($Command -join ' '))
    if ($Command[0] -eq 'devices') {
        if ($script:case -eq 'multiple') { return "List of devices attached`nSYNTHETIC device`nSECOND device" }
        return "List of devices attached`nSYNTHETIC device"
    }
    if ($Command[0] -ne '-s' -or $Command[1] -ne 'SYNTHETIC') { throw 'UNTARGETED_TEST_COMMAND' }
    $c = $Command[2..($Command.Count-1)] -join ' '
    switch -Regex ($c) {
        '^shell getprop ro.product.model$' { if ($script:case -eq 'foreign') { return 'OTHER' }; return 'SM-X400' }
        '^shell getprop ro.product.manufacturer$' { return 'samsung' }
        '^shell getprop ro.build.version.sdk$' { return '36' }
        '^shell getprop ro.build.version.release$' { return '16' }
        '^shell am get-current-user$' { return '0' }
        '^shell pm list packages -u ' { if ($script:case -eq 'existing') { return 'package:dev.kidremote.child.unassigned.debug' }; return '' }
        '^shell cmd package help$' { if ($script:case -eq 'unknown-capability') { return 'UNKNOWN' }; return '  -R: disallow replacement of existing application' }
        '^install --no-streaming -R --user 0 ' { if ($script:case -eq 'install-error') { throw 'SENSITIVE_DO_NOT_OUTPUT' }; return "Performing Push Install`nSuccess" }
        '^shell am start -W -n ' { return 'Status: ok' }
        '^shell run-as ' { if ($script:case -eq 'identity-present') { return 'PRESENT' }; return 'EMPTY' }
        default { throw 'UNEXPECTED_TEST_COMMAND' }
    }
}
$count = 0
foreach ($case in @('success','store-paint','existing','multiple','foreign','bad-hash','unknown-capability','identity-present','unrecognized','adb-missing','viewer-missing','unreadable','qr-hash','install-error','host-only')) {
    $script:case=$case; $script:calls=[Collections.Generic.List[string]]::new(); $script:viewerCalls=0
    $output = (Invoke-KRInvalidCamera -HostOnly:($case -eq 'host-only')) -join "`n"
    if ($case -in @('success','store-paint')) {
        if ($output -notmatch 'RESULT=OWNER_OBSERVED_INVALID_QR_WITH_EMPTY_LOCAL_IDENTITY' -or $script:viewerCalls -ne 1) { Write-Output "FAILED_CASE=$case"; Write-Output ($output -split "`n" | Where-Object { $_ -match '^(FAILED_CHECK|STOP_STAGE|EXCEPTION_CATEGORY)=' }); throw 'SUCCESS_FLOW_ASSERTION' }
    } elseif ($output -match 'RESULT=OWNER_OBSERVED_INVALID_QR_WITH_EMPTY_LOCAL_IDENTITY') { throw 'FALSE_SUCCESS' }
    if ($case -in @('existing','multiple','foreign','bad-hash','unknown-capability')) {
        if (@($script:calls | Where-Object { $_ -match ' install | am start ' }).Count -ne 0) { throw 'MUTATION_BEFORE_GUARD' }
    }
    if ($case -in @('adb-missing','viewer-missing','bad-hash','unreadable','qr-hash','host-only')) {
        if ($script:calls.Count -ne 0 -or $script:viewerCalls -ne 0 -or $output -notmatch 'INSTALLATION_STATUS=NOT_ATTEMPTED') { throw 'LOCAL_GUARD_REACHED_ADB' }
    }
    $expectedReason = @{ 'adb-missing'='ADB_PATH'; 'viewer-missing'='LOCAL_VIEWER'; 'bad-hash'='APK_READ_HASH'; 'unreadable'='APK_READ_HASH'; 'qr-hash'='QR_READ_HASH' }
    if ($expectedReason.ContainsKey($case) -and $output -notmatch "FAILED_CHECK=$($expectedReason[$case])") { throw 'WRONG_FAILED_CHECK' }
    if ($case -eq 'install-error' -and $output -notmatch 'INSTALLATION_STATUS=ATTEMPTED_UNVERIFIED') { throw 'LOST_INSTALL_ATTEMPT' }
    if ($case -eq 'success' -and $output -notmatch 'INSTALLATION_STATUS=VERIFIED') { throw 'LOST_VERIFIED_INSTALL' }
    if ($output -match 'SENSITIVE_DO_NOT_OUTPUT') { throw 'RAW_EXCEPTION_LEAK' }
    if ($output -match 'SYNTHETIC|SECOND|package:') { throw 'RAW_TARGET_OR_PACKAGE_OUTPUT' }
    if (($script:calls -join "`n") -match 'uninstall|clear-data|pm clear|pm grant|pm revoke|logcat|screencap|kill-server') { throw 'OUT_OF_SCOPE_OPERATION' }
    $count++
}
foreach ($name in @('ADB_TRACE','ADB_SERVER_SOCKET','ANDROID_ADB_SERVER_PORT')) {
    $saved=[Environment]::GetEnvironmentVariable($name)
    try {
        [Environment]::SetEnvironmentVariable($name,'SENSITIVE_DO_NOT_OUTPUT')
        $script:calls.Clear(); $output=(Invoke-KRInvalidCamera) -join "`n"
        if ($script:calls.Count -ne 0 -or $output -notmatch 'FAILED_CHECK=ADB_ENVIRONMENT' -or $output -match 'SENSITIVE_DO_NOT_OUTPUT') { throw 'ENVIRONMENT_GUARD_FAILED' }
        $count++
    } finally { [Environment]::SetEnvironmentVariable($name,$saved) }
}
Write-Output "PREPARATION_FAKE_BOUNDARY_TESTS=$count PASS; NO_ADB_NO_DEVICE_NO_VIEWER_EXECUTED"
