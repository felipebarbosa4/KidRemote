param(
 [Parameter(Mandatory=$true)][ValidateSet('Create','Start','Stop')][string]$Mode,
 [string]$TaskDirectory,
 [string]$Sdk='C:\Users\3feli\AppData\Local\Android\Sdk'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not (Test-Path "$Sdk\emulator\emulator.exe")){throw 'SDK_EMULATOR_MISSING'}
if($Mode -eq 'Create') {
 if($TaskDirectory){throw 'CREATE_ALLOCATES_NEW_DIRECTORY'}
 $root=Join-Path $env:LOCALAPPDATA 'KidRemote\kr006-runtime'
 $id=[guid]::NewGuid().ToString()
 $TaskDirectory=Join-Path $root $id
 New-Item -ItemType Directory -Path $TaskDirectory | Out-Null
 $state=[ordered]@{Scope='KR006_RUNTIME';Id=$id;Directory=$TaskDirectory;AvdName=('kr006_'+$id.Replace('-',''));Port=5584;Sdk=$Sdk}
 $state | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $TaskDirectory 'owner.json') -Encoding UTF8
 New-Item -ItemType Directory -Path (Join-Path $TaskDirectory 'avds') | Out-Null
 $env:ANDROID_AVD_HOME=Join-Path $TaskDirectory 'avds'
 $env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
 Push-Location $TaskDirectory
 try {
  'no' | & "$Sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd -n $state.AvdName -k 'system-images;android-36;default;x86_64' -p (Join-Path $TaskDirectory 'avds\device.avd') -d pixel_2
  if($LASTEXITCODE -ne 0){throw 'TASK_AVD_CREATE_FAILED'}
 } finally {Pop-Location}
 Write-Output ('TASK_DIRECTORY='+$TaskDirectory)
 exit
}
if(-not $TaskDirectory){throw 'TASK_DIRECTORY_REQUIRED'}
$state=Get-Content -Raw -LiteralPath (Join-Path $TaskDirectory 'owner.json') | ConvertFrom-Json
if($state.Scope -ne 'KR006_RUNTIME' -or $state.Directory -cne $TaskDirectory -or $state.Sdk -cne $Sdk -or $state.AvdName -cne ('kr006_'+$state.Id.Replace('-','')) -or $state.Port -ne 5584){throw 'TASK_OWNERSHIP_UNVERIFIED'}
$env:ANDROID_AVD_HOME=Join-Path $TaskDirectory 'avds'
$serial='emulator-'+$state.Port
if($Mode -eq 'Start') {
 if(Get-NetTCPConnection -LocalPort 5584,5585 -ErrorAction SilentlyContinue){throw 'TASK_PORT_ALREADY_USED'}
 $p=Start-Process -FilePath "$Sdk\emulator\emulator.exe" -ArgumentList @('-avd',$state.AvdName,'-port','5584','-no-window','-no-snapshot','-no-boot-anim','-no-audio','-gpu','swiftshader','-no-metrics') -WorkingDirectory $TaskDirectory -RedirectStandardOutput (Join-Path $TaskDirectory 'emulator.stdout.log') -RedirectStandardError (Join-Path $TaskDirectory 'emulator.stderr.log') -PassThru
 Write-Output ('TASK_EMULATOR_PROCESS_STARTED='+$p.Id)
} else {
 $name=(& "$Sdk\platform-tools\adb.exe" -s $serial emu avd name 2>$null | Select-Object -First 1)
 if($null -ne $name){$name=$name.Trim()}
 if($LASTEXITCODE -ne 0 -or $name -cne $state.AvdName){throw 'TASK_EMULATOR_IDENTITY_UNVERIFIED'}
 & "$Sdk\platform-tools\adb.exe" -s $serial emu kill
 if($LASTEXITCODE -ne 0){throw 'TASK_EMULATOR_STOP_FAILED'}
 Write-Output 'TASK_STOP_REQUESTED_NO_AVD_DELETION'
}
