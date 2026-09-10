Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){Write-Host 'SKIP: recorder fake process requires Windows.';exit 0}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('kr003-recorder-test-'+[Guid]::NewGuid().ToString('N'))
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
try{
    New-Item -ItemType Directory -Path $temporary|Out-Null
    $fake=Join-Path $temporary 'fake-recorder.exe';$source=Join-Path $temporary 'fake.cs'
    [IO.File]::WriteAllText($source,'public static class FakeRecorder { public static int Main(string[] a) { System.IO.File.WriteAllText(System.Reflection.Assembly.GetExecutingAssembly().Location+".arguments",System.String.Join("|",a)); System.Console.WriteLine("KR003_RECORDER_PID:4242"); return 0; } }')
    & (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe') /nologo /target:exe (('/out:')+$fake) $source
    if($LASTEXITCODE -ne 0){throw 'FAKE_COMPILER_FAILED'}
    . (Join-Path $PSScriptRoot 'Start-KR003.ps1') -Adb $fake -VisualCalibration -FunctionsOnly
    . (Join-Path $PSScriptRoot 'ReferenceVideo.Runner.ps1')
    $runDirectory=$temporary;$runId='video-20000101-000000-12345678';$script:RVMedia=$temporary
    $script:RVRecorders=@();$script:RVProcesses=@{};$script:RVStderr=@{};$script:RecorderMode='RUNNING';$script:KillCalls=0
    function Invoke-LabAdbResult([string[]]$Arguments){
        if($Arguments[0] -eq 'pull'){
            [IO.File]::WriteAllBytes($Arguments[2],[byte[]]@(1,2,3,4));$reply=''
        }elseif($Arguments[1] -eq 'kill'){
            Assert-Equal $Arguments[2] '-2';Assert-Equal $Arguments[3] '4242'
            $script:KillCalls++;$script:RecorderMode='ABSENT';$reply=''
        }elseif($Arguments[1] -eq 'sha256sum'){$reply=(Get-FileHash (Join-Path $temporary 'held-out.mp4')).Hash.ToLowerInvariant()+'  file'}
        else{$reply=if($script:RecorderMode -eq 'ABSENT'){'KR003_ABSENT'}elseif($script:RecorderMode -eq 'WRONG'){'unrelated process'}else{$script:RVRecorders[0].ExpectedCommand.Replace(' ',[string][char]0)+[char]0}}
        [PSCustomObject]@{Stdout=$reply;ExitCode=0;StderrClass='NONE'}
    }
    $record=Start-RVRecording 'held-out' 120
    Assert-Equal $record.RecorderPid 4242
    Assert-Equal ([IO.File]::ReadAllText($fake+'.arguments') -match '^shell\|sh\|-c\|.*echo KR003_RECORDER_PID:\$\$; exec screenrecord --time-limit 120') $true
    Assert-Equal (Get-RVOwnedRecorderState $record) 'OWNED_RUNNING'
    $script:RecorderMode='WRONG';$rejected=$false
    try{Stop-RVRecording $record}catch{$rejected=$true}
    Assert-Equal $rejected $true;Assert-Equal $script:KillCalls 0
    $script:RecorderMode='RUNNING';Stop-RVRecording $record
    Assert-Equal $script:KillCalls 1;Assert-Equal $record.Termination 'VERIFIED';Assert-Equal $record.CopyStatus 'VERIFIED'
    Stop-RVRecording $record;Assert-Equal $script:KillCalls 1
    # A failed prior pull must never be overwritten on retry.
    $record.CopyStatus='NOT_ATTEMPTED';$rejected=$false
    try{Stop-RVRecording $record}catch{$rejected=$_.Exception.Message -eq 'INVALID:VIDEO_COPY_EXISTS_PRESERVE_PARTIAL'}
    Assert-Equal $rejected $true
    Assert-Equal ([IO.File]::ReadAllBytes((Join-Path $temporary 'held-out.mp4')).Length) 4
    $script:RVEnrollment=[PSCustomObject]@{FrozenTicks=30;References=@()}
    foreach($role in @('ORDINARY','RESTRICTED')){
        foreach($extension in @('rgb','png')){[IO.File]::WriteAllBytes((Join-Path $temporary ($role+'.'+$extension)),[byte[]]@(1,2,3,4))}
        $script:RVEnrollment.References+=[PSCustomObject]@{Role=$role;File=$role+'.rgb';ViewFile=$role+'.png';Sha256=(Get-FileHash (Join-Path $temporary ($role+'.rgb'))).Hash.ToLowerInvariant();ViewSha256=(Get-FileHash (Join-Path $temporary ($role+'.png'))).Hash.ToLowerInvariant();ConfirmedTicks=20;OwnerConfirmation='MATCHES_DISPLAYED_SURFACE'}
    }
    Write-JsonFile 'references.json' $script:RVEnrollment
    $script:RVFrozenHash=(Get-FileHash (Join-Path $temporary 'references.json')).Hash
    Assert-RVReferenceFiles;$script:Checks++
    [IO.File]::WriteAllBytes((Join-Path $temporary 'RESTRICTED.rgb'),[byte[]]@(4,3,2,1))
    $rejected=$false;try{Assert-RVReferenceFiles}catch{$rejected=$_.Exception.Message -eq 'INVALID:REFERENCE_INTEGRITY'}
    Assert-Equal $rejected $true
    $script:RVEnrollment.References[1].Role='ORDINARY'
    $rejected=$false;try{Assert-RVReferenceFiles}catch{$rejected=$_.Exception.Message -eq 'INVALID:REFERENCE_FREEZE_INTEGRITY'}
    Assert-Equal $rejected $true
    Write-Host ($script:Checks.ToString()+' recorder ownership, termination and partial-preservation assertions passed; fake device only.')
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
