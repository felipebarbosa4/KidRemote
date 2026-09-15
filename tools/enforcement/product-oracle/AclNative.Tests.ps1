Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:OS -cne 'Windows_NT'){throw 'WINDOWS_NATIVE_ONLY'}
Import-Module (Join-Path $PSScriptRoot 'BackendHost.psm1')
$module=Get-Module BackendHost
$prior=$env:LOCALAPPDATA;$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-acl-'+[Guid]::NewGuid());$env:LOCALAPPDATA=$root
$path=Join-Path $root 'KidRemote/physical-lab';$script:n=0
function Check($b){$script:n++;if(-not $b){throw "ACL_NATIVE_$script:n"}}
function Expected([scriptblock]$Action,[string]$Code){$caught=$null;try{& $Action}catch{$caught=$_.Exception};Check ($null -ne $caught);Check ($caught.Data['hostStage'] -ceq 'LEASE_STATE');Check ($caught.Data['hostCode'] -ceq $Code);Check ($caught.Message -notmatch 'HOST_PREREQUISITE|S-1-5-|[A-Z]:\\')}
function Protect([hashtable]$Ops=@{}){return (& $module {param($p,$o) Protect-LabDirectory $p $o} $path $Ops)}
try{
 Check ((Protect) -ceq 'CREATED')
 $user=[Security.Principal.WindowsIdentity]::GetCurrent().User;$acl=Get-Acl -LiteralPath $path
 Check ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ceq $user.Value)
 Check (& $module {param($a,$u) Test-LabAcl $a $u} $acl $user)
 $sddl=$acl.Sddl
 Check ((Protect @{Apply={throw 'IDEMPOTENCE_MUST_NOT_APPLY'}}) -ceq 'UNCHANGED');Check ((Get-Acl $path).Sddl -ceq $sddl)
 # Actual native inherited ACL initialization, then exact repair and readback.
 $acl.SetAccessRuleProtection($false,$true);Set-Acl -LiteralPath $path -AclObject $acl
 Check ((Protect) -ceq 'REPAIRED_INITIALIZATION');Check ((Get-Acl $path).AreAccessRulesProtected)
 Check (& $module {param($a,$u) Test-LabAcl $a $u} (Get-Acl $path) $user)
 # Inject OS failures at exact boundaries; successful ACL semantics above are native, not mocks.
 Expected {Protect @{Read={throw [UnauthorizedAccessException]::new()}}} LAB_DIRECTORY_ACL_READ_FAILED
 $acl=Get-Acl $path;$acl.SetAccessRuleProtection($false,$true);Set-Acl $path $acl
 Expected {Protect @{Apply={throw [UnauthorizedAccessException]::new()}}} LAB_DIRECTORY_ACL_APPLY_FAILED
 $null=Protect
 Expected {Protect @{Create={throw [IO.IOException]::new()}}} LAB_DIRECTORY_CREATE_FAILED
 $other=Join-Path $root 'unrelated';[void][IO.Directory]::CreateDirectory($other);$unchanged=(Get-Acl $other).Sddl
 Expected {& $module {param($p) Protect-LabDirectory $p} $other} LAB_DIRECTORY_OWNER_INVALID
 Check ((Get-Acl $other).Sddl -ceq $unchanged)
 $guard=& $module {param($p) Open-LabLeaseLock $p} $path
 try{Expected {& $module {param($p) Open-LabLeaseLock $p} $path} LEASE_LOCK_BUSY}finally{$guard.Dispose()}
 [IO.File]::WriteAllText((Join-Path $path 'lease.dpapi.tmp'),'synthetic-truncation')
 Expected {& $module {param($p) Assert-LabSecretState $p} $path} PARTIAL_PROTECTED_LEASE
 Remove-Item (Join-Path $path 'lease.dpapi.tmp')
 [IO.File]::WriteAllText((Join-Path $path 'resources.json'),'{}')
 Expected {& $module {param($p) Assert-LabSecretState $p} $path} LEASE_SECRET_STATE_CONFLICT
 Remove-Item (Join-Path $path 'resources.json')
 # Actual DPAPI write/read across an independent module reload; never emit its contents.
 $value=@{format=1;id=[Guid]::NewGuid().ToString();secret=[Guid]::NewGuid().ToString()};$secretFile=Join-Path $path 'lease.dpapi'
 & $module {param($p,$v) Write-LabProtected $p $v} $secretFile $value
 $hash=(Get-FileHash $secretFile).Hash;$null=Protect;Check ((Get-FileHash $secretFile).Hash -ceq $hash)
 Remove-Module BackendHost;Import-Module (Join-Path $PSScriptRoot 'BackendHost.psm1');$module=Get-Module BackendHost
 $actual=& $module {param($p) Read-LabProtected $p} $secretFile
 Check ($actual.id -ceq $value.id -and $actual.secret -ceq $value.secret)
 Check ((Protect) -ceq 'UNCHANGED')
 Write-Output "OD51_NATIVE_ACL_CHECKS=$script:n;PS=$($PSVersionTable.PSVersion.Major);ACTUAL_NTFS_ACL_AND_DPAPI=PASS;DENIED_FAULTS=INJECTED;DEVICE=NOT_INVOKED"
}finally{$env:LOCALAPPDATA=$prior;if(Test-Path $root){Remove-Item $root -Recurse -Force}}
