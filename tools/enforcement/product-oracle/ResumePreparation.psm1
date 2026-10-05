Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
function Invoke-ResumePreparation([string]$Directory,[hashtable]$Ops,[string]$Path){
 if($Path -cnotin @('ENROLL','RESET_ENROLL','VERIFY_REUSE')){throw 'INVALID:RESUME_PATH'}
 $j=Read-ProductJournal $Directory;if($j.rows.Count -or $j.partial){throw 'INVALID:RESUME_ATTEMPT_NOT_NEW'}
 if(-not(Test-Path -LiteralPath (Join-Path $Directory 'resume-review'))){throw 'INVALID:RESUME_REVIEW_REQUIRED'}
 $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) BEGIN STARTED
 try{
  if($Path -ceq 'RESET_ENROLL'){
   $id=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $id RESET_ADMITTED OD50_FIXED_SCOPE
   & $Ops.Reset $id
  }
  # Cancel only reviewed own abandoned sessions before generating a new QR.
  if($Path -cne 'VERIFY_REUSE'){
   $id=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $id PAIRING_CLEANUP_ADMITTED OD51_FIXED_SCOPE
   & $Ops.CancelPairings $id
  }
  $id=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $id REVERSE_ADMITTED OD51_FIXED_SCOPE;& $Ops.Reverse $id
  if($Path -ceq 'VERIFY_REUSE'){
   $id=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $id RESUME_ADMITTED OD51_FIXED_SCOPE;& $Ops.VerifyReuse $id
  }else{
   $id=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $id ENROLLMENT_ADMITTED OD51_FIXED_SCOPE;& $Ops.Enroll $id
  }
  $id=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $id SETUP_ADMITTED OD51_FIXED_SCOPE;& $Ops.Consent $id
  $id=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $id POLICY_ADMITTED OD51_FIXED_SCOPE
  if($Path -ceq 'VERIFY_REUSE'){& $Ops.Normalize $id}else{& $Ops.Configure $id}
  return [pscustomobject]@{status='PREPARED_NOT_PASS';cleanup='UNVERIFIED';path=$Path}
 }catch{
  $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) VERDICT INVALID
  $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) CLEANUP UNVERIFIED
  throw
 }
}
Export-ModuleMember -Function Invoke-ResumePreparation
