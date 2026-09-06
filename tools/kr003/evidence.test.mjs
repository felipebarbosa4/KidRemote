import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, cpSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { ingestCheckpoint, ingestQualification, ingestRecoveryDiagnostic } from "./ingest.mjs";
import { validateAndroidSpike } from "../validate-android-spike.mjs";
const temporary = fn => {
  const directory=mkdtempSync(join(tmpdir(),"kr003-synthetic-"));
  try { fn(directory); } finally { rmSync(directory,{recursive:true}); }
};
test("checkpoint ingestion validates independent cycles, not observation columns or empty trace",()=>temporary(dir=>{
  const header='"Cycle","ClearRestoredOrdinaryUse","ExpiryPersistence","PhysicalHome","SettingsRecovery","OrdinaryReentry"';
  const rows=Array.from({length:10},(_,i)=>`"${i+1}","usable","persistent-block","blocked","usable","persistent-block"`);
  const csv=join(dir,"observer.csv"),trace=join(dir,"trace.log");
  writeFileSync(csv,'\ufeff'+[header,...rows].join('\r\n'));
  writeFileSync(trace,'--------- beginning of main\n--------- beginning of system\n');
  const result=ingestCheckpoint(csv,trace);
  assert.equal(result.cycles,10);
  assert.equal(result.capturedEventLines,0);
  assert.equal(result.traceComplete,false);
  assert.equal(result.internalSampleCount,"UNSPECIFIED");
  for(const changed of [rows.slice(1),[rows[0],...rows.slice(0,9)],rows.map((r,i)=>i===4?r.replace('persistent-block','flicker'):r)]) {
    writeFileSync(csv,[header,...changed].join('\n'));
    assert.throws(()=>ingestCheckpoint(csv,trace));
  }
}));
test("qualification ingestion does not promote internal signals and rejects altered counts/holds",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  save('manifest.json',{Bundle:{protocol:'KR003-Q1',sourceCommit:'a'.repeat(40)}});
  const row={Attempt:1,Phase:'QUALIFICATION',Revision:42,Observer:'PASS',Automated:'PASS',LatencyMs:123,HoldMillis:10000};
  const summary={Status:'INCOMPLETE',ValidPairedObservations:1,InternalPairedStatistics:{Count:1,P50:123,P95:123,Max:123}};
  save('attempts.json',[row]); save('summary.json',summary);
  assert.equal(ingestQualification(dir).validPairedObservations,1);
  save('attempts.json',[row,row]); assert.throws(()=>ingestQualification(dir),/Duplicate attempt/);
  save('attempts.json',[{...row,HoldMillis:9999}]); assert.throws(()=>ingestQualification(dir),/short observation/);
  save('attempts.json',[{...row,Observer:'UNRECORDED'}]);
  save('summary.json',{...summary,ValidPairedObservations:0,InternalPairedStatistics:{Count:0,P50:null,P95:null,Max:null}});
  assert.equal(ingestQualification(dir).validPairedObservations,0);
  save('summary.json',{...summary,Status:'PASSED_THIS_CONFIGURATION_ONLY',ValidPairedObservations:0});
  assert.throws(()=>ingestQualification(dir));
}));
test("legacy calibration missing summary is preserved as incomplete, not a physical failure",()=>temporary(dir=>{
  writeFileSync(join(dir,'manifest.json'),JSON.stringify({Bundle:{protocol:'KR003-Q1',sourceCommit:'a'.repeat(40)}}));
  writeFileSync(join(dir,'attempts.json'),'[]');
  writeFileSync(join(dir,'calibration.json'),JSON.stringify({Phase:'CALIBRATION',Observer:'PASS',Automated:'PASS',LatencyMs:148}));
  const result=ingestQualification(dir);
  assert.equal(result.status,'INCOMPLETE_MISSING_SUMMARY');
  assert.equal(result.validPairedObservations,0);
  assert.equal(result.calibration.Observer,'PASS');
  assert.equal(result.networkRestoration,'UNSPECIFIED');
}));
test("v2 full run requires retained calibration, corroborated recovery and independent cleanup evidence",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const calibration={Attempt:0,Phase:'CALIBRATION',Observer:'PASS',Automated:'PASS',LatencyMs:123};
  const rows=Array.from({length:100},(_,i)=>({Attempt:i+1,Phase:'QUALIFICATION',Revision:100+i,Observer:'PASS',Automated:'PASS',LatencyMs:123,HoldMillis:10000}));
  save('manifest.json',{Bundle:{protocol:'KR003-Q2',sourceCommit:'a'.repeat(40)},OfflineOwnerConfirmed:true});
  save('attempts.json',[calibration,...rows]); save('calibration.json',calibration);
  const safety={PhysicalHomeAndSettings:'OWNER_PASS',Reentry:'OWNER_PASS',ClearTouch:'FIXTURE_COUNTER_INCREMENT',IndependentExpirySamples:0,Oracle:'CORROBORATED'};
  save('safety-calibration.json',safety); save('safety-final.json',safety);
  save('final-metrics.json',{samples:rows.map(r=>r.LatencyMs),sampleCount:100});
  save('network-restoration.json',{Status:'RESTORED_AND_FLAGS_VERIFIED'});
  const summary={Status:'PASSED_THIS_CONFIGURATION_ONLY',ValidPairedObservations:100,InternalPairedStatistics:{Count:100,P50:123,P95:123,Max:123},SafetyChecksPassed:true,Kr003Complete:false,Offline:true,FinalizationErrors:[],QualificationRequested:true};
  save('summary.json',summary);
  assert.equal(ingestQualification(dir).validPairedObservations,100);
  save('safety-calibration.json',{...safety,Oracle:'UNCORROBORATED'}); assert.throws(()=>ingestQualification(dir));
  save('safety-calibration.json',safety); save('summary.json',{...summary,FinalizationErrors:['NETWORK_UNVERIFIED']}); assert.throws(()=>ingestQualification(dir));
}));
test("calibration-only completion cannot become qualification or discard an oracle disagreement",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const calibration={Attempt:0,Phase:'CALIBRATION',Observer:'PASS',Automated:'PASS',LatencyMs:123};
  const safety={PhysicalHomeAndSettings:'OWNER_PASS',Oracle:'CORROBORATED',Reentry:'OWNER_PASS',ClearTouch:'FIXTURE_COUNTER_INCREMENT'};
  save('manifest.json',{Bundle:{protocol:'KR003-Q2',sourceCommit:'a'.repeat(40)},CalibrationOnly:true});
  save('attempts.json',[calibration]); save('calibration.json',calibration); save('safety-calibration.json',safety);
  save('summary.json',{Status:'CALIBRATION_COMPLETED_ONLY',ValidPairedObservations:0,InternalPairedStatistics:{Count:0,P50:null,P95:null,Max:null},QualificationRequested:false});
  assert.equal(ingestQualification(dir).validPairedObservations,0);
  save('safety-calibration.json',{...safety,Oracle:'UNCORROBORATED'});
  assert.throws(()=>ingestQualification(dir));
}));
test("least-privilege validator rejects new files, permissions, unprotected debug entry and release trace",()=>temporary(dir=>{
  const path='spikes/android-enforcement';
  cpSync(resolve(path),join(dir,path),{recursive:true,filter:p=>!/(?:^|\/)(?:build|\.gradle)(?:\/|$)/.test(p)});
  assert.deepEqual(validateAndroidSpike(dir),[]);
  const cases=[
    [path+'/ordinary-fixture/src/main/kotlin/dev/kidremote/spike/ordinary/FixtureActivity.kt','\nfun forbidden() { println("synthetic") }'],
    [path+'/app/src/debug/AndroidManifest.xml',null],
    [path+'/app/src/release/kotlin/dev/kidremote/spike/enforcement/EnforcementTrace.kt','\n// android.util.Log forbidden'],
    [path+'/app/src/release/kotlin/dev/kidremote/spike/enforcement/EnforcementTrace.kt','\n// hasWindowFocus() forbidden'],
    [path+'/app/src/debug/kotlin/dev/kidremote/spike/enforcement/EnforcementTrace.kt','\n// getSource() forbidden: event.getSource()'],
    [path+'/ordinary-fixture/src/main/AndroidManifest.xml','\n<uses-permission android:name="android.permission.INTERNET" />'],
  ];
  for(const [file,addition] of cases) {
    const target=join(dir,file),original=readFileSync(target,'utf8');
    writeFileSync(target,addition ? original+addition : original.replace('android.permission.DUMP','android.permission.INTERNET'));
    assert(validateAndroidSpike(dir).length>0,file);
    writeFileSync(target,original);
  }
  const extra=join(dir,path+'/ordinary-fixture/src/main/kotlin/dev/kidremote/spike/ordinary/Unreviewed.kt');
  writeFileSync(extra,'val forbidden = event.getSource()');
  assert(validateAndroidSpike(dir).length>0,'New source files must be scanned too');
}));

test("focused recovery diagnostic is phase-local, diagnostic-only and has a non-destructive bailout",()=>{
  const runner=readFileSync(resolve('tools/kr003/Start-KR003.ps1'),'utf8');
  const module=readFileSync(resolve('tools/kr003/Qualification.psm1'),'utf8');
  const bailout=readFileSync(resolve('tools/kr003/Clear-KR003-Lab.ps1'),'utf8');
  const packager=readFileSync(resolve('tools/kr003/package.mjs'),'utf8');
  for(const phase of ['SETTINGS_ROOT','DIGITAL_WELLBEING_ATTEMPT','RECOVERY_BUTTON_ATTEMPT','POST_RECOVERY_STATE']) {
    assert.match(runner,new RegExp(`Start-DiagnosticPhase '${phase}'`));
    assert.match(module,new RegExp(`'${phase}'`));
  }
  assert.match(packager,/protocol:"KR003-Q5-RECOVERY-TASK-RESET-CALIBRATION"/);
  assert.match(packager,/diagnosticOnly:true/);
  assert.match(packager,/Clear-KR003-Lab\.ps1/);
  assert.match(runner,/EqualityDiagnosticImplemented=\$false/);
  assert.match(runner,/UsesRawPackageOrComponentIdentity=\$false/);
  assert.match(bailout,/Get-BailoutState 'CLEAR'/);
  assert.match(bailout,/Latency samples preserved|latency samples preserved/i);
  assert.doesNotMatch(bailout,/Invoke-BailoutAdb @\('(?:uninstall|root|reboot)'|shell','pm','clear|enabled_accessibility_services|appops','set|svc','(?:wifi|data)','disable/);
});

test("focused diagnostic ingestion preserves physical and software outcomes without creating qualification samples",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  save('manifest.json',{Bundle:{protocol:'KR003-Q3-RECOVERY-DIAGNOSTIC',diagnosticOnly:true,sourceCommit:'a'.repeat(40)},RecoveryDiagnostic:true});
  const names=['SETTINGS_ROOT','DIGITAL_WELLBEING_ATTEMPT','RECOVERY_BUTTON_ATTEMPT','POST_RECOVERY_STATE'];
  const phases=names.map((Name,i)=>({Name,PhysicalResult:i===0?'PASS':i===1||i===2?'FAIL':'UNRECORDED',Oracle:['SAFE_TRANSITION_CORROBORATED','ORDINARY_REATTACHMENT_CORROBORATED','PENDING','ORDINARY_ATTACHED_OBSERVED'][i],AfterSequence:i*10,LastSequence:(i+1)*10}));
  save('recovery-diagnostic.json',{Protocol:'KR003-Q3-RECOVERY-DIAGNOSTIC',EqualityDiagnosticImplemented:false,UsesRawPackageOrComponentIdentity:false,Result:'EVIDENCE_CAPTURED',Phases:phases});
  save('diagnostic-bailout.json',{Operation:'CLEAR_LAB_TIMER_ONLY',Status:'VERIFIED',RestrictionReleased:true,LatencySamplesPreserved:true,ConsumerRecoveryEvidence:false,AppDataCleared:false,Uninstalled:false,PermissionsAltered:false});
  save('summary.json',{Status:'DIAGNOSTIC_COMPLETED_ONLY',Reason:'PHYSICAL_FAILURE_RECORDED',QualificationRequested:false,RecoveryDiagnosticRequested:true,Kr003Complete:false,ProductionApproved:false,FinalizationErrors:[]});
  const result=ingestRecoveryDiagnostic(dir);
  assert.equal(result.qualificationSamples,0);
  assert.equal(result.phases[1].physicalResult,'FAIL');
  assert.equal(result.phases[1].oracle,'ORDINARY_REATTACHMENT_CORROBORATED');
  assert.equal(result.bailout,'VERIFIED');
  phases[3].PhysicalResult='';
  save('recovery-diagnostic.json',{Protocol:'KR003-Q3-RECOVERY-DIAGNOSTIC',EqualityDiagnosticImplemented:false,UsesRawPackageOrComponentIdentity:false,Result:'EVIDENCE_CAPTURED',Phases:phases});
  assert.equal(ingestRecoveryDiagnostic(dir).phases[3].physicalResult,'UNRECORDED');
  phases[3].PhysicalResult='UNRECORDED';
  save('manifest.json',{Bundle:{protocol:'KR003-Q4-RECOVERY-REPAIR-CALIBRATION',diagnosticOnly:true,sourceCommit:'b'.repeat(40)},RecoveryDiagnostic:true});
  save('recovery-diagnostic.json',{Protocol:'KR003-Q4-RECOVERY-REPAIR-CALIBRATION',EqualityDiagnosticImplemented:false,UsesRawPackageOrComponentIdentity:false,Result:'EVIDENCE_CAPTURED',Phases:phases});
  assert.equal(ingestRecoveryDiagnostic(dir).sourceCommit,'b'.repeat(40));
  save('manifest.json',{Bundle:{protocol:'KR003-Q5-RECOVERY-TASK-RESET-CALIBRATION',diagnosticOnly:true,sourceCommit:'c'.repeat(40)},RecoveryDiagnostic:true});
  save('recovery-diagnostic.json',{Protocol:'KR003-Q5-RECOVERY-TASK-RESET-CALIBRATION',EqualityDiagnosticImplemented:false,UsesRawPackageOrComponentIdentity:false,Result:'EVIDENCE_CAPTURED',Phases:phases});
  assert.equal(ingestRecoveryDiagnostic(dir).sourceCommit,'c'.repeat(40));
  phases[2].AfterSequence=19;
  save('recovery-diagnostic.json',{Protocol:'KR003-Q5-RECOVERY-TASK-RESET-CALIBRATION',EqualityDiagnosticImplemented:false,UsesRawPackageOrComponentIdentity:false,Result:'EVIDENCE_CAPTURED',Phases:phases});
  assert.throws(()=>ingestRecoveryDiagnostic(dir),/overlap|reuse/);
}));
