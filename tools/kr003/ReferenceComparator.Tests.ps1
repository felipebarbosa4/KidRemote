param([string]$Ffmpeg='',[switch]$RequireCodec)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ReferenceVideo.psm1') -Force
Initialize-KRVideoCore
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
if(-not $Ffmpeg){$tool=Get-Command ffmpeg -ErrorAction SilentlyContinue;if($tool){$Ffmpeg=$tool.Source}}
if(-not $Ffmpeg){if($RequireCodec){throw 'CODEC_TEST_DEPENDENCY_REQUIRED'};Write-Host 'SKIP: comparator codec tests; FFmpeg unavailable.';exit 0}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('kr003-comparator-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary|Out-Null
function New-Surface([string]$Role){
    $bytes=New-Object 'byte[]' (128*128*3)
    for($y=0;$y -lt 128;$y++){for($x=0;$x -lt 128;$x++){
        $p=($y*128+$x)*3
        if($Role -eq 'ORDINARY'){$bytes[$p]=30;$bytes[$p+1]=60;$bytes[$p+2]=90;if($x -ge 32 -and $x -lt 96 -and $y -ge 48 -and $y -lt 80){$bytes[$p]=200;$bytes[$p+1]=160;$bytes[$p+2]=40}}
        elseif($Role -eq 'RESTRICTED'){$bytes[$p]=220;$bytes[$p+1]=225;$bytes[$p+2]=230;if($y -lt 32){$bytes[$p]=30;$bytes[$p+1]=90;$bytes[$p+2]=160}}
        else{$bytes[$p]=110;$bytes[$p+1]=170;$bytes[$p+2]=90}
    }}
    return ,$bytes
}
function Encode-Surface([string]$Name,[byte[]]$Pixels,[int]$Quality){
    $raw=Join-Path $temporary ($Name+'.rgb');[IO.File]::WriteAllBytes($raw,$Pixels)
    $png=Join-Path $temporary ($Name+'.png');$video=Join-Path $temporary ($Name+'.mp4')
    $null=Invoke-KRVideoTool $Ffmpeg @('-v','error','-f','rawvideo','-pixel_format','rgb24','-video_size','128x128','-i',$raw,'-frames:v','1',$png)
    $null=Invoke-KRVideoTool $Ffmpeg @('-v','error','-loop','1','-framerate','5','-i',$png,'-frames:v','6','-vf','scale=out_color_matrix=bt709:out_range=tv,format=yuv420p','-c:v','libx264','-crf',([string]$Quality),'-colorspace','bt709','-color_range','tv',$video)
    return $video
}
try{
    $o=New-Surface 'ORDINARY';$r=New-Surface 'RESTRICTED';$third=New-Surface 'THIRD'
    Assert-Equal ([KR003.ReferenceVideoCore]::HasSpatialVariation((New-Object 'byte[]' 49152))) $false
    Assert-Equal ([KR003.ReferenceVideoCore]::HasSpatialVariation($o)) $true
    $oPath=Encode-Surface 'reference-o' $o 18;$rPath=Encode-Surface 'reference-r' $r 18
    $oRef=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$oPath,128,128,$null,$null,16,0,$true,$false,'').ReferencePixels
    $rRef=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$rPath,128,128,$null,$null,16,0,$true,$false,'').ReferencePixels
    # Development encodes only: measure the envelope before held-out creation.
    $developmentMax=0.0
    foreach($quality in @(20,24,28)){foreach($role in @('o','r')){
        $pixels=if($role -eq 'o'){$o}else{$r};$reference=if($role -eq 'o'){$oRef}else{$rRef}
        $path=Encode-Surface ('development-'+$role+$quality) $pixels $quality
        $decoded=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$path,128,128,$oRef,$rRef,16,255,$false,$true,'')
        foreach($frame in $decoded.Frames){$distance=if($role -eq 'o'){$frame.OrdinaryDistance}else{$frame.RestrictedDistance};$developmentMax=[Math]::Max($developmentMax,$distance)}
    }}
    $measuredLimit=[Math]::Ceiling($developmentMax*1.15+0.25)
    # Pinned engineering rule must cover development, not be fitted to held-out.
    $profile=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'reference-comparator.json') -Raw|ConvertFrom-Json
    Assert-Equal ($measuredLimit -le $profile.MaximumTileMae) $true
    $limit=[double]$profile.MaximumTileMae
    foreach($role in @('o','r')){foreach($quality in @(21,27)){
        $pixels=if($role -eq 'o'){$o}else{$r};$expected=if($role -eq 'o'){'ORDINARY'}else{'RESTRICTED'}
        $path=Encode-Surface ('held-out-'+$role+$quality) $pixels $quality
        $cached=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$path,128,128,$oRef,$rRef,16,$limit,$false,$false,'')
        $uncached=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$path,128,128,$oRef,$rRef,16,$limit,$false,$true,'')
        Assert-Equal ($cached.Frames.Label -join ',') ($uncached.Frames.Label -join ',')
        Assert-Equal ($cached.Frames.Pts -join ',') ($uncached.Frames.Pts -join ',')
        Assert-Equal (@($cached.Frames|Where-Object{$_.Label -ne $expected}).Count) 0
        if($role -eq 'o'){Assert-Equal (Get-KRVideoLabelVerdict $cached.Frames[2].Label 'RESTRICTED') 'FAIL'}
    }}
    $partial=$r.Clone();$localized=$r.Clone();$ambiguous=New-Object 'byte[]' $r.Length
    for($p=0;$p -lt $r.Length;$p++){$ambiguous[$p]=[byte](($o[$p]+$r[$p])/2)}
    for($y=48;$y -lt 112;$y++){for($x=32;$x -lt 96;$x++){for($c=0;$c -lt 3;$c++){$partial[($y*128+$x)*3+$c]=$o[($y*128+$x)*3+$c]}}}
    for($y=55;$y -lt 63;$y++){for($x=55;$x -lt 63;$x++){for($c=0;$c -lt 3;$c++){$localized[($y*128+$x)*3+$c]=0}}}
    foreach($negative in @(@{Name='third';Pixels=$third},@{Name='partial';Pixels=$partial},@{Name='localized';Pixels=$localized},@{Name='ambiguous';Pixels=$ambiguous})){
        $path=Encode-Surface ('negative-'+$negative.Name) $negative.Pixels 25
        $decoded=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$path,128,128,$oRef,$rRef,16,$limit,$false,$false,'')
        Assert-Equal (@($decoded.Frames|Where-Object{$_.Label -ne 'UNKNOWN'}).Count) 0
    }
    Assert-Equal (Get-KRVideoLabelVerdict 'RESTRICTED' 'UNASSIGNED') 'INVALID'
    # A separate inter-frame encoded sequence includes a one-frame disappearance.
    $sequenceRoles=@('ORDINARY','ORDINARY','RESTRICTED','RESTRICTED','ORDINARY','RESTRICTED','RESTRICTED','ORDINARY','ORDINARY')
    $sequenceBytes=New-Object 'byte[]' ($o.Length*$sequenceRoles.Count)
    for($index=0;$index -lt $sequenceRoles.Count;$index++){
        $pixels=if($sequenceRoles[$index] -eq 'ORDINARY'){$o}else{$r}
        [Array]::Copy($pixels,0,$sequenceBytes,$index*$o.Length,$o.Length)
    }
    $sequenceRaw=Join-Path $temporary 'held-out-sequence.rgb';[IO.File]::WriteAllBytes($sequenceRaw,$sequenceBytes)
    $sequencePath=Join-Path $temporary 'held-out-sequence.mp4'
    $null=Invoke-KRVideoTool $Ffmpeg @('-v','error','-f','rawvideo','-pixel_format','rgb24','-video_size','128x128','-framerate','5','-i',$sequenceRaw,'-vf','scale=out_color_matrix=bt709:out_range=tv,format=yuv420p','-c:v','libx264','-crf','21','-colorspace','bt709','-color_range','tv','-output_ts_offset','2',$sequencePath)
    $sequence=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$sequencePath,128,128,$oRef,$rRef,16,$limit,$false,$false,'')
    Assert-Equal ($sequence.Frames.Label -join ',') ($sequenceRoles -join ',')
    Assert-Equal (Get-KRVideoLabelVerdict $sequence.Frames[4].Label 'RESTRICTED') 'FAIL'
    Assert-Equal $sequence.Frames.Count 9
    Assert-Equal ($sequence.Frames[0].Pts*$sequence.TimeBaseNumerator/$sequence.TimeBaseDenominator) 2
    $cancel=Join-Path $temporary 'cancel.stop';[IO.File]::WriteAllText($cancel,'SYNTHETIC')
    $rejected=$false
    try{$null=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$oPath,128,128,$oRef,$rRef,16,$limit,$false,$false,$cancel)}catch{$rejected=$true}
    Assert-Equal $rejected $true
    $truncated=Join-Path $temporary 'truncated.mp4';$encoded=[IO.File]::ReadAllBytes($oPath)
    [IO.File]::WriteAllBytes($truncated,[byte[]]$encoded[0..99])
    $rejected=$false
    try{$null=[KR003.ReferenceVideoCore]::Decode($Ffmpeg,$truncated,128,128,$oRef,$rRef,16,$limit,$false,$false,'')}catch{$rejected=$true}
    Assert-Equal $rejected $true
    Write-Host ('COMPARATOR_SYNTHETIC_ONLY '+([PSCustomObject]@{Assertions=$script:Checks;DevelopmentMaximumTileMae=$developmentMax;DevelopmentDerivedCeiling=$measuredLimit;PinnedTileMae=$limit;TilePixels=16;StridePixels=8;LocalizedNegativePixels='8x8';CheckpointReplacementAuthorized=$false}|ConvertTo-Json -Compress))
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
