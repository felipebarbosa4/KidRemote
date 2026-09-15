Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../update-review/Review.psm1')
function Get-ReplacementCommand([string]$Action,[string]$Apk){
 switch -Exact ($Action){
  'Uninstall' {return @('uninstall','dev.kidremote.child.unassigned.debug')}
  'Install' {
   if(-not [IO.Path]::IsPathRooted($Apk) -or $Apk -match '["\r\n]' -or -not $Apk.EndsWith('.apk')){throw 'INVALID:LAB_APK_PATH'}
   if((Get-FileHash -LiteralPath $Apk).Hash.ToLowerInvariant() -cne 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'){throw 'INVALID:LAB_APK_HASH'}
   return @('install','-t',$Apk)
  }
  'ReverseRead' {return @('reverse','--list')}
  'Reverse' {return @('reverse','--no-rebind','tcp:47366','tcp:47366')}
  'RemoveReverse' {return @('reverse','--remove','tcp:47366')}
  'OpenUsage' {return @('shell','am','start','-W','-a','android.settings.USAGE_ACCESS_SETTINGS','-d','package:dev.kidremote.child.unassigned.debug')}
  'OpenAccessibility' {return @('shell','am','start','-W','-a','android.settings.ACCESSIBILITY_SETTINGS')}
  'OpenChild' {return @('shell','am','start','-W','-n','dev.kidremote.child.unassigned.debug/dev.kidremote.child.ChildActivity')}
  default {throw 'INVALID:REPLACEMENT_COMMAND_REJECTED'}
 }
}
function Assert-LabReverse([string]$Raw,[bool]$Present){
 $rows=@($Raw -split '\r?\n'|Where-Object{$_})
 if($rows.Count -gt 32){throw 'INVALID:REVERSE_AMBIGUOUS'}
 $matches=@($rows|Where-Object{$_ -match '(^|\s)tcp:47366(\s|$)'})
 if($Present){if($matches.Count -ne 1 -or $matches[0] -cnotmatch '^\S+\s+tcp:47366\s+tcp:47366\s*$'){throw 'INVALID:REVERSE_UNVERIFIED'}}
 elseif($matches.Count){throw 'INVALID:REVERSE_ALREADY_OWNED'}
}
function Invoke-ReplacementAdb([string]$Adb,[string]$Serial,[string]$Action,[string]$Apk,[scriptblock]$Run){
 if($Serial -cnotmatch '^[A-Za-z0-9._:-]{1,80}$'){throw 'INVALID:TARGET_SERIAL'}
 $arguments=Get-ReplacementCommand $Action $Apk
 $r=& $Run $Adb (@('-s',$Serial)+$arguments) ''
 if($r.stderr.Trim()){throw 'INVALID:ADB_REJECTED'}
 if($Action -in @('Uninstall','Install') -and $r.stdout.Trim() -cnotmatch '^(Performing Streamed Install\r?\n)?Success$'){throw 'INVALID:REPLACEMENT_FAILED'}
 if($Action -like 'Open*' -and ($r.stdout -match 'Error:|Exception|Permission Denial' -or $r.stdout -notmatch '(?m)^Status: ok\r?$')){throw 'INVALID:ACTIVITY_LAUNCH_REJECTED'}
 return $r.stdout
}
Export-ModuleMember -Function Get-ReplacementCommand,Assert-LabReverse,Invoke-ReplacementAdb
