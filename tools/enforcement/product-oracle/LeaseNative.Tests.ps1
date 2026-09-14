Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:OS -cne 'Windows_NT'){throw 'WINDOWS_NATIVE_ONLY'}
Import-Module (Join-Path $PSScriptRoot 'BackendHost.psm1') -Force
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-native-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
$script:n=0;function Check($b){$script:n++;if(-not $b){throw "OD51_NATIVE_$script:n"}}
try{
 & (Get-Module BackendHost) {param($r) Protect-LabDirectory $r} $root
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
 }
 Write-Output "OD51_NATIVE_DPAPI_LOCK_TRANSPORT_CHECKS=$script:n;REAL_DOCKER_ADB=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
