<#
Goal: Record exactly 10 independent owner-observed Mi 8 stability attempts before qualification.
Context: The corrected KR-003 debug APK is already installed through the owner-assisted Windows ADB boundary.
Constraints: No Home injection, destructive action, sensitive log capture, or attachment-derived pass classification.
Done when: Ten observer-entered rows, one sanitized trace, and a separately labelled attachment count are written locally.
#>

param(
    [string]$Adb = 'C:\platform-tools\adb.exe',
    [string]$CalculatorPackage = 'com.miui.calculator',
    [string]$OutputDirectory = 'C:\platform-tools\kr003-checkpoint'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$package = 'dev.kidremote.spike.enforcement'
$activity = "$package/.MainActivity"
$cycles = 10
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$tracePath = Join-Path $OutputDirectory "KidRemoteKR003-$stamp.log"
$traceErrorPath = Join-Path $OutputDirectory "KidRemoteKR003-$stamp.err.log"
$resultsPath = Join-Path $OutputDirectory "observer-results-$stamp.csv"

function Invoke-Adb {
    param([string[]]$Arguments)

    & $Adb @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "ADB command failed: $($Arguments -join ' ')"
    }
}

function Read-Classification {
    param(
        [string]$Prompt,
        [string[]]$Allowed
    )

    while ($true) {
        $answer = (Read-Host "$Prompt [$($Allowed -join '/')]").Trim().ToLowerInvariant()
        if ($Allowed -contains $answer) {
            return $answer
        }
        Write-Host 'Entry not recognized; this runner never infers a physical result.' -ForegroundColor Yellow
    }
}

if (-not (Test-Path -LiteralPath $Adb)) {
    throw "ADB executable not found: $Adb"
}

$results = @()
$logcat = $null

try {
    $state = & $Adb get-state
    if ($LASTEXITCODE -ne 0 -or ($state -join '').Trim() -ne 'device') {
        throw 'The authorized lab device is not available to Windows ADB.'
    }

    $logcat = Start-Process `
        -FilePath $Adb `
        -ArgumentList @('logcat', '-v', 'monotonic', '-T', '1', '-s', 'KidRemoteKR003:I', '*:S') `
        -RedirectStandardOutput $tracePath `
        -RedirectStandardError $traceErrorPath `
        -PassThru `
        -NoNewWindow

    Write-Host 'This runner records operator-entered observations only.' -ForegroundColor Cyan
    Write-Host 'It never treats overlay attachment as a physical pass.' -ForegroundColor Cyan

    Read-Host 'If currently blocked, tap Open device settings. Press Enter when Settings or the unblocked harness is visible'
    Invoke-Adb -Arguments @('shell', 'am', 'start', '-n', $activity)
    Read-Host 'Tap Clear lab timer once to establish the initial cleared state, then press Enter'

    for ($cycle = 1; $cycle -le $cycles; $cycle++) {
        Write-Host "`n=== Independent attempted cycle $cycle of $cycles ===" -ForegroundColor Cyan
        Invoke-Adb -Arguments @('shell', 'am', 'start', '-n', $activity)
        Read-Host 'Tap Arm 10-second lab timer, then immediately press Enter'
        Invoke-Adb -Arguments @('shell', 'monkey', '-p', $CalculatorPackage, '-c', 'android.intent.category.LAUNCHER', '1')

        Write-Host 'Waiting through expiry and at least 10 seconds of persistence observation...'
        Start-Sleep -Seconds 22
        $expiryResult = Read-Classification -Prompt 'Expiry observation' `
            -Allowed @('persistent-block', 'flicker', 'no-block', 'invalid')

        Read-Host 'Press Home PHYSICALLY exactly once, observe for 5 seconds, then press Enter here'
        $homeResult = Read-Classification -Prompt 'Physical Home observation' `
            -Allowed @('blocked', 'escaped', 'flicker', 'invalid')

        Read-Host 'Tap Open device settings on the restriction, verify Settings, then press Enter'
        $settingsResult = Read-Classification -Prompt 'Designated Settings observation' `
            -Allowed @('usable', 'not-usable', 'invalid')

        Invoke-Adb -Arguments @('shell', 'monkey', '-p', $CalculatorPackage, '-c', 'android.intent.category.LAUNCHER', '1')
        Start-Sleep -Seconds 5
        $reentryResult = Read-Classification -Prompt 'Settings-to-ordinary-app re-entry observation' `
            -Allowed @('persistent-block', 'flicker', 'ordinary-usable', 'invalid')

        Read-Host 'Tap Open device settings again, then press Enter so this cycle can be cleared'
        Invoke-Adb -Arguments @('shell', 'am', 'start', '-n', $activity)
        Read-Host 'Tap Clear lab timer, then press Enter'
        Invoke-Adb -Arguments @('shell', 'monkey', '-p', $CalculatorPackage, '-c', 'android.intent.category.LAUNCHER', '1')
        Start-Sleep -Seconds 3
        $clearResult = Read-Classification -Prompt 'After clear, was Calculator ordinary use restored?' `
            -Allowed @('usable', 'still-blocked', 'invalid')

        $results += [PSCustomObject]@{
            Cycle = $cycle
            ClearRestoredOrdinaryUse = $clearResult
            ExpiryPersistence = $expiryResult
            PhysicalHome = $homeResult
            SettingsRecovery = $settingsResult
            OrdinaryReentry = $reentryResult
        }

        $results | Export-Csv -NoTypeInformation -Path $resultsPath
    }
}
finally {
    if ($null -ne $logcat -and -not $logcat.HasExited) {
        Stop-Process -Id $logcat.Id
    }
}

Start-Sleep -Seconds 1
$attachmentCount = @(
    Select-String -Path $tracePath -SimpleMatch 'kind=overlay_attached' -ErrorAction SilentlyContinue
).Count

Write-Host "`nObserver-entered results (not an automated pass/fail decision):" -ForegroundColor Cyan
$results | Format-Table -AutoSize
Write-Host "Results: $resultsPath"
Write-Host "Sanitized trace: $tracePath"
Write-Host "Internal overlay-attachment transitions: $attachmentCount (not physical passes)"
Write-Host 'Review and report on-device expiry-to-attachment sample count/p50/p95/max separately.'
