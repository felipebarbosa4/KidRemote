Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:OS -cne 'Windows_NT'){throw 'WINDOWS_NATIVE_ONLY'}
Import-Module (Join-Path $PSScriptRoot 'BackendHost.psm1') -Force
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-native-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
$script:n=0;function Check($b){$script:n++;if(-not $b){throw "OD51_NATIVE_$script:n"}}
try{
 $originalLocal=$env:LOCALAPPDATA;$env:LOCALAPPDATA=$root
 try{$null=& (Get-Module BackendHost) {param($r) Protect-LabDirectory $r} (Join-Path $root 'KidRemote/physical-lab')}finally{$env:LOCALAPPDATA=$originalLocal}
 $p=Join-Path $root 'test.dpapi';$value=@{id=[Guid]::NewGuid().ToString();secret=[Guid]::NewGuid().ToString()}
 & (Get-Module BackendHost) {param($p,$v) Write-LabProtected $p $v} $p $value
 Check (-not ([IO.File]::ReadAllText($p)).Contains($value.secret))
 $actual=& (Get-Module BackendHost) {param($p) Read-LabProtected $p} $p
 Check ($actual.secret -ceq $value.secret)
 $guard=[IO.File]::Open((Join-Path $root 'runner.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 try{$caught=$false;try{$other=[IO.File]::Open((Join-Path $root 'runner.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$other.Dispose()}catch{$caught=$true};Check $caught}finally{$guard.Dispose()}
 $guard=[IO.File]::Open((Join-Path $root 'runner.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$guard.Dispose();Check $true
 [IO.File]::WriteAllText(($p+'.tmp'),'truncated');$caught=$false;try{& (Get-Module BackendHost) {param($p) Read-LabProtected $p} $p}catch{$caught=$true};Check $caught
 # Real native process boundary with a fake Docker executable; no docker/device invoked.
 $exe=Join-Path $root 'fake-docker.exe'
 $code='using System; class DockerFixture { static int Main(string[] a) { if(a.Length==4 && a[0]=="--host" && a[1]=="npipe:////./pipe/dockerDesktopLinuxEngine" && a[2]=="info" && a[3]=="SAFE_FIXTURE") { Console.Write("NATIVE_FAKE_ONLY"); return 0; } return 73; } }'
 if($PSVersionTable.PSVersion.Major -eq 5){
  Add-Type -TypeDefinition $code -OutputAssembly $exe -OutputType ConsoleApplication
  Import-Module (Join-Path $PSScriptRoot '../update-review/Review.psm1') -Force
  $r=Invoke-ReviewProcess $exe @('--host','npipe:////./pipe/dockerDesktopLinuxEngine','info','SAFE_FIXTURE') '';Check ($r.stdout -ceq 'NATIVE_FAKE_ONLY')
  $caught=$false;try{$null=Invoke-ReviewProcess $exe @('arbitrary-target') ''}catch{$caught=$true};Check $caught
  # Exercise native PowerShell -> frozen native Node -> fake native Docker, private pipes,
  # DPAPI session persistence, exclusive concurrent admission and normal stop/restart.
  $b=$null;$savedLocal=$env:LOCALAPPDATA
  try{
   $env:LOCALAPPDATA=Join-Path $root 'local';[void][IO.Directory]::CreateDirectory($env:LOCALAPPDATA)
   $dockerDir=Join-Path $env:LOCALAPPDATA 'Programs/DockerDesktop/resources/bin';[void][IO.Directory]::CreateDirectory($dockerDir);Copy-Item $exe (Join-Path $dockerDir 'docker.exe')
   $bundle=Join-Path $root 'bundle';$runtime=Join-Path $bundle 'runtime';[void][IO.Directory]::CreateDirectory($runtime)
   Copy-Item (Get-Command node.exe).Source (Join-Path $runtime 'node.exe')
   [IO.File]::WriteAllText((Join-Path $bundle 'backend-compatibility.json'),(@{format=1;source=('a'*40);digest=('b'*64)}|ConvertTo-Json -Compress))
   $source=Join-Path $bundle 'source';$scripts=Join-Path $source 'tools/enforcement/physical-lab';[void][IO.Directory]::CreateDirectory($scripts)
   $fake=@'
import {createInterface} from 'node:readline';import {spawnSync} from 'node:child_process';import {parsePrivateFrame} from './lease.mjs';
const r=createInterface({input:process.stdin});let started=false;
r.on('line',line=>{if(line==='STOP'){process.stdout.write('STOPPED_DATA_RETAINED\n');r.close();process.stdin.destroy();return;}
 let c;try{c=parsePrivateFrame(line);}catch{process.stdout.write(JSON.stringify({ready:false,code:'JSON_FRAME_'+line.charCodeAt(0)})+'\n');return;}const x=spawnSync(c.docker,['--host',c.host,'info','SAFE_FIXTURE'],{encoding:'utf8'});
 if(started||x.status!==0||x.stdout!=='NATIVE_FAKE_ONLY'||!c.secrets.database||c.source!=='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'){process.stdout.write('{"ready":false}\n');return;}
 started=true;process.stdout.write('{"ready":true,"jwt":"fixture.payload.signature","compatibility":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","review":{"owners":1,"households":1,"sessions":[],"devices":[]}}\n');});
'@
   [IO.File]::WriteAllText((Join-Path $scripts 'runtime.mjs'),$fake)
   Copy-Item (Join-Path $PSScriptRoot '../physical-lab/lease.mjs') (Join-Path $scripts 'lease.mjs')
   # Public-source syntax check and structural-only framing diagnostic (no secret bytes).
   $null=Invoke-ReviewProcess (Join-Path $runtime 'node.exe') @('--check',(Join-Path $scripts 'runtime.mjs')) ''
   Write-Output 'NATIVE_PIPE_FIRST_START'
   $b=Start-ProductBackend $source $bundle ('a'*40);$leaseId=$b.local.id;Check ($null -ne $b.jwt)
   $caught=$false;try{$other=Start-ProductBackend $source $bundle ('a'*40)}catch{$caught=$true};Check $caught
   $d=[pscustomobject]@{id=[Guid]::NewGuid().ToString();policy_epoch=[Guid]::NewGuid().ToString()};Save-ProductLabDevice $b $d
   Check ((Stop-ProductBackend $b) -ceq 'STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED');$b=$null
   Write-Output 'NATIVE_PIPE_SECOND_START'
   $b=Start-ProductBackend $source $bundle ('a'*40)
   Check ($b.local.id -ceq $leaseId -and $b.local.device.id -ceq $d.id -and $b.local.device.policy_epoch -ceq $d.policy_epoch)
   $null=Stop-ProductBackend $b;$b=$null
   $caught=$false;try{$other=Start-ProductBackend $source $bundle ('b'*40)}catch{$caught=$true};Check $caught
   foreach($stage in @('DOCKER_ENGINE','LAB_PORTS','LEASE_STATE','LEASE_START','POSTGRES_READY','AUTH_READY','GATEWAY_READY','BACKEND_HEALTH')){
    $failed="import {createInterface} from 'node:readline';const r=createInterface({input:process.stdin});r.on('line',line=>{if(line==='STOP'){r.close();process.stdin.destroy();return;}process.stdout.write(JSON.stringify({ready:false,code:'SYNTHETIC_NATIVE_FAILURE',stage:'"+$stage+"'})+'\n');});"
    [IO.File]::WriteAllText((Join-Path $scripts 'runtime.mjs'),$failed)
    $observed=$null;try{$other=Start-ProductBackend $source $bundle ('a'*40)}catch{$observed=$_.Exception.Data['hostStage']}
    Check ($observed -ceq $stage)
   }

  }finally{if($b){$null=Stop-ProductBackend $b};$env:LOCALAPPDATA=$savedLocal}
 }
 Write-Output "OD51_NATIVE_DPAPI_LOCK_TRANSPORT_CHECKS=$script:n;REAL_DOCKER_ADB=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
