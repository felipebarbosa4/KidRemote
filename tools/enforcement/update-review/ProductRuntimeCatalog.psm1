Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Known=[ordered]@{
 identity='no_backup/device-identity';pairing='no_backup/pairing-pending';accounting='no_backup/accounting.db';writeIntent='no_backup/accounting-write-intent';syncPages='no_backup/sync-page-progress';syncRetry='no_backup/sync-retry';consent='shared_prefs/enforcement-consent.xml'
}
function Get-ReviewStatePaths([bool]$ProductRuntime=$false) {
 $paths=[ordered]@{}
 foreach($k in $script:Known.Keys){$paths[$k]=$script:Known[$k];foreach($suffix in @('bak','new')){$paths[$k+'_'+$suffix]=$script:Known[$k]+'.'+$suffix}}
 foreach($suffix in @('wal','shm','journal')){$paths['accounting_'+$suffix]='no_backup/accounting.db-'+$suffix}
 if($ProductRuntime){
  # Exact dependency constants verified in approved lab DEX and local AndroidX bytecode.
  # This opt-in does not reclassify either immutable historical physical attempt.
  $paths['runtime_profile']='files/profileInstalled'
  $paths['runtime_profileWritten']='files/profileinstaller_profileWrittenFor_lastUpdateTime.dat'
  $paths['runtime_workPrefs']='shared_prefs/androidx.work.util.preferences.xml'
  foreach($location in @('no_backup','databases')){
   $key='runtime_work_'+$location;$base=$location+'/androidx.work.workdb';$paths[$key]=$base
   foreach($suffix in @('wal','shm','journal')){$paths[$key+'_'+$suffix]=$base+'-'+$suffix}
  }
 }
 return $paths
}
Export-ModuleMember -Function Get-ReviewStatePaths
