# Owner-operated only. Dot-source for preparation tests; never executed by the agent against ADB.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Invoke-KRInvalidAdb([string[]]$Command) {
    $output = & 'C:\platform-tools\adb.exe' @Command 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'ADB_REJECTED' }
    return (($output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
}
function Invoke-KRInvalidCamera {
    $stage = 'LOCAL_ARTIFACTS'
    $installedHere = $false
    try {
        if ($env:ADB_TRACE -or $env:ADB_SERVER_SOCKET -or $env:ANDROID_ADB_SERVER_PORT) { throw 'UNEXPECTED_ADB_ENVIRONMENT' }
        $root = 'C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe'
        $apk = "$root\artifacts-kr007-14d82db\debug\child-debug.apk"
        $qr = "$root\camera-storage-2026-09-11T23-02-20-209Z\scene-invalid.png"
        $package = 'dev.kidremote.child.unassigned.debug'
        if (!(Test-Path -LiteralPath 'C:\platform-tools\adb.exe')) { throw 'ADB_MISSING' }
        if (!(Test-Path -LiteralPath 'C:\Windows\System32\mspaint.exe')) { throw 'LOCAL_VIEWER_MISSING' }
        if ((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne '3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9') { throw 'APK_HASH' }
        if ((Get-FileHash -LiteralPath $qr -Algorithm SHA256).Hash -ne '3c9a84602486d7052346116f0e182527578970f36a894a8a733b6515cd1d5287') { throw 'QR_HASH' }
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
        $stage = 'INSTALL_NEW_ONLY'
        # -R explicitly disables replacement at the package-manager boundary; never -r or -g.
        $installResult = Invoke-KRInvalidAdb ($target + @('install','--no-streaming','-R','--user','0',$apk))
        if ($installResult -notmatch '(?m)^Success\s*$') { throw 'INSTALL_NOT_VERIFIED' }
        $installedHere = $true
        $stage = 'OPEN'
        $openResult = Invoke-KRInvalidAdb ($target + @('shell','am','start','-W','-n',"$package/dev.kidremote.child.ChildActivity"))
        if ($openResult -notmatch '(?m)^Status: ok\s*$') { throw 'OPEN_NOT_VERIFIED' }
        $stage = 'FRESH_STATE'
        # Read only two existence bits, never credential bytes or directory contents.
        $probe = '"if [ -d no_backup ]; then if [ ! -e no_backup/device-identity ] && [ ! -e no_backup/pairing-pending ]; then echo EMPTY; else echo PRESENT; fi; else echo UNKNOWN; fi"'
        if ((Invoke-KRInvalidAdb ($target + @('shell','run-as',$package,'sh','-c',$probe))) -ne 'EMPTY') { throw 'IDENTITY_STATE_UNKNOWN_OR_PRESENT' }
        if ((Read-Host 'Aguarde carregar. Confirma tela Nao pareado, sem recuperacao/pareamento pendente? S=sim; outro=parar') -ine 'S') { throw 'NOT_FRESH' }
        $stage = 'OWNER_CAMERA_CHECK'
        Start-Process -FilePath 'C:\Windows\System32\mspaint.exe' -ArgumentList ('"' + $qr + '"') # Owner-local only.
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
    } catch { Write-Output "STOP_STAGE=$stage"; Write-Output 'RESULT=STOPPED_OR_UNCERTAIN_NO_AUTOMATIC_RETRY' }
    finally {
        Write-Output "NEW_INSTALL_VERIFIED_THIS_INVOCATION=$installedHere"
        Write-Output 'Nenhuma limpeza automatica. Se instalacao foi tentada, o app pode permanecer instalado; permissao concedida permanece. Pare camera/saia do app manualmente. Nao reinstale, limpe dados, revogue ou repita.'
    }
}
if ($MyInvocation.InvocationName -ne '.') { Invoke-KRInvalidCamera }
