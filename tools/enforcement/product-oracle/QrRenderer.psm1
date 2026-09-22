Set-StrictMode -Version Latest

function Throw-ProductQrRender([string]$Code){
 if($Code -cnotin @('QR_RENDER_PROCESS_FAILED','QR_RENDER_OUTPUT_INVALID')){$Code='QR_RENDER_PROCESS_FAILED'}
 throw ('INVALID:'+$Code)
}

function Invoke-ProductQrRenderer([string]$Executable,[string[]]$Arguments,[string]$InputText,[scriptblock]$OnStage={}){
 foreach($argument in $Arguments){if($argument -match '["\r\n]' -or $argument.EndsWith('\')){Throw-ProductQrRender QR_RENDER_PROCESS_FAILED}}
 $inputBytes=(New-Object Text.UTF8Encoding($false)).GetBytes($InputText)
 if($inputBytes.Length -lt 1 -or $inputBytes.Length -gt 256){$inputBytes=$null;Throw-ProductQrRender QR_RENDER_PROCESS_FAILED}
 & $OnStage QR_RENDER_PROCESS
 $process=New-Object Diagnostics.Process
 $process.StartInfo.FileName=$Executable;$process.StartInfo.UseShellExecute=$false;$process.StartInfo.CreateNoWindow=$true
 $process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true;$process.StartInfo.RedirectStandardInput=$true
 $process.StartInfo.Arguments=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
 $stdout=$null;$stderr=$null
 try{
  try{
   [void]$process.Start();$stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync()
   $process.StandardInput.BaseStream.Write($inputBytes,0,$inputBytes.Length);$process.StandardInput.BaseStream.Flush();$process.StandardInput.BaseStream.Close();$inputBytes=$null
   if(-not $process.WaitForExit(60000)){try{$process.Kill()}catch{};Throw-ProductQrRender QR_RENDER_PROCESS_FAILED}
   $stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult()
  }catch{Throw-ProductQrRender QR_RENDER_PROCESS_FAILED}
  # Some JVM/host configurations write bounded diagnostics to stderr even when
  # rendering succeeds. Discard it and trust only exit status plus the decoded
  # PNG checks below; raw stderr never enters evidence.
  if($process.ExitCode -ne 0 -or $stdout.Length -gt 350000 -or $stderr.Length -gt 65536){Throw-ProductQrRender QR_RENDER_PROCESS_FAILED}
  & $OnStage QR_RENDER_VALIDATE
  if($stdout.Length -lt 12 -or $stdout -cnotmatch '^[A-Za-z0-9+/]+={0,2}$'){Throw-ProductQrRender QR_RENDER_OUTPUT_INVALID}
  try{$png=[Convert]::FromBase64String($stdout)}catch{Throw-ProductQrRender QR_RENDER_OUTPUT_INVALID}
  try{
   if($png.Length -lt 8 -or $png.Length -gt 262144 -or $png[0] -ne 137 -or $png[1] -ne 80 -or $png[2] -ne 78 -or $png[3] -ne 71 -or $png[4] -ne 13 -or $png[5] -ne 10 -or $png[6] -ne 26 -or $png[7] -ne 10){Throw-ProductQrRender QR_RENDER_OUTPUT_INVALID}
  }finally{$png=$null}
  return $stdout
 }finally{$inputBytes=$null;$stdout=$null;$stderr=$null;$process.Dispose()}
}

Export-ModuleMember -Function Invoke-ProductQrRenderer
