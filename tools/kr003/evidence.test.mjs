import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, cpSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { ingestCheckpoint, ingestQualification, ingestRecoveryDiagnostic, ingestOracleTransport, ingestUiAutomationTransport } from "./ingest.mjs";
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
    [path+'/input-probe/src/main/AndroidManifest.xml','\n<instrumentation android:targetPackage="synthetic" />'],
    [path+'/input-probe/src/debug/kotlin/dev/kidremote/spike/inputprobe/OneTouchInstrumentation.kt','\n// forbidden getRootInActiveWindow('],
    [path+'/input-probe/src/debug/kotlin/dev/kidremote/spike/inputprobe/OneTouchInstrumentation.kt','\n// forbidden sendPointerSync'],
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

test("Q7 qualification uses an active fixture oracle, three human checkpoints and a non-destructive bailout",()=>{
  const runner=readFileSync(resolve('tools/kr003/Start-KR003.ps1'),'utf8');
  const module=readFileSync(resolve('tools/kr003/Qualification.psm1'),'utf8');
  const bailout=readFileSync(resolve('tools/kr003/Clear-KR003-Lab.ps1'),'utf8');
  const packager=readFileSync(resolve('tools/kr003/package.mjs'),'utf8');
  for(const phase of ['SETTINGS_ROOT','DIGITAL_WELLBEING_ATTEMPT','RECOVERY_BUTTON_ATTEMPT','POST_RECOVERY_STATE']) {
    assert.match(runner,new RegExp(`Start-DiagnosticPhase '${phase}'`));
    assert.match(module,new RegExp(`'${phase}'`));
  }
  assert.match(packager,/protocol:"KR003-Q7-MI8-ACTIVE-ORACLE-QUALIFICATION"/);
  assert.match(packager,/runnerVersion:7/);
  assert.match(packager,/humanCheckpointMaximum:3/);
  assert.match(packager,/diagnosticOnly:false/);
  assert.match(packager,/requiresOffline:true/);
  assert.match(packager,/5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b/);
  assert.match(packager,/Clear-KR003-Lab\.ps1/);
  assert.match(runner,/EqualityDiagnosticImplemented=\$false/);
  assert.match(runner,/UsesRawPackageOrComponentIdentity=\$false/);
  assert.match(runner,/shell','input','tap/);
  assert.match(runner,/Assert-KRIndependentFixtureBlock/);
  assert.match(runner,/PREFLIGHT_NORMAL_PASS/);
  assert.match(runner,/PREFLIGHT_NEGATIVE_CONTROL/);
  assert.match(runner,/POST_RUN_SAFETY/);
  assert.match(bailout,/Get-BailoutState 'CLEAR'/);
  assert.match(bailout,/Latency samples preserved|latency samples preserved/i);
  assert.doesNotMatch(runner,/uiautomator|screencap|dumpsys\s+window|input','(?:text|keyevent)|pm','clear|uninstall','/i);
  assert.equal((runner.match(/'shell','input','tap'/g)??[]).length,1,'Only the reviewed fixture-owned input operation is allowed');
  assert.doesNotMatch(bailout,/Invoke-BailoutAdb @\('(?:uninstall|root|reboot)'|shell','pm','clear|enabled_accessibility_services|appops','set|svc','(?:wifi|data)','disable/);
});

test("UiAutomation injection result cannot replace independent fixture delivery or finish evidence",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const p={Request:12,Stage:'COMPLETE',Outcome:'INJECTED',DownAccepted:true,UpAccepted:true,Cleanup:'FRAMEWORK_FINISH'};
  const s={Protocol:'KR003-UIAUTOMATION-TRANSPORT-PREFLIGHT',SourceCommit:'a'.repeat(40),FixtureSha256:'b'.repeat(64),ProbeSha256:'c'.repeat(64),
    RestrictionChanged:false,RadiosChanged:false,PermissionsChanged:false,DestructiveAction:false,Q7Samples:0,ProbeResult:p,
    Status:'PASSED_TRANSPORT_PREFLIGHT',Reason:'FIXTURE_COUNTER_INCREMENTED_ONCE',FixtureReceiverWorked:true,CounterIncremented:true,RejectedOperation:null,BeforeTaps:4,AfterTaps:5};
  const before={focused:true,resumed:true,probeReady:true,instance:20,probeX:540,probeY:1956,taps:4};
  const after={...before,taps:5};
  const ops=['DEVICE_STATE','FIXTURE_INSTALL','PROBE_INSTALL','FIXTURE_OPEN','FIXTURE_STATE','UIAUTOMATION_TAP','FIXTURE_STATE'].map(OperationCategory=>({OperationCategory,ExitCode:0,StderrClass:'NONE'}));
  const reset=()=>{save('summary.json',s);save('probe.json',p);save('operations.json',ops);save('fixture-before.json',before);save('fixture-after.json',after);};
  reset(); assert.equal(ingestUiAutomationTransport(dir).q7Samples,0);
  for(const changed of [{...after,taps:4},{...after,taps:6},{...after,instance:21},{...after,focused:false},{...after,probeX:500}]) {
    reset();save('fixture-after.json',changed);assert.throws(()=>ingestUiAutomationTransport(dir));
  }
  reset();save('probe.json',{...p,RawPackage:'forbidden'});assert.throws(()=>ingestUiAutomationTransport(dir));
  reset();save('operations.json',[...ops,ops[5]]);assert.throws(()=>ingestUiAutomationTransport(dir));
  reset();save('summary.json',{...s,ProbeResult:{...p,UpAccepted:false}});save('probe.json',{...p,UpAccepted:false});assert.throws(()=>ingestUiAutomationTransport(dir));
  reset();save('summary.json',{...s,Status:'INVALID',Reason:'UIAUTOMATION_INJECTION_OR_CLEANUP',CounterIncremented:false,AfterTaps:4,ProbeResult:{...p,Stage:'DOWN',Outcome:'SECURITY_EXCEPTION',DownAccepted:false,UpAccepted:false}});
  save('probe.json',{...p,Stage:'DOWN',Outcome:'SECURITY_EXCEPTION',DownAccepted:false,UpAccepted:false});
  assert.equal(ingestUiAutomationTransport(dir).status,'INVALID');
}));

test("Q7 ingestion requires 100 active-oracle rows and exactly three passing human checkpoints",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const candidate='5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b';
  const fixture='f'.repeat(64);
  const bundle={protocol:'KR003-Q7-MI8-ACTIVE-ORACLE-QUALIFICATION',sourceCommit:'e'.repeat(40),runnerVersion:7,diagnosticOnly:false,requiresOffline:true,candidateSha256:candidate,fixtureSha256:fixture,oracleModel:'ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS',humanCheckpointMaximum:3};
  save('manifest.json',{Bundle:bundle,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:true});
  const calibration={Attempt:0,Phase:'CALIBRATION',Revision:99,PhysicalObserver:'PASS',AutomatedOracle:'PASS',InputOracle:'PASS',LatencyMs:111,HoldMillis:10000,InjectedBlockedTaps:20,PositiveControlTap:'REACHED_FIXTURE'};
  const rows=Array.from({length:100},(_,i)=>({Attempt:i+1,Phase:'QUALIFICATION',Revision:100+i,PhysicalObserver:'NOT_SAMPLED',AutomatedOracle:'PASS',InputOracle:'PASS',LatencyMs:120+i%5,HoldMillis:10000,InjectedBlockedTaps:20,PositiveControlTap:'REACHED_FIXTURE'}));
  save('attempts.json',[calibration,...rows]); save('calibration.json',calibration);
  save('human-checkpoints.json',[
    {Name:'PREFLIGHT_NORMAL_PASS',Result:'PASS'},
    {Name:'PREFLIGHT_NEGATIVE_CONTROL',Result:'PASS'},
    {Name:'POST_RUN_SAFETY',Result:'PASS'},
  ]);
  const phases=[
    {Name:'SETTINGS_ROOT',PhysicalResult:'PASS',Oracle:'SAFE_TRANSITION_CORROBORATED'},
    {Name:'DIGITAL_WELLBEING_ATTEMPT',PhysicalResult:'FAIL',Oracle:'ORDINARY_REATTACHMENT_CORROBORATED'},
    {Name:'RECOVERY_BUTTON_ATTEMPT',PhysicalResult:'PASS',Oracle:'FRESH_SAFE_TRANSITION_CORROBORATED',SafeTransitionElapsed:1000,LastElapsed:11000,ReattachedAfterSafe:false,UnknownAfterSafe:false},
    {Name:'POST_RECOVERY_STATE',PhysicalResult:'UNRECORDED',Oracle:'SAFE_STATE_OBSERVED'},
  ];
  save('safety-final.json',{Phase:'final',Result:'PHYSICAL_PASS_RECORDED',FinalVisibilityPhysical:'PASS',HomePhysical:'PASS',RecoveryReason:'PHYSICAL_PASS_RECORDED',ReentryPhysical:'PASS',ClearTouch:'FIXTURE_COUNTER_INCREMENT'});
  save('recovery-final.json',{Phases:phases});
  save('final-metrics.json',{samples:rows.map(r=>r.LatencyMs),sampleCount:100});
  save('network-restoration.json',{Status:'RESTORED_AND_FLAGS_VERIFIED'});
  save('diagnostic-bailout.json',{Status:'VERIFIED',RestrictionReleased:true,LatencySamplesPreserved:true});
  const sorted=rows.map(r=>r.LatencyMs).sort((a,b)=>a-b), stats={Count:100,P50:sorted[49],P95:sorted[94],Max:sorted[99]};
  save('summary.json',{EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',HumanCheckpointSessions:3,PhysicalExpiryObservations:2,InternalPairedStatistics:stats,ValidPairedObservations:100,Status:'PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY',Offline:true,SafetyChecksPassed:true,FinalizationErrors:[]});
  assert.equal(ingestQualification(dir).automatedExpiryCycles,100);
  rows[40].InputOracle='FAIL'; save('attempts.json',[calibration,...rows]);
  assert.throws(()=>ingestQualification(dir));
  rows[40].InputOracle='PASS'; save('attempts.json',[calibration,...rows]);
  save('human-checkpoints.json',[{Name:'PREFLIGHT_NORMAL_PASS',Result:'PASS'}]);
  assert.throws(()=>ingestQualification(dir));
}));

test("Q7 partial run preserves completed automated count without fabricating qualification",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const bundle={protocol:'KR003-Q7-MI8-ACTIVE-ORACLE-QUALIFICATION',sourceCommit:'e'.repeat(40),runnerVersion:7,diagnosticOnly:false,requiresOffline:true,candidateSha256:'5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b',fixtureSha256:'f'.repeat(64),oracleModel:'ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS',humanCheckpointMaximum:3};
  save('manifest.json',{Bundle:bundle,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:true});
  const pass=i=>({Attempt:i,Phase:'QUALIFICATION',Revision:100+i,AutomatedOracle:'PASS',InputOracle:'PASS'});
  save('attempts.json',[pass(1),pass(2),{...pass(3),AutomatedOracle:'FAIL',Reason:'RESTRICTION_LEAKED_INPUT'}]);
  save('human-checkpoints.json',[{Name:'PREFLIGHT_NORMAL_PASS',Result:'PASS'},{Name:'PREFLIGHT_NEGATIVE_CONTROL',Result:'PASS'}]);
  save('summary.json',{EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',Status:'FAIL',Reason:'RESTRICTION_LEAKED_INPUT'});
  const result=ingestQualification(dir);
  assert.equal(result.automatedExpiryCycles,2);
  assert.equal(result.humanCheckpointSessions,2);
  assert.equal(result.partial,true);
}));

test("Q6 ingestion requires 100 physical rows, offline restoration and both phase-local safety checkpoints",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const candidate='5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b';
  const fixture='6653f10b527cc9a273a8c0ea045cd250f6978c1acfb8e92b00b701f6c14f84bb';
  const bundle={protocol:'KR003-Q6-MI8-OFFLINE-QUALIFICATION',sourceCommit:'d'.repeat(40),runnerVersion:6,diagnosticOnly:false,requiresOffline:true,candidateSha256:candidate,fixtureSha256:fixture,calibratedBy:{runId:'run-20260906-171929-69a3abda'}};
  save('manifest.json',{Bundle:bundle,OfflineNetworkRequested:true,OfflineOwnerConfirmed:true,CalibrationOnly:false,RecoveryDiagnostic:false});
  const calibration={Attempt:0,Phase:'CALIBRATION',Revision:99,Observer:'PASS',Automated:'PASS',LatencyMs:111,HoldMillis:10000};
  const rows=Array.from({length:100},(_,i)=>({Attempt:i+1,Phase:'QUALIFICATION',Revision:100+i,Observer:'PASS',Automated:'PASS',LatencyMs:120+i%5,HoldMillis:10000}));
  save('attempts.json',[calibration,...rows]); save('calibration.json',calibration);
  const phaseRows=[
    {Name:'SETTINGS_ROOT',PhysicalResult:'PASS',Oracle:'SAFE_TRANSITION_CORROBORATED',AfterSequence:1,LastSequence:5},
    {Name:'DIGITAL_WELLBEING_ATTEMPT',PhysicalResult:'FAIL',Oracle:'ORDINARY_REATTACHMENT_CORROBORATED',AfterSequence:5,LastSequence:9},
    {Name:'RECOVERY_BUTTON_ATTEMPT',PhysicalResult:'PASS',Oracle:'FRESH_SAFE_TRANSITION_CORROBORATED',AfterSequence:9,LastSequence:14,SafeTransitionElapsed:1000,LastElapsed:11000,LastDisposition:'SAFE_SYSTEM',LastAttached:false,ReattachedAfterSafe:false,UnknownAfterSafe:false},
    {Name:'POST_RECOVERY_STATE',PhysicalResult:'UNRECORDED',Oracle:'SAFE_STATE_OBSERVED',AfterSequence:14,LastSequence:14},
  ];
  for(const phase of ['calibration','final']) {
    save(`safety-${phase}.json`,{Protocol:bundle.protocol,Phase:phase,HomePhysical:'PASS',HoldOracle:'RESTRICTION_HELD',RecoveryFile:`recovery-${phase}.json`,RecoveryReason:'PHYSICAL_PASS_RECORDED',ReentryPhysical:'PASS',ReentryOracle:'ORDINARY_RESTRICTION_HELD',ClearTouch:'FIXTURE_COUNTER_INCREMENT',Result:'PHYSICAL_PASS_RECORDED',IndependentExpirySamples:0});
    save(`recovery-${phase}.json`,{Protocol:bundle.protocol,EqualityDiagnosticImplemented:false,UsesRawPackageOrComponentIdentity:false,Phases:phaseRows});
  }
  save('diagnostic-bailout.json',{Status:'VERIFIED',RestrictionReleased:true,LatencySamplesPreserved:true,ConsumerRecoveryEvidence:false,AppDataCleared:false,Uninstalled:false,PermissionsAltered:false});
  save('network-restoration.json',{Status:'RESTORED_AND_FLAGS_VERIFIED'});
  save('final-metrics.json',{samples:rows.map(r=>r.LatencyMs),sampleCount:100});
  const sorted=rows.map(r=>r.LatencyMs).sort((a,b)=>a-b);
  const stats={Count:100,P50:sorted[49],P95:sorted[94],Max:sorted[99]};
  const summary={Status:'PASSED_THIS_CONFIGURATION_ONLY',Reason:'COMPLETED',ValidPairedObservations:100,InternalPairedStatistics:stats,StatisticsAvailable:true,SafetyChecksPassed:true,Kr003Complete:false,Offline:true,FinalizationErrors:[],QualificationRequested:true,RecoveryDiagnosticRequested:false};
  save('summary.json',summary);
  assert.equal(ingestQualification(dir).validPairedObservations,100);
  save('safety-final.json',{...JSON.parse(readFileSync(join(dir,'safety-final.json'))),HomePhysical:'FAIL'});
  assert.throws(()=>ingestQualification(dir));
  save('safety-final.json',{...JSON.parse(readFileSync(join(dir,'safety-calibration.json'))),Phase:'final',RecoveryFile:'recovery-final.json'});
  save('recovery-final.json',{Protocol:bundle.protocol,EqualityDiagnosticImplemented:false,UsesRawPackageOrComponentIdentity:false,Phases:phaseRows.map((p,i)=>i===2?{...p,LastElapsed:10999}:p)});
  assert.throws(()=>ingestQualification(dir),/stable-safe interval/);
  save('recovery-final.json',{Protocol:bundle.protocol,EqualityDiagnosticImplemented:false,UsesRawPackageOrComponentIdentity:false,Phases:phaseRows});
  save('network-restoration.json',{Status:'RESTORE_FAILED_OWNER_ACTION_REQUIRED'});
  assert.throws(()=>ingestQualification(dir));
}));

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

test("oracle transport ingestion preserves only sanitized operation classes and never creates a Q7 sample",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const base={Protocol:'KR003-Q7-ORACLE-TRANSPORT-PREFLIGHT',SourceCommit:'a'.repeat(40),FixtureSha256:'b'.repeat(64),
    StartedUtc:'2026-09-07T00:00:00Z',EndedUtc:'2026-09-07T00:00:01Z',FixtureReceiverWorked:true,BeforeTaps:3,AfterTaps:4,
    CounterIncremented:true,RejectedOperation:null,RejectedExitCode:null,RejectedStderrClass:null,RestrictionChanged:false,RadiosChanged:false,
    PermissionsChanged:false,DestructiveAction:false,Q7Samples:0};
  const operations=[
    {OperationCategory:'DEVICE_STATE',ExitCode:0,StderrClass:'NONE'},
    {OperationCategory:'FIXTURE_INSTALL',ExitCode:0,StderrClass:'NONE'},
    {OperationCategory:'FIXTURE_OPEN',ExitCode:0,StderrClass:'NONE'},
    {OperationCategory:'FIXTURE_STATE',ExitCode:0,StderrClass:'NONE'},
    {OperationCategory:'INPUT_TAP',ExitCode:0,StderrClass:'NONE'},
    {OperationCategory:'FIXTURE_STATE',ExitCode:0,StderrClass:'NONE'},
  ];
  save('summary.json',{...base,Status:'PASSED_TRANSPORT_PREFLIGHT',Reason:'FIXTURE_COUNTER_INCREMENTED_ONCE'});
  save('operations.json',operations);
  let result=ingestOracleTransport(dir);
  assert.equal(result.status,'PASSED_TRANSPORT_PREFLIGHT');
  assert.equal(result.counterIncremented,true);
  assert.equal(result.q7Samples,0);
  save('summary.json',{...base,Status:'INVALID',Reason:'ADB_OPERATION_REJECTED',AfterTaps:null,CounterIncremented:false,
    RejectedOperation:'INPUT_TAP',RejectedExitCode:255,RejectedStderrClass:'SECURITY_EXCEPTION'});
  save('operations.json',[...operations.slice(0,4),{OperationCategory:'INPUT_TAP',ExitCode:255,StderrClass:'SECURITY_EXCEPTION'}]);
  result=ingestOracleTransport(dir);
  assert.equal(result.rejectedOperation,'INPUT_TAP');
  assert.equal(result.rejectedStderrClass,'SECURITY_EXCEPTION');
  save('operations.json',[...operations.slice(0,4),{OperationCategory:'INPUT_TAP',ExitCode:255,StderrClass:'SECURITY_EXCEPTION',Raw:'forbidden'}]);
  assert.throws(()=>ingestOracleTransport(dir));
}));

test("oracle transport source is fixture-only and records no raw ADB output",()=>{
  const runner=readFileSync(resolve('tools/kr003/Test-KR003-OracleTransport.ps1'),'utf8');
  const packager=readFileSync(resolve('tools/kr003/package-transport.mjs'),'utf8');
  assert.match(runner,/KR003-Q7-ORACLE-TRANSPORT-PREFLIGHT/);
  assert.match(runner,/OperationCategory=\$Category; ExitCode=\$ExitCode; StderrClass=\$StderrClass|New-KRTransportOperationRecord/);
  assert.match(runner,/Invoke-TransportAdb 'INPUT_TAP' @\('shell','input','tap'/);
  assert.doesNotMatch(runner,/screencap|uiautomator|dumpsys\s+window|pm[^\n]+clear|uninstall|reboot|appops[^\n]+set|svc[^\n]+disable/i);
  assert.doesNotMatch(runner,/Write-TransportJson[^\n]+(?:stdout|stderr)|RawStdout|RawStderr/i);
  assert.match(packager,/diagnosticOnly:true/);
  assert.match(packager,/223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc/);
});
