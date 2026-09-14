Set-StrictMode -Version Latest
function Start-ProductBackend([string]$SourceRoot){
 # Reuse existing WSL + native Docker Desktop topology; no installation/configuration repair.
 $docker=Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
 $wsl=Join-Path $env:WINDIR 'System32\wsl.exe'
 if(-not (Test-Path -LiteralPath $docker) -or -not (Test-Path -LiteralPath $wsl)){throw 'INVALID:START_DOCKER_DESKTOP_AND_RETRY_BEFORE_REPLACEMENT'}
 foreach($port in @(47361,47362,47363,47364,47365,47366)){
  $c=New-Object Net.Sockets.TcpClient
  try{$task=$c.ConnectAsync('127.0.0.1',$port);if($task.Wait(200) -and $c.Connected){throw 'INVALID:LAB_PORT_ALREADY_OWNED'}}catch{if($_.Exception.Message -ceq 'INVALID:LAB_PORT_ALREADY_OWNED'){throw}}finally{$c.Dispose()}
 }
 if($SourceRoot -cnotmatch '^C:\\[A-Za-z0-9 ._\\-]+$'){throw 'INVALID:LAB_SOURCE_PATH'}
 $linux='/mnt/c/'+$SourceRoot.Substring(3).Replace('\','/')+'/tools/kr004/test-local-db.mjs'
 $linuxDocker='/mnt/c/'+$docker.Substring(3).Replace('\','/')
 $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$wsl;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 $args=@('-d','Ubuntu-24.04','--exec','/usr/bin/env','KR_PRODUCT_LAB_STDIN=1','/home/felby/.nvm/versions/node/v22.23.1/bin/node',$linux,$linuxDocker,'npipe:////./pipe/dockerDesktopLinuxEngine','--enrollment-dev')
 $p.StartInfo.Arguments=($args|ForEach-Object{'"'+$_+'"'}) -join ' '
 try{
  [void]$p.Start();$stderr=$p.StandardError.ReadToEndAsync();$line=$p.StandardOutput.ReadLineAsync();$timer=[Diagnostics.Stopwatch]::StartNew()
  while($timer.Elapsed.TotalSeconds -lt 600){
   if($line.IsCompleted){$value=$line.GetAwaiter().GetResult();if($null -eq $value){throw 'INVALID:BACKEND_START_FAILED'}
    if($value.StartsWith('PARENT_DEV_READY:')){return @{process=$p;stderr=$stderr;stdout=$p.StandardOutput.ReadToEndAsync()}}
    if($value.Length -gt 8192){throw 'INVALID:BACKEND_OUTPUT_BOUNDS'};$line=$p.StandardOutput.ReadLineAsync()
   }
   Start-Sleep -Milliseconds 100
  }
  throw 'INVALID:BACKEND_START_TIMEOUT'
 }catch{
  try{$p.StandardInput.WriteLine('STOP');$p.StandardInput.Close();[void]$p.WaitForExit(30000)}catch{}
  $p.Dispose();throw 'INVALID:START_DOCKER_DESKTOP_OR_REVIEW_BACKEND_PREREQUISITES'
 }
}
function Stop-ProductBackend($Backend){
 if($null -eq $Backend){return 'NOT_STARTED'}
 $p=$Backend.process
 try{
  $p.StandardInput.WriteLine('STOP');$p.StandardInput.Close()
  if(-not $p.WaitForExit(60000)){throw 'INVALID:BACKEND_CLEANUP_TIMEOUT'}
  $text=$Backend.stdout.GetAwaiter().GetResult();$err=$Backend.stderr.GetAwaiter().GetResult()
  if($p.ExitCode -ne 0 -or $err.Trim() -or -not $text.Contains('CLEANUP=VERIFIED_TASK_CONTAINER_REMOVED') -or -not $text.Contains('TASK_NETWORK_REMOVED')){throw 'INVALID:BACKEND_CLEANUP_UNVERIFIED'}
  return 'TASK_BACKEND_REMOVED_LOCAL_IDENTITY_RETAINED_OFFLINE'
 }finally{$p.Dispose()}
}
Export-ModuleMember -Function Start-ProductBackend,Stop-ProductBackend
