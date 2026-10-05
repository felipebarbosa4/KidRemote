Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../../kr003/OracleTransport.psm1')

function Invoke-ProductAdb([string]$Adb,[string]$Serial,[string[]]$Arguments) {
    if($Serial -notmatch '^[A-Za-z0-9._:-]{1,80}$'){throw 'INVALID:TARGET_SERIAL'}
    # Enumerated read/probe surface; deliberately excludes installation, settings writes and product broadcasts.
    $line=$Arguments -join ' '
    $allowed=$line -match '^shell getprop ro\.(product\.(manufacturer|model)|build\.(version\.(release|sdk|security_patch)|id))$' -or
      $line -match '^shell settings --user current get (secure (enabled_accessibility_services|accessibility_enabled)|global (low_power|app_standby_enabled))$' -or
      $line -match '^shell cmd appops get dev\.kidremote\.child\.unassigned\.debug GET_USAGE_STATS$' -or
      $line -match '^shell pm path dev\.kidremote\.(child\.unassigned\.debug|spike\.ordinary)$' -or
      $line -match '^shell am start -W -n (dev\.kidremote\.child\.unassigned\.debug/dev\.kidremote\.child\.ChildActivity|dev\.kidremote\.spike\.ordinary/\.FixtureActivity)$' -or
      $line -match '^shell am broadcast --receiver-foreground -n dev\.kidremote\.spike\.ordinary/\.FixtureReceiver --el request [0-9]+$' -or
      $line -match '^shell input tap [0-9]{1,5} [0-9]{1,5}$'
    if(-not $allowed){throw 'INVALID:ADB_COMMAND_NOT_ALLOWED'}
    $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$Adb;$p.StartInfo.UseShellExecute=$false
    $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true;$p.StartInfo.CreateNoWindow=$true
    $all=@('-s',$Serial)+$Arguments
    foreach($a in $all){if($a -match '["\r\n]' -or $a.EndsWith('\')){throw 'INVALID:ADB_ARGUMENT'}}
    $p.StartInfo.Arguments=($all|ForEach-Object{'"'+$_+'"'}) -join ' '
    try {
        [void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
        if(-not $p.WaitForExit(10000)){$p.Kill();throw 'INVALID:ADB_TIMEOUT'}
        $out=$o.GetAwaiter().GetResult();$err=Get-KRTransportStderrClass $e.GetAwaiter().GetResult()
        if($p.ExitCode -ne 0 -or $err -ne 'NONE' -or $out.Length -gt 65536){throw 'INVALID:ADB_REJECTED'}
        return $out
    } finally {$p.Dispose()}
}
function Invoke-ProductHttp([string]$Origin,[string]$Path,[Security.SecureString]$Jwt,$Body,[string]$Method='POST') {
    $uri=[Uri]$Origin
    if(-not $uri.IsAbsoluteUri -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/' -or ($uri.Scheme -ne 'https' -and -not ($uri.Scheme -eq 'http' -and $uri.Host -ceq '127.0.0.1'))){throw 'INVALID:BACKEND_ORIGIN'}
    if($Path -notmatch '^/parent/devices/[a-f0-9-]{36}/operations$' -and $Path -cne '/rpc/parent_devices'){throw 'INVALID:BACKEND_PATH'}
    $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Jwt)
    try {
        $token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        $args=@{Uri=$Origin.TrimEnd('/')+$Path;Method=$Method;Headers=@{Authorization='Bearer '+$token};UseBasicParsing=$true;MaximumRedirection=0;TimeoutSec=10;ErrorAction='Stop'}
        if($Method -eq 'POST'){$args.ContentType='application/json';$args.Body=ConvertTo-Json -InputObject $Body -Depth 6 -Compress}
        try {$response=Invoke-WebRequest @args} catch {throw 'INVALID:CANONICAL_HTTP_UNAVAILABLE'}
        if($response.StatusCode -ne 200 -or $response.Content.Length -gt 65536){throw 'INVALID:CANONICAL_HTTP_REJECTED'}
        try {return ($response.Content|ConvertFrom-Json)} catch {throw 'INVALID:CANONICAL_HTTP_SCHEMA'}
    } finally {$token=$null;[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)}
}
function Assert-ProductPhysicalReadiness {
    # This compiled product targets the emulator-only 10.0.2.2 origin; release has no endpoint.
    # No editable manifest flag is allowed to turn an unvalidated transport into physical readiness.
    throw 'INVALID:PRODUCT_CHILD_TRANSPORT_NOT_VALIDATED'
}
Export-ModuleMember -Function Invoke-ProductAdb,Invoke-ProductHttp,Assert-ProductPhysicalReadiness
