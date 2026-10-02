Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:OverlayName='SAMSUNG_SM_X400_ANDROID_16_API_36_BP4A_251205_006_PATCH_2026_07_05'
$script:Expected=[ordered]@{
 manufacturer='samsung';model='SM-X400';android='16';api='36';build='BP4A.251205.006';patch='2026-07-05'
}
function Get-OemConfigurationValue($Configuration,[string]$Name){
 if($null -eq $Configuration){return $null}
 if($Configuration -is [Collections.IDictionary]){if(-not $Configuration.Contains($Name)){return $null};return [string]$Configuration[$Name]}
 $property=$Configuration.PSObject.Properties[$Name]
 if($null -eq $property){return $null}
 return [string]$property.Value
}
function Get-ProductRuntimeOemOverlayName($Configuration){
 foreach($name in $script:Expected.Keys){if((Get-OemConfigurationValue $Configuration $name) -cne $script:Expected[$name]){return 'NONE'}}
 return $script:OverlayName
}
function Get-ProductRuntimeOemOverlayPaths($Configuration){
 $paths=[ordered]@{}
 if((Get-ProductRuntimeOemOverlayName $Configuration) -ceq $script:OverlayName){
  # Structural classification only. The fixed metadata program reads size/existence,
  # never this SharedPreferences file's contents.
  $paths['runtime_samsung_ids']='shared_prefs/android.app.ActivityThread.IDS.xml'
 }
 return $paths
}
Export-ModuleMember -Function Get-ProductRuntimeOemOverlayName,Get-ProductRuntimeOemOverlayPaths
