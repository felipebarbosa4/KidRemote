Set-StrictMode -Version Latest
# Native Windows only. DPAPI + current-user/SYSTEM ACL; no WSL, installed Node or SDK needed.
function Write-LabPipeLine($Process,[string]$Text){
 # Explicit UTF-8 payload. Framework may have emitted one BOM when creating its pipe;
 # the private Node parser accepts only that single optional framing marker.
 $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text+"`n")
 $Process.StandardInput.BaseStream.Write($bytes,0,$bytes.Length);$Process.StandardInput.BaseStream.Flush()
}
function Throw-LabState([string]$Code){
 $e=New-Object Exception('INVALID:'+$Code);$e.Data['hostStage']='LEASE_STATE';$e.Data['hostCode']=$Code;throw $e
}
function Write-LabAclRecord([string]$Root,[string]$Id,[string]$Stage){
 $path=Join-Path $Root ('acl-recovery-'+$Id+'.'+$Stage)
 $f=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.Encoding]::UTF8.GetBytes((@{kind='ACL_INITIALIZATION';attempt=$Id;stage=$Stage;utc=[DateTime]::UtcNow.ToString('o');owner='CURRENT_USER';scope='EXACT_PHYSICAL_LAB_DIRECTORY';leaseData='UNCHANGED'}|ConvertTo-Json -Compress));$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}
}
function Test-LabAcl($Acl,$User){
 $rules=@($Acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
 if(-not $Acl.AreAccessRulesProtected -or $rules.Count -ne 2){return $false}
 $seen=@{}
 foreach($rule in $rules){
  $sid=$rule.IdentityReference.Value
  if($sid -cnotin @($User.Value,'S-1-5-18') -or $seen.ContainsKey($sid) -or $rule.IsInherited -or $rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or $rule.FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl -or $rule.InheritanceFlags -ne ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit) -or $rule.PropagationFlags -ne [Security.AccessControl.PropagationFlags]::None){return $false}
  $seen[$sid]=$true
 }
 return $true
}
function Protect-LabDirectory([string]$Path,[hashtable]$Ops=@{}){
 if($env:OS -cne 'Windows_NT'){throw 'INVALID:NATIVE_WINDOWS_REQUIRED'}
 try{
  $expected=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'KidRemote\physical-lab'))
  if([IO.Path]::GetFullPath($Path) -ine $expected){Throw-LabState LAB_DIRECTORY_OWNER_INVALID}
  foreach($p in @((Split-Path $expected -Parent),$expected)){
   if(Test-Path -LiteralPath $p){$item=Get-Item -LiteralPath $p -Force -ErrorAction Stop;if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){Throw-LabState LAB_DIRECTORY_OWNER_INVALID}}
  }
 }catch{if($_.Exception.Data.Contains('hostCode')){throw};Throw-LabState LAB_DIRECTORY_OWNER_INVALID}
 $created=-not [IO.Directory]::Exists($Path)
 try{if($Ops.ContainsKey('Create')){& $Ops.Create $Path}else{[void][IO.Directory]::CreateDirectory($Path)}}catch{Throw-LabState LAB_DIRECTORY_CREATE_FAILED}
 try{$user=[Security.Principal.WindowsIdentity]::GetCurrent().User;if($Ops.ContainsKey('Read')){$acl=& $Ops.Read $Path}else{$acl=Get-Acl -LiteralPath $Path -ErrorAction Stop};$owner=$acl.GetOwner([Security.Principal.SecurityIdentifier])}catch{Throw-LabState LAB_DIRECTORY_ACL_READ_FAILED}
 # A directory newly created by this invocation may receive the admin group's
 # default owner. Existing ownership is never inferred from a pathname alone.
 if(-not $created -and $owner.Value -cne $user.Value){Throw-LabState LAB_DIRECTORY_OWNER_INVALID}
 try{$exact=Test-LabAcl $acl $user}catch{Throw-LabState LAB_DIRECTORY_RULES_INVALID}
 if($exact -and $owner.Value -ceq $user.Value){return 'UNCHANGED'}
 try{
  # Only an empty initialization or exact known lease files may be repaired.
  foreach($f in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)){
   if($f.PSIsContainer -or ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -or ($f.Name -cnotin @('runner.lock','lease.dpapi','lease.dpapi.tmp','resources.json','resources.json.tmp') -and $f.Name -cnotmatch '^acl-recovery-[a-f0-9-]{36}\.(ADMITTED|APPLIED)$')){Throw-LabState LAB_DIRECTORY_RULES_INVALID}
  }
  foreach($r in @($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))){
   if($r.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or (-not $r.IsInherited -and $r.IdentityReference.Value -cnotin @($user.Value,'S-1-5-18'))){Throw-LabState LAB_DIRECTORY_RULES_INVALID}
  }
  if(Test-Path -LiteralPath (Join-Path $Path 'resources.json')){
   $raw=[IO.File]::ReadAllText((Join-Path $Path 'resources.json'));if($raw.Length -gt 8192){Throw-LabState LAB_DIRECTORY_RULES_INVALID};$record=$raw|ConvertFrom-Json
   if($record.format -ne 1 -or $record.id -cnotmatch '^[a-f0-9-]{36}$' -or $record.source -cnotmatch '^[a-f0-9]{40}$' -or $record.schema -cnotmatch '^[a-f0-9]{64}$' -or $record.volume -cne ('kr-physical-'+$record.id+'-data')){Throw-LabState LAB_DIRECTORY_OWNER_INVALID}
  }
 }catch{if($_.Exception.Data.Contains('hostCode')){throw};Throw-LabState LAB_DIRECTORY_RULES_INVALID}
 try{
  $repairId=[Guid]::NewGuid().ToString();Write-LabAclRecord $Path $repairId ADMITTED
  # Modify access/owner only, preserving unrelated security descriptor sections.
  $acl.SetAccessRuleProtection($true,$false)
  foreach($r in @($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))){[void]$acl.RemoveAccessRuleSpecific($r)}
  $acl.SetOwner($user)
  foreach($sid in @($user,(New-Object Security.Principal.SecurityIdentifier('S-1-5-18')))){
   $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')))
  }
  if($Ops.ContainsKey('Apply')){& $Ops.Apply $Path $acl}else{Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop}
 }catch{Throw-LabState LAB_DIRECTORY_ACL_APPLY_FAILED}
 try{$verified=Get-Acl -LiteralPath $Path -ErrorAction Stop}catch{Throw-LabState LAB_DIRECTORY_ACL_READ_FAILED}
 if($verified.GetOwner([Security.Principal.SecurityIdentifier]).Value -cne $user.Value){Throw-LabState LAB_DIRECTORY_OWNER_INVALID}
 if(-not(Test-LabAcl $verified $user)){Throw-LabState LAB_DIRECTORY_RULES_INVALID}
 try{Write-LabAclRecord $Path $repairId APPLIED}catch{Throw-LabState LAB_DIRECTORY_ACL_APPLY_FAILED}
 return $(if($created){'CREATED'}else{'REPAIRED_INITIALIZATION'})
}
function Open-LabLeaseLock([string]$Root){
 try{return [IO.File]::Open((Join-Path $Root 'runner.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{Throw-LabState LEASE_LOCK_BUSY}
}
function Assert-LabSecretState([string]$Root){
 if(Test-Path -LiteralPath (Join-Path $Root 'lease.dpapi.tmp')){Throw-LabState PARTIAL_PROTECTED_LEASE}
 if((Test-Path -LiteralPath (Join-Path $Root 'resources.json')) -and -not(Test-Path -LiteralPath (Join-Path $Root 'lease.dpapi'))){Throw-LabState LEASE_SECRET_STATE_CONFLICT}
}
function Write-LabProtected([string]$Path,$Value){
 if(Test-Path -LiteralPath ($Path+'.tmp')){Throw-LabState PARTIAL_PROTECTED_LEASE}
 $plain=$Value|ConvertTo-Json -Depth 8 -Compress;$secure=ConvertTo-SecureString $plain -AsPlainText -Force;$plain=$null
 $encoded=ConvertFrom-SecureString $secure;$secure.Dispose()
 $f=[IO.File]::Open(($Path+'.tmp'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.Encoding]::UTF8.GetBytes($encoded);$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}
 if(Test-Path -LiteralPath $Path){[IO.File]::Replace(($Path+'.tmp'),$Path,[System.Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move(($Path+'.tmp'),$Path)}
}
function Read-LabProtected([string]$Path){
 if(Test-Path -LiteralPath ($Path+'.tmp')){Throw-LabState PARTIAL_PROTECTED_LEASE}
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
 $root=Join-Path $env:LOCALAPPDATA 'KidRemote\physical-lab'
 $guard=$null;$p=$null;$runtimeStarted=$false;$stage='LEASE_LOCK'
 try{
  $null=Protect-LabDirectory $root
  $guard=Open-LabLeaseLock $root
  Assert-LabSecretState $root
  $stage='PROTECTED_STATE';$secretFile=Join-Path $root 'lease.dpapi'
  if(-not(Test-Path -LiteralPath $secretFile)){
   if(Test-Path -LiteralPath (Join-Path $root 'resources.json')){throw 'INVALID:LEASE_SECRETS_MISSING'}
   $compatibilityFile=Join-Path $Bundle 'backend-compatibility.json';$compatibility=[IO.File]::ReadAllText($compatibilityFile)|ConvertFrom-Json
   $new=[ordered]@{compatibility=$compatibility;format=1;id=[Guid]::NewGuid().ToString();source=$Source;device=$null;secrets=@{}}
   foreach($k in @('database','jwt','parentPassword','probePassword')){$bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($bytes)}finally{$rng.Dispose()};$v=([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant();if($k.EndsWith('Password')){$v+='aA1!'};$new.secrets[$k]=$v}
   Write-LabProtected $secretFile $new;$new=$null
  }
  $stage='PROTECTED_READ';$local=Read-LabProtected $secretFile
  if($local.format -ne 1 -or $local.id -cnotmatch '^[a-f0-9-]{36}$'){throw 'INVALID:LEASE_SOURCE_MISMATCH'}
  $proof=if($local.PSObject.Properties.Name -contains 'compatibility'){$local.compatibility}else{[IO.File]::ReadAllText((Join-Path $SourceRoot 'tools/enforcement/physical-lab/legacy-compatibility.json'))|ConvertFrom-Json}
  $current=[IO.File]::ReadAllText((Join-Path $Bundle 'backend-compatibility.json'))|ConvertFrom-Json
  if($current.source -cne $Source -or $current.format -ne 1 -or $current.digest -cnotmatch '^[a-f0-9]{64}$' -or $proof.source -cne $local.source -or $proof.digest -cne $current.digest -or $proof.format -ne 1){throw 'INVALID:BACKEND_COMPATIBILITY_MISMATCH'}
  $stage='NATIVE_START';$p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$node;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
  $p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
  $script=Join-Path $SourceRoot 'tools\enforcement\physical-lab\runtime.mjs';if($script.Contains('"')){throw 'INVALID:SOURCE_PATH'};$p.StartInfo.Arguments='"'+$script+'"'
  [void]$p.Start();$runtimeStarted=$true;$err=$p.StandardError.ReadToEndAsync()
  $config=@{root=$SourceRoot;state=(Join-Path $root 'resources.json');source=$local.source;executionSource=$Source;compatibility=$proof;id=$local.id;secrets=$local.secrets;docker=$docker;host='npipe:////./pipe/dockerDesktopLinuxEngine'}
  Write-LabPipeLine $p ($config|ConvertTo-Json -Depth 8 -Compress);$config=$null
  $stage='LEASE_START';$line=$p.StandardOutput.ReadLineAsync()
  if(-not $line.Wait(600000)){throw 'INVALID:BACKEND_START_TIMEOUT'}
  $raw=$line.GetAwaiter().GetResult();if(-not $raw -or $raw.Length -gt 8192){throw 'INVALID:BACKEND_START_FAILED'};$ready=$raw|ConvertFrom-Json;$raw=$null
  if(-not $ready.ready){if($ready.PSObject.Properties.Name -contains 'stage' -and $ready.stage -cin @('DOCKER_ENGINE','LAB_PORTS','LEASE_STATE','LEASE_START','POSTGRES_READY','AUTH_READY','GATEWAY_READY','BACKEND_HEALTH')){$stage=$ready.stage};$reason='LIVE_BACKEND_PREFLIGHT_FAILED';if($ready.PSObject.Properties.Name -contains 'code' -and $ready.code -cmatch '^[A-Z0-9_]{1,80}$'){$reason=$ready.code};throw ('INVALID:'+$reason)}
  if($ready.jwt -cnotmatch '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'){throw 'INVALID:LAB_SESSION_SCHEMA'}
  $review=$ready.review;$digest=$ready.compatibility
  $stage='PRIVATE_SESSION';$jwt=ConvertTo-SecureString $ready.jwt -AsPlainText -Force;$ready=$null
  return @{review=$review;compatibility=$digest;process=$p;stderr=$err;stdout=$p.StandardOutput.ReadToEndAsync();guard=$guard;secretFile=$secretFile;local=$local;jwt=$jwt;root=$root}
 }catch{
  $original=$_.Exception
  if(-not $original.Data.Contains('hostCode') -and $stage -cin @('PROTECTED_STATE','PROTECTED_READ')){$original.Data['hostStage']='LEASE_STATE';$original.Data['hostCode']='LEASE_SECRET_STATE_CONFLICT'}
  $failureType=$_.Exception.GetType().Name;if($_.Exception.Message -cmatch '^INVALID:[A-Z0-9_]{1,100}$'){$failureType=$_.Exception.Message.Substring(8)};$failureLine=$_.InvocationInfo.ScriptLineNumber;$runtimeExit='RUNNING';$diagnostic='NONE'
  if($p -and $runtimeStarted -and $p.HasExited){$runtimeExit=[string]$p.ExitCode;try{$diagnosticText=$err.GetAwaiter().GetResult();$diagnostic=if($diagnosticText -match 'SyntaxError'){'SYNTAX'}elseif($diagnosticText -match 'Cannot find module|ERR_MODULE_NOT_FOUND'){'MODULE'}elseif($diagnosticText){'OTHER'}else{'EMPTY'}}catch{$diagnostic='UNAVAILABLE'}}
  if($p){try{Write-LabPipeLine $p 'STOP';$p.StandardInput.BaseStream.Close();[void]$p.WaitForExit(60000)}catch{};$p.Dispose()};if($guard){$guard.Dispose()};$e=New-Object Exception('INVALID:HOST_'+$stage+'_LINE_'+$failureLine+'_'+$failureType+'_EXIT_'+$runtimeExit+'_'+$diagnostic);$map=@{LEASE_LOCK='LEASE_STATE';PROTECTED_STATE='LEASE_STATE';PROTECTED_READ='LEASE_STATE';NATIVE_START='RUNTIME_VERIFY';PRIVATE_SESSION='BACKEND_HEALTH'};$e.Data['hostStage']=if($map.ContainsKey($stage)){$map[$stage]}else{$stage};if($original.Data.Contains('hostCode')){$e.Data['hostCode']=$original.Data['hostCode'];$e.Data['hostStage']=$original.Data['hostStage']};throw $e
 }
}
function Start-ProductBackend([string]$SourceRoot,[string]$Bundle,[string]$Source){
 try{return Start-ProductBackendCore $SourceRoot $Bundle $Source}catch{
  if($_.Exception.Data.Contains('hostStage')){throw}
  $stage=switch($_.Exception.Message){'INVALID:DOCKER_CLIENT_MISSING'{'DOCKER_CLIENT'} 'INVALID:NATIVE_RUNTIME_MISSING'{'RUNTIME_VERIFY'} 'INVALID:NATIVE_WINDOWS_REQUIRED'{'RUNTIME_VERIFY'} default{'LEASE_STATE'}}
  $code=if($stage -ceq 'LEASE_STATE'){'LEASE_SECRET_STATE_CONFLICT'}else{'HOST_PREREQUISITE'};$e=New-Object Exception('INVALID:'+$code);$e.Data['hostStage']=$stage;$e.Data['hostCode']=$code;throw $e
 }
}
function Save-ProductLabDevice($Backend,$Device){
 if($Device.id -cnotmatch '^[a-f0-9-]{36}$' -or $Device.policy_epoch -cnotmatch '^[a-f0-9-]{36}$'){throw 'INVALID:LEASE_DEVICE_SCHEMA'}
 if($Backend.local.device -and ($Backend.local.device.id -cne $Device.id -or $Backend.local.device.policy_epoch -cne $Device.policy_epoch)){throw 'INVALID:LEASE_DEVICE_CHANGED'}
 $Backend.local.device=[pscustomobject]@{id=$Device.id;policy_epoch=$Device.policy_epoch};Write-LabProtected $Backend.secretFile $Backend.local
}
function Clear-ProductLabSavedDevice($Backend){
 $Backend.local.device=$null;Write-LabProtected $Backend.secretFile $Backend.local
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
Export-ModuleMember -Function Clear-ProductLabSavedDevice,Start-ProductBackend,Stop-ProductBackend,Save-ProductLabDevice
