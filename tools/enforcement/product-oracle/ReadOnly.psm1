Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Child='dev.kidremote.child.unassigned.debug'
$script:Fixture='dev.kidremote.spike.ordinary'
function Invoke-InventoryAdb([string]$Adb,[string]$Serial,[string[]]$Arguments){
 $line=$Arguments -join ' '
 $pkg='dev\.kidremote\.(child\.unassigned\.debug|spike\.ordinary)'
 $allowed=($line -ceq 'devices') -or ($line -ceq 'shell am get-current-user') -or
  $line -match '^shell getprop ro\.(product\.(manufacturer|model)|build\.(id|version\.(release|sdk|security_patch)))$' -or
  $line -match ('^shell (pm path|dumpsys package|pm list packages -u) '+$pkg+'$') -or
  $line -match '^shell settings --user current get (secure (enabled_accessibility_services|accessibility_enabled)|global (low_power|app_standby_enabled))$' -or
  $line -match ('^shell cmd appops get '+$pkg+' GET_USAGE_STATS$') -or
  $line -match '^shell sha256sum /data/app/[A-Za-z0-9_./=+~-]+/base\.apk$'
 if($line -match '(^|/)\.\.?(/|$)'){$allowed=$false}
 if(-not $allowed){throw 'INVALID:READ_ONLY_COMMAND_REJECTED'}
 if($line -ne 'devices' -and $Serial -cnotmatch '^[A-Za-z0-9._:-]{1,80}$'){throw 'INVALID:TARGET_SELECTION'}
 $all=if($line -eq 'devices'){$Arguments}else{@('-s',$Serial)+$Arguments}
 $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$Adb;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.EnvironmentVariables.Remove('ADB_TRACE')
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 $p.StartInfo.Arguments=($all|ForEach-Object{'"'+$_+'"'}) -join ' '
 try{
  [void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
  if(-not $p.WaitForExit(10000)){$p.Kill();throw 'INVALID:ADB_TIMEOUT'}
  $raw=$o.GetAwaiter().GetResult();$err=$e.GetAwaiter().GetResult()
  if($line -eq 'devices'){$err=($err -split '\r?\n'|Where-Object{$_ -and $_ -notin @('* daemon not running; starting now at tcp:5037','* daemon started successfully')}) -join "`n"}
  if($p.ExitCode -ne 0 -or $err.Trim() -or $raw.Length -gt 262144){throw 'INVALID:ADB_READ_REJECTED'}
  return $raw
 }catch{throw 'INVALID:ADB_READ_FAILED'}finally{$p.Dispose()}
}
function Select-InventoryTarget([string]$Raw){
 $lines=@($Raw.Trim() -split '\r?\n'|Where-Object{$_ -and $_ -cne 'List of devices attached'})
 if($lines.Count -ne 1 -or $lines[0] -cnotmatch '^([A-Za-z0-9._:-]{1,80})\s+device$' -or $Matches[1] -like 'emulator-*'){throw 'INVALID:ONE_AUTHORIZED_TARGET_REQUIRED'}
 return $Matches[1] # Memory only; never written or echoed by the entrypoint.
}
function Get-InventoryPackage([string]$Package,[scriptblock]$Read){
 if($Package -cnotin @($script:Child,$script:Fixture)){throw 'INVALID:PACKAGE_SCOPE'}
 $paths=(& $Read @('shell','pm','path',$Package)).Trim()
 $retained=(& $Read @('shell','pm','list','packages','-u',$Package)).Trim()
 $r=[ordered]@{package=$Package;installed=$false;retainedState='POSSIBLE_PRESERVE';versionCode='UNSPECIFIED';versionName='UNSPECIFIED';stopped='UNSPECIFIED';basePath='UNSPECIFIED';sha256='UNSPECIFIED';signerSha256='UNSPECIFIED';signerSource='NOT_OBTAINABLE_WITH_BOUNDED_SHELL_READS';serviceRegistered=$false}
 if(-not $paths){if($retained -and $retained -cne ('package:'+$Package)){throw 'INVALID:PACKAGE_AMBIGUOUS'};if(-not $retained){$r.retainedState='NO_PACKAGE_RECORD_DATA_ABSENCE_NOT_PROVEN'};return [pscustomobject]$r}
 if($paths -cnotmatch '^package:(/data/app/[A-Za-z0-9_./=+~-]+/base\.apk)$'){throw 'INVALID:APK_PATH_AMBIGUOUS'}
 $r.basePath=$Matches[1];$r.installed=$true
 $dump=& $Read @('shell','dumpsys','package',$Package)
 foreach($pair in @(@('versionCode','(?m)^\s*versionCode=(\d+)\b'),@('versionName','(?m)^\s*versionName=([A-Za-z0-9._+-]{1,100})\s*$'),@('stopped','(?m)^\s*User 0:.*\bstopped=(true|false)\b'))){
  $m=[regex]::Matches($dump,$pair[1]);if($m.Count -ne 1){throw 'INVALID:PACKAGE_METADATA_AMBIGUOUS'};$r[$pair[0]]=$m[0].Groups[1].Value
 }
 $r.serviceRegistered=$dump.Contains('dev.kidremote.child.enforcement.ChildEnforcementService')
 try{$hash=(& $Read @('shell','sha256sum',$r.basePath)).Trim();if($hash -cnotmatch ('^([a-f0-9]{64})\s+'+[regex]::Escape($r.basePath)+'$')){throw 'unverified'};$r.sha256=$Matches[1]}catch{$r.sha256='UNSPECIFIED'}
 return [pscustomobject]$r
}
function Invoke-ReadOnlyInventory([scriptblock]$Read){
 if((& $Read @('shell','am','get-current-user')).Trim() -cne '0'){throw 'INVALID:ANDROID_USER_SCOPE'}
 $config=[ordered]@{};$expected=@{manufacturer='samsung';model='SM-X400';android='16';api='36';build='BP4A.251205.006';patch='2026-07-05';batterySaver='0';appStandby='1'}
 foreach($p in @(@('manufacturer','ro.product.manufacturer'),@('model','ro.product.model'),@('android','ro.build.version.release'),@('api','ro.build.version.sdk'),@('build','ro.build.id'),@('patch','ro.build.version.security_patch'))){
  $v=(& $Read @('shell','getprop',$p[1])).Trim();if($v -cnotmatch '^[A-Za-z0-9._+-]{1,100}$'){throw 'INVALID:CONFIGURATION_SCHEMA'};$config[$p[0]]=$v
 }
 $config.batterySaver=(& $Read @('shell','settings','--user','current','get','global','low_power')).Trim()
 $config.appStandby=(& $Read @('shell','settings','--user','current','get','global','app_standby_enabled')).Trim()
 if($config.batterySaver -notin @('0','1') -or $config.appStandby -notin @('0','1')){throw 'INVALID:CONFIGURATION_SCHEMA'}
 $result=[ordered]@{scope='READ_ONLY_INVENTORY_NOT_ENFORCEMENT';classification='CONFIGURATION_MISMATCH';configuration=$config;child=$null;fixture=$null;accessibility='UNSPECIFIED';usageAccess='UNSPECIFIED';installDecision='NO_AUTOMATIC_INSTALL_OR_UPDATE';physicalOracle='BLOCKED'}
 foreach($k in $expected.Keys){if($config[$k] -cne $expected[$k]){return [pscustomobject]$result}}
 $result.child=Get-InventoryPackage $script:Child $Read;$result.fixture=Get-InventoryPackage $script:Fixture $Read
 if($result.child.installed){
  $services=(& $Read @('shell','settings','--user','current','get','secure','enabled_accessibility_services')).Trim()
  $enabled=(& $Read @('shell','settings','--user','current','get','secure','accessibility_enabled')).Trim()
  $component=$script:Child+'/dev.kidremote.child.enforcement.ChildEnforcementService'
  $result.accessibility=if($enabled -eq '1' -and $component -cin @($services -split ':') -and $result.child.serviceRegistered){'ENABLED'}else{'NOT_VERIFIED_ENABLED'}
  $usage=& $Read @('shell','cmd','appops','get',$script:Child,'GET_USAGE_STATS')
  $modes=[regex]::Matches($usage,'GET_USAGE_STATS:\s*([a-z_]+)\b')
  $result.usageAccess=if($modes.Count -eq 1 -and $modes[0].Groups[1].Value -ceq 'allow'){'ENABLED'}else{'NOT_VERIFIED_ENABLED'}
 }
 if(($result.child.installed -and $result.child.sha256 -eq 'UNSPECIFIED') -or ($result.fixture.installed -and $result.fixture.sha256 -eq 'UNSPECIFIED')){$result.classification='PROVENANCE_UNVERIFIED'}
 elseif($result.child.installed){$result.classification=if($result.accessibility -ne 'ENABLED' -or $result.usageAccess -ne 'ENABLED'){'PERMISSION_SETUP_REQUIRED'}else{'PRODUCT_ALREADY_PRESENT_REVIEW_REQUIRED'}}
 elseif($result.child.retainedState -eq 'POSSIBLE_PRESERVE'){$result.classification='PRODUCT_ALREADY_PRESENT_REVIEW_REQUIRED'}
 else{$result.classification='READY_FOR_INSTALL_REVIEW'}
 return [pscustomobject]$result
}
Export-ModuleMember -Function Invoke-InventoryAdb,Select-InventoryTarget,Get-InventoryPackage,Invoke-ReadOnlyInventory
