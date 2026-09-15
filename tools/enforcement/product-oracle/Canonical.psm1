Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ProductOracle.psm1')
function Invoke-LabWire([string]$Service,[string]$Path,[string]$Method,$Body,[Security.SecureString]$Jwt){
 $ports=@{auth=47361;rest=47362;gateway=47366;mail=47365}
 if(-not $ports.ContainsKey($Service) -or $Method -notin @('GET','POST') -or $Path -notmatch '^/(signup|verify|rpc/(bootstrap_household|parent_devices)|parent/pairing-sessions|api/v1/messages|api/v1/message/[A-Za-z0-9-]+|parent/devices/[a-f0-9-]{36}/operations)$'){throw 'INVALID:LAB_ROUTE'}
 $args=@{Uri=('http://127.0.0.1:'+$ports[$Service]+$Path);Method=$Method;UseBasicParsing=$true;MaximumRedirection=0;TimeoutSec=10;ErrorAction='Stop'};$ptr=[IntPtr]::Zero
 try{
  if($null -ne $Jwt){$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Jwt);$args.Headers=@{Authorization='Bearer '+[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)}}
  if($Method -eq 'POST'){$args.ContentType='application/json';$args.Body=$Body|ConvertTo-Json -Depth 8 -Compress}
  try{$r=Invoke-WebRequest @args}catch{
   $code=0;try{$code=[int]$_.Exception.Response.StatusCode}catch{}
   if($code -in @(401,403,409,429,503)){throw ('INVALID:HTTP_'+$code)};throw 'INVALID:HTTP_TIMEOUT_OR_REFUSED'
  }
  if($r.StatusCode -ne 200 -or $r.Content.Length -gt 65536){throw 'INVALID:HTTP_BOUNDS'}
  try{return ($r.Content|ConvertFrom-Json)}catch{throw 'INVALID:HTTP_JSON'}
 }finally{if($ptr -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)};$args=$null}
}
function New-LabParent([scriptblock]$Wire){
 # Same local Auth/mail/bootstrap route as KR-009; no elevated key or identity in evidence.
 $email='product-lab-'+[Guid]::NewGuid().ToString()+'@example.test'
 $password=[Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N')+'aA1!'
 $null=& $Wire auth '/signup' POST @{email=$email;password=$password} $null;$password=$null;$token=$null
 for($i=0;$i -lt 30 -and -not $token;$i++){
  $mail=& $Wire mail '/api/v1/messages' GET $null $null
  $hits=@($mail.messages|Where-Object{@($_.To|Where-Object{$_.Address -ceq $email}).Count -eq 1})
  if($hits.Count -gt 1){throw 'INVALID:AUTH_MAIL_AMBIGUOUS'}
  if($hits.Count -eq 1){
   if($hits[0].ID -cnotmatch '^[A-Za-z0-9-]+$'){throw 'INVALID:AUTH_MAIL_SCHEMA'}
   $message=& $Wire mail ('/api/v1/message/'+$hits[0].ID) GET $null $null
   $text=([string]$message.HTML).Replace('&amp;','&');$matches=[regex]::Matches($text,'http://127\.0\.0\.1:47361/verify\?[^\s"<>]+')
   if($matches.Count -ne 1){throw 'INVALID:AUTH_MAIL_SCHEMA'}
   $match=[regex]::Match($matches[0].Value,'[?&]token=([a-f0-9]+)(&|$)');if(-not $match.Success){throw 'INVALID:AUTH_MAIL_SCHEMA'};$token=$match.Groups[1].Value
  }else{Start-Sleep -Milliseconds 200}
 }
 if(-not $token){throw 'INVALID:AUTH_MAIL_TIMEOUT'}
 $session=& $Wire auth '/verify' POST @{token_hash=$token;type='signup'} $null;$token=$null
 if($session.access_token -cnotmatch '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'){throw 'INVALID:AUTH_SESSION_SCHEMA'}
 $jwt=ConvertTo-SecureString $session.access_token -AsPlainText -Force;$session=$null
 $house=& $Wire rest '/rpc/bootstrap_household' POST @{p_timezone='Etc/UTC'} $jwt
 if($house.household_id -cnotmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'){throw 'INVALID:HOUSEHOLD_SCHEMA'}
 return $jwt
}
function Assert-LabInteger($Value){if(($Value -isnot [int] -and $Value -isnot [long] -and $Value -isnot [bigint]) -or $Value -lt 0 -or $Value -gt 9007199254740991){throw 'INVALID:CANONICAL_NUMBER'}}
function Get-LabDevice([scriptblock]$Wire,[Security.SecureString]$Jwt,[string]$Device,[string]$Epoch){
 $page=& $Wire rest '/rpc/parent_devices' POST @{p_after=$null} $Jwt
 if($page.protocol_version -ne 1 -or $page.devices -isnot [Array] -or $page.devices.Count -gt 50){throw 'INVALID:DEVICE_LIST_SCHEMA'}
 $rows=@($page.devices|Where-Object{$_.id -ceq $Device});if($rows.Count -ne 1){throw 'INVALID:OWN_DEVICE_NOT_FOUND'};$d=$rows[0]
 if($d.policy_epoch -cne $Epoch -or $d.policy_configured -isnot [bool] -or -not $d.policy_configured -or $null -eq $d.report){throw 'INVALID:DEVICE_EPOCH_OR_POLICY'}
 Assert-LabInteger $d.version;$r=$d.report
 foreach($k in @('version','sequence','used_ms','remaining_ms','bonus_seconds')){Assert-LabInteger $r.$k}
 foreach($k in @('manual_lock','restriction_required','restriction_applied')){if($r.$k -isnot [bool]){throw 'INVALID:REPORT_BOOLEAN'}}
 if($r.period_key -cnotmatch '^[1-9][0-9]*:\d{4}-\d{2}-\d{2}$' -or $r.health -cnotmatch '^[A-Z_]+:[A-Z_]+$'){throw 'INVALID:REPORT_SCHEMA'}
 try{$server=[DateTimeOffset]::Parse($page.server_utc);$received=[DateTimeOffset]::Parse($r.received_at)}catch{throw 'INVALID:REPORT_TIMESTAMP'}
 if($received -gt $server -or ($server-$received).TotalSeconds -gt 30 -or $d.version -ne $r.version){throw 'INVALID:REPORT_STALE_OR_CONCURRENT'}
 return $d
}
function New-CanonicalCallbacks([scriptblock]$Wire,[Security.SecureString]$Jwt,[string]$Device,[string]$Epoch){
 if($Device -cnotmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' -or $Epoch -cnotmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'){throw 'INVALID:CANONICAL_SCOPE'}
 $state=@{sequence=-1;version=-1;period=$null};$integer=${function:Assert-LabInteger}
 $initial={
  $d=Get-LabDevice $Wire $Jwt $Device $Epoch;$r=$d.report;$state.sequence=$r.sequence;$state.version=$d.version;$state.period=$r.period_key
  [pscustomobject]@{device_id=$Device;policy_epoch=$Epoch;version=$d.version;sequence=$r.sequence;period_key=$r.period_key;manual_lock=$r.manual_lock;restriction_required=$r.restriction_required;remaining_ms=$r.remaining_ms;health=$r.health}
 }.GetNewClosure()
 $operation={param($q)
  if($q.device_id -cne $Device -or $q.kind -notin @('LOCK','UNLOCK') -or $q.protocol_version -ne 1 -or @($q.payload.Keys).Count -ne 0){throw 'INVALID:CONTROL_SCOPE'}
  $expected=New-ProductOperation $q.operation_id $Device $q.kind $q.expected_version
  # Server expected-version and UUID semantics decide retries; never adjust expected version on conflict.
  $reply=& $Wire gateway ('/parent/devices/'+$Device+'/operations') POST $expected $Jwt
  & $integer $reply.version;Assert-ProductAccepted $reply $expected $Epoch;return $reply
 }.GetNewClosure()
 $report={param($v,$required)
  $d=Get-LabDevice $Wire $Jwt $Device $Epoch;$r=$d.report
  Assert-ProductReport $r $v $required $state.sequence $state.period
  $state.sequence=$r.sequence;$state.version=$v;return $r
 }.GetNewClosure()
 $status={param($id,$v)
  $rows=@(& $Wire gateway ('/parent/devices/'+$Device+'/operations') GET $null $Jwt)
  if($rows.Count -gt 100){throw 'INVALID:STATUS_BOUNDS'}
  $matches=@($rows|Where-Object{$_.operation_id -ceq $id});if($matches.Count -ne 1 -or $matches[0].version -ne $v -or $matches[0].device_id -cne $Device){throw 'INVALID:STATUS_SCOPE'}
  if($matches[0].status -notin @('accepted','pending','persisted','applied','superseded','expired_for_period','failed','rejected')){throw 'INVALID:STATUS_SCHEMA'}
  return ($matches[0].status -ceq 'applied')
 }.GetNewClosure()
 return @{Initial=$initial;Operation=$operation;Report=$report;Status=$status}
}
# Future tunnel action is deliberately separate from the read-only bundle and never executed here.
function Get-LabReverseArguments {return @('reverse','tcp:47366','tcp:47366')}
Export-ModuleMember -Function Invoke-LabWire,New-LabParent,New-CanonicalCallbacks,Get-LabDevice,Get-LabReverseArguments
