Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:OS -cne 'Windows_NT'){throw 'WINDOWS_NATIVE_TEST_ONLY'}
Import-Module (Join-Path $PSScriptRoot 'ReplacementAdb.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../update-review/Review.psm1') -Force
$root=Join-Path ([IO.Path]::GetTempPath()) ('od50-native-'+[Guid]::NewGuid().ToString());[void][IO.Directory]::CreateDirectory($root)
$script:n=0
function Check($b){$script:n++;if(-not $b){throw "NATIVE_CHECK_$script:n"}}
try{
 $exe=Join-Path $root 'fake-adb.exe'
 if($PSVersionTable.PSVersion.Major -ne 5){throw 'USE_NATIVE_WINDOWS_POWERSHELL_51_FOR_COMPILER'}
 Add-Type -Path (Join-Path $PSScriptRoot 'ReplacementNativeFixture.cs') -OutputAssembly $exe -OutputType ConsoleApplication
 $run={param($e,$a,$i) Invoke-ReviewProcess $e $a $i}
 Check ((Invoke-ReplacementAdb $exe SYNTHETIC Uninstall '' $run) -ceq 'Success')
 Assert-LabReverse (Invoke-ReplacementAdb $exe SYNTHETIC ReverseRead '' $run) $false;Check $true
 $null=Invoke-ReplacementAdb $exe SYNTHETIC Reverse '' $run
 Assert-LabReverse (Invoke-ReplacementAdb $exe SYNTHETIC ReverseRead '' $run) $true;Check $true
 $caught=$false;try{$null=Invoke-ReplacementAdb $exe SYNTHETIC Reverse '' $run}catch{$caught=$true};Check $caught
 $null=Invoke-ReplacementAdb $exe SYNTHETIC RemoveReverse '' $run
 Assert-LabReverse (Invoke-ReplacementAdb $exe SYNTHETIC ReverseRead '' $run) $false;Check $true
 $env:OD50_FAKE_FAILURE='1';$caught=$false;try{$null=Invoke-ReplacementAdb $exe SYNTHETIC Uninstall '' $run}catch{$caught=$true};Check $caught
 Write-Output "REPLACEMENT_NATIVE_FAKE_ADB_CHECKS=$script:n;REAL_ADB=NOT_INVOKED"
}finally{
 Remove-Item Env:OD50_FAKE_FAILURE -ErrorAction SilentlyContinue
 Remove-Item -LiteralPath $root -Recurse -Force
}
