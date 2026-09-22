Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'QrRenderer.psm1') -Force
$script:n=0;function Check($value){$script:n++;if(-not $value){throw "QR_RENDER_CHECK_$script:n"}}
$executable=(Get-Process -Id $PID).Path
$png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
function Encoded([string]$Command){return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))}
function Render([string]$Command,$Stages){return Invoke-ProductQrRenderer $executable @('-NoProfile','-EncodedCommand',(Encoded $Command)) 'synthetic-private-qr' {param($s)$Stages.values+=,$s}.GetNewClosure()}
$stages=@{values=@()};$value=Render ("[Console]::Out.Write('"+$png+"')") $stages
Check ($value -ceq $png);Check (($stages.values -join ',') -ceq 'QR_RENDER_PROCESS,QR_RENDER_VALIDATE')
$stages=@{values=@()};$caught=$null;try{$null=Render 'exit 7' $stages}catch{$caught=$_};Check ($caught.Exception.Message -ceq 'INVALID:QR_RENDER_PROCESS_FAILED');Check (($stages.values -join ',') -ceq 'QR_RENDER_PROCESS')
$stages=@{values=@()};$caught=$null;try{$null=Render "[Console]::Out.Write('NOT_BASE64')" $stages}catch{$caught=$_};Check ($caught.Exception.Message -ceq 'INVALID:QR_RENDER_OUTPUT_INVALID');Check (($stages.values -join ',') -ceq 'QR_RENDER_PROCESS,QR_RENDER_VALIDATE')
$stages=@{values=@()};$value=Render ("[Console]::Error.Write('PRIVATE_RAW_STDERR');[Console]::Out.Write('"+$png+"')") $stages
Check ($value -ceq $png);Check (($stages.values -join ',') -ceq 'QR_RENDER_PROCESS,QR_RENDER_VALIDATE')
$stages=@{values=@()};$caught=$null;try{$null=Render ("[Console]::Error.Write('"+('x'*65537)+"');[Console]::Out.Write('"+$png+"')") $stages}catch{$caught=$_};Check ($caught.Exception.Message -ceq 'INVALID:QR_RENDER_PROCESS_FAILED');Check ($caught.Exception.Message -notmatch 'PRIVATE_RAW_STDERR')
$caught=$null;try{$null=Invoke-ProductQrRenderer $executable @('-NoProfile') ('x'*257) {} }catch{$caught=$_};Check ($caught.Exception.Message -ceq 'INVALID:QR_RENDER_PROCESS_FAILED')
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'QrRenderer.psm1'))
Check ($source -notmatch 'Write-(Host|Output)|stderr\s*\+|InputText\s*\+')
Write-Output "QR_RENDER_CHECKS=$script:n;RAW_PAYLOAD_AND_STDERR=NOT_EMITTED;DEVICE=NOT_INVOKED"
