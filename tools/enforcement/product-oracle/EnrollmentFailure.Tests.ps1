Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'LivePreparation.psm1') -Force
$script:n=0;function Check($value){$script:n++;if(-not $value){throw "ENROLLMENT_FAILURE_CHECK_$script:n"}}
function FakeWindow([bool]$Ready=$true){
 $window=[pscustomobject]@{readyValue=$Ready;closedValue=$false}
 $window|Add-Member ScriptMethod Snapshot {return [pscustomobject]@{Ready=$this.readyValue;Visible=$this.readyValue;ValidHandle=$this.readyValue;TitleMatches=$true;TopMost=$true;Interactive=$true;ActivationAttempted=$true;Closed=$this.closedValue;TimedOut=$false}}
 $window|Add-Member ScriptMethod Dispose {$this.closedValue=$true};return $window
}
function RunCase([scriptblock]$Pairing,[scriptblock]$Render,[scriptblock]$Factory,[scriptblock]$Open,[scriptblock]$Poll,[int]$Timeout=100){
 $state=@{preparationStage='NONE'};$stage={param($value)$state.preparationStage=$value}.GetNewClosure();$caught=$null
 try{$null=Invoke-ProductEnrollmentPreparation $state $Pairing $Render $Factory $Open $Poll {} $stage $Timeout}catch{$caught=$_}
 return [pscustomobject]@{error=$caught;state=$state}
}
$goodPairing={param($stage)& $stage PAIRING_SESSION_CREATE;& $stage PAIRING_SESSION_VALIDATE;return [pscustomobject]@{qr=[pscustomobject]@{protocol_version=1;session_id=[Guid]::NewGuid().ToString();token=('A'*43)}}}
$goodRender={param($qr,$stage)& $stage QR_RENDER_PROCESS;& $stage QR_RENDER_VALIDATE;return 'SYNTHETIC_PNG'}
$goodFactory={param($encoded) return FakeWindow}
$case=RunCase {param($stage)& $stage PAIRING_SESSION_CREATE;throw 'PRIVATE_CREATE_FAILURE'} $goodRender $goodFactory {} {[pscustomobject]@{id='never'}}
Check ($case.error.Exception.Message -ceq 'INVALID:PAIRING_SESSION_CREATE_FAILED');Check ($case.error.Exception.Data['preparationStage'] -ceq 'PAIRING_SESSION_CREATE')
$case=RunCase {param($stage)& $stage PAIRING_SESSION_CREATE;& $stage PAIRING_SESSION_VALIDATE;throw 'PRIVATE_SCHEMA'} $goodRender $goodFactory {} {[pscustomobject]@{id='never'}}
Check ($case.error.Exception.Message -ceq 'INVALID:PAIRING_SESSION_INVALID');Check ($case.error.Exception.Data['preparationStage'] -ceq 'PAIRING_SESSION_VALIDATE')
$case=RunCase $goodPairing {param($qr,$stage)& $stage QR_RENDER_PROCESS;throw 'PRIVATE_RAW_STDERR'} $goodFactory {} {[pscustomobject]@{id='never'}}
Check ($case.error.Exception.Message -ceq 'INVALID:QR_RENDER_PROCESS_FAILED');Check ($case.error.Exception.Data['preparationStage'] -ceq 'QR_RENDER_PROCESS');Check ($case.error.Exception.Message -notmatch 'PRIVATE_RAW_STDERR')
$failure=Get-ProductPreparationFailure $case.error $case.state;$sanitized=[ordered]@{hostValidated=$true;hostFailureStage='NONE';hostFailureCode='NONE';preparationFailureStage=$failure.stage;preparationFailureCode=$failure.code;preparation=[ordered]@{path='ENROLL'};primary=[ordered]@{status='INVALID';reason=$failure.reason;cleanup='UNVERIFIED'};reverseCleanup='OWN_REVERSE_REMOVED'}
Check ($sanitized.preparationFailureStage -ceq 'QR_RENDER_PROCESS');Check ($sanitized.preparationFailureCode -ceq 'QR_RENDER_PROCESS_FAILED');Check ($sanitized.primary.reason -ceq 'INVALID:QR_RENDER_PROCESS_FAILED');Check (($sanitized|ConvertTo-Json -Depth 5) -notmatch 'PRIVATE_RAW_STDERR')
$case=RunCase $goodPairing {param($qr,$stage)& $stage QR_RENDER_PROCESS;& $stage QR_RENDER_VALIDATE;throw 'MALFORMED_PRIVATE_OUTPUT'} $goodFactory {} {[pscustomobject]@{id='never'}}
Check ($case.error.Exception.Message -ceq 'INVALID:QR_RENDER_OUTPUT_INVALID');Check ($case.error.Exception.Data['preparationStage'] -ceq 'QR_RENDER_VALIDATE')
$case=RunCase $goodPairing $goodRender {throw 'WINDOW_PRIVATE_FAILURE'} {} {[pscustomobject]@{id='never'}}
Check ($case.error.Exception.Message -ceq 'INVALID:QR_WINDOW_CREATE_FAILED');Check ($case.error.Exception.Data['preparationStage'] -ceq 'QR_WINDOW_CREATE')
$case=RunCase $goodPairing $goodRender {FakeWindow $false} {} {[pscustomobject]@{id='never'}}
Check ($case.error.Exception.Message -ceq 'INVALID:QR_WINDOW_NOT_READY');Check ($case.error.Exception.Data['preparationStage'] -ceq 'QR_WINDOW_READY_INITIAL')
$case=RunCase $goodPairing $goodRender $goodFactory {throw 'PRIVATE_ADB_FAILURE'} {[pscustomobject]@{id='never'}}
Check ($case.error.Exception.Message -ceq 'INVALID:CHILD_OPEN_FAILED');Check ($case.error.Exception.Data['preparationStage'] -ceq 'CHILD_OPEN_FOR_SCAN')
$window=FakeWindow;$case=RunCase $goodPairing $goodRender {return $window}.GetNewClosure() {$window.readyValue=$false}.GetNewClosure() {[pscustomobject]@{id='never'}}
Check ($case.error.Exception.Message -ceq 'INVALID:QR_WINDOW_NOT_READY');Check ($case.error.Exception.Data['preparationStage'] -ceq 'QR_WINDOW_READY_AFTER_CHILD_OPEN')
$case=RunCase $goodPairing $goodRender $goodFactory {} {throw 'PRIVATE_BACKEND_FAILURE'}
Check ($case.error.Exception.Message -ceq 'INVALID:QR_ENROLLMENT_POLL_FAILED');Check ($case.error.Exception.Data['preparationStage'] -ceq 'QR_ENROLLMENT_POLL')
$case=RunCase $goodPairing $goodRender $goodFactory {} {$null} 1
Check ($case.error.Exception.Message -ceq 'INVALID:PAIRING_TIMEOUT');Check ($case.error.Exception.Data['preparationStage'] -ceq 'QR_ENROLLMENT_TIMEOUT')
$runner=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Run-ProductReplacement.ps1'));$live=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'LivePreparation.psm1'))
Check ($runner -match 'preparationFailureStage=\$preparationFailureStage;preparationFailureCode=\$preparationFailureCode')
Check ($runner.Contains("if(`$hostValidated){") -and $runner.Contains("`$hostFailureCode='NONE';`$reason=`$failure.reason"))
Check ($live -notmatch '(?s)\$ops\.Enroll=\{.*?Invoke-ReviewProcess')
Check ($runner -notmatch 'preparationFailure(Code|Stage).*stderr|preparationFailure(Code|Stage).*token')
try{throw 'PRIVATE_UNTYPED_FAILURE'}catch{$fallback=Get-ProductPreparationFailure $_ @{preparationStage='NONE'}};Check ($fallback.stage -ceq 'PREPARATION_ORCHESTRATION');Check ($fallback.code -ceq 'PREPARATION_ORCHESTRATION_FAILED');Check ($fallback.reason -notmatch 'PRIVATE_UNTYPED_FAILURE')
Write-Output "ENROLLMENT_FAILURE_CHECKS=$script:n;TYPED_RESULT_SHAPE=PASS;PRIVATE_OUTPUT=NOT_EMITTED;DEVICE=NOT_INVOKED"
