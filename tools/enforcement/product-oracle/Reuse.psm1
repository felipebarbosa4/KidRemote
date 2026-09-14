Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Replacement.psm1') -Force
function Invoke-ReusePreparation([string]$Directory,[hashtable]$Ops){
 $j=Read-ProductJournal $Directory;if($j.rows.Count -or $j.partial){throw 'INVALID:EXISTING_ATTEMPT_REVIEW_REQUIRED'}
 $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) BEGIN STARTED
 & $Ops.HostReady;& $Ops.Configuration
 if((& $Ops.FixtureHash) -cne '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'){throw 'INVALID:FIXTURE_PROVENANCE'}
 Assert-ReplacementRecord (& $Ops.Installed) $false
 & $Ops.ReuseIdentityPermissions
 $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) REUSE_VERIFIED EXACT_LEASE_DEVICE_PERMISSIONS
 foreach($pair in @(@('REVERSE_ADMITTED','Reverse'),@('RESUME_ADMITTED','Resume'),@('POLICY_ADMITTED','Normalize'))){
  $id=[Guid]::NewGuid().ToString();$null=Add-ProductJournal $Directory $id $pair[0] OD51_FIXED_SCOPE;& $Ops[$pair[1]] $id
 }
 return [pscustomobject]@{status='PREPARED_NOT_PASS';reuse=$true;ownerSetupActions=0}
}
# The gate is separately injectable. No preparation callback is invoked on host failure.
function Invoke-ProductHostGate([hashtable]$Ops){
 try{foreach($stage in @('Bundle','Tools','Lease','LiveHealth','Ports','Artifacts','Journal','ReadOnlyTarget')){& $Ops[$stage]}}
 catch{throw 'INVALID:INVALID_HOST_PREFLIGHT'}
}
Export-ModuleMember -Function Invoke-ReusePreparation,Invoke-ProductHostGate
