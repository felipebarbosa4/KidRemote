# Owner-operated only. Dot-source for preparation tests; never executed by the agent against ADB.
param([switch]$HostOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-KRInvalidArtifacts {
    $script:failedLocalCheck = 'ADB_ENVIRONMENT'
    if ($env:ADB_TRACE -or $env:ADB_SERVER_SOCKET -or $env:ANDROID_ADB_SERVER_PORT) { throw 'GUARD' }
    $root = 'C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe'
    $apk = "$root\artifacts-kr007-14d82db\debug\child-debug.apk"
    $qr = "$root\camera-storage-2026-09-11T23-02-20-209Z\scene-invalid.png"
    $script:failedLocalCheck = 'ADB_PATH'
    if (!(Test-Path -LiteralPath 'C:\platform-tools\adb.exe' -PathType Leaf)) { throw 'GUARD' }
    $script:failedLocalCheck = 'LOCAL_VIEWER'
    $viewer = 'C:\Windows\System32\mspaint.exe'
    if (!(Test-Path -LiteralPath $viewer -PathType Leaf)) {
        $paint = @(Get-AppxPackage -Name Microsoft.Paint | Where-Object {
            $_.PackageFamilyName -eq 'Microsoft.Paint_8wekyb3d8bbwe' -and
            [string]$_.Status -eq 'Ok' -and [string]$_.SignatureKind -eq 'Store' -and !$_.IsDevelopmentMode
        })
        if ($paint.Count -ne 1) { throw 'GUARD' }
        $viewer = Join-Path $paint[0].InstallLocation 'PaintApp\mspaint.exe'
        if (!(Test-Path -LiteralPath $viewer -PathType Leaf)) { throw 'GUARD' }
    }
    $script:failedLocalCheck = 'APK_READ_HASH'
    if ((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne '3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9') { throw 'GUARD' }
    $script:failedLocalCheck = 'QR_READ_HASH'
    if ((Get-FileHash -LiteralPath $qr -Algorithm SHA256).Hash -ne '3c9a84602486d7052346116f0e182527578970f36a894a8a733b6515cd1d5287') { throw 'GUARD' }
    return @{Apk=$apk; Qr=$qr; Viewer=$viewer}
}
function Invoke-KRInvalidProcess([string]$Executable,[string[]]$Command,[int]$TimeoutMillis=120000) {
    # Same redirected Process pattern as existing host tools; no PowerShell stderr pipeline.
    $p = New-Object Diagnostics.Process
    $p.StartInfo.FileName=$Executable; $p.StartInfo.UseShellExecute=$false; $p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardOutput=$true; $p.StartInfo.RedirectStandardError=$true
    $p.StartInfo.Arguments=($Command | ForEach-Object {
        '"' + ([regex]::Replace([regex]::Replace($_,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')) + '"'
    }) -join ' '
    $r=@{Completed=$false; ExitCode='UNKNOWN'; Stdout=''; Stderr=''; Category='PROCESS_START_FAILED'}
    $started=$false
    try {
        $started=$p.Start()
        if (!$started) { return $r }
        $outTask=$p.StandardOutput.ReadToEndAsync(); $errTask=$p.StandardError.ReadToEndAsync()
        $r.Category='PROCESS_TIMEOUT'
        if (!$p.WaitForExit($TimeoutMillis)) { return $r }
        $r.ExitCode=$p.ExitCode; $r.Category='STREAM_INCOMPLETE'
        if (!$outTask.Wait(5000) -or !$errTask.Wait(5000)) { return $r }
        $r.Stdout=$outTask.Result; $r.Stderr=$errTask.Result; $r.Completed=$true; $r.Category='NONE'
    } catch {
        $r.Category=if (!$started) {'PROCESS_START_FAILED'} else {'PROCESS_IO_FAILED'}
    } finally {
        if ($started -and !$p.HasExited) {
            try { $p.Kill(); if (!$p.WaitForExit(5000)) { $r.Category='PROCESS_TERMINATION_UNVERIFIED' } }
            catch { $r.Category='PROCESS_TERMINATION_UNVERIFIED' }
        }
        $p.Dispose()
    }
    return $r
}
function Get-KRInvalidNativeDiagnostic($Result) {
    $text=$Result.Stdout + "`n" + $Result.Stderr # In memory only; never print raw native output.
    $code='NONE'
    $known=@('INSTALL_FAILED_USER_RESTRICTED','INSTALL_FAILED_ALREADY_EXISTS','INSTALL_FAILED_UPDATE_INCOMPATIBLE',
        'INSTALL_FAILED_VERSION_DOWNGRADE','INSTALL_FAILED_INSUFFICIENT_STORAGE','INSTALL_FAILED_INVALID_APK',
        'INSTALL_FAILED_NO_MATCHING_ABIS','INSTALL_FAILED_OLDER_SDK','INSTALL_FAILED_TEST_ONLY',
        'INSTALL_FAILED_DUPLICATE_PERMISSION','INSTALL_FAILED_ABORTED','INSTALL_FAILED_INTERNAL_ERROR',
        'INSTALL_FAILED_VERIFICATION_FAILURE','INSTALL_FAILED_VERIFICATION_TIMEOUT','INSTALL_FAILED_MISSING_SPLIT',
        'INSTALL_PARSE_FAILED_NOT_APK','INSTALL_PARSE_FAILED_BAD_MANIFEST','INSTALL_PARSE_FAILED_NO_CERTIFICATES',
        'INSTALL_PARSE_FAILED_INCONSISTENT_CERTIFICATES','INSTALL_PARSE_FAILED_MANIFEST_MALFORMED')
    if ($text -match '\b(INSTALL_(?:FAILED|PARSE_FAILED)_[A-Z0-9_]+)\b') {
        $code=if ($Matches[1] -cin $known) {$Matches[1]} else {'UNRECOGNIZED_INSTALL_CODE'}
    }
    $category=$Result.Category
    if ($Result.Completed -and $Result.ExitCode -ne 0) {
        $category=if ($code -ne 'NONE') {'INSTALLER_REJECTION'} elseif ($text -match 'device unauthorized') {'TRANSPORT_UNAUTHORIZED'} elseif ($text -match 'device offline') {'TRANSPORT_OFFLINE'} else {'NATIVE_NONZERO_EXIT'}
    }
    return @{ExitCode=$Result.ExitCode; InstallCode=$code; Category=$category; Completed=$Result.Completed}
}
function Invoke-KRInvalidAdb([string[]]$Command) {
    $result=Invoke-KRInvalidProcess 'C:\platform-tools\adb.exe' $Command
    $script:lastNativeDiagnostic=Get-KRInvalidNativeDiagnostic $result
    if (!$result.Completed -or $result.ExitCode -ne 0 -or $script:lastNativeDiagnostic.InstallCode -ne 'NONE') { throw 'ADB_NATIVE_RESULT_REJECTED' }
    return $result.Stdout.Trim()
}
function Invoke-KRInvalidCamera([switch]$HostOnly) {
    $stage = 'LOCAL_ARTIFACTS'
    $installationStatus = 'NOT_ATTEMPTED'
    $script:lastNativeDiagnostic=$null
    try {
        $artifacts = Get-KRInvalidArtifacts
        $apk = $artifacts.Apk; $qr = $artifacts.Qr
        $package = 'dev.kidremote.child.unassigned.debug'
        if ($HostOnly) { Write-Output 'HOST_ARTIFACT_CHECKS=PASS_NO_ADB'; return }
        $stage = 'OWNER_TARGET_CONFIRMATION'
        if ((Read-Host 'Conecte SOMENTE o Samsung SM-X400 por USB. Sem restricao KR-003 impedindo o teste, digite SM-X400; qualquer outra resposta para') -cne 'SM-X400') { throw 'OWNER_STOP' }
        $stage = 'SINGLE_USB_TARGET'
        $listing = Invoke-KRInvalidAdb @('devices')
        $lines = @($listing -split "`r?`n" | Where-Object { $_.Trim() -and $_ -notmatch '^List of devices attached' })
        if ($lines.Count -ne 1 -or $lines[0] -notmatch '^([A-Za-z0-9]+)\s+device$') { throw 'TARGET_UNKNOWN' }
        $selectedDevice = $Matches[1] # Memory only; never printed or persisted.
        $target = @('-s', $selectedDevice)
        $stage = 'CONFIGURATION'
        $model = Invoke-KRInvalidAdb ($target + @('shell','getprop','ro.product.model'))
        $maker = Invoke-KRInvalidAdb ($target + @('shell','getprop','ro.product.manufacturer'))
        $api = Invoke-KRInvalidAdb ($target + @('shell','getprop','ro.build.version.sdk'))
        $android = Invoke-KRInvalidAdb ($target + @('shell','getprop','ro.build.version.release'))
        if ($model -cne 'SM-X400' -or $maker -ine 'samsung' -or $api -ne '36' -or $android -ne '16') { throw 'CONFIGURATION_MISMATCH' }
        if ((Invoke-KRInvalidAdb ($target + @('shell','am','get-current-user'))) -ne '0') { throw 'NONPRIMARY_USER' }
        Write-Output 'CONFIGURATION=samsung/SM-X400/Android16/API36'
        $stage = 'PACKAGE_ABSENCE'
        # Filter on the device; -u includes retained uninstalled records. Never list unrelated packages.
        $existing = Invoke-KRInvalidAdb ($target + @('shell','pm','list','packages','-u',$package))
        if ($existing -ne '') { throw 'EXISTING_OR_UNKNOWN_PACKAGE_RECORD' }
        $stage = 'NO_REPLACE_CAPABILITY'
        $helpText = Invoke-KRInvalidAdb ($target + @('shell','cmd','package','help'))
        if ($helpText -notmatch '(?m)^\s*-R:\s*disallow replacement of existing application') { throw 'NO_REPLACE_NOT_VERIFIED' }
        $stage = 'PACKAGE_ABSENCE_RECHECK'
        if ((Invoke-KRInvalidAdb ($target + @('shell','pm','list','packages','-u',$package))) -ne '') { throw 'EXISTING_OR_UNKNOWN_PACKAGE_RECORD' }
        $stage = 'INSTALL_NEW_ONLY'
        # -R explicitly disables replacement at the package-manager boundary; never -r or -g.
        $installationStatus = 'ATTEMPTED_UNVERIFIED'
        $installResult = Invoke-KRInvalidAdb ($target + @('install','--no-streaming','-R','--user','0',$apk))
        $stage = 'INSTALL_SUCCESS_RESPONSE'
        if ($installResult -notmatch '(?m)^Success\s*$') { throw 'INSTALL_NOT_VERIFIED' }
        $stage = 'INSTALL_PACKAGE_VERIFICATION'
        $verifiedPackage=Invoke-KRInvalidAdb ($target + @('shell','pm','list','packages','--user','0',$package))
        if ($verifiedPackage -cne "package:$package") { throw 'INSTALL_PACKAGE_NOT_VERIFIED' }
        $installationStatus = 'VERIFIED'
        $stage = 'OPEN'
        $openResult = Invoke-KRInvalidAdb ($target + @('shell','am','start','-W','-n',"$package/dev.kidremote.child.ChildActivity"))
        if ($openResult -notmatch '(?m)^Status: ok\s*$') { throw 'OPEN_NOT_VERIFIED' }
        $stage = 'FRESH_STATE'
        # Read only two existence bits, never credential bytes or directory contents.
        $probe = '"if [ -d no_backup ]; then if [ ! -e no_backup/device-identity ] && [ ! -e no_backup/pairing-pending ]; then echo EMPTY; else echo PRESENT; fi; else echo UNKNOWN; fi"'
        if ((Invoke-KRInvalidAdb ($target + @('shell','run-as',$package,'sh','-c',$probe))) -ne 'EMPTY') { throw 'IDENTITY_STATE_UNKNOWN_OR_PRESENT' }
        if ((Read-Host 'Aguarde carregar. Confirma tela Nao pareado, sem recuperacao/pareamento pendente? S=sim; outro=parar') -ine 'S') { throw 'NOT_FRESH' }
        $stage = 'OWNER_CAMERA_CHECK'
        Start-Process -FilePath $artifacts.Viewer -ArgumentList ('"' + $qr + '"') # Owner-local only.
        Write-Output 'No PC: mostre o QR inteiro, sem recortar a borda branca. No tablet: Escanear QR do responsavel; permita camera manualmente; aponte somente para este QR por ate 30 segundos.'
        $answer = Read-Host 'P=apareceu QR invalido apos escanear; N=nao reconheceu; E=outro erro; qualquer outra resposta=incerto'
        $stage = 'POST_STATE'
        $emptyAfter = (Invoke-KRInvalidAdb ($target + @('shell','run-as',$package,'sh','-c',$probe))) -eq 'EMPTY'
        Write-Output "NO_LOCAL_IDENTITY_OR_PENDING=$emptyAfter"
        $stage = 'OWNER_CAMERA_RELEASE'
        $released = (Read-Host 'Se ainda escaneando, toque Parar camera. Confirme preview fechado e indicador de camera deixou de indicar uso ativo por este app. S=confirmado; outro=incerto') -ieq 'S'
        Write-Output "OWNER_CAMERA_RELEASE_CONFIRMED=$released"
        if ($answer -ieq 'P' -and $emptyAfter -and $released) {
            Write-Output 'RESULT=OWNER_OBSERVED_INVALID_QR_WITH_EMPTY_LOCAL_IDENTITY'
            Write-Output 'NO_REDEMPTION=SOURCE_DERIVED_NOT_NETWORK_INSTRUMENTED'
        } else { Write-Output 'RESULT=NOT_ESTABLISHED_NO_AUTOMATIC_RETRY' }
    } catch {
        $reason = $stage
        if ($stage -eq 'LOCAL_ARTIFACTS') { $reason = $script:failedLocalCheck }
        $category = switch ($_.Exception.GetType().Name) {
            'RuntimeException' { 'GUARD_OR_RUNTIME' }
            'ItemNotFoundException' { 'NOT_FOUND' }
            'UnauthorizedAccessException' { 'ACCESS_DENIED' }
            'IOException' { 'IO' }
            default { 'OTHER' }
        }
        Write-Output "STOP_STAGE=$stage"; Write-Output "FAILED_CHECK=$reason"; Write-Output "EXCEPTION_CATEGORY=$category"
        if ($null -ne $script:lastNativeDiagnostic) {
            Write-Output "NATIVE_EXIT_CODE=$($script:lastNativeDiagnostic.ExitCode)"
            Write-Output "INSTALL_ERROR_CODE=$($script:lastNativeDiagnostic.InstallCode)"
            Write-Output "NATIVE_CATEGORY=$($script:lastNativeDiagnostic.Category)"
        } else { Write-Output 'NATIVE_EXIT_CODE=UNKNOWN'; Write-Output 'NATIVE_CATEGORY=NOT_INVOKED' }
        Write-Output 'RESULT=STOPPED_OR_UNCERTAIN_NO_AUTOMATIC_RETRY'
    }
    finally {
        Write-Output "INSTALLATION_STATUS=$installationStatus"
        if ($installationStatus -eq 'NOT_ATTEMPTED') { Write-Output 'Nenhuma instalacao foi tentada por esta execucao.' }
        else { Write-Output 'Nenhuma limpeza automatica. O app pode permanecer instalado; permissao concedida permanece. Pare camera/saia do app manualmente. Nao reinstale, limpe dados, revogue ou repita.' }
    }
}
if ($MyInvocation.InvocationName -ne '.') { Invoke-KRInvalidCamera -HostOnly:$HostOnly }
