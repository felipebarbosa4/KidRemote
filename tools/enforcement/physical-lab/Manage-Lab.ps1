param([ValidateSet('status','teardown')][string]$Action='status',[Parameter(Mandatory=$true)][string]$Bundle,[string]$ConfirmLease,[Parameter(Mandatory=$true)][string]$ExpectedManifestHash)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Intended for a separately approved future owner operation, never automatic run cleanup.
$manifestPath=Join-Path $Bundle 'bundle.json'
if($ExpectedManifestHash -cnotmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $manifestPath).Hash.ToLowerInvariant() -cne $ExpectedManifestHash){throw 'INVALID:BUNDLE_HASH'}
$m=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
foreach($f in $m.files){if($f.name -cnotmatch '^[A-Za-z0-9_./-]+$' -or $f.name -match '(^|/)\.\.?(/|$)' -or (Get-FileHash -LiteralPath (Join-Path $Bundle $f.name)).Hash.ToLowerInvariant() -cne $f.sha256){throw 'INVALID:BUNDLE_FILE_HASH'}}
Import-Module (Join-Path $Bundle 'source/tools/enforcement/product-oracle/BackendHost.psm1') -Force
$root=Join-Path $env:LOCALAPPDATA 'KidRemote/physical-lab';$guard=$null
try{
 $guard=[IO.File]::Open((Join-Path $root 'runner.lock'),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 $local=& (Get-Module BackendHost) {param($p) Read-LabProtected $p} (Join-Path $root 'lease.dpapi')
 if($m.source -cne $local.source){throw 'INVALID:LEASE_SOURCE_MISMATCH'}
 $docker=Join-Path $env:LOCALAPPDATA 'Programs/DockerDesktop/resources/bin/docker.exe';if(-not(Test-Path $docker)){$docker='C:\Program Files\Docker\Docker\resources\bin\docker.exe'}
 $c=@{root=(Join-Path $Bundle 'source');state=(Join-Path $root 'resources.json');source=$local.source;id=$local.id;secrets=$local.secrets;docker=$docker;host='npipe:////./pipe/dockerDesktopLinuxEngine';action=$Action;confirmLease=$ConfirmLease}
 $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=Join-Path $Bundle 'runtime/node.exe';$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true;$p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 $script=Join-Path $Bundle 'source/tools/enforcement/physical-lab/admin.mjs';$p.StartInfo.Arguments='"'+$script+'"';[void]$p.Start();$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.StandardInput.WriteLine(($c|ConvertTo-Json -Depth 8 -Compress));$p.StandardInput.Close();$c=$null
 if(-not $p.WaitForExit(180000) -or $p.ExitCode -ne 0){throw 'INVALID:LAB_ADMIN_FAILED_CLOSED'}
 Write-Output ($out.GetAwaiter().GetResult())
}finally{if($guard){$guard.Dispose()};$local=$null}
