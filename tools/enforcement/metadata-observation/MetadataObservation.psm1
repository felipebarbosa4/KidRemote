Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:ChildPackage='dev.kidremote.child.unassigned.debug'
$script:FixturePackage='dev.kidremote.spike.ordinary'
$script:Directories=@('no_backup','files','databases','shared_prefs')

function Get-Od51MetadataScript($Paths) {
 if($null -eq $Paths -or $Paths.Count -lt 1){throw 'METADATA_OUTPUT_SCHEMA_INVALID'}
 $values=@{};$cases=@()
 foreach($row in $Paths.GetEnumerator()){
  if($row.Key -cnotmatch '^[A-Za-z_]+$' -or $row.Value -cnotmatch '^(no_backup|files|databases|shared_prefs)/[A-Za-z0-9._/-]{1,180}$' -or $row.Value -match '(^|/)\.\.?(/|$)' -or $values.ContainsKey($row.Value)){throw 'METADATA_OUTPUT_SCHEMA_INVALID'}
  $values[$row.Value]=$true
  $cases+="  '$($row.Value)') known=`$((known+1)); printf 'KNOWN|$($row.Key)|%s\n' `"`$bytes`" ;;"
 }
 $lines=@(
  'set -u',
  "printf 'OD51META|1\n'",
  'total=0; known=0; unexpected=0',
  'for d in no_backup files databases shared_prefs; do',
  ' if [ -L "$d" ]; then exit 21; fi',
  ' if [ -e "$d" ]; then',
  '  if [ ! -d "$d" ]; then exit 21; fi',
  '  if [ ! -r "$d" ] || [ ! -x "$d" ]; then exit 20; fi',
  '  listing=$(find "$d" -mindepth 1 -print) || exit 20',
  '  if [ -n "$listing" ]; then',
  '   oldifs=$IFS',
  "   IFS='",
  "'",
  '   for p in $listing; do',
  '    case "$p" in "$d"/*) rel=${p#"$d"/} ;; *) exit 22 ;; esac',
  '    if [ -z "$rel" ] || [ ${#p} -gt 200 ]; then exit 22; fi',
  '    case "$rel" in *[!A-Za-z0-9._/-]*|/*|*/../*|../*|..|*/./*|./*|.) exit 22 ;; esac',
  '    if [ -L "$p" ]; then exit 21; fi',
  '    if [ -d "$p" ]; then continue; fi',
  '    if [ ! -f "$p" ]; then exit 21; fi',
  '    bytes=$(stat -c ''%s'' "$p") || exit 20',
  '    case "$bytes" in ''''|*[!0-9]*) exit 22 ;; esac',
  '    total=$((total+1))',
  '    case "$p" in'
 )
 $lines+=$cases
 $lines+=@(
  '     *) unexpected=$((unexpected+1)); if [ "$unexpected" -gt 64 ]; then exit 22; fi; printf ''UNEXPECTED|%s|%s|%s\n'' "$d" "$rel" "$bytes" ;;',
  '    esac',
  '   done',
  '   IFS=$oldifs',
  '  fi',
  ' fi',
  'done',
  "printf 'COUNTS|%s|%s|%s\n' `"`$total`" `"`$known`" `"`$unexpected`"",
  "printf 'END|1\n'"
 )
 return ($lines -join "`n")+"`n"
}

function Test-Od51SafeRelativeName([string]$Name) {
 return $Name.Length -ge 1 -and $Name.Length -le 200 -and $Name -cmatch '^[A-Za-z0-9._/-]+$' -and -not $Name.StartsWith('/') -and -not (('/'+$Name+'/').Contains('/../')) -and -not (('/'+$Name+'/').Contains('/./')) -and -not $Name.Contains('//')
}

function Convert-Od51MetadataOutput([string]$Raw,$Paths) {
 if($Raw.Length -gt 32768){throw 'METADATA_OUTPUT_BOUNDS'}
 $lines=@($Raw.TrimEnd("`r","`n") -split '\r?\n')
 if($lines.Count -lt 3 -or $lines[0] -cne 'OD51META|1' -or $lines[-1] -cne 'END|1'){throw 'METADATA_OUTPUT_SCHEMA_INVALID'}
 $knownSeen=@{};$unexpectedSeen=@{};$unexpected=@();$counts=$null
 $pathToKind=@{};foreach($p in $Paths.GetEnumerator()){$pathToKind[$p.Value]=$p.Key}
 for($i=1;$i -lt $lines.Count-1;$i++){
  $line=$lines[$i]
  if($line -cmatch '^KNOWN\|([A-Za-z_]+)\|([0-9]{1,12})$'){
   $kind=$Matches[1];if(-not $Paths.Contains($kind) -or $knownSeen.ContainsKey($kind) -or $null -ne $counts){throw 'METADATA_OUTPUT_SCHEMA_INVALID'}
   $knownSeen[$kind]=[long]$Matches[2];continue
  }
  if($line -cmatch '^UNEXPECTED\|(no_backup|files|databases|shared_prefs)\|([A-Za-z0-9._/-]{1,200})\|([0-9]{1,12})$'){
   $directory=$Matches[1];$name=$Matches[2];$bytes=[long]$Matches[3];$full=$directory+'/'+$name
   if($unexpected.Count -ge 64){throw 'METADATA_OUTPUT_BOUNDS'}
   if($null -ne $counts -or -not (Test-Od51SafeRelativeName $name) -or $full.Length -gt 200 -or $pathToKind.ContainsKey($full) -or $unexpectedSeen.ContainsKey($full)){throw 'METADATA_OUTPUT_SCHEMA_INVALID'}
   $unexpectedSeen[$full]=$true;$unexpected+=,[pscustomobject]@{directory=$directory;relativeName=$name;bytes=$bytes};continue
  }
  if($line -cmatch '^COUNTS\|([0-9]{1,4})\|([0-9]{1,4})\|([0-9]{1,3})$'){
   if($null -ne $counts){throw 'METADATA_OUTPUT_SCHEMA_INVALID'}
   $counts=@([int]$Matches[1],[int]$Matches[2],[int]$Matches[3]);continue
  }
  throw 'METADATA_OUTPUT_SCHEMA_INVALID'
 }
 if($null -eq $counts -or $counts[0] -ne ($knownSeen.Count+$unexpected.Count) -or $counts[1] -ne $knownSeen.Count -or $counts[2] -ne $unexpected.Count){throw 'METADATA_OUTPUT_SCHEMA_INVALID'}
 $present=@();foreach($kind in $Paths.Keys){if($knownSeen.ContainsKey($kind)){$present+=,$kind}}
 return [pscustomobject]@{metadataStatus='METADATA_ONLY';metadataFinding=$(if($unexpected.Count){'UNKNOWN_DURABLE_FILES_PRESENT'}else{'METADATA_ONLY'});metadataKnown=$true;knownPresent=$present;totalDurableFiles=$counts[0];knownDurableFiles=$counts[1];otherDurableFiles=$counts[2];unexpectedStructuralEntries=$unexpected}
}

function Convert-Od51MetadataProcessResult($ProcessResult,$Paths) {
 if($ProcessResult.outputTooLarge){return [pscustomobject]@{metadataStatus='METADATA_OUTPUT_BOUNDS';metadataKnown=$false}}
 if($ProcessResult.exitCode -eq 0 -and $ProcessResult.stderrPresent){return [pscustomobject]@{metadataStatus='METADATA_OUTPUT_SCHEMA_INVALID';metadataKnown=$false}}
 if($ProcessResult.exitCode -eq 0){
  try{return Convert-Od51MetadataOutput $ProcessResult.stdout $Paths}catch{
   $status=if($_.Exception.Message -ceq 'METADATA_OUTPUT_BOUNDS'){'METADATA_OUTPUT_BOUNDS'}else{'METADATA_OUTPUT_SCHEMA_INVALID'}
   return [pscustomobject]@{metadataStatus=$status;metadataKnown=$false}
  }
 }
 $header=$ProcessResult.stdout -cmatch '^OD51META\|1(?:\r?\n|$)'
 $status=if(-not $header){'RUN_AS_FAILED'}elseif($ProcessResult.exitCode -eq 20){'PRIVATE_DIRECTORY_UNREADABLE'}elseif($ProcessResult.exitCode -eq 21){'SYMLINK_OR_NONREGULAR_ENTRY'}elseif($ProcessResult.exitCode -eq 22){'METADATA_OUTPUT_BOUNDS'}else{'METADATA_OUTPUT_SCHEMA_INVALID'}
 return [pscustomobject]@{metadataStatus=$status;metadataKnown=$false}
}

function Test-Od51AdbCommand([string[]]$Arguments,[string]$InputText,[string]$FixedMetadataScript,[string]$AllowedPullDestination='') {
 $line=$Arguments -join ' '
 if($line -ceq 'devices'){return -not $InputText}
 if($line -ceq 'shell am get-current-user'){return -not $InputText}
 if($line -cmatch '^shell getprop ro\.(product\.(manufacturer|model)|build\.(id|version\.(release|sdk|security_patch)))$'){return -not $InputText}
 if($line -cmatch '^shell (pm path|dumpsys package) dev\.kidremote\.(child\.unassigned\.debug|spike\.ordinary)$'){return -not $InputText}
 if($line -cmatch '^shell sha256sum /data/app/[A-Za-z0-9_./=+~-]+/base\.apk$' -and $line -notmatch '(^|/)\.\.?(/|$)'){return -not $InputText}
 if($line -ceq 'reverse --list'){return -not $InputText}
 if($Arguments.Count -eq 3 -and $Arguments[0] -ceq 'pull' -and $Arguments[1] -cmatch '^/data/app/[A-Za-z0-9_./=+~-]+/base\.apk$' -and $Arguments[1] -notmatch '(^|/)\.\.?(/|$)' -and $AllowedPullDestination -and $Arguments[2] -ceq $AllowedPullDestination){return -not $InputText}
 if($line -ceq 'shell -T run-as dev.kidremote.child.unassigned.debug sh'){return $InputText -ceq $FixedMetadataScript}
 return $false
}

function Invoke-Od51Adb([string]$Adb,[string]$Serial,[string[]]$Arguments,[string]$InputText,[string]$FixedMetadataScript,[string]$AllowedPullDestination='') {
 if(-not (Test-Od51AdbCommand $Arguments $InputText $FixedMetadataScript $AllowedPullDestination)){throw 'READ_ONLY_COMMAND_REJECTED'}
 if(($Arguments -join ' ') -cne 'devices' -and $Serial -cnotmatch '^[A-Za-z0-9._:-]{1,80}$'){throw 'TARGET_SELECTION_INVALID'}
 $all=if(($Arguments -join ' ') -ceq 'devices'){$Arguments}else{@('-s',$Serial)+$Arguments}
 foreach($a in $all){if($a -match '["\r\n]' -or $a.EndsWith('\')){throw 'READ_ONLY_COMMAND_REJECTED'}}
 $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$Adb;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true;$p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.EnvironmentVariables.Remove('ADB_TRACE')
 $p.StartInfo.Arguments=($all|ForEach-Object{'"'+$_+'"'}) -join ' '
 try{
  [void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
  if($InputText){$b=(New-Object Text.UTF8Encoding($false)).GetBytes($InputText);$p.StandardInput.BaseStream.Write($b,0,$b.Length);$p.StandardInput.BaseStream.Flush();$b=$null};$p.StandardInput.Close()
  if(-not $p.WaitForExit(60000)){$p.Kill();throw 'ADB_TIMEOUT'}
  $stdout=$o.GetAwaiter().GetResult();$stderr=$e.GetAwaiter().GetResult()
  if(($Arguments -join ' ') -ceq 'devices'){$stderr=($stderr -split '\r?\n'|Where-Object{$_ -and $_ -notin @('* daemon not running; starting now at tcp:5037','* daemon started successfully')}) -join "`n"}
  return [pscustomobject]@{exitCode=$p.ExitCode;stdout=$(if($stdout.Length -le 32768){$stdout}else{''});stderrPresent=[bool]$stderr.Trim();outputTooLarge=($stdout.Length -gt 32768 -or $stderr.Length -gt 32768)}
 }catch{if($_.Exception.Message -in @('ADB_TIMEOUT','READ_ONLY_COMMAND_REJECTED','TARGET_SELECTION_INVALID')){throw};throw 'ADB_PROCESS_FAILED'}finally{$p.Dispose()}
}

function Get-Od51AdbText($Result,[bool]$AllowAbsentPackage=$false) {
 if($Result.outputTooLarge -or $Result.stderrPresent){throw 'ADB_READ_FAILED'}
 if($AllowAbsentPackage -and $Result.exitCode -eq 1 -and -not $Result.stdout.Trim()){return ''}
 if($Result.exitCode -ne 0){throw 'ADB_READ_FAILED'}
 return $Result.stdout
}

function Select-Od51Target([string]$Raw) {
 $lines=@($Raw.Trim() -split '\r?\n'|Where-Object{$_ -and $_ -cne 'List of devices attached'})
 if($lines.Count -ne 1 -or $lines[0] -cnotmatch '^([A-Za-z0-9._:-]{1,80})\s+device$' -or $Matches[1] -like 'emulator-*'){throw 'ONE_AUTHORIZED_NON_EMULATOR_TARGET_REQUIRED'}
 return $Matches[1]
}

function Test-Od51ReverseAbsent([string]$Raw,[int]$Port) {
 if($Port -lt 1024 -or $Port -gt 65535){throw 'REVERSE_OUTPUT_INVALID'}
 if(-not $Raw.Trim()){return $true}
 foreach($line in @($Raw.Trim() -split '\r?\n')){
  if($line -cnotmatch '^[A-Za-z0-9._:-]{1,80}\s+tcp:[0-9]{1,5}\s+tcp:[0-9]{1,5}$'){throw 'REVERSE_OUTPUT_INVALID'}
  if(@($line -split '\s+') -contains ('tcp:'+$Port)){return $false}
 }
 return $true
}

function Get-Od51Configuration([scriptblock]$Read) {
 if((& $Read @('shell','am','get-current-user')).Trim() -cne '0'){throw 'CONFIGURATION_INVALID'}
 $r=[ordered]@{}
 foreach($p in @(@('manufacturer','ro.product.manufacturer'),@('model','ro.product.model'),@('android','ro.build.version.release'),@('api','ro.build.version.sdk'),@('build','ro.build.id'),@('securityPatch','ro.build.version.security_patch'))){
  $v=(& $Read @('shell','getprop',$p[1])).Trim();if($v -cnotmatch '^[A-Za-z0-9._+-]{1,100}$'){throw 'CONFIGURATION_INVALID'};$r[$p[0]]=$v
 }
 return [pscustomobject]$r
}

function Get-Od51Package([string]$Package,[scriptblock]$Read) {
 if($Package -cnotin @($script:ChildPackage,$script:FixturePackage)){throw 'PACKAGE_SCOPE_INVALID'}
 $raw=(& $Read @('shell','pm','path',$Package)).Trim();if(-not $raw){return [pscustomobject]@{installed=$false;sha256='UNSPECIFIED';versionCode='UNSPECIFIED';versionName='UNSPECIFIED';basePath='UNSPECIFIED'}}
 if($raw -cnotmatch '^package:(/data/app/[A-Za-z0-9_./=+~-]+/base\.apk)$' -or $Matches[1] -match '(^|/)\.\.?(/|$)'){throw 'PACKAGE_METADATA_INVALID'}
 $path=$Matches[1];$dump=& $Read @('shell','dumpsys','package',$Package)
 $versionCode=[regex]::Matches($dump,'(?m)^\s*versionCode=(\d+)\b');$versionName=[regex]::Matches($dump,'(?m)^\s*versionName=([A-Za-z0-9._+-]{1,100})\s*$')
 if($versionCode.Count -ne 1 -or $versionName.Count -ne 1){throw 'PACKAGE_METADATA_INVALID'}
 $hash=(& $Read @('shell','sha256sum',$path)).Trim();if($hash -cnotmatch ('^([a-f0-9]{64})\s+'+[regex]::Escape($path)+'$')){throw 'PACKAGE_METADATA_INVALID'}
 return [pscustomobject]@{installed=$true;sha256=$Matches[1];versionCode=$versionCode[0].Groups[1].Value;versionName=$versionName[0].Groups[1].Value;basePath=$path}
}

function Convert-Od51Signer([string]$Raw) {
 if($Raw -notmatch '(?m)^Verifies\r?$' -or [regex]::Matches($Raw,'(?m)^Number of signers: 1\r?$').Count -ne 1){throw 'PACKAGE_SIGNER_INVALID'}
 $matches=[regex]::Matches($Raw,'(?m)^(?:V[0-9]+ )?Signer #?1(?: |:)certificate SHA-256 digest: ([a-f0-9]{64})\s*$')
 if($matches.Count -eq 0){$matches=[regex]::Matches($Raw,'(?m)^V[0-9]+ Signer: certificate SHA-256 digest: ([a-f0-9]{64})\s*$')}
 if($matches.Count -ne 1 -or [regex]::Matches($Raw,'certificate SHA-256 digest: ([a-fA-F0-9]{64})').Count -ne 1){throw 'PACKAGE_SIGNER_INVALID'}
 return $matches[0].Groups[1].Value
}

function Get-Od51Signer([string]$Java,[string]$Jar,[string]$Apk) {
 $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$Java;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 $args=@('--enable-native-access=ALL-UNNAMED','-jar',$Jar,'verify','--verbose','--print-certs',$Apk);$p.StartInfo.Arguments=($args|ForEach-Object{'"'+$_+'"'}) -join ' '
 try{[void]$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();if(-not $p.WaitForExit(60000)){$p.Kill();throw 'PACKAGE_SIGNER_INVALID'};$stdout=$o.GetAwaiter().GetResult();$stderr=$e.GetAwaiter().GetResult();if($p.ExitCode -ne 0 -or $stderr.Trim() -or $stdout.Length -gt 65536){throw 'PACKAGE_SIGNER_INVALID'};return Convert-Od51Signer $stdout}catch{throw 'PACKAGE_SIGNER_INVALID'}finally{$p.Dispose()}
}

Export-ModuleMember -Function Get-Od51MetadataScript,Test-Od51SafeRelativeName,Convert-Od51MetadataOutput,Convert-Od51MetadataProcessResult,Test-Od51AdbCommand,Invoke-Od51Adb,Get-Od51AdbText,Select-Od51Target,Test-Od51ReverseAbsent,Get-Od51Configuration,Get-Od51Package,Convert-Od51Signer,Get-Od51Signer
