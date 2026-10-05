Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Test-only callbacks: no real HTTP, process, window or device operation.
function Test-EnrollmentClosureContext([string]$Bundle,[bool]$NativeRenderer=$false){
 $realRenderer=${function:Invoke-ProductQrRenderer}
 $ctx=@{pairings=0;renders=0;windows=0;opens=0;polls=0;disposed=0;bundle=$Bundle}
 $wireStub={param($service,$path,$method,$body,$jwt)
  if($jwt -isnot [Security.SecureString]){throw 'SYNTHETIC_JWT_NOT_CAPTURED'}
  if($service -ceq 'gateway' -and $path -ceq '/parent/pairing-sessions' -and $method -ceq 'POST'){
   $ctx.pairings++;return [pscustomobject]@{result='CREATED';expires_at=[DateTimeOffset]::UtcNow.AddMinutes(5).ToString('o');qr=[pscustomobject]@{protocol_version=1;session_id='11111111-1111-4111-8111-111111111111';token=('A'*43)}}
  }
  if($service -ceq 'rest' -and $path -ceq '/rpc/parent_devices' -and $method -ceq 'POST'){
   $ctx.polls++;return [pscustomobject]@{protocol_version=1;devices=@([pscustomobject]@{id='22222222-2222-4222-8222-222222222222';policy_epoch='33333333-3333-4333-8333-333333333333';version=0;revoked=$false})}
  };throw 'SYNTHETIC_UNEXPECTED_ROUTE'
 }.GetNewClosure()
 $renderStub={param([string]$Executable,[string[]]$Arguments,[string]$InputText,[scriptblock]$OnStage)
  $expectedClasspath=(Join-Path $ctx.bundle 'host-qr.jar')+';'+(Join-Path $ctx.bundle 'zxing-core.jar')
  if($Executable -cne (Join-Path $ctx.bundle 'runtime\jbr\bin\java.exe') -or $Arguments.Count -ne 3 -or $Arguments[0] -cne '-cp' -or $Arguments[1] -cne $expectedClasspath -or $Arguments[2] -cne 'HostQr'){throw 'SYNTHETIC_RENDER_CONTEXT_LOST'}
  $qr=$InputText|ConvertFrom-Json
  if($qr.protocol_version -ne 1 -or $qr.session_id -cne '11111111-1111-4111-8111-111111111111' -or $qr.token -cne ('A'*43)){throw 'SYNTHETIC_RENDER_PAYLOAD_LOST'}
  $ctx.renders++;if($NativeRenderer){return (& $realRenderer $Executable $Arguments $InputText $OnStage)}
  & $OnStage QR_RENDER_PROCESS;& $OnStage QR_RENDER_VALIDATE;return 'SYNTHETIC_PNG'
 }.GetNewClosure()
 $windowStub={param([string]$encoded)
  if($NativeRenderer){$bytes=[Convert]::FromBase64String($encoded);if([BitConverter]::ToString($bytes[0..7]) -cne '89-50-4E-47-0D-0A-1A-0A'){throw 'SYNTHETIC_PNG_INVALID'};$bytes=$null}
  elseif($encoded -cne 'SYNTHETIC_PNG'){throw 'SYNTHETIC_WINDOW_PAYLOAD'};$ctx.windows++
  $window=[pscustomobject]@{context=$ctx}
  $window|Add-Member ScriptMethod Snapshot {return [pscustomobject]@{Ready=$true;Visible=$true;ValidHandle=$true;TitleMatches=$true;TopMost=$true;Interactive=$true;ActivationAttempted=$true;Closed=$false;TimedOut=$false}}
  $window|Add-Member ScriptMethod Dispose {$this.context.disposed++};return $window
 }.GetNewClosure()
 $actionStub={param($adb,$serial,$action,$apk,$run)
  if($adb -cne 'SYNTHETIC_NONEXISTENT_ADB' -or $serial -cne 'SYNTHETIC_SERIAL' -or $action -cne 'OpenChild'){throw 'SYNTHETIC_UNEXPECTED_DEVICE_ACTION'};$ctx.opens++
 }.GetNewClosure()
 $jwt=ConvertTo-SecureString 'SYNTHETIC_NOT_A_CREDENTIAL' -AsPlainText -Force
 $prep=New-LivePreparation 'SYNTHETIC_NONEXISTENT_ADB' 'SYNTHETIC_SERIAL' $Bundle $Bundle $jwt
 $liveModule=$prep.wire.Module
 $oldWire=& $liveModule {${function:Invoke-LabWire}}
 $oldWindow=& $liveModule {${function:New-ProductQrWindow}}
 $oldRender=${function:Invoke-ProductQrRenderer};$oldAction=${function:Invoke-ReplacementAdb}
 try{
  & $liveModule {param($wire,$window) Set-Item Function:script:Invoke-LabWire $wire;Set-Item Function:script:New-ProductQrWindow $window} $wireStub $windowStub
  Set-Item Function:global:Invoke-ProductQrRenderer $renderStub
  Set-Item Function:global:Invoke-ReplacementAdb $actionStub
  try{& $prep.ops.Enroll 6>$null}catch{throw ('ENROLL_CALLBACK_CONTEXT_FAILED_'+$prep.state.preparationStage+'_'+$_.Exception.Message)}
  foreach($key in @('pairings','renders','windows','opens','polls')){if($ctx[$key] -ne 1){throw ('ENROLL_CALLBACK_COUNT_'+$key)}}
  if($ctx.disposed -lt 1 -or $prep.state.device.id -cne '22222222-2222-4222-8222-222222222222' -or $prep.state.preparationStage -cne 'QR_ENROLLMENT_POLL'){throw 'ENROLL_CALLBACK_RESULT'}
  Write-Output ('ENROLL_CALLBACK_CONTEXT=PASS;NATIVE_RENDERER='+$NativeRenderer+';HTTP_WINDOW_DEVICE=STUBBED;DEVICE=NOT_INVOKED')
 }finally{
  & $liveModule {param($wire,$window) Set-Item Function:script:Invoke-LabWire $wire;Set-Item Function:script:New-ProductQrWindow $window} $oldWire $oldWindow
  Set-Item Function:global:Invoke-ProductQrRenderer $oldRender
  Set-Item Function:global:Invoke-ReplacementAdb $oldAction
  $jwt.Dispose()
 }
}

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
 Test-EnrollmentClosureContext (Join-Path $root 'synthetic-bundle')
 Test-EnrollmentClosureContext (Join-Path $root 'second synthetic bundle')
 $journal=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
 $null=Read-ProductJournal $journal
 $e=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $modules 'Run-ProductReplacement.ps1'),[ref]$null,[ref]$e)
 if($e){throw 'FROZEN_ENTRYPOINT_PARSE_FAILED'}
 Write-Output 'FROZEN_OWNER_MODULE_IMPORTS=17;ENTRYPOINT_PARSE=PASS;COMMANDS=20;ENROLL_CLOSURE=PASS;REVERSE_CLOSURE_STAGE=PASS;JOURNAL_CREATE_READ=PASS;DEVICE=NOT_INVOKED'
}finally{
 foreach($name in $names+@('Review','QrPresentation')){Remove-Module $name -Force -ErrorAction SilentlyContinue}
 Remove-Item -LiteralPath $root -Recurse -Force
}
