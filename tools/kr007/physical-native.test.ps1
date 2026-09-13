Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot\physical-invalid-camera.ps1"
$owned = Join-Path ([IO.Path]::GetTempPath()) ('kr007-native-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($owned)
$exe = Join-Path $owned 'fixture.exe'
try {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $build = & $compiler /nologo /target:exe "/out:$exe" "$PSScriptRoot\NativePreparationFixture.cs" 2>&1
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $exe)) { throw 'FAKE_NATIVE_BUILD_FAILED' }
    $oldWrapperThrew=$false
    try {
        # Exact former wrapper boundary, replacing ONLY adb.exe with a native fixture.
        $Command=@('info')
        $output = & $exe @Command 2>&1
        if ($LASTEXITCODE -ne 0) { throw 'ADB_REJECTED' }
        $null = (($output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    } catch { $oldWrapperThrew=$true }
    Write-Output "OLD_STDERR_STOP_INTERFERENCE=$oldWrapperThrew PS_MAJOR=$($PSVersionTable.PSVersion.Major)"
    if ($PSVersionTable.PSVersion.Major -eq 5 -and !$oldWrapperThrew) { throw 'EXPECTED_51_REPRO_NOT_OBSERVED' }
    $r=Invoke-KRInvalidProcess $exe @('info')
    if (!$r.Completed -or $r.ExitCode -ne 0 -or $r.Stdout.Trim() -ne 'Success' -or !$r.Stderr.Contains('informational')) { throw 'SEPARATE_STREAMS_FAILED' }
    $d=Get-KRInvalidNativeDiagnostic $r
    if ($d.Category -ne 'NONE' -or $d.InstallCode -ne 'NONE') { throw 'INFORMATIONAL_STDERR_REJECTED' }
    $r=Invoke-KRInvalidProcess $exe @('reject'); $d=Get-KRInvalidNativeDiagnostic $r
    if (!$r.Completed -or $d.ExitCode -ne 7 -or $d.InstallCode -ne 'INSTALL_FAILED_USER_RESTRICTED' -or $d.Category -ne 'INSTALLER_REJECTION') { throw 'INSTALLER_REJECTION_LOST' }
    if (($d | ConvertTo-Json -Compress) -match 'PRIVATE_SYNTHETIC_DETAIL') { throw 'RAW_DETAIL_LEAK' }
    $r=Invoke-KRInvalidProcess $exe @('missing')
    if (!$r.Completed -or $r.ExitCode -ne 0 -or $r.Stdout -match '(?m)^Success\s*$') { throw 'MISSING_SUCCESS_CONTROL_FAILED' }
    $r=Invoke-KRInvalidProcess (Join-Path $owned 'absent.exe') @('info')
    if ($r.Completed -or $r.ExitCode -ne 'UNKNOWN' -or $r.Category -ne 'PROCESS_START_FAILED') { throw 'START_FAILURE_LOST' }
    $r=Invoke-KRInvalidProcess $exe @('slow') 100
    if ($r.Completed -or $r.ExitCode -ne 'UNKNOWN' -or $r.Category -ne 'PROCESS_TIMEOUT') { throw 'INCOMPLETE_EXECUTION_LOST' }
    $argument='a space "quoted" trailing\'
    $r=Invoke-KRInvalidProcess $exe @('args',$argument)
    if (!$r.Completed -or $r.Stdout.TrimEnd("`r","`n") -cne $argument) { throw 'NATIVE_ARGUMENT_QUOTING_FAILED' }
    Write-Output 'NATIVE_PROCESS_CASES=6 PASS; REAL_FAKE_EXECUTABLE_NO_ADB'
} finally {
    # Only newly allocated test artifacts; no device/tool/other process cleanup.
    if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe }
    [IO.Directory]::Delete($owned)
}
