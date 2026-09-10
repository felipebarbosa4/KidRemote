<#
Goal: release only the disposable KR-003 lab timer if an owner becomes trapped during an approved runner or excluded diagnostic.
Context: owner-operated Windows ADB; debug receiver protected by android.permission.DUMP; the bundle protocol is allowlisted before use.
Constraints: no uninstall, app-data clear, permission change, input injection, network change, or evidence claim.
Done when: restriction/overlay are absent and the exact latency sample array is unchanged.
#>
param([string]$Adb = 'C:\platform-tools\adb.exe')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
$receiver='dev.kidremote.spike.enforcement/.LabControlReceiver'
$request=0L

function Invoke-BailoutAdb {
    param([string[]]$Arguments)
    $process=New-Object Diagnostics.Process
    $process.StartInfo=New-Object Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName=$Adb
    $process.StartInfo.UseShellExecute=$false
    $process.StartInfo.RedirectStandardOutput=$true
    $process.StartInfo.RedirectStandardError=$true
    $process.StartInfo.CreateNoWindow=$true
    $quoted=foreach($argument in $Arguments) {
        if ($argument.Contains('"') -or $argument.Contains([string][char]13) -or $argument.Contains([string][char]10) -or $argument.EndsWith('\')) { throw 'INVALID:ADB_ARGUMENT' }
        '"' + $argument + '"'
    }
    $process.StartInfo.Arguments=$quoted -join ' '
    try {
        [void]$process.Start()
        $stdoutTask=$process.StandardOutput.ReadToEndAsync()
        $stderrTask=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'INVALID:ADB_TIMEOUT' }
        $stdout=$stdoutTask.GetAwaiter().GetResult()
        $stderr=$stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -or $stderr -match 'SecurityException|Permission Denial') { throw 'INVALID:ADB_REJECTED' }
        return $stdout
    } finally { $process.Dispose() }
}

function Get-BailoutState([string]$Operation='SNAPSHOT') {
    $script:request++
    $raw=Invoke-BailoutAdb @('shell','am','broadcast','--receiver-foreground','-n',$receiver,'--es','operation',$Operation,'--el','request',"$script:request",'--el','after','0')
    $state=Convert-KRReply -Raw $raw -Request $script:request
    if ($state.schema -ne 2) { throw 'INVALID:DEBUG_SCHEMA_UPDATE_REQUIRED' }
    return $state
}

try {
    if (-not (Test-Path -LiteralPath $Adb)) { throw 'INVALID:ADB_MISSING' }
    $bundle=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle.json') -Raw | ConvertFrom-Json
    $diagnosticBundle=($bundle.protocol -eq 'KR003-Q3-RECOVERY-DIAGNOSTIC' -and $bundle.diagnosticOnly)
    $qualificationBundle=($bundle.protocol -eq 'KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION' -and $bundle.runnerVersion -eq 12 -and -not $bundle.diagnosticOnly)
    $visualCalibrationBundle=($bundle.protocol -eq 'KR003-VISUAL-CHANNEL-CALIBRATION' -and $bundle.runnerVersion -eq 1 -and $bundle.diagnosticOnly -and $bundle.diagnosticScope -eq 'VISUAL_CHANNEL_ONLY')
    if (-not $diagnosticBundle -and -not $qualificationBundle -and -not $visualCalibrationBundle) { throw 'INVALID:BUNDLE_SCHEMA' }
    foreach($name in @('Clear-KR003-Lab.ps1','Qualification.psm1')) {
        $entries=@($bundle.files | Where-Object { $_.name -ceq $name })
        if ($entries.Count -ne 1) { throw 'INVALID:BUNDLE_INTEGRITY' }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $name)).Hash.ToLowerInvariant() -cne $entries[0].sha256) { throw 'INVALID:BUNDLE_INTEGRITY' }
    }
    if ((Invoke-BailoutAdb @('get-state')).Trim() -ne 'device') { throw 'INVALID:DEVICE_UNAVAILABLE' }
    $before=Get-BailoutState
    $beforeSamples=@($before.samples)
    $null=Get-BailoutState 'CLEAR'
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do {
        $after=Get-BailoutState
        if (-not $after.armed -and -not $after.restriction -and -not $after.attached) { break }
        Start-Sleep -Milliseconds 250
    } while ($watch.Elapsed.TotalSeconds -lt 8)
    if ($after.armed -or $after.restriction -or $after.attached) { throw 'FAIL:BAILOUT_DID_NOT_RELEASE' }
    $afterSamples=@($after.samples)
    if ($beforeSamples.Count -ne $afterSamples.Count -or (($beforeSamples -join ',') -cne ($afterSamples -join ','))) { throw 'FAIL:BAILOUT_CHANGED_METRICS' }
    Write-Host ('Verified: lab restriction released; ' + $afterSamples.Count + ' latency samples preserved. This is not consumer recovery evidence.') -ForegroundColor Green
    exit 0
} catch {
    $message=$_.Exception.Message
    if ($message -notmatch '^(FAIL|INVALID):[A-Z0-9_]+$') { $message='INVALID:BAILOUT_HOST_EXCEPTION' }
    Write-Host ('Bailout not verified: ' + $message) -ForegroundColor Yellow
    exit 2
}
