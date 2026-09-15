Set-StrictMode -Version Latest
# Native Windows only. DPAPI + current-user/SYSTEM ACL; no WSL, installed Node or SDK needed.
function Write-LabPipeLine($Process,[string]$Text){
 # Explicit UTF-8 payload. Framework may have emitted one BOM when creating its pipe;
 # the private Node parser accepts only that single optional framing marker.
 $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text+"`n")
 $Process.StandardInput.BaseStream.Write($bytes,0,$bytes.Length);$Process.StandardInput.BaseStream.Flush()
}
function Protect-LabDirectory([string]$Path){
 if($env:OS -cne 'Windows_NT'){throw 'INVALID:NATIVE_WINDOWS_REQUIRED'}
 [void][IO.Directory]::CreateDirectory($Path)
 $acl=New-Object Security.AccessControl.DirectorySecurity
 $acl.SetAccessRuleProtection($true,$false)
 foreach($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,(New-Object Security.Principal.SecurityIdentifier('S-1-5-18')))){
  $rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow');$acl.AddAccessRule($rule)
 };Set-Acl -LiteralPath $Path -AclObject $acl
}
function Write-LabProtected([string]$Path,$Value){
 if(Test-Path -LiteralPath ($Path+'.tmp')){throw 'INVALID:PARTIAL_PROTECTED_LEASE'}
 $plain=$Value|ConvertTo-Json -Depth 8 -Compress;$secure=ConvertTo-SecureString $plain -AsPlainText -Force;$plain=$null
 $encoded=ConvertFrom-SecureString $secure;$secure.Dispose()
 $f=[IO.File]::Open(($Path+'.tmp'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.Encoding]::UTF8.GetBytes($encoded);$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}
 if(Test-Path -LiteralPath $Path){[IO.File]::Replace(($Path+'.tmp'),$Path,[System.Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move(($Path+'.tmp'),$Path)}
}
function Read-LabProtected([string]$Path){
 if(Test-Path -LiteralPath ($Path+'.tmp')){throw 'INVALID:PARTIAL_PROTECTED_LEASE'}
 $s=ConvertTo-SecureString ([IO.File]::ReadAllText($Path));$p=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
 try{return ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($p)|ConvertFrom-Json)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p);$s.Dispose()}
}
function Start-ProductBackendCore([string]$SourceRoot,[string]$Bundle,[string]$Source){
 if($env:OS -cne 'Windows_NT'){throw 'INVALID:NATIVE_WINDOWS_REQUIRED'}
 $docker=Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
 if(-not(Test-Path -LiteralPath $docker)){$docker='C:\Program Files\Docker\Docker\resources\bin\docker.exe'}
 $node=Join-Path $Bundle 'runtime\node.exe'
 if(-not(Test-Path -LiteralPath $docker)){throw 'INVALID:DOCKER_CLIENT_MISSING'}
 if(-not(Test-Path -LiteralPath $node)){throw 'INVALID:NATIVE_RUNTIME_MISSING'}
 $root=Join-Path $env:LOCALAPPDATA 'KidRemote\physical-lab';Protect-LabDirectory $root
 $guard=$null;$p=$null;$runtimeStarted=$false;$stage='LEASE_LOCK'
 try{
  $guard=[IO.File]::Open((Join-Path $root 'runner.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  $stage='PROTECTED_STATE';$secretFile=Join-Path $root 'lease.dpapi'
  if(-not(Test-Path -LiteralPath $secretFile)){
   if(Test-Path -LiteralPath (Join-Path $root 'resources.json')){throw 'INVALID:LEASE_SECRETS_MISSING'}
   $new=[ordered]@{format=1;id=[Guid]::NewGuid().ToString();source=$Source;device=$null;secrets=@{}}
   foreach($k in @('database','jwt','parentPassword','probePassword')){$bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($bytes)}finally{$rng.Dispose()};$v=([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant();if($k.EndsWith('Password')){$v+='aA1!'};$new.secrets[$k]=$v}
   Write-LabProtected $secretFile $new;$new=$null
  }
  $stage='PROTECTED_READ';$local=Read-LabProtected $secretFile
  if($local.format -ne 1 -or $local.source -cne $Source -or $local.id -cnotmatch '^[a-f0-9-]{36}$'){throw 'INVALID:LEASE_SOURCE_MISMATCH'}
  $stage='NATIVE_START';$p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$node;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
  $p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
  $script=Join-Path $SourceRoot 'tools\enforcement\physical-lab\runtime.mjs';if($script.Contains('"')){throw 'INVALID:SOURCE_PATH'};$p.StartInfo.Arguments='"'+$script+'"'
  [void]$p.Start();$runtimeStarted=$true;$err=$p.StandardError.ReadToEndAsync()
  $config=@{root=$SourceRoot;state=(Join-Path $root 'resources.json');source=$Source;id=$local.id;secrets=$local.secrets;docker=$docker;host='npipe:////./pipe/dockerDesktopLinuxEngine'}
  Write-LabPipeLine $p ($config|ConvertTo-Json -Depth 8 -Compress);$config=$null
  $stage='LEASE_START';$line=$p.StandardOutput.ReadLineAsync()
  if(-not $line.Wait(600000)){throw 'INVALID:BACKEND_START_TIMEOUT'}
  $raw=$line.GetAwaiter().GetResult();if(-not $raw -or $raw.Length -gt 8192){throw 'INVALID:BACKEND_START_FAILED'};$ready=$raw|ConvertFrom-Json;$raw=$null
  if(-not $ready.ready){if($ready.PSObject.Properties.Name -contains 'stage' -and $ready.stage -cin @('DOCKER_ENGINE','LAB_PORTS','LEASE_STATE','LEASE_START','POSTGRES_READY','AUTH_READY','GATEWAY_READY','BACKEND_HEALTH')){$stage=$ready.stage};$reason='LIVE_BACKEND_PREFLIGHT_FAILED';if($ready.PSObject.Properties.Name -contains 'code' -and $ready.code -cmatch '^[A-Z0-9_]{1,80}$'){$reason=$ready.code};throw ('INVALID:'+$reason)}
  if($ready.jwt -cnotmatch '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'){throw 'INVALID:LAB_SESSION_SCHEMA'}
  $stage='PRIVATE_SESSION';$jwt=ConvertTo-SecureString $ready.jwt -AsPlainText -Force;$ready=$null
  return @{process=$p;stderr=$err;stdout=$p.StandardOutput.ReadToEndAsync();guard=$guard;secretFile=$secretFile;local=$local;jwt=$jwt;root=$root}
 }catch{
  $failureType=$_.Exception.GetType().Name;if($_.Exception.Message -cmatch '^INVALID:[A-Z0-9_]{1,100}$'){$failureType=$_.Exception.Message.Substring(8)};$failureLine=$_.InvocationInfo.ScriptLineNumber;$runtimeExit='RUNNING';$diagnostic='NONE'
  if($p -and $runtimeStarted -and $p.HasExited){$runtimeExit=[string]$p.ExitCode;try{$diagnosticText=$err.GetAwaiter().GetResult();$diagnostic=if($diagnosticText -match 'SyntaxError'){'SYNTAX'}elseif($diagnosticText -match 'Cannot find module|ERR_MODULE_NOT_FOUND'){'MODULE'}elseif($diagnosticText){'OTHER'}else{'EMPTY'}}catch{$diagnostic='UNAVAILABLE'}}
  if($p){try{Write-LabPipeLine $p 'STOP';$p.StandardInput.BaseStream.Close();[void]$p.WaitForExit(60000)}catch{};$p.Dispose()};if($guard){$guard.Dispose()};$e=New-Object Exception('INVALID:HOST_'+$stage+'_LINE_'+$failureLine+'_'+$failureType+'_EXIT_'+$runtimeExit+'_'+$diagnostic);$map=@{LEASE_LOCK='LEASE_STATE';PROTECTED_STATE='LEASE_STATE';PROTECTED_READ='LEASE_STATE';NATIVE_START='RUNTIME_VERIFY';PRIVATE_SESSION='BACKEND_HEALTH'};$e.Data['hostStage']=if($map.ContainsKey($stage)){$map[$stage]}else{$stage};throw $e
 }
}
function Start-ProductBackend([string]$SourceRoot,[string]$Bundle,[string]$Source){
 try{return Start-ProductBackendCore $SourceRoot $Bundle $Source}catch{
  if($_.Exception.Data.Contains('hostStage')){throw}
  $stage=switch($_.Exception.Message){'INVALID:DOCKER_CLIENT_MISSING'{'DOCKER_CLIENT'} 'INVALID:NATIVE_RUNTIME_MISSING'{'RUNTIME_VERIFY'} 'INVALID:NATIVE_WINDOWS_REQUIRED'{'RUNTIME_VERIFY'} default{'LEASE_STATE'}}
  $e=New-Object Exception('INVALID:HOST_PREREQUISITE');$e.Data['hostStage']=$stage;throw $e
 }
}
function Save-ProductLabDevice($Backend,$Device){
 if($Device.id -cnotmatch '^[a-f0-9-]{36}$' -or $Device.policy_epoch -cnotmatch '^[a-f0-9-]{36}$'){throw 'INVALID:LEASE_DEVICE_SCHEMA'}
 if($Backend.local.device -and ($Backend.local.device.id -cne $Device.id -or $Backend.local.device.policy_epoch -cne $Device.policy_epoch)){throw 'INVALID:LEASE_DEVICE_CHANGED'}
 $Backend.local.device=[pscustomobject]@{id=$Device.id;policy_epoch=$Device.policy_epoch};Write-LabProtected $Backend.secretFile $Backend.local
}
function Stop-ProductBackend($Backend){
 if($null -eq $Backend){return 'NOT_STARTED'}
 $p=$Backend.process
 try{
  Write-LabPipeLine $p 'STOP';$p.StandardInput.BaseStream.Close()
  if(-not $p.WaitForExit(60000)){throw 'INVALID:BACKEND_STOP_TIMEOUT'}
  $text=$Backend.stdout.GetAwaiter().GetResult();$err=$Backend.stderr.GetAwaiter().GetResult()
  if($p.ExitCode -ne 0 -or $err.Trim() -or $text.Trim() -cne 'STOPPED_DATA_RETAINED'){throw 'INVALID:BACKEND_STOP_UNVERIFIED'}
  return 'STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED'
 }finally{$p.Dispose();$Backend.guard.Dispose();$Backend.jwt.Dispose();$Backend.local=$null}
}
Export-ModuleMember -Function Start-ProductBackend,Stop-ProductBackend,Save-ProductLabDevice
