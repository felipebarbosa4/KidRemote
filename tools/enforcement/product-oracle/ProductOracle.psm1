Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../../kr003/Qualification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../kr003/DevicePreflight.psm1') -Force

function Assert-ProductProvenance($Expected,$Actual) {
    foreach($key in @('Branch','Source','ChildHash','FixtureHash','Package','Service','Manufacturer','Model','Android','Api','Build','Patch','BatterySaver','AppStandby')) {
        if([string]::IsNullOrWhiteSpace([string]$Expected.$key) -or $Expected.$key -ceq 'UNSPECIFIED' -or $Expected.$key -cne $Actual.$key){throw 'INVALID:PROVENANCE_MISMATCH'}
    }
    foreach($key in @('ChildHash','FixtureHash')){if($Expected.$key -cnotmatch '^[a-f0-9]{64}$'){throw 'INVALID:APK_HASH_SCHEMA'}}
    if($Expected.Source -cnotmatch '^[a-f0-9]{40}$'){throw 'INVALID:SOURCE_SCHEMA'}
    if($Expected.Package -cne 'dev.kidremote.child.unassigned.debug' -or $Expected.Service -cne 'dev.kidremote.child.unassigned.debug/dev.kidremote.child.enforcement.ChildEnforcementService'){throw 'INVALID:PRODUCT_COMPONENT'}
}
function Assert-ProductPermissions([string]$Usage,[string]$Services,[string]$Enabled,[string]$Component) {
    if((Get-KRUsageAccessVerification $Usage).RunnerState -ne 'ENABLED' -or (Get-KRAccessibilityVerification $Services $Enabled $Component).RunnerState -ne 'ENABLED'){throw 'INVALID:PRODUCT_PERMISSION_SETUP_REQUIRED'}
}
function Convert-ProductFixture([string]$Raw,[long]$Request) {
    if($Raw.Length -gt 16384){throw 'INVALID:FIXTURE_REPLY_SIZE'}
    $s=Convert-KRReply -Raw $Raw -Request $Request -Fixture
    if($s.schema -ne 2 -or -not $s.probeReady -or $s.probeX -lt 1 -or $s.probeX -gt 10000 -or $s.probeY -lt 1 -or $s.probeY -gt 10000){throw 'INVALID:FIXTURE_ORACLE_UNAVAILABLE'}
    return $s
}
function Assert-ProductPositive($Before,$After) {
    if($Before.instance -ne $After.instance -or $Before.probeX -ne $After.probeX -or $Before.probeY -ne $After.probeY -or $After.elapsed -lt $Before.elapsed){throw 'INVALID:FIXTURE_CHANGED'}
    if(-not $Before.focused -or -not $After.focused -or -not $Before.resumed -or -not $After.resumed -or $After.taps -ne $Before.taps+1){throw 'INVALID:POSITIVE_CONTROL_FAILED'}
}
function Assert-ProductReport($Report,[long]$Version,[bool]$Required,[long]$AfterSequence,[string]$Period) {
    if($Report.version -ne $Version -or $Report.sequence -le $AfterSequence -or $Report.period_key -cne $Period -or $Report.restriction_required -isnot [bool] -or $Report.manual_lock -isnot [bool] -or $Report.restriction_required -ne $Required -or $Report.manual_lock -ne $Required -or $Report.health -notmatch ':NONE$' -or $Report.remaining_ms -le 0){throw 'INVALID:REPORT_OR_CLEANUP_PRECONDITION'}
}
function New-ProductOperation([string]$Id,[string]$Device,[string]$Kind,[long]$Version) {
    if($Id -notmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' -or $Device -notmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' -or $Kind -notin @('LOCK','UNLOCK') -or $Version -lt 1){throw 'INVALID:OPERATION_ARGUMENT'}
    return [PSCustomObject]@{protocol_version=1;operation_id=$Id;device_id=$Device;kind=$Kind;payload=@{};expected_version=$Version}
}
function Assert-ProductAccepted($Reply,$Request,[string]$Epoch) {
    if($Reply.status -cne 'accepted' -or $Reply.operation_id -cne $Request.operation_id -or $Reply.device_id -cne $Request.device_id -or $Reply.policy_epoch -cne $Epoch -or $Reply.version -ne $Request.expected_version+1){throw 'INVALID:CANONICAL_OPERATION_REJECTED'}
}
function Get-ProductFailure($ErrorRecord) {
    $m=[string]$ErrorRecord.Exception.Message
    if($m -match '^(FAIL|INVALID):[A-Z0-9_]+$'){return $m}
    return 'INVALID:TRANSPORT_OR_SCHEMA'
}
function Invoke-ProductSlice([hashtable]$Ops) {
    # Ops are host transports, not product hooks. No raw transport or bearer output enters this journal.
    $j=[PSCustomObject]@{scope='ONE_PRODUCT_VERTICAL_SLICE';attempt=[Guid]::NewGuid().ToString();status='INVALID';reason='NOT_STARTED';cleanup='NOT_REQUIRED';lockId=[Guid]::NewGuid().ToString();unlockId=[Guid]::NewGuid().ToString();independentPositive=$false;independentBlocked=$false;independentRestored=$false;corroborated=$false}
    $sent=$false;$lock=$null;$request=$null;$initial=$null;$primary=$null
    try {
        & $Ops.Preflight
        $initial=& $Ops.Initial
        if($initial.manual_lock -or $initial.restriction_required -or $initial.remaining_ms -le 180000 -or $initial.health -cne 'UNRESTRICTED_OBSERVED:NONE'){throw 'INVALID:INITIAL_STATE_NOT_SAFE_FOR_SHORT_SLICE'}
        & $Ops.StartFixture
        $p=& $Ops.Fixture; & $Ops.Tap $p; & $Ops.Pause
        Assert-ProductPositive $p (& $Ops.Fixture);$j.independentPositive=$true
        $request=New-ProductOperation $j.lockId $initial.device_id 'LOCK' $initial.version
        # Persist intent before an ambiguous HTTP write. A retry must use this same UUID/body.
        & $Ops.Journal $j;$sent=$true;$lock=& $Ops.Operation $request
        Assert-ProductAccepted $lock $request $initial.policy_epoch
        & $Ops.Sync
        $report=& $Ops.Report $lock.version $true
        Assert-ProductReport $report $lock.version $true $initial.sequence $initial.period_key
        & $Ops.StartFixture
        $b=& $Ops.BlockedFixture
        if($b.focused){throw 'FAIL:FIXTURE_REGAINED_FOCUS'}
        Assert-KRIndependentFixtureBlock $b $b
        for($probe=0;$probe -lt 3;$probe++) {
            & $Ops.Tap $b;& $Ops.Pause;$current=& $Ops.Fixture
            if($current.elapsed -lt $b.elapsed){throw 'INVALID:FIXTURE_CLOCK'}
            Assert-KRIndependentFixtureBlock $b $current
        }
        $j.independentBlocked=$true
        # Supporting telemetry cannot turn a contradicted fixture oracle into PASS.
        $j.corroborated=[bool](& $Ops.Status $j.lockId $lock.version)
        if(-not $j.corroborated){throw 'INVALID:STATUS_NOT_CORROBORATED'}
    } catch {$primary=Get-ProductFailure $_}
    finally {
        if($sent) {
            $j.cleanup='UNVERIFIED'
            try {
                # Resolve a lost LOCK response only with the original action ID, never invent a second LOCK.
                if($null -eq $lock){$lock=& $Ops.Operation $request}
                Assert-ProductAccepted $lock $request $initial.policy_epoch
                $unlock=New-ProductOperation $j.unlockId $initial.device_id 'UNLOCK' $lock.version
                & $Ops.Journal $j
                try {$u=& $Ops.Operation $unlock}
                catch {if($null -eq $primary){$primary=Get-ProductFailure $_};$u=& $Ops.Operation $unlock}
                Assert-ProductAccepted $u $unlock $initial.policy_epoch
                & $Ops.Sync;$r=& $Ops.Report $u.version $false
                Assert-ProductReport $r $u.version $false $initial.sequence $initial.period_key
                & $Ops.StartFixture;$p=& $Ops.Fixture;& $Ops.Tap $p;& $Ops.Pause
                Assert-ProductPositive $p (& $Ops.Fixture);$j.independentRestored=$true
                if(-not (& $Ops.Status $j.unlockId $u.version)){throw 'INVALID:FINAL_STATUS_UNVERIFIED'}
                $j.cleanup='VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT'
            } catch {if($null -eq $primary){$primary=Get-ProductFailure $_}}
        }
        if($null -ne $primary){$j.status=$primary.Split(':')[0];$j.reason=$primary.Split(':')[1]}
        elseif($j.independentPositive -and $j.independentBlocked -and $j.independentRestored -and $j.corroborated -and $j.cleanup -eq 'VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT'){$j.status='PASS';$j.reason='ONE_INDEPENDENT_VERTICAL_SLICE'}
        else {$j.reason='INCOMPLETE_ORACLE'}
        & $Ops.Journal $j
    }
    return $j
}
Export-ModuleMember -Function Assert-ProductProvenance,Assert-ProductPermissions,Convert-ProductFixture,Assert-ProductPositive,Assert-ProductReport,New-ProductOperation,Assert-ProductAccepted,Invoke-ProductSlice
