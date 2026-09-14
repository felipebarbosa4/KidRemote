Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Known=[ordered]@{
 identity='no_backup/device-identity';pairing='no_backup/pairing-pending';accounting='no_backup/accounting.db';writeIntent='no_backup/accounting-write-intent';syncPages='no_backup/sync-page-progress';syncRetry='no_backup/sync-retry';consent='shared_prefs/enforcement-consent.xml'
}
function Get-ReviewStatePaths {
 $paths=[ordered]@{}
 foreach($k in $script:Known.Keys){$paths[$k]=$script:Known[$k];foreach($suffix in @('bak','new')){$paths[$k+'_'+$suffix]=$script:Known[$k]+'.'+$suffix}}
 foreach($suffix in @('wal','shm','journal')){$paths['accounting_'+$suffix]='no_backup/accounting.db-'+$suffix}
 return $paths
}
function Get-ReviewStateScript {
 # Fixed metadata-only program. No cat/sqlite/content reads, app calls, writes or caller-supplied paths.
 $lines=@('set -eu')
 foreach($p in (Get-ReviewStatePaths).GetEnumerator()){
  $lines+="if [ -L $($p.Value) ]; then printf '$($p.Key)|UNKNOWN|0\n'; elif [ -f $($p.Value) ]; then printf '$($p.Key)|PRESENT|'; stat -c '%s' $($p.Value); elif [ -e $($p.Value) ]; then printf '$($p.Key)|UNKNOWN|0\n'; else printf '$($p.Key)|ABSENT|0\n'; fi"
 }
 # Count only; unknown filenames stay on the device. Refuse symlinks and unreadable directories.
 $lines+='total=0; for d in no_backup files databases shared_prefs; do if [ -L "$d" ]; then exit 3; fi; if [ -d "$d" ]; then test -r "$d"; test -x "$d"; links=$(find "$d" -type l); if [ -n "$links" ]; then exit 3; fi; entries=$(find "$d" -type f); if [ -n "$entries" ]; then n=$(printf "%s\n" "$entries" | wc -l); total=$((total+n)); fi; elif [ -e "$d" ]; then exit 3; fi; done; printf "LINKS|0\nTOTAL|%s\n" "$total"'
 return ($lines -join "`n")+"`n"
}
function Convert-ReviewState([string]$Raw){
 if($Raw.Length -gt 16384){throw 'PRIVATE_STATE_REVIEW_REQUIRED'}
 $paths=Get-ReviewStatePaths;$seen=@{};$present=0;$rows=@();$total=$null;$links=$null
 foreach($line in @($Raw.Trim() -split '\r?\n')){
  if($line -cmatch '^(TOTAL|LINKS)\|\s*([0-9]{1,8})$'){
   if($seen.ContainsKey($Matches[1])){throw 'PRIVATE_STATE_REVIEW_REQUIRED'};$seen[$Matches[1]]=$true
   if($Matches[1] -eq 'TOTAL'){$total=[long]$Matches[2]}else{$links=[long]$Matches[2]};continue
  }
  if($line -cnotmatch '^([A-Za-z_]+)\|(PRESENT|ABSENT|UNKNOWN)\|([0-9]{1,12})$'){throw 'PRIVATE_STATE_REVIEW_REQUIRED'}
  $key=$Matches[1];$state=$Matches[2];$size=[long]$Matches[3]
  if(-not $paths.Contains($key) -or $seen.ContainsKey($key) -or ($state -ne 'PRESENT' -and $size -ne 0)){throw 'PRIVATE_STATE_REVIEW_REQUIRED'}
  $seen[$key]=$true;if($state -eq 'PRESENT'){$present++};$rows+=,[pscustomobject]@{kind=$key;presence=$state;bytes=$size}
 }
 if($seen.Count -ne $paths.Count+2 -or $null -eq $total -or $null -eq $links -or $total -lt $present -or $links -ne 0 -or @($rows|Where-Object{$_.presence -eq 'UNKNOWN'}).Count){throw 'PRIVATE_STATE_REVIEW_REQUIRED'}
 return [pscustomobject]@{status='METADATA_ONLY';files=$rows;otherDurableFiles=($total-$present);totalDurableFiles=$total;identityMeaning='BLOB_EXISTENCE_ONLY_NOT_DECRYPTED';removalMeaning='INSIDE_ENCRYPTED_IDENTITY_NOT_READ';ackMeaning='INSIDE_ACCOUNTING_DB_NOT_READ';sufficientForEmptyStateReview=($total -eq 0)}
}
function Convert-ReviewSigner([string]$Raw){
 if($Raw -notmatch '(?m)^Verifies\r?$' -or [regex]::Matches($Raw,'(?m)^Number of signers: 1\r?$').Count -ne 1){throw 'READ_ONLY_REVIEW_INVALID'}
 $matches=[regex]::Matches($Raw,'(?m)^(?:V[0-9]+ )?Signer #?1(?: |:)certificate SHA-256 digest: ([a-f0-9]{64})\s*$')
 # SDK output differs between versions: accept only one digest, never DN/hashCode/SHA1.
 if($matches.Count -eq 0){$matches=[regex]::Matches($Raw,'(?m)^V[0-9]+ Signer: certificate SHA-256 digest: ([a-f0-9]{64})\s*$')}
 $all=[regex]::Matches($Raw,'certificate SHA-256 digest: ([a-fA-F0-9]{64})')
 if($matches.Count -ne 1 -or $all.Count -ne 1){throw 'READ_ONLY_REVIEW_INVALID'}
 return $matches[0].Groups[1].Value
}
function Invoke-ReviewProcess([string]$Executable,[string[]]$Arguments,[string]$InputText=''){
 foreach($a in $Arguments){if($a -match '["\r\n]' -or $a.EndsWith('\')){throw 'READ_ONLY_REVIEW_INVALID'}}
 $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$Executable;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true;$p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.EnvironmentVariables.Remove('ADB_TRACE')
 $p.StartInfo.Arguments=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '
 try{
  [void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
  if($InputText){$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($InputText);$p.StandardInput.BaseStream.Write($bytes,0,$bytes.Length);$p.StandardInput.BaseStream.Flush();$bytes=$null};$p.StandardInput.BaseStream.Close()
  if(-not $p.WaitForExit(60000)){$p.Kill();throw 'READ_ONLY_REVIEW_INVALID'}
  $out=$o.GetAwaiter().GetResult();$err=$e.GetAwaiter().GetResult()
  if($p.ExitCode -ne 0 -or $out.Length -gt 65536 -or $err.Length -gt 65536){throw 'READ_ONLY_REVIEW_INVALID'}
  return [pscustomobject]@{stdout=$out;stderr=$err}
 }catch{throw 'READ_ONLY_REVIEW_INVALID'}finally{$p.Dispose()}
}
function Get-InstalledSigner([string]$Adb,[string]$Serial,[string]$BasePath,[string]$Temporary,[string]$Java,[string]$SignerJar,[scriptblock]$Run,[string]$ExpectedHash='3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9'){
 if($ExpectedHash -cnotmatch '^[a-f0-9]{64}$'){throw 'READ_ONLY_REVIEW_INVALID'}
 if($Serial -cnotmatch '^[A-Za-z0-9._:-]{1,80}$' -or $BasePath -cnotmatch '^/data/app/[A-Za-z0-9_./=+~-]+/base\.apk$' -or $BasePath -match '(^|/)\.\.?(/|$)'){throw 'READ_ONLY_REVIEW_INVALID'}
 $path=Join-Path $Temporary 'installed-base.apk'
 if(Test-Path -LiteralPath $path){throw 'READ_ONLY_REVIEW_INVALID'}
 try{
  $null=& $Run $Adb @('-s',$Serial,'pull',$BasePath,$path) ''
  if(-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -gt 200MB){throw 'READ_ONLY_REVIEW_INVALID'}
  $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  if($hash -cne $ExpectedHash){throw 'READ_ONLY_REVIEW_INVALID'}
  $result=& $Run $Java @('--enable-native-access=ALL-UNNAMED','-jar',$SignerJar,'verify','--verbose','--print-certs',$path) ''
  if($result.stderr.Trim()){throw 'READ_ONLY_REVIEW_INVALID'}
  return [pscustomobject]@{sha256=$hash;signerSha256=(Convert-ReviewSigner $result.stdout)}
 }finally{if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force};if(Test-Path -LiteralPath $path){throw 'READ_ONLY_REVIEW_INVALID'}}
}
function Get-PrivateMetadata([string]$Adb,[string]$Serial,[scriptblock]$Run){
 if($Serial -cnotmatch '^[A-Za-z0-9._:-]{1,80}$'){throw 'READ_ONLY_REVIEW_INVALID'}
 try{$r=& $Run $Adb @('-s',$Serial,'shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh') (Get-ReviewStateScript)
 if($r.stderr.Trim()){throw 'PRIVATE_STATE_REVIEW_REQUIRED'};return Convert-ReviewState $r.stdout
 }catch{return [pscustomobject]@{status='UNKNOWN';sufficientForEmptyStateReview=$false}}
}
function Get-UpdateReviewDecision($Installed,$State,[string]$LabSigner,[bool]$LabValid){
 if(-not $LabValid){return 'LAB_APK_PROVENANCE_UNVERIFIED'}
 if($null -eq $Installed -or $Installed.signerSha256 -cnotmatch '^[a-f0-9]{64}$'){return 'READ_ONLY_REVIEW_INVALID'}
 if($Installed.signerSha256 -cne $LabSigner){return 'SIGNER_MISMATCH_BLOCKED'}
 if($State.status -cne 'METADATA_ONLY' -or -not $State.sufficientForEmptyStateReview){return 'PRIVATE_STATE_REVIEW_REQUIRED'}
 return 'SAFE_DATA_PRESERVING_UPDATE_REVIEW'
}
Export-ModuleMember -Function Get-ReviewStatePaths,Get-ReviewStateScript,Convert-ReviewState,Convert-ReviewSigner,Invoke-ReviewProcess,Get-InstalledSigner,Get-PrivateMetadata,Get-UpdateReviewDecision
