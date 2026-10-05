Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not ('Od51RetryDiagnostic' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'SyncRetryDiagnostic.cs')}
function Get-Od51RetryScript { return [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Read-SyncRetry.sh')) }
function Convert-Od51RetryProcessResult($ProcessResult){
 # No raw transport or exception is returned, persisted or written to the console.
 try{
  if($ProcessResult.outputTooLarge){return [pscustomobject]@{status='INVALID';failureCode='ADB_OUTPUT_TOO_LARGE'}}
  if($ProcessResult.stderrPresent){return [pscustomobject]@{status='INVALID';failureCode='ADB_STDERR_PRESENT'}}
  if($ProcessResult.exitCode -ne 0){return [pscustomobject]@{status='INVALID';failureCode='ADB_EXIT_NONZERO'}}
  $summary=[Od51RetryDiagnostic]::Summarize([string]$ProcessResult.stdout)
  $public=[ordered]@{}
  foreach($key in @('status','failureCode','checksumValidity','schemaValidity','pending','stopped','reason','attemptCount','delayMs','bootRecorded','deadlineRecorded','legacyReasonDerived')){$public[$key]=$summary[$key]}
  return [pscustomobject]$public
 }catch{return [pscustomobject]@{status='INVALID';failureCode='RETRY_PROCESS_INVALID'}}
 finally{$ProcessResult=$null}
}
Export-ModuleMember -Function Get-Od51RetryScript,Convert-Od51RetryProcessResult
