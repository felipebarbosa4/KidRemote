Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-frozen-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
$names=@('ResumeReview','ResumePreparation','Reuse','BackendHost','Journal','Replacement','ReplacementAdb','ReadOnly','Canonical','EnrollmentHost','QrPresentation','QrRenderer','LivePreparation','LiveSlice','ProductOracle','ProductTransport')
try{
 # The freezer emits UTF-8 BOM for scripts so Windows PowerShell 5.1 reads UI labels correctly.
 Copy-Item -LiteralPath (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path -Destination (Join-Path $root 'tools') -Recurse
 foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $root 'tools') -Recurse -File|Where-Object{$_.Extension -in @('.ps1','.psm1')})){
  $text=[IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8);[IO.File]::WriteAllText($file.FullName,$text,(New-Object Text.UTF8Encoding($true)))
 }
 $modules=Join-Path $root 'tools/enforcement/product-oracle'
 foreach($name in $names){Import-Module (Join-Path $modules ($name+'.psm1'))}
 Import-Module (Join-Path $root 'tools/enforcement/update-review/Review.psm1')
 # Imports alone did not prove command availability in 871fcfa. Exercise the real journal seam.
 foreach($command in @('Resolve-ProductPreparation','Invoke-ResumePreparation','Read-ResumeReview','Get-ResumableHistoryReview','Clear-ProductLabSavedDevice','New-ProductJournal','Read-ProductJournal','Add-ProductJournal','Invoke-ProductHostGate','Start-ProductBackend','Invoke-ReviewProcess','New-LivePreparation','Get-ProductPreparationFailure','New-LiveSliceCallbacks','Invoke-ProductSlice','New-ProductQrWindow','Invoke-ProductQrEnrollment','Invoke-ProductQrRenderer','Get-ReviewedPairingExpectations','Invoke-ReviewedPairingCleanup')){
  if(-not(Get-Command $command -ErrorAction SilentlyContinue)){throw ('MISSING_ENTRYPOINT_COMMAND_'+$command)}
 }
 $jwt=ConvertTo-SecureString 'synthetic' -AsPlainText -Force
 try{
  $prep=New-LivePreparation 'SYNTHETIC_ADB' 'SYNTHETIC_SERIAL' $root $root $jwt
  $found=& $prep.ops.Enroll.Module {[bool](Get-Command New-ProductQrWindow -ErrorAction SilentlyContinue)}
  if(-not $found){throw 'ENROLL_CLOSURE_QR_COMMAND_MISSING'}
  $reverseError=$null
  try{& $prep.ops.Reverse ([Guid]::NewGuid().ToString())}catch{$reverseError=$_}
  if($prep.state.preparationStage -cne 'REVERSE_CREATE'){throw 'REVERSE_CLOSURE_STAGE_NOT_RECORDED'}
  if($null -eq $reverseError){throw 'REVERSE_SYNTHETIC_ADB_UNEXPECTED_SUCCESS'}
  if($reverseError.Exception.Message -cne 'READ_ONLY_REVIEW_INVALID'){throw ('REVERSE_CLOSURE_UNEXPECTED_FAILURE_'+$reverseError.Exception.GetType().Name)}
 }finally{$jwt.Dispose()}
 $journal=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
 $null=Read-ProductJournal $journal
 $e=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $modules 'Run-ProductReplacement.ps1'),[ref]$null,[ref]$e)
 if($e){throw 'FROZEN_ENTRYPOINT_PARSE_FAILED'}
 Write-Output 'FROZEN_OWNER_MODULE_IMPORTS=17;ENTRYPOINT_PARSE=PASS;COMMANDS=20;ENROLL_CLOSURE=PASS;REVERSE_CLOSURE_STAGE=PASS;JOURNAL_CREATE_READ=PASS;DEVICE=NOT_INVOKED'
}finally{
 foreach($name in $names+@('Review','QrPresentation')){Remove-Module $name -Force -ErrorAction SilentlyContinue}
 Remove-Item -LiteralPath $root -Recurse -Force
}
