Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1') -Force

function Assert-ReplacementRecord($r,[bool]$Old){
 $hash=if($Old){'3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9'}else{'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'}
 $signer=if($Old){'771bc0fa9b91aecba8fd2d0e7d1e3af27237840198327731e098bb83dcbc97d7'}else{'638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb'}
 $version=if($Old){1}else{2};$name=if($Old){'0.0.1-local'}else{'0.0.2-local-physical-lab'}
 if($r.package -cne 'dev.kidremote.child.unassigned.debug' -or $r.sha256 -cne $hash -or $r.signer -cne $signer -or $r.version -ne $version -or $r.versionName -cne $name -or $r.serviceRegistered -isnot [bool] -or $r.serviceRegistered -ne (-not $Old)){throw 'INVALID:REPLACEMENT_PROVENANCE'}
}
function Invoke-ReplacementPreparation([string]$Directory,[hashtable]$Ops){
 # This function admits only preparation. PASS belongs exclusively to Invoke-ProductSlice.
 # An existing/partial journal is review-only; never resume an unknown uninstall.
 $state=Read-ProductJournal $Directory
 if($state.partial -or $state.rows.Count){throw 'INVALID:EXISTING_ATTEMPT_REVIEW_REQUIRED'}
 $meta=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))|ConvertFrom-Json
 if(-not ($meta.PSObject.Properties.Name -contains 'replacement') -or $meta.replacement.decision -cne 'OD-50'){throw 'INVALID:DESTRUCTIVE_AUTHORIZATION_MISSING'}
 $stage='BEGIN';$changed=$false
 try{
  $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) BEGIN STARTED
  & $Ops.HostReady # verifies approved local APK/signature/tools/backend before uninstall
  & $Ops.Configuration
  if((& $Ops.FixtureHash) -cne '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'){throw 'INVALID:FIXTURE_PROVENANCE'}
  Assert-ReplacementRecord (& $Ops.Installed) $true
  $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) PREMUTATION EXACT_OLD_AND_FIXTURE_VERIFIED
  foreach($pair in @(@('UNINSTALL_ADMITTED','Uninstall'),@('INSTALL_ADMITTED','Install'),@('REVERSE_ADMITTED','Reverse'),@('ENROLLMENT_ADMITTED','Enroll'),@('SETUP_ADMITTED','Consent'),@('POLICY_ADMITTED','Configure'))){
   $stage=$pair[0]
   $event=[Guid]::NewGuid().ToString()
   $null=Add-ProductJournal $Directory $event $stage OD50_FIXED_SCOPE
   if($stage -ceq 'UNINSTALL_ADMITTED'){$changed=$true}
   & $Ops[$pair[1]] $event
   if($stage -ceq 'UNINSTALL_ADMITTED' -and -not (& $Ops.Absent)){throw 'INVALID:UNINSTALL_ABSENCE_UNVERIFIED'}
   if($stage -ceq 'INSTALL_ADMITTED'){Assert-ReplacementRecord (& $Ops.Installed) $false}
  }
  return [pscustomobject]@{status='PREPARED_NOT_PASS';lastStage=$stage;replacementAdmitted=$changed;attempt=$meta.attempt}
 }catch{
  $reason=[string]$_.Exception.Message;if($reason -cnotmatch '^INVALID:[A-Z0-9_]+$'){$reason='INVALID:PREPARATION_TRANSPORT_OR_SCHEMA'}
  $null=Add-ProductJournal $Directory $meta.attempt VERDICT INVALID
  # Callback must do only bounded recovery; no restoration of the obsolete APK.
  $cleanup='UNVERIFIED'
  try{
   $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) CLEANUP_ADMITTED OD50_FIXED_SCOPE
   & $Ops.Recovery $stage $changed
   if(-not $changed){$cleanup='NOT_REQUIRED'}
  }catch{}
  $null=Add-ProductJournal $Directory ([Guid]::NewGuid().ToString()) CLEANUP $cleanup
  return [pscustomobject]@{status='INVALID';reason=$reason;lastStage=$stage;replacementAdmitted=$changed;cleanup=$cleanup;attempt=$meta.attempt}
 }
}
Export-ModuleMember -Function Assert-ReplacementRecord,Invoke-ReplacementPreparation
