import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, cpSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { createHash } from "node:crypto";
import { ingestCheckpoint, ingestQualification, ingestRecoveryDiagnostic, ingestOracleTransport, ingestDeviceTransport, ingestOracleCalibration, ingestUiAutomationTransport, ingestMonkeyTransport } from "./ingest.mjs";
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
    [path+'/input-probe/src/debug/kotlin/dev/kidremote/spike/inputprobe/MonkeyTouchMain.kt','\nfun leak() { System.out.println("raw") }'],
    [path+'/input-probe/src/debug/kotlin/dev/kidremote/spike/inputprobe/MonkeyTouchMain.kt','\n// forbidden setActivityController('],
    [path+'/input-probe/src/debug/kotlin/dev/kidremote/spike/inputprobe/MonkeyTouchMain.kt','\n// forbidden setAccessible('],
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

test("configuration-bound qualification uses an active fixture oracle, three human checkpoints and a non-destructive bailout",()=>{
  const runner=readFileSync(resolve('tools/kr003/Start-KR003.ps1'),'utf8');
  const module=readFileSync(resolve('tools/kr003/Qualification.psm1'),'utf8');
  const bailout=readFileSync(resolve('tools/kr003/Clear-KR003-Lab.ps1'),'utf8');
  const packager=readFileSync(resolve('tools/kr003/package.mjs'),'utf8');
  for(const phase of ['SETTINGS_ROOT','DIGITAL_WELLBEING_ATTEMPT','RECOVERY_BUTTON_ATTEMPT','POST_RECOVERY_STATE']) {
    assert.match(runner,new RegExp(`Start-DiagnosticPhase '${phase}'`));
    assert.match(module,new RegExp(`'${phase}'`));
  }
  assert.match(packager,/protocol:"KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION"/);
  assert.match(packager,/runnerVersion:12/);
  assert.match(packager,/networkCapabilityModel:"ANDROID_SYSTEM_FEATURES_WIFI_AND_TELEPHONY_DATA"/);
  assert.match(packager,/awakeStateModel:"ANDROID_STAY_ON_WHILE_PLUGGED_IN_PLUS_POWER_SOURCE"/);
  assert.match(packager,/navigationModeModel:"SECURE_SETTINGS_CURRENT_USER_COARSE_ENUM"/);
  assert.match(packager,/calibration-20260908-231756-97a0855b/);
  assert.match(packager,/BP4A\.251205\.006/);
  assert.match(packager,/humanCheckpointMaximum:3/);
  assert.match(packager,/diagnosticOnly:false/);
  assert.match(packager,/requiresOffline:true/);
  assert.match(packager,/assert\.equal\(candidateSha256,calibrationSummary\.CandidateSha256/);
  assert.match(packager,/Clear-KR003-Lab\.ps1/);
  assert.match(runner,/EqualityDiagnosticImplemented=\$false/);
  assert.match(runner,/UsesRawPackageOrComponentIdentity=\$false/);
  assert.match(runner,/shell','input','tap/);
  assert.match(runner,/Assert-KRIndependentFixtureBlock/);
  assert.match(runner,/PREFLIGHT_NORMAL_PASS/);
  assert.match(runner,/PREFLIGHT_NEGATIVE_CONTROL/);
  assert.match(runner,/POST_RUN_SAFETY/);
  assert.match(runner,/shell','svc','power','stayon','true/);
  assert.match(runner,/stay_on_while_plugged_in/);
  assert.match(runner,/Restore-StayAwake/);
  assert.match(runner,/settings','--user','current','get','secure','navigation_mode/);
  assert.match(runner,/HOME CONTROL CHECK/);
  assert.match(runner,/navigation mode does not establish that its Home control is visible/);
  assert.match(runner,/HomeControlExercisability='UNKNOWN'/);
  assert.match(runner,/HOME_ACTION_NOT_EXERCISABLE/);
  assert.match(runner,/HOME_ACTION_RESISTED/);
  assert.match(runner,/HOME_ACTION_ESCAPED/);
  assert.match(runner,/if\(\$homeControl -ne 'AVAILABLE'\).*INVALID:SAFETY_/s);
  assert(runner.indexOf("$homeControl=Read-HomeControlExercisability")<runner.indexOf("$homeInstruction=Get-KRHomeActionInstruction"));
  assert.match(runner,/HOME_ACTION_EXERCISED_AND_RESISTED|Get-KRHomeActionResult/);
  assert.match(runner,/Do not tap Open device settings/);
  assert.doesNotMatch(runner,/settings','(?:--user','current',)?'put','secure','navigation_mode/);
  assert.doesNotMatch(runner,/RawBattery|RawSetting|BatteryDump|StackTrace/);
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

test("Monkey transport requires independent delivery and verified disposable-helper cleanup",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const p={Request:12,Stage:'COMPLETE',Outcome:'INJECTED',DownAccepted:true,UpAccepted:true};
  const s={Protocol:'KR003-MONKEY-TRANSPORT-PREFLIGHT',SourceCommit:'a'.repeat(40),FixtureSha256:'b'.repeat(64),HelperSha256:'c'.repeat(64),
    RestrictionChanged:false,RadiosChanged:false,PermissionsChanged:false,DestructiveAction:false,Q7Samples:0,ProbeResult:p,HelperCleanup:'REMOVED_AND_VERIFIED',
    Status:'PASSED_TRANSPORT_PREFLIGHT',Reason:'FIXTURE_COUNTER_INCREMENTED_ONCE',FixtureReceiverWorked:true,CounterIncremented:true,RejectedOperation:null,BeforeTaps:4,AfterTaps:5};
  const before={focused:true,resumed:true,probeReady:true,instance:20,probeX:540,probeY:1956,taps:4},after={...before,taps:5};
  const ops=['DEVICE_STATE','FIXTURE_INSTALL','MONKEY_TOOL_CHECK','HELPER_PUSH','FIXTURE_OPEN','FIXTURE_STATE','MONKEY_TOUCH','FIXTURE_STATE','HELPER_REMOVE','HELPER_ABSENCE'].map(OperationCategory=>({OperationCategory,ExitCode:0,StderrClass:'NONE'}));
  const reset=()=>{save('summary.json',s);save('probe.json',p);save('operations.json',ops);save('fixture-before.json',before);save('fixture-after.json',after);};
  reset(); assert.equal(ingestMonkeyTransport(dir).q7Samples,0);
  for(const changed of [{...after,taps:4},{...after,taps:6},{...after,instance:21},{...after,focused:false},{...after,probeX:500}]) {
    reset();save('fixture-after.json',changed);assert.throws(()=>ingestMonkeyTransport(dir));
  }
  reset();save('summary.json',{...s,HelperCleanup:'UNVERIFIED'});assert.throws(()=>ingestMonkeyTransport(dir));
  reset();save('operations.json',ops.filter(o=>o.OperationCategory!=='HELPER_REMOVE'));assert.throws(()=>ingestMonkeyTransport(dir));
  reset();save('operations.json',[...ops,ops[6]]);assert.throws(()=>ingestMonkeyTransport(dir));
  reset();save('probe.json',{...p,RawOutput:'forbidden'});assert.throws(()=>ingestMonkeyTransport(dir));
  reset();const denied={...p,Stage:'DOWN',Outcome:'SECURITY_EXCEPTION',DownAccepted:false,UpAccepted:false};
  save('summary.json',{...s,Status:'INVALID',Reason:'MONKEY_INJECTION',ProbeResult:denied,AfterTaps:4,CounterIncremented:false});save('probe.json',denied);
  assert.equal(ingestMonkeyTransport(dir).status,'INVALID');
}));

test("Monkey helper cannot invoke the full driver, add permissions, or collect UI data",()=>{
  const runner=readFileSync(resolve('tools/kr003/Test-KR003-MonkeyTransport.ps1'),'utf8');
  const helper=readFileSync(resolve('spikes/android-enforcement/input-probe/src/debug/kotlin/dev/kidremote/spike/inputprobe/MonkeyTouchMain.kt'),'utf8');
  assert.equal((runner.match(/'MONKEY_TOUCH' @/g)??[]).length,1);
  assert.match(runner,/'timeout','-k','2','15'/);
  assert.doesNotMatch(runner,/uiautomator|screencap|dumpsys|shell','input|appops|settings','put|LAB_ARM|svc','|uninstall/);
  assert.match(helper,/inject.invoke\(event, null, null, 0\)/);
  assert.doesNotMatch(helper,/Class.forName\("com.android.commands.monkey.Monkey"\)|setAccessible\(|getDeclaredMethod\(|printStackTrace\(/);
});

test("Q7 ingestion requires 100 active-oracle rows and exactly three passing human checkpoints",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const candidate='5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b';
  const fixture='f'.repeat(64);
  const approvedConfiguration={schema:1,manufacturer:'samsung',model:'SM-X400',androidVersion:'16',apiLevel:'36',securityPatch:'2026-07-05',buildId:'BP4A.251205.006'};
  const calibratedBy={protocol:'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION',sourceCommit:'a'.repeat(40),runDirectory:'calibration-20260908-231756-97a0855b',status:'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY',reason:'COMPLETED',summarySha256:'b'.repeat(64),deviceSha256:'c'.repeat(64),transportDeviceEvidenceSha256:'d'.repeat(64),calibrationSamples:1,qualificationSamples:0,physicalAgreement:'PASS',candidateSha256:candidate,fixtureSha256:fixture};
  const bundle={protocol:'KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION',sourceCommit:'e'.repeat(40),runnerVersion:11,diagnosticOnly:false,requiresOffline:true,candidateSha256:candidate,fixtureSha256:fixture,approvedConfiguration,ownerProvidedLabels:{device:'Galaxy Tab S10 Lite',software:'One UI 8.5'},physicalExecution:'NOT_RUN',calibratedBy,oracleModel:'ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS',networkCapabilityModel:'ANDROID_SYSTEM_FEATURES_WIFI_AND_TELEPHONY_DATA',awakeStateModel:'ANDROID_STAY_ON_WHILE_PLUGGED_IN_PLUS_POWER_SOURCE',navigationModeModel:'SECURE_SETTINGS_CURRENT_USER_COARSE_ENUM',humanCheckpointMaximum:3,qualificationCycles:100,resumeAllowed:false,poolingAllowed:false};
  const capturedDevice={Manufacturer:'samsung',Model:'SM-X400',Android:'16',Api:'36',Patch:'2026-07-05',BuildId:'BP4A.251205.006',wifi_on:'0',mobile_data:'0'};
  save('manifest.json',{Bundle:bundle,InitialDevice:capturedDevice,Device:capturedDevice,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:true,StayAwakeRequested:true});
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
  save('safety-final.json',{Phase:'final',Result:'PHYSICAL_PASS_RECORDED',FinalVisibilityPhysical:'PASS',HomePhysical:'PASS',NavigationMode:'GESTURE',HomeActionResult:'HOME_ACTION_EXERCISED_AND_RESISTED',HomeResultSource:'OWNER_RESPONSE',RecoveryReason:'PHYSICAL_PASS_RECORDED',ReentryPhysical:'PASS',ClearTouch:'FIXTURE_COUNTER_INCREMENT'});
  save('recovery-final.json',{Phases:phases});
  save('final-metrics.json',{samples:rows.map(r=>r.LatencyMs),sampleCount:100});
  save('network-restoration.json',{Status:'RESTORED_AND_FLAGS_VERIFIED'});
  save('stay-awake.json',{Schema:1,Mechanism:'ANDROID_STAY_ON_WHILE_PLUGGED_IN',OriginalSetting:0,AppliedSetting:15,Changed:true,PowerSourceBefore:'USB',PowerSourceAfter:'USB',Establishment:'VERIFIED',VerificationSource:'GLOBAL_SETTING_PLUS_DUMPSYS_BATTERY',VerificationCount:203,LastPowerSource:'USB',LastVerifiedUtc:'2026-09-09T01:00:00Z'});
  save('stay-awake-restoration.json',{Schema:1,Status:'RESTORED_AND_SETTING_VERIFIED',OriginalSetting:0,ObservedSetting:0,Changed:true,VerificationSource:'GLOBAL_SETTING_READBACK',AtUtc:'2026-09-09T02:00:00Z'});
  save('navigation-mode.json',{Schema:1,Mode:'GESTURE',VerificationSource:'SECURE_SETTINGS_CURRENT_USER_NAVIGATION_MODE',ParseResult:'VALUE_2',VerificationCount:2,LastVerifiedUtc:'2026-09-09T01:59:00Z'});
  save('network-capabilities.json',{Schema:1,Wifi:'PRESENT',MobileData:'ABSENT',VerificationSource:'PM_HAS_FEATURE',AtUtc:'2026-09-09T00:00:00Z'});
  save('network-operations.json',[
    {Sequence:1,Operation:'PROBE_WIFI_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:0,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:00Z'},
    {Sequence:2,Operation:'PROBE_MOBILE_DATA_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:1,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:01Z'},
  ]);
  save('diagnostic-bailout.json',{Status:'VERIFIED',RestrictionReleased:true,LatencySamplesPreserved:true});
  save('permission-verification.json',{UsageAccessRunner:'ENABLED',AccessibilityRunner:'ENABLED',ServiceHeartbeat:'FRESH',CandidateHealth:'HEALTHY',CandidateEligible:'ELIGIBLE',UsageAccessVerificationSource:'CMD_APPOPS_GET_GET_USAGE_STATS',AccessibilityVerificationSource:'SECURE_SETTINGS_CURRENT_USER_COMPONENT_NAME',UsageAccessParseResult:'MODE_ALLOWED',AccessibilityParseResult:'GLOBAL_ENABLED_COMPONENT_MATCH_FULL'});
  const sorted=rows.map(r=>r.LatencyMs).sort((a,b)=>a-b), stats={Count:100,P50:sorted[49],P95:sorted[94],Max:sorted[99]};
  save('summary.json',{EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',HumanCheckpointSessions:3,PhysicalExpiryObservations:2,InternalPairedStatistics:stats,ValidPairedObservations:100,Status:'PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY',Offline:true,SafetyChecksPassed:true,FinalizationErrors:[]});
  assert.equal(ingestQualification(dir).automatedExpiryCycles,100);
  save('navigation-mode.json',{Schema:1,Mode:'UNKNOWN',VerificationSource:'SECURE_SETTINGS_CURRENT_USER_NAVIGATION_MODE',ParseResult:'UNPARSEABLE',VerificationCount:1,LastVerifiedUtc:'2026-09-09T01:59:00Z'});
  assert.throws(()=>ingestQualification(dir));
  save('navigation-mode.json',{Schema:1,Mode:'GESTURE',VerificationSource:'SECURE_SETTINGS_CURRENT_USER_NAVIGATION_MODE',ParseResult:'VALUE_2',VerificationCount:2,LastVerifiedUtc:'2026-09-09T01:59:00Z'});
  save('network-operations.json',[
    {Sequence:1,Operation:'PROBE_WIFI_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:0,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:00Z',RawStderr:'forbidden'},
    {Sequence:2,Operation:'PROBE_MOBILE_DATA_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:1,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:01Z'},
  ]);
  assert.throws(()=>ingestQualification(dir));
  save('network-operations.json',[
    {Sequence:1,Operation:'PROBE_WIFI_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:0,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:00Z'},
    {Sequence:2,Operation:'PROBE_MOBILE_DATA_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:1,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:01Z'},
  ]);
  save('manifest.json',{Bundle:bundle,InitialDevice:{...capturedDevice,BuildId:'DRIFTED'},Device:capturedDevice,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:true,StayAwakeRequested:true});
  assert.throws(()=>ingestQualification(dir));
  save('manifest.json',{Bundle:bundle,InitialDevice:capturedDevice,Device:capturedDevice,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:true,StayAwakeRequested:true});
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

test("100 valid Samsung rows followed by checkpoint-3 screen/keyguard INVALID remain one non-resumable INVALID",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const candidate='5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b',fixture='f'.repeat(64);
  const approvedConfiguration={schema:1,manufacturer:'samsung',model:'SM-X400',androidVersion:'16',apiLevel:'36',securityPatch:'2026-07-05',buildId:'BP4A.251205.006'};
  const calibratedBy={protocol:'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION',sourceCommit:'a'.repeat(40),runDirectory:'calibration-20260908-231756-97a0855b',status:'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY',reason:'COMPLETED',summarySha256:'b'.repeat(64),deviceSha256:'c'.repeat(64),transportDeviceEvidenceSha256:'d'.repeat(64),calibrationSamples:1,qualificationSamples:0,physicalAgreement:'PASS',candidateSha256:candidate,fixtureSha256:fixture};
  const bundle={protocol:'KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION',sourceCommit:'e'.repeat(40),runnerVersion:9,diagnosticOnly:false,requiresOffline:true,candidateSha256:candidate,fixtureSha256:fixture,approvedConfiguration,ownerProvidedLabels:{device:'Galaxy Tab S10 Lite',software:'One UI 8.5'},physicalExecution:'NOT_RUN',calibratedBy,oracleModel:'ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS',networkCapabilityModel:'ANDROID_SYSTEM_FEATURES_WIFI_AND_TELEPHONY_DATA',humanCheckpointMaximum:3,qualificationCycles:100,resumeAllowed:false,poolingAllowed:false};
  save('manifest.json',{Bundle:bundle,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:true});
  const latencies=Array.from({length:100},(_,i)=>i===94?317:i===99?334:Math.min(316,51+i*2));
  const rows=latencies.map((LatencyMs,i)=>({Attempt:i+1,Phase:'QUALIFICATION',Revision:100+i,PhysicalObserver:'NOT_SAMPLED',AutomatedOracle:'PASS',InputOracle:'PASS',LatencyMs,HoldMillis:22000,InjectedBlockedTaps:20,PositiveControlTap:'REACHED_FIXTURE'}));
  save('attempts.json',rows);
  save('human-checkpoints.json',[
    {Name:'PREFLIGHT_NORMAL_PASS',Result:'PASS',Evidence:'TEN_SECOND_VISIBLE_RESULT_PLUS_ACTIVE_FIXTURE_INPUT_DENIAL'},
    {Name:'PREFLIGHT_NEGATIVE_CONTROL',Result:'PASS',Evidence:'LAB_CLEAR_PLUS_REAL_ADB_INPUT_REACHED_FIXTURE'},
    {Name:'POST_RUN_SAFETY',Result:'INVALID',Evidence:'GUIDED_CHECKPOINT_STOPPED_WITH_PRESERVED_SUBSTEP_EVIDENCE'},
  ]);
  save('network-capabilities.json',{Schema:1,Wifi:'PRESENT',MobileData:'ABSENT',VerificationSource:'PM_HAS_FEATURE',AtUtc:'2026-09-09T00:00:00Z'});
  save('network-operations.json',[
    {Sequence:1,Operation:'PROBE_WIFI_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:0,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:00Z'},
    {Sequence:2,Operation:'PROBE_MOBILE_DATA_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:1,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:01Z'},
  ]);
  const sorted=[...latencies].sort((a,b)=>a-b),stats={Count:100,P50:sorted[49],P95:sorted[94],Max:sorted[99]};
  save('summary.json',{EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',Status:'INVALID',Reason:'SCREEN_OR_KEYGUARD',StatisticsAvailable:true,InternalPairedStatistics:stats,ValidPairedObservations:100});
  const result=ingestQualification(dir);
  assert.equal(result.status,'INVALID');assert.equal(result.reason,'SCREEN_OR_KEYGUARD');
  assert.equal(result.qualificationRows,100);assert.equal(result.automatedExpiryCycles,100);
  assert.deepEqual(result.automatedStats,stats);assert.equal(result.humanCheckpointSessions,2);
  assert.deepEqual(result.checkpointResults.map(c=>[c.name,c.result]),[
    ['PREFLIGHT_NORMAL_PASS','PASS'],['PREFLIGHT_NEGATIVE_CONTROL','PASS'],['POST_RUN_SAFETY','INVALID'],
  ]);
  assert.equal(bundle.resumeAllowed,false);assert.equal(bundle.poolingAllowed,false);assert.equal(result.kr003Complete,false);

  // A later runner-v10 safety-oracle failure keeps all 100 automated rows but never becomes qualification PASS.
  bundle.runnerVersion=10;bundle.awakeStateModel='ANDROID_STAY_ON_WHILE_PLUGGED_IN_PLUS_POWER_SOURCE';
  save('manifest.json',{Bundle:bundle,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:true,StayAwakeRequested:true});
  save('stay-awake.json',{Schema:1,Mechanism:'ANDROID_STAY_ON_WHILE_PLUGGED_IN',OriginalSetting:0,AppliedSetting:15,Changed:true,PowerSourceBefore:'USB',PowerSourceAfter:'USB',Establishment:'VERIFIED',VerificationSource:'GLOBAL_SETTING_PLUS_DUMPSYS_BATTERY',VerificationCount:204,LastPowerSource:'USB',LastVerifiedUtc:'2026-09-09T01:00:00Z'});
  save('stay-awake-restoration.json',{Schema:1,Status:'RESTORED_AND_SETTING_VERIFIED',OriginalSetting:0,ObservedSetting:0,Changed:true,VerificationSource:'GLOBAL_SETTING_READBACK',AtUtc:'2026-09-09T02:00:00Z'});
  save('human-checkpoints.json',[
    {Name:'PREFLIGHT_NORMAL_PASS',Result:'PASS',Evidence:'TEN_SECOND_VISIBLE_RESULT_PLUS_ACTIVE_FIXTURE_INPUT_DENIAL'},
    {Name:'PREFLIGHT_NEGATIVE_CONTROL',Result:'PASS',Evidence:'LAB_CLEAR_PLUS_REAL_ADB_INPUT_REACHED_FIXTURE'},
    {Name:'POST_RUN_SAFETY',Result:'FAIL',Evidence:'GUIDED_CHECKPOINT_STOPPED_WITH_PRESERVED_SUBSTEP_EVIDENCE'},
  ]);
  save('safety-final.json',{Phase:'final',Result:'INCOMPLETE',Reason:'RESTRICTION_LOST',FinalVisibilityPhysical:'PASS',HomePhysical:'UNRECORDED',HoldOracle:'RESTRICTION_HELD',RecoveryReason:'UNRECORDED',ReentryPhysical:'UNRECORDED',ClearTouch:'UNRECORDED'});
  save('summary.json',{EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',Status:'FAIL',Reason:'RESTRICTION_LOST',StatisticsAvailable:true,InternalPairedStatistics:stats,ValidPairedObservations:100});
  const failed=ingestQualification(dir);
  assert.equal(failed.status,'FAIL');assert.equal(failed.reason,'RESTRICTION_LOST');
  assert.equal(failed.automatedExpiryCycles,100);assert.equal(failed.safetyCheckpoint.homePhysical,'UNRECORDED');
  assert.equal(failed.safetyCheckpoint.finalVisibilityPhysical,'PASS');
  // A partial/INVALID run may truthfully retain failed cleanup; only a final PASS requires successful restoration.
  save('stay-awake-restoration.json',{Schema:1,Status:'RESTORE_FAILED_OWNER_ACTION_REQUIRED',OriginalSetting:0,ObservedSetting:null,Changed:true,VerificationSource:'GLOBAL_SETTING_READBACK',AtUtc:'2026-09-09T02:00:00Z'});
  const cleanupFailed=ingestQualification(dir);
  assert.equal(cleanupFailed.stayAwakeRestoration,'RESTORE_FAILED_OWNER_ACTION_REQUIRED');
  assert.equal(cleanupFailed.kr003Complete,false);

  // Runner-v12 separates mode, control availability, action exercise and outcome; unavailable remains INVALID.
  bundle.runnerVersion=12;bundle.navigationModeModel='SECURE_SETTINGS_CURRENT_USER_COARSE_ENUM';
  save('manifest.json',{Bundle:bundle,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:true,StayAwakeRequested:true});
  save('navigation-mode.json',{Schema:1,Mode:'THREE_BUTTON',VerificationSource:'SECURE_SETTINGS_CURRENT_USER_NAVIGATION_MODE',ParseResult:'VALUE_0',VerificationCount:2,LastVerifiedUtc:'2026-09-09T01:59:00Z'});
  save('safety-final.json',{Phase:'final',Result:'INCOMPLETE',Reason:'SAFETY_FINAL_HOME_CONTROL',FinalVisibilityPhysical:'PASS',HomePhysical:'INVALID',HoldOracle:'RESTRICTION_HELD',RecoveryReason:'UNRECORDED',ReentryPhysical:'UNRECORDED',ClearTouch:'UNRECORDED',NavigationMode:'THREE_BUTTON',NavigationModeClassification:'NAV_MODE_THREE_BUTTON',HomeControlExercisability:'UNAVAILABLE',HomeControlSource:'OWNER_RESPONSE',HomeActionState:'HOME_ACTION_NOT_EXERCISABLE',HomeActionOutcome:'UNRECORDED',HomeActionResult:'HOME_ACTION_NOT_EXERCISABLE_OR_UNKNOWN',HomeResultSource:'OWNER_RESPONSE'});
  save('summary.json',{EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',Status:'INVALID',Reason:'SAFETY_FINAL_HOME_CONTROL',StatisticsAvailable:true,InternalPairedStatistics:stats,ValidPairedObservations:100});
  const v12Invalid=ingestQualification(dir);
  assert.equal(v12Invalid.safetyCheckpoint.navigationModeClassification,'NAV_MODE_THREE_BUTTON');
  assert.equal(v12Invalid.safetyCheckpoint.homeControlExercisability,'UNAVAILABLE');
  assert.equal(v12Invalid.safetyCheckpoint.homeActionState,'HOME_ACTION_NOT_EXERCISABLE');
}));

test("configuration qualification network-preflight INVALID retains zero cycles and checkpoints",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const candidate='5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b',fixture='f'.repeat(64);
  const approvedConfiguration={schema:1,manufacturer:'samsung',model:'SM-X400',androidVersion:'16',apiLevel:'36',securityPatch:'2026-07-05',buildId:'BP4A.251205.006'};
  const calibratedBy={protocol:'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION',sourceCommit:'a'.repeat(40),runDirectory:'calibration-20260908-231756-97a0855b',status:'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY',reason:'COMPLETED',summarySha256:'b'.repeat(64),deviceSha256:'c'.repeat(64),transportDeviceEvidenceSha256:'d'.repeat(64),calibrationSamples:1,qualificationSamples:0,physicalAgreement:'PASS',candidateSha256:candidate,fixtureSha256:fixture};
  const bundle={protocol:'KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION',sourceCommit:'e'.repeat(40),runnerVersion:9,diagnosticOnly:false,requiresOffline:true,candidateSha256:candidate,fixtureSha256:fixture,approvedConfiguration,ownerProvidedLabels:{device:'Galaxy Tab S10 Lite',software:'One UI 8.5'},physicalExecution:'NOT_RUN',calibratedBy,oracleModel:'ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS',networkCapabilityModel:'ANDROID_SYSTEM_FEATURES_WIFI_AND_TELEPHONY_DATA',humanCheckpointMaximum:3,qualificationCycles:100,resumeAllowed:false,poolingAllowed:false};
  save('manifest.json',{Bundle:bundle,EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',OfflineNetworkRequested:true,OfflineOwnerConfirmed:false});
  save('attempts.json',[]);save('human-checkpoints.json',[]);
  save('summary.json',{EvidenceModel:'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS',Status:'INVALID',Reason:'ADB_REJECTED'});
  save('network-capabilities.json',{Schema:1,Wifi:'PRESENT',MobileData:'ABSENT',VerificationSource:'PM_HAS_FEATURE',AtUtc:'2026-09-09T00:00:00Z'});
  save('network-operations.json',[
    {Sequence:1,Operation:'PROBE_WIFI_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:0,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:00Z'},
    {Sequence:2,Operation:'PROBE_MOBILE_DATA_CAPABILITY',Phase:'PREFLIGHT',Result:'ACCEPTED',ExitCode:1,StderrClass:'NONE',AtUtc:'2026-09-09T00:00:01Z'},
    {Sequence:3,Operation:'DISABLE_WIFI',Phase:'ISOLATION',Result:'REJECTED',ExitCode:1,StderrClass:'PERMISSION_DENIAL',AtUtc:'2026-09-09T00:00:02Z'},
  ]);
  const result=ingestQualification(dir);
  assert.equal(result.status,'INVALID');assert.equal(result.automatedExpiryCycles,0);assert.equal(result.humanCheckpointSessions,0);
  assert.equal(result.networkCapabilities.MobileData,'ABSENT');assert.equal(result.partial,true);
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

test("generic device transport ingestion accepts only sanitized metadata and one fixture tap",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const device={Schema:1,Manufacturer:'samsung',Model:'SM-X000',AndroidVersion:'16',ApiLevel:'36',SecurityPatch:'2026-08-05',BuildId:'BP2A.260805.001',
    BatteryManagement:{BatterySaver:'DISABLED',AdaptiveBattery:'ENABLED',AppStandby:'ENABLED',OemBatteryManagement:'UNSPECIFIED'},
    RequiredPermissionState:{UsageAccess:'NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED',AccessibilityService:'NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED'}};
  const operations=['ADB_STATE',...Array(6).fill('DEVICE_METADATA'),...Array(3).fill('BATTERY_STATE'),'CANDIDATE_INSTALL_STATE','FIXTURE_INSTALL','FIXTURE_PATH','FIXTURE_PULL','FIXTURE_OPEN','FIXTURE_STATE','INPUT_TAP','FIXTURE_STATE']
    .map(OperationCategory=>({OperationCategory,ExitCode:0,StderrClass:'NONE'}));
  const summary={Protocol:'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT',Status:'PASSED_TRANSPORT_PREFLIGHT',Reason:'FIXTURE_COUNTER_INCREMENTED_ONCE',
    SourceCommit:'a'.repeat(40),FixtureSha256:'b'.repeat(64),DeviceEvidenceSha256:null,AdbAuthorized:true,MetadataComplete:true,BundleVerified:true,InstalledFixtureHashVerified:true,
    FixtureReady:true,BeforeTaps:4,AfterTaps:5,CounterIncremented:true,RejectedOperation:null,CandidateInstalledByRunner:false,TimerUsed:false,
    RestrictionChanged:false,RadiosChanged:false,PermissionsChanged:false,DestructiveAction:false,QualificationSamples:0};
  save('device.json',device);summary.DeviceEvidenceSha256=createHash('sha256').update(readFileSync(join(dir,'device.json'))).digest('hex');save('operations.json',operations);save('summary.json',summary);
  const result=ingestDeviceTransport(dir);assert.equal(result.status,'PASSED_TRANSPORT_PREFLIGHT');assert.equal(result.candidateInstalledByRunner,false);
  save('device.json',{...device,Serial:'forbidden'});assert.throws(()=>ingestDeviceTransport(dir));
  save('device.json',device);save('operations.json',operations.map((entry,i)=>i===0?{...entry,Raw:'forbidden'}:entry));assert.throws(()=>ingestDeviceTransport(dir));
  save('operations.json',operations);save('summary.json',{...summary,AfterTaps:6});assert.throws(()=>ingestDeviceTransport(dir));
  save('summary.json',{...summary,Status:'FAIL',Reason:'INPUT_NOT_DELIVERED',AfterTaps:4,CounterIncremented:false});
  assert.equal(ingestDeviceTransport(dir).status,'FAIL');
  rmSync(join(dir,'device.json'));save('operations.json',[{OperationCategory:'ADB_STATE',ExitCode:1,StderrClass:'OTHER'}]);
  save('summary.json',{...summary,Status:'INVALID',Reason:'ADB_OPERATION_REJECTED',SourceCommit:null,FixtureSha256:null,DeviceEvidenceSha256:null,
    AdbAuthorized:false,MetadataComplete:false,BundleVerified:false,InstalledFixtureHashVerified:false,FixtureReady:false,BeforeTaps:null,AfterTaps:null,
    CounterIncremented:false,RejectedOperation:'ADB_STATE'});
  assert.equal(ingestDeviceTransport(dir).status,'INVALID');
}));

test("bounded generic oracle calibration cannot create qualification rows or promote telemetry",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const runnerPermission={UsageAccessRunner:'ENABLED',AccessibilityRunner:'ENABLED',UsageAccessVerificationSource:'CMD_APPOPS_GET_GET_USAGE_STATS',
    AccessibilityVerificationSource:'SECURE_SETTINGS_CURRENT_USER_COMPONENT_NAME',UsageAccessParseResult:'MODE_ALLOWED',AccessibilityParseResult:'GLOBAL_ENABLED_COMPONENT_MATCH_FULL'};
  const permission={UsageAccessRunner:'ENABLED',AccessibilityRunner:'ENABLED',ServiceHeartbeat:'FRESH',CandidateHealth:'HEALTHY',CandidateEligible:'ELIGIBLE',
    UsageAccessVerificationSource:'CMD_APPOPS_GET_GET_USAGE_STATS',AccessibilityVerificationSource:'SECURE_SETTINGS_CURRENT_USER_COMPONENT_NAME',
    UsageAccessParseResult:'MODE_ALLOWED',AccessibilityParseResult:'GLOBAL_ENABLED_COMPONENT_MATCH_FULL'};
  const device={Schema:2,Manufacturer:'samsung',Model:'SM-X000',AndroidVersion:'16',ApiLevel:'36',SecurityPatch:'2026-08-05',BuildId:'BP2A.260805.001',
    BatteryManagement:{BatterySaver:'DISABLED',AdaptiveBattery:'ENABLED',AppStandby:'ENABLED',OemBatteryManagement:'UNSPECIFIED'},
    RequiredPermissionState:{UsageAccess:'GRANTED',AccessibilityService:'GRANTED'},RunnerPermissionVerification:runnerPermission};
  const operations=['ADB_STATE','DEVICE_METADATA','BATTERY_STATE','CANDIDATE_INSTALL','CANDIDATE_PATH','CANDIDATE_PULL','FIXTURE_INSTALL','FIXTURE_PATH','FIXTURE_PULL','CANDIDATE_OPEN','CANDIDATE_STATE','CANDIDATE_CLEAR','FIXTURE_OPEN','FIXTURE_STATE','INPUT_TAP','CANDIDATE_ARM']
    .map(OperationCategory=>({OperationCategory,ExitCode:0,StderrClass:'NONE'}));
  const summary={Protocol:'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION',Status:'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY',Reason:'COMPLETED',
    SourceCommit:'a'.repeat(40),CandidateSha256:'b'.repeat(64),FixtureSha256:'c'.repeat(64),TransportEvidenceProtocol:'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT',
    TransportDeviceEvidenceSha256:'d'.repeat(64),
    PositiveControl:true,BlockedControl:true,ServiceContinuous:true,PhysicalAgreement:'PASS',CleanupVerified:true,Revision:8,LatencyMs:120,HoldMillis:10010,
    InjectedBlockedTaps:20,CalibrationSamples:1,QualificationSamples:0,CandidateTelemetryCorroboratingOnly:true,FixtureIndependentPackageAndUid:true,
    SharedState:false,NodeTextContentAccess:false,Screenshots:false,NetworkChanged:false,PermissionsChangedByRunner:false,DestructiveAction:false,
    PermissionVerification:permission};
  save('device.json',device);save('permission-verification.json',permission);save('operations.json',operations);save('summary.json',summary);
  assert.equal(ingestOracleCalibration(dir).qualificationSamples,0);
  save('summary.json',{...summary,PhysicalAgreement:'UNRECORDED'});assert.throws(()=>ingestOracleCalibration(dir));
  save('summary.json',{...summary,QualificationSamples:1});assert.throws(()=>ingestOracleCalibration(dir));
  save('summary.json',{...summary,CandidateTelemetryCorroboratingOnly:false});assert.throws(()=>ingestOracleCalibration(dir));
  save('summary.json',summary);save('permission-verification.json',{...permission,AccessibilityRunner:'UNKNOWN'});assert.throws(()=>ingestOracleCalibration(dir));
  rmSync(join(dir,'permission-verification.json'));
  const {PermissionVerification,...historicalSummary}=summary;
  save('summary.json',{...historicalSummary,Status:'INVALID',Reason:'REQUIRED_PERMISSION_STATE_NOT_VERIFIED',PositiveControl:false,BlockedControl:false,
    ServiceContinuous:false,PhysicalAgreement:'UNRECORDED',Revision:null,LatencyMs:null,HoldMillis:0,InjectedBlockedTaps:0,CalibrationSamples:0});
  assert.equal(ingestOracleCalibration(dir).status,'INVALID');
}));

test("runner-v2 derivation and runner-v4 typed ARM host evidence preserve zero-sample boundaries",()=>temporary(dir=>{
  const save=(name,value)=>writeFileSync(join(dir,name),JSON.stringify(value));
  const permission={UsageAccessRunner:'ENABLED',AccessibilityRunner:'ENABLED',ServiceHeartbeat:'FRESH',CandidateHealth:'HEALTHY',CandidateEligible:'ELIGIBLE',
    UsageAccessVerificationSource:'CMD_APPOPS_GET_GET_USAGE_STATS',AccessibilityVerificationSource:'SECURE_SETTINGS_CURRENT_USER_COMPONENT_NAME',
    UsageAccessParseResult:'MODE_ALLOWED',AccessibilityParseResult:'GLOBAL_ENABLED_COMPONENT_MATCH_FULL'};
  const operations=['ADB_STATE','FIXTURE_OPEN','FIXTURE_STATE','INPUT_TAP','FIXTURE_STATE','CANDIDATE_STATE','CANDIDATE_ARM','CANDIDATE_STATE','CANDIDATE_CLEAR']
    .map(OperationCategory=>({OperationCategory,ExitCode:0,StderrClass:'NONE'}));
  const summary={Protocol:'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION',Status:'INVALID',Reason:'HOST_EXCEPTION',SourceCommit:'c'.repeat(40),
    CandidateSha256:'a'.repeat(64),FixtureSha256:'b'.repeat(64),TransportEvidenceProtocol:'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT',
    TransportDeviceEvidenceSha256:'d'.repeat(64),PositiveControl:true,BlockedControl:false,ServiceContinuous:false,PhysicalAgreement:'UNRECORDED',
    PermissionVerification:permission,CleanupVerified:true,Revision:null,LatencyMs:null,HoldMillis:0,InjectedBlockedTaps:0,CalibrationSamples:0,
    QualificationSamples:0,CandidateTelemetryCorroboratingOnly:true,FixtureIndependentPackageAndUid:true,SharedState:false,NodeTextContentAccess:false,
    Screenshots:false,NetworkChanged:false,PermissionsChangedByRunner:false,DestructiveAction:false};
  save('permission-verification.json',permission);save('operations.json',operations);save('summary.json',summary);
  let result=ingestOracleCalibration(dir);
  assert.equal(result.permissionVerificationPassed,true);
  assert.equal(result.hostStage,'ARM');
  assert.equal(result.hostStageSource,'DERIVED_FROM_V2_ARTIFACT_SEQUENCE');
  assert.equal(result.exceptionClass,'UNSPECIFIED_V2_NOT_RETAINED');
  assert.equal(result.cleanupStatus,'VERIFIED');
  const host={Schema:1,HostStage:'ARM',ExceptionClass:'PROPERTY_NOT_FOUND_EXCEPTION',PrimaryReason:'INVALID:HOST_EXCEPTION',
    FinalizationStatus:'COMPLETED',CleanupStatus:'VERIFIED'};
  save('summary.json',{...summary,HostDiagnostic:host});result=ingestOracleCalibration(dir);
  assert.equal(result.status,'INVALID');assert.equal(result.reason,'HOST_EXCEPTION');assert.equal(result.calibrationSamples,0);
  assert.equal(result.qualificationSamples,0);assert.equal(result.hostStageSource,'CAPTURED_RUNNER_V3');
  assert.equal(result.exceptionClass,'PROPERTY_NOT_FOUND_EXCEPTION');assert.equal(result.finalizationStatus,'COMPLETED');assert.equal(result.cleanupStatus,'VERIFIED');
  save('summary.json',{...summary,HostDiagnostic:{...host,ExceptionMessage:'forbidden raw detail'}});
  assert.throws(()=>ingestOracleCalibration(dir));
}));

test("new-device runners stay transport-first, generic and privacy bounded",()=>{
  const transport=readFileSync(resolve('tools/kr003/Test-KR003-DeviceTransport.ps1'),'utf8');
  const calibration=readFileSync(resolve('tools/kr003/Test-KR003-OracleCalibration.ps1'),'utf8');
  const preflightPackager=readFileSync(resolve('tools/kr003/package-device-preflight.mjs'),'utf8');
  const calibrationPackager=readFileSync(resolve('tools/kr003/package-oracle-calibration.mjs'),'utf8');
  assert.match(transport,/CandidateInstalledByRunner=\$false/);assert.doesNotMatch(preflightPackager,/'candidate\.apk'/);
  assert.match(transport,/Invoke-DeviceAdb 'INPUT_TAP'/);assert.match(calibration,/QualificationSamples=0/);
  assert.match(calibration,/permission-verification\.json/);assert.match(calibration,/settings','--user','current','get','secure','enabled_accessibility_services/);
  assert.match(calibrationPackager,/runnerVersion:5/);
  assert.match(calibration,/HostDiagnostic=Get-KRCalibrationHostDiagnostic/);
  for(const source of [transport,calibration]) assert.doesNotMatch(source,/ro\.serialno|ro\.build\.fingerprint|ANDROID_ID|screencap|uiautomator|dumpsys\s+window/i);
  assert.doesNotMatch(calibration,/for\([^\n]+-le 100|OfflineNetwork|svc[^\n]+disable/i);
});
