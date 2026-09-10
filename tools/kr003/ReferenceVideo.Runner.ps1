# Dot-sourced by the single reference/video entrypoint after shared runner helpers.
function Assert-RVLocalPath([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    if($full -notmatch '^C:\\platform-tools\\kr003-reference-video(?:\\|$)'){throw 'INVALID:VIDEO_LOCAL_PATH'}
    $cursor=$full
    while($cursor){
        if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'INVALID:VIDEO_REPARSE_PATH'}
        $cursor=Split-Path -Parent $cursor
    }
    return $full
}
function Save-RVRecorders { Write-JsonFile 'recorders.json' @($script:RVRecorders) }
function Start-RVRecording([string]$Name,[int]$Seconds) {
    if($Name -notin @('ordinary-reference','restricted-reference','held-out') -or $Seconds -notin @(6,120)){throw 'INVALID:RECORDER_ARGUMENT'}
    $remote='/data/local/tmp/kr003-'+$runId+'-'+$Name+'.mp4'
    $command='screenrecord --time-limit '+$Seconds+' --bit-rate 20000000 '+$remote
    $record=[PSCustomObject]@{Name=$Name;DevicePath=$remote;ExpectedCommand=$command;RecorderPid=$null;
        HostProcessId=$null;HostProcessStartedTicks=$null;StartTicks=[Diagnostics.Stopwatch]::GetTimestamp();EndTicks=$null;
        LimitSeconds=$Seconds;Termination='UNVERIFIED';CopyStatus='NOT_ATTEMPTED';LocalFile=$Name+'.mp4';DeviceFileCleanup='OWNER_EXPLICIT_REMOVAL_AFTER_REVIEW';VideoSha256=$null}
    $script:RVRecorders+=$record;Save-RVRecorders
    $process=New-Object Diagnostics.Process;$process.StartInfo=New-Object Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName=$Adb;$process.StartInfo.UseShellExecute=$false;$process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true
    # Shell PID becomes screenrecord PID via exec; never discover/kill by package name.
    $shell='echo KR003_RECORDER_PID:$$; exec '+$command
    $process.StartInfo.Arguments='shell sh -c "'''+$shell+'''"'
    [void]$process.Start();$script:RVProcesses[$Name]=$process
    $record.HostProcessId=$process.Id;$record.HostProcessStartedTicks=$process.StartTime.ToUniversalTime().Ticks;Save-RVRecorders
    $script:RVStderr[$Name]=$process.StandardError.ReadToEndAsync()
    $line=$process.StandardOutput.ReadLineAsync()
    if(-not $line.Wait(5000) -or $line.Result -notmatch '^KR003_RECORDER_PID:([0-9]{1,9})$'){throw 'INVALID:RECORDER_PID_UNVERIFIED'}
    $record.RecorderPid=[int]$Matches[1];if($record.RecorderPid -le 1){throw 'INVALID:RECORDER_PID_UNVERIFIED'}
    Save-RVRecorders
    return $record
}
function Get-RVOwnedRecorderState($Record) {
    if($null -eq $Record.RecorderPid -or $Record.RecorderPid -le 1 -or
        $Record.DevicePath -cne ('/data/local/tmp/kr003-'+$runId+'-'+$Record.Name+'.mp4') -or
        $Record.ExpectedCommand -cne ('screenrecord --time-limit '+$Record.LimitSeconds+' --bit-rate 20000000 '+$Record.DevicePath)) {throw 'INVALID:RECORDER_OWNERSHIP'}
    $probe='if [ -e /proc/'+$Record.RecorderPid+' ]; then cat /proc/'+$Record.RecorderPid+'/cmdline; else echo KR003_ABSENT; fi'
    $response=Invoke-LabAdbResult @('shell','sh','-c',("'"+$probe+"'"))
    if($response.ExitCode -ne 0 -or $response.StderrClass -ne 'NONE'){throw 'INVALID:RECORDER_STATE_UNVERIFIED'}
    if($response.Stdout.Trim() -ceq 'KR003_ABSENT'){return 'ABSENT'}
    $actual=$response.Stdout.Replace([string][char]0,' ').Trim()
    if($actual -cne $Record.ExpectedCommand){throw 'INVALID:RECORDER_OWNERSHIP'}
    return 'OWNED_RUNNING'
}
function Stop-RVRecording($Record) {
    if($Record.Termination -ne 'VERIFIED'){
        $state=Get-RVOwnedRecorderState $Record
        if($state -eq 'OWNED_RUNNING'){
            $response=Invoke-LabAdbResult @('shell','kill','-2',([string]$Record.RecorderPid))
            if($response.ExitCode -ne 0 -or $response.StderrClass -ne 'NONE'){throw 'INVALID:RECORDER_STOP_REJECTED'}
        }
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while((Get-RVOwnedRecorderState $Record) -ne 'ABSENT'){
            if($watch.Elapsed.TotalSeconds -ge 15){throw 'INVALID:RECORDER_STOP_UNVERIFIED'}
            Start-Sleep -Milliseconds 100
        }
        $Record.EndTicks=[Diagnostics.Stopwatch]::GetTimestamp();$Record.Termination='VERIFIED';Save-RVRecorders
    }
    if($script:RVProcesses.ContainsKey($Record.Name)){
        $process=$script:RVProcesses[$Record.Name]
        if(-not $process.WaitForExit(5000)){throw 'INVALID:RECORDER_HOST_EXIT_UNVERIFIED'}
        if($process.ExitCode -ne 0){throw 'INVALID:RECORDER_EXIT_REJECTED'}
    }
    if($Record.CopyStatus -ne 'VERIFIED'){
        $local=Join-Path $script:RVMedia $Record.LocalFile
        if(Test-Path -LiteralPath $local){throw 'INVALID:VIDEO_COPY_EXISTS_PRESERVE_PARTIAL'}
        $response=Invoke-LabAdbResult @('pull',$Record.DevicePath,$local)
        if($response.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $local)){throw 'INVALID:VIDEO_COPY_FAILED'}
        $deviceHash=(Invoke-LabAdb @('shell','sha256sum',$Record.DevicePath)).Trim()
        if($deviceHash -notmatch '^([a-f0-9]{64})\s'){throw 'INVALID:VIDEO_DEVICE_HASH'}
        $expected=$Matches[1];$actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $local).Hash.ToLowerInvariant()
        if($actual -cne $expected){throw 'INVALID:VIDEO_COPY_HASH'}
        $Record.VideoSha256=$actual;$Record.CopyStatus='VERIFIED';Save-RVRecorders
    }
}
function Wait-RVRecording($Record) {
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do{
        Check-EarlyStop;Assert-RVHealth
        if($script:RVProcesses[$Record.Name].HasExited){Stop-RVRecording $Record;return}
        Start-Sleep -Milliseconds 100
    }while($watch.Elapsed.TotalSeconds -lt $Record.LimitSeconds+10)
    throw 'INVALID:RECORDER_TIMEOUT'
}
function Assert-RVHealth {
    $snapshot=Get-LabState;Assert-KRHealth $snapshot;Assert-QualificationPermissionState $snapshot;Assert-StayAwake
    if($null -ne $script:VisualRestriction){Assert-KRHold $snapshot ([long]$script:VisualRestriction.Revision) ([long]$script:VisualRestriction.FixtureTapBaseline) (Get-FixtureState)}
}
function Save-RVReference([string]$Role,$Record) {
    $path=Join-Path $script:RVMedia $Record.LocalFile;$probe=Get-KRVideoProbe $script:RVFfprobe $path
    if($null -eq $script:RVProbe){$script:RVProbe=$probe}else{
        if(($probe|ConvertTo-Json -Compress) -cne ($script:RVProbe|ConvertTo-Json -Compress)){throw 'INVALID:REFERENCE_CAPTURE_CONFIGURATION_CHANGED'}
    }
    $decoded=[KR003.ReferenceVideoCore]::Decode($script:RVFfmpeg,$path,$probe.Width,$probe.Height,$null,$null,16,2,$true,$false,(Join-Path $runDirectory 'cancel.stop'))
    if(-not [KR003.ReferenceVideoCore]::HasSpatialVariation($decoded.ReferencePixels)){throw 'INVALID:BLANK_REFERENCE'}
    $raw=Join-Path $script:RVMedia ($Role+'.rgb');$png=Join-Path $script:RVMedia ($Role+'.png')
    [IO.File]::WriteAllBytes($raw,$decoded.ReferencePixels)
    $null=Invoke-KRVideoTool $script:RVFfmpeg @('-v','error','-f','rawvideo','-pixel_format','rgb24','-video_size',("$($probe.Width)x$($probe.Height)"),'-i',$raw,'-frames:v','1',$png)
    $sha=(Get-FileHash -Algorithm SHA256 -LiteralPath $raw).Hash.ToLowerInvariant()
    $imageHash=(Get-FileHash -Algorithm SHA256 -LiteralPath $png).Hash.ToLowerInvariant()
    $ref=[PSCustomObject]@{Role=$Role;File=$Role+'.rgb';ViewFile=$Role+'.png';Sha256=$sha;ViewSha256=$imageHash;
        VideoSha256=$Record.VideoSha256;CapturedTicks=$Record.EndTicks;ConfirmedTicks=$null;OwnerConfirmation='UNVERIFIED';
        CaptureConfiguration='NORMALIZED_VIDEO_RGB24';FirstPts=$decoded.Frames[0].Pts}
    $script:RVEnrollment.References+= $ref;Write-JsonFile 'references.json' $script:RVEnrollment
    Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
    $form=New-Object Windows.Forms.Form;$form.Text='KidRemote local reference: '+$Role
    $form.Width=900;$form.Height=700;$form.TopMost=$true
    $picture=New-Object Windows.Forms.PictureBox;$picture.Dock='Fill';$picture.SizeMode='Zoom';$picture.Image=[Drawing.Image]::FromFile($png)
    $form.Controls.Add($picture)
    try{
        $form.Show();[Windows.Forms.Application]::DoEvents()
        $confirmationWatch=[Diagnostics.Stopwatch]::StartNew()
        $result=Read-Result -Prompt ('LOCAL REFERENCE '+$Role+': compare this full image with the actual tablet. P only if it matches the '+$Role+' surface actually displayed; otherwise I or Q. Do not interact with the tablet.') -Poll {
            [Windows.Forms.Application]::DoEvents();if(-not $form.Visible){throw 'INVALID:REFERENCE_VIEWER_CLOSED'}
            if($confirmationWatch.Elapsed.TotalSeconds -gt 120){throw 'INVALID:REFERENCE_CONFIRMATION_TIMEOUT'};Assert-RVHealth
        }
        if($result -ne 'PASS'){throw 'INVALID:REFERENCE_OWNER_REJECTED'}
        $ref.OwnerConfirmation='MATCHES_DISPLAYED_SURFACE';$ref.ConfirmedTicks=[Diagnostics.Stopwatch]::GetTimestamp()
    }finally{$picture.Image.Dispose();$form.Close();$form.Dispose();Write-JsonFile 'references.json' $script:RVEnrollment}
}
function Assert-RVReferenceFiles {
    if(@($script:RVEnrollment.References).Count -ne 2 -or
        @($script:RVEnrollment.References|Where-Object{$_.Role -ceq 'ORDINARY'}).Count -ne 1 -or
        @($script:RVEnrollment.References|Where-Object{$_.Role -ceq 'RESTRICTED'}).Count -ne 1 -or
        $null -eq $script:RVEnrollment.FrozenTicks -or
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $runDirectory 'references.json')).Hash -cne $script:RVFrozenHash){throw 'INVALID:REFERENCE_FREEZE_INTEGRITY'}
    foreach($ref in $script:RVEnrollment.References){
        if($ref.OwnerConfirmation -cne 'MATCHES_DISPLAYED_SURFACE' -or $ref.ConfirmedTicks -gt $script:RVEnrollment.FrozenTicks){throw 'INVALID:REFERENCE_CONFIRMATION'}
        foreach($pair in @(@{File=$ref.File;Hash=$ref.Sha256},@{File=$ref.ViewFile;Hash=$ref.ViewSha256})){
            if($pair.File -notmatch '^(ORDINARY|RESTRICTED)\.(rgb|png)$' -or
                (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $script:RVMedia $pair.File)).Hash.ToLowerInvariant() -cne $pair.Hash){throw 'INVALID:REFERENCE_INTEGRITY'}
        }
    }
}
function Invoke-RVAnalysis {
    Assert-RVReferenceFiles
    if((Get-FileHash -Algorithm SHA256 $script:RVFfmpeg).Hash -cne $script:RVEnrollment.DecoderSha256 -or
        (Get-FileHash -Algorithm SHA256 $script:RVFfprobe).Hash -cne $script:RVEnrollment.ProbeToolSha256 -or
        (Get-FileHash -Algorithm SHA256 (Join-Path $PSScriptRoot 'reference-comparator.json')).Hash -cne $script:RVEnrollment.ProfileSha256){throw 'INVALID:CLASSIFIER_CONFIGURATION_CHANGED'}
    $record=@($script:RVRecorders|Where-Object{$_.Name -eq 'held-out'})[0]
    if($record.StartTicks -le $script:RVEnrollment.FrozenTicks){throw 'INVALID:REFERENCE_FREEZE_BOUNDARY'}
    $path=Join-Path $script:RVMedia $record.LocalFile;$probe=Get-KRVideoProbe $script:RVFfprobe $path
    if((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() -cne $record.VideoSha256){throw 'INVALID:VIDEO_INTEGRITY'}
    if(($probe|ConvertTo-Json -Compress) -cne ($script:RVProbe|ConvertTo-Json -Compress)){throw 'INVALID:HELD_OUT_CONFIGURATION_CHANGED'}
    $o=[IO.File]::ReadAllBytes((Join-Path $script:RVMedia 'ORDINARY.rgb'));$r=[IO.File]::ReadAllBytes((Join-Path $script:RVMedia 'RESTRICTED.rgb'))
    $profile=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'reference-comparator.json') -Raw|ConvertFrom-Json
    if([KR003.ReferenceVideoCore]::Distance($o,$r,$probe.Width,$probe.Height,$profile.TilePixels) -le 2*$profile.MaximumTileMae){throw 'INVALID:REFERENCE_SEPARATION'}
    $decoded=[KR003.ReferenceVideoCore]::Decode($script:RVFfmpeg,$path,$probe.Width,$probe.Height,$o,$r,$profile.TilePixels,$profile.MaximumTileMae,$false,$false,(Join-Path $runDirectory 'cancel.stop'))
    $rows=@();$transitions=@();$lastLabel=$null
    foreach($frame in $decoded.Frames){
        $context=Get-KRVideoFramePhase $frame.Pts $decoded.TimeBaseNumerator $decoded.TimeBaseDenominator $record @($script:VisualPhases)
        $rows+=[PSCustomObject]@{Index=$frame.Index;Pts=$frame.Pts;Hash=$frame.Hash;Label=$frame.Label;CacheHit=$frame.CacheHit;
            OrdinaryDistance=$frame.OrdinaryDistance;RestrictedDistance=$frame.RestrictedDistance;Phase=$context.Phase;Verdict=(Get-KRVideoLabelVerdict $frame.Label $context.Phase)}
        if($frame.Label -cne $lastLabel){$transitions+=[PSCustomObject]@{Index=$frame.Index;Pts=$frame.Pts;From=$lastLabel;To=$frame.Label};$lastLabel=$frame.Label}
    }
    $timing=Get-KRVideoTimestampCharacterization $decoded.Frames $decoded.TimeBaseNumerator $decoded.TimeBaseDenominator
    $analysis=[PSCustomObject]@{Status='CHARACTERIZED';PhaseSpecificVisualVerdict='INVALID_ALIGNMENT_UNVERIFIED';
        UnknownFrames=@($rows|Where-Object{$_.Label -eq 'UNKNOWN'}).Count;FramesProcessed=$rows.Count;
        RecognitionCalls=$decoded.RecognitionCalls;CacheHits=$decoded.CacheHits;DecodePasses=1;AnalysisTotalMillis=$decoded.TotalMillis;
        DistinctPixelHashes=@($rows.Hash|Select-Object -Unique).Count;Probe=$probe;Timing=$timing;ObservedLabelTransitions=$transitions;
        CaptureOuterStartTicks=$record.StartTicks;CaptureOuterEndTicks=$record.EndTicks;HostTickFrequency=[Diagnostics.Stopwatch]::Frequency;
        Rows=$rows;CheckpointReplacementAuthorized=$false;QualificationRows=0;Time04Rows=0;MatrixContribution='NONE'}
    Write-JsonFile 'video-analysis.json' $analysis
    if($analysis.UnknownFrames -gt 0){throw 'INVALID:UNKNOWN_VISUAL_SURFACE'}
    if(($transitions.To -join ',') -cne 'ORDINARY,RESTRICTED,ORDINARY'){throw 'INVALID:VISUAL_TRANSITIONS_UNVERIFIED'}
}
