# Preparation-only tests: all ADB, viewer, hash/file and owner-input boundaries are fakes.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\physical-invalid-camera.ps1"
function Test-Path { param($LiteralPath) return $true }
function Get-FileHash {
    param($LiteralPath,$Algorithm)
    if ($script:case -eq 'bad-hash') { return @{Hash='BAD'} }
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
        '^install --no-streaming -R --user 0 ' { return "Performing Push Install`nSuccess" }
        '^shell am start -W -n ' { return 'Status: ok' }
        '^shell run-as ' { if ($script:case -eq 'identity-present') { return 'PRESENT' }; return 'EMPTY' }
        default { throw 'UNEXPECTED_TEST_COMMAND' }
    }
}
$count = 0
foreach ($case in @('success','existing','multiple','foreign','bad-hash','unknown-capability','identity-present','unrecognized')) {
    $script:case=$case; $script:calls=[Collections.Generic.List[string]]::new(); $script:viewerCalls=0
    $output = (Invoke-KRInvalidCamera) -join "`n"
    if ($case -eq 'success') {
        if ($output -notmatch 'RESULT=OWNER_OBSERVED_INVALID_QR_WITH_EMPTY_LOCAL_IDENTITY' -or $script:viewerCalls -ne 1) { throw 'SUCCESS_FLOW_ASSERTION' }
    } elseif ($output -match 'RESULT=OWNER_OBSERVED_INVALID_QR_WITH_EMPTY_LOCAL_IDENTITY') { throw 'FALSE_SUCCESS' }
    if ($case -in @('existing','multiple','foreign','bad-hash','unknown-capability')) {
        if (@($script:calls | Where-Object { $_ -match ' install | am start ' }).Count -ne 0) { throw 'MUTATION_BEFORE_GUARD' }
    }
    if ($output -match 'SYNTHETIC|SECOND|package:') { throw 'RAW_TARGET_OR_PACKAGE_OUTPUT' }
    if (($script:calls -join "`n") -match 'uninstall|clear-data|pm clear|pm grant|pm revoke|logcat|screencap|kill-server') { throw 'OUT_OF_SCOPE_OPERATION' }
    $count++
}
Write-Output "PREPARATION_FAKE_BOUNDARY_TESTS=$count PASS; NO_ADB_NO_DEVICE_NO_VIEWER_EXECUTED"
