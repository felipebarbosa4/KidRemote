import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { createHash } from "node:crypto";
import assert from "node:assert/strict";
const decode = path => readFileSync(path,"utf8").replace(/^\uFEFF/,"");
const hash = path => createHash("sha256").update(readFileSync(path)).digest("hex");

function ingestQ7(directory, manifest, rows, summary, read) {
  assert.equal(manifest.Bundle.runnerVersion,7);
  assert.equal(manifest.Bundle.diagnosticOnly,false);
  assert.equal(manifest.Bundle.requiresOffline,true);
  assert.equal(manifest.Bundle.oracleModel,'ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS');
  assert.equal(manifest.Bundle.humanCheckpointMaximum,3);
  assert.equal(manifest.Bundle.candidateSha256,'5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b');
  assert.match(manifest.Bundle.fixtureSha256,/^[a-f0-9]{64}$/);
  assert.equal(manifest.EvidenceModel,'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS');
  assert.equal(summary.EvidenceModel,'ACTIVE_FIXTURE_ORACLE_PLUS_THREE_HUMAN_CHECKPOINTS');
  assert.equal(new Set(rows.map(r=>`${r.Phase}:${r.Attempt}`)).size,rows.length,'Duplicate attempt');
  const qualificationRows=rows.filter(r=>r.Phase==='QUALIFICATION');
  const completed=qualificationRows.filter(r=>r.AutomatedOracle==='PASS'&&r.InputOracle==='PASS');
  assert(completed.every((r,i)=>r.Attempt===i+1),'Completed active-oracle attempts must be consecutive');
  assert.equal(new Set(completed.map(r=>r.Revision)).size,completed.length,'Duplicate active-oracle revision');
  const finalStatuses=['PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY','FAILED_P95'];
  if(!finalStatuses.includes(summary.Status)) {
    const checkpoints=existsSync(resolve(directory,'human-checkpoints.json'))?read('human-checkpoints.json'):[];
    return {sourceCommit:manifest.Bundle.sourceCommit,status:summary.Status,reason:summary.Reason,
      automatedExpiryCycles:completed.length,humanCheckpointSessions:checkpoints.length,partial:true,kr003Complete:false};
  }
  assert.equal(manifest.OfflineNetworkRequested,true);
  assert.equal(manifest.OfflineOwnerConfirmed,true);
  const calibration=read('calibration.json');
  assert.equal(calibration.Phase,'CALIBRATION');
  assert.equal(calibration.PhysicalObserver,'PASS');
  assert.equal(calibration.AutomatedOracle,'PASS');
  assert.equal(calibration.InputOracle,'PASS');
  assert.equal(qualificationRows.length,100);
  assert.equal(completed.length,100);
  assert(completed.every((r,i)=>r.Attempt===i+1&&r.PhysicalObserver==='NOT_SAMPLED'));
  assert(completed.every(r=>Number.isInteger(r.LatencyMs)&&r.LatencyMs>=0&&r.HoldMillis>=10000&&r.InjectedBlockedTaps>=20&&r.PositiveControlTap==='REACHED_FIXTURE'));
  assert.equal(new Set(completed.map(r=>r.Revision)).size,100);
  const checkpoints=read('human-checkpoints.json');
  assert.deepEqual(checkpoints.map(c=>[c.Name,c.Result]),[
    ['PREFLIGHT_NORMAL_PASS','PASS'],
    ['PREFLIGHT_NEGATIVE_CONTROL','PASS'],
    ['POST_RUN_SAFETY','PASS'],
  ]);
  assert.equal(summary.HumanCheckpointSessions,3);
  assert.equal(summary.PhysicalExpiryObservations,2);
  const safety=read('safety-final.json'), diagnostic=read('recovery-final.json');
  assert.equal(safety.Phase,'final');
  assert.equal(safety.Result,'PHYSICAL_PASS_RECORDED');
  assert.equal(safety.FinalVisibilityPhysical,'PASS');
  assert.equal(safety.HomePhysical,'PASS');
  assert.equal(safety.RecoveryReason,'PHYSICAL_PASS_RECORDED');
  assert.equal(safety.ReentryPhysical,'PASS');
  assert.equal(safety.ClearTouch,'FIXTURE_COUNTER_INCREMENT');
  assert.deepEqual(diagnostic.Phases.map(p=>[p.Name,p.PhysicalResult,p.Oracle]),[
    ['SETTINGS_ROOT','PASS','SAFE_TRANSITION_CORROBORATED'],
    ['DIGITAL_WELLBEING_ATTEMPT','FAIL','ORDINARY_REATTACHMENT_CORROBORATED'],
    ['RECOVERY_BUTTON_ATTEMPT','PASS','FRESH_SAFE_TRANSITION_CORROBORATED'],
    ['POST_RECOVERY_STATE','UNRECORDED','SAFE_STATE_OBSERVED'],
  ]);
  const recovery=diagnostic.Phases[2];
  assert(recovery.LastElapsed-recovery.SafeTransitionElapsed>=10000&&!recovery.ReattachedAfterSafe&&!recovery.UnknownAfterSafe);
  const final=read('final-metrics.json');
  assert.deepEqual(final.samples,completed.map(r=>r.LatencyMs));
  assert.equal(final.sampleCount,100);
  const sorted=completed.map(r=>r.LatencyMs).sort((a,b)=>a-b);
  const stats={Count:100,P50:sorted[49],P95:sorted[94],Max:sorted[99]};
  assert.deepEqual(summary.InternalPairedStatistics,stats);
  assert.equal(summary.ValidPairedObservations,100);
  assert.equal(summary.Status,stats.P95>2000?'FAILED_P95':'PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY');
  assert.equal(summary.Offline,true);
  assert.equal(summary.SafetyChecksPassed,true);
  assert.deepEqual(summary.FinalizationErrors,[]);
  const restored=read('network-restoration.json'), bailout=read('diagnostic-bailout.json');
  assert.equal(restored.Status,'RESTORED_AND_FLAGS_VERIFIED');
  assert.equal(bailout.Status,'VERIFIED');
  assert.equal(bailout.RestrictionReleased,true);
  assert.equal(bailout.LatencySamplesPreserved,true);
  return {sourceCommit:manifest.Bundle.sourceCommit,status:summary.Status,automatedExpiryCycles:100,
    physicalExpiryObservations:2,humanCheckpointSessions:3,stats,kr003Complete:false};
}

export function ingestCheckpoint(csvPath, tracePath) {
  const lines = decode(csvPath).trim().split(/\r?\n/);
  const rows = lines.map(l=>l.split(",").map(cell=>{
    assert(/^"[^"\r\n]*"$/.test(cell),"Unexpected checkpoint CSV syntax");
    return cell.slice(1,-1);
  }));
  assert.deepEqual(rows.shift(),["Cycle","ClearRestoredOrdinaryUse","ExpiryPersistence","PhysicalHome","SettingsRecovery","OrdinaryReentry"]);
  assert.equal(rows.length,10);
  rows.forEach((row,i)=>assert.deepEqual(row,[String(i+1),"usable","persistent-block","blocked","usable","persistent-block"]));
  const trace = decode(tracePath).trim().split(/\r?\n/);
  const eventLines = trace.filter(l=>!/^--------- beginning of (main|system)$/.test(l));
  return { cycles:10, successfulObserverCycles:10, csvSha256:hash(csvPath),traceSha256:hash(tracePath),
    capturedEventLines:eventLines.length, traceComplete:eventLines.length>0, internalSampleCount:"UNSPECIFIED",
    physicalTrialsNotObservationColumns:true };
}

export function ingestQualification(directory) {
  const read = name => JSON.parse(decode(resolve(directory,name)));
  const manifest = read("manifest.json"), rows = read("attempts.json");
  const summary = existsSync(resolve(directory,"summary.json")) ? read("summary.json") : null;
  assert(["KR003-Q1","KR003-Q2","KR003-Q6-MI8-OFFLINE-QUALIFICATION","KR003-Q7-MI8-ACTIVE-ORACLE-QUALIFICATION"].includes(manifest.Bundle.protocol));
  assert.match(manifest.Bundle.sourceCommit,/^[a-f0-9]{40}$/);
  assert(Array.isArray(rows),"Attempt journal must be an array");
  if(manifest.Bundle.protocol==='KR003-Q7-MI8-ACTIVE-ORACLE-QUALIFICATION') {
    assert(summary,'Q7 requires a finalized summary');
    return ingestQ7(directory,manifest,rows,summary,read);
  }
  const completed = rows.filter(r=>r.Phase==="QUALIFICATION"&&r.Observer==="PASS"&&r.Automated==="PASS");
  assert.equal(new Set(rows.map(r=>`${r.Phase}:${r.Attempt}`)).size,rows.length,"Duplicate attempt");
  assert(completed.every((r,i)=>r.Attempt===i+1),"Completed attempts must be consecutive");
  assert.equal(new Set(completed.map(r=>r.Revision)).size,completed.length,"Duplicate revision");
  assert(completed.every(r=>Number.isInteger(r.LatencyMs)&&r.LatencyMs>=0&&r.HoldMillis>=10000),"Unpaired/short observation");
  const sorted=completed.map(r=>r.LatencyMs).sort((a,b)=>a-b);
  const stats= sorted.length ? {count:sorted.length,p50:sorted[Math.ceil(.5*sorted.length)-1],p95:sorted[Math.ceil(.95*sorted.length)-1],max:sorted.at(-1)} : {count:0};
  if(!summary) return {sourceCommit:manifest.Bundle.sourceCommit,attempts:rows.length,validPairedObservations:completed.length,stats,status:"INCOMPLETE_MISSING_SUMMARY",calibration:existsSync(resolve(directory,"calibration.json")) ? read("calibration.json") : null,physicalRecoveryObservation:"UNSPECIFIED",networkRestoration:"UNSPECIFIED",kr003Complete:false};
  if(summary.StatisticsAvailable===false) return {sourceCommit:manifest.Bundle.sourceCommit,status:summary.Status,reason:summary.Reason,independentlyComputedStats:stats,reportingIncomplete:true,kr003Complete:false};
  assert.equal(summary.ValidPairedObservations,completed.length,"Host summary count mismatch");
  if(!sorted.length) assert.equal(summary.InternalPairedStatistics.Count,0);
  if(sorted.length) {
    assert.deepEqual(summary.InternalPairedStatistics,{Count:stats.count,P50:stats.p50,P95:stats.p95,Max:stats.max},"Host summary percentile mismatch");
  }
  if(summary.Status==='CALIBRATION_COMPLETED_ONLY') {
    assert.equal(manifest.CalibrationOnly,true);
    assert.equal(summary.QualificationRequested,false);
    assert.equal(rows.filter(r=>r.Phase==='QUALIFICATION').length,0);
    const calibration=read('calibration.json'), safety=read('safety-calibration.json');
    assert.deepEqual(rows,[calibration]);
    assert.equal(calibration.Observer,'PASS');
    assert.equal(calibration.Automated,'PASS');
    assert.equal(safety.PhysicalHomeAndSettings,'OWNER_PASS');
    assert.equal(safety.Oracle,'CORROBORATED');
    assert.equal(safety.Reentry,'OWNER_PASS');
    assert.equal(safety.ClearTouch,'FIXTURE_COUNTER_INCREMENT');
  }
  const qualified = ["PASSED_THIS_CONFIGURATION_ONLY","ONLINE_ONLY_OFFLINE_GATE_OPEN","FAILED_P95"].includes(summary.Status);
  if(qualified) {
    assert.equal(rows.filter(r=>r.Phase==='QUALIFICATION').length,100,"No hidden invalid/failed qualification attempt allowed");
    assert.equal(completed.length,100);
    assert.equal(summary.SafetyChecksPassed,true);
    assert.equal(summary.Kr003Complete,false);
    const calibration=read("calibration.json");
    assert.equal(calibration.Phase,"CALIBRATION");
    assert.equal(calibration.Observer,"PASS");
    assert.equal(calibration.Automated,"PASS");
    if(['KR003-Q2','KR003-Q6-MI8-OFFLINE-QUALIFICATION'].includes(manifest.Bundle.protocol)) {
      assert.equal(summary.QualificationRequested,true);
      assert.deepEqual(rows.filter(r=>r.Phase==='CALIBRATION'),[calibration],"Calibration must survive in the attempt journal");
      if(manifest.Bundle.protocol==='KR003-Q6-MI8-OFFLINE-QUALIFICATION') {
        assert.equal(calibration.HoldMillis>=10000,true,"Calibration physical hold is incomplete");
      }
      assert.deepEqual(summary.FinalizationErrors,[],"Cleanup/reporting failure cannot qualify");
      const restored=read('network-restoration.json');
      assert(!String(restored.Status).includes('FAILED'),"Radio restoration must not be silently unverified");
    }
    if(manifest.Bundle.protocol==='KR003-Q6-MI8-OFFLINE-QUALIFICATION') {
      assert.equal(manifest.Bundle.diagnosticOnly,false);
      assert.equal(manifest.Bundle.requiresOffline,true);
      assert.equal(manifest.Bundle.runnerVersion,6);
      assert.equal(manifest.Bundle.candidateSha256,'5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b');
      assert.equal(manifest.Bundle.fixtureSha256,'6653f10b527cc9a273a8c0ea045cd250f6978c1acfb8e92b00b701f6c14f84bb');
      assert.equal(manifest.Bundle.calibratedBy?.runId,'run-20260906-171929-69a3abda');
      assert.equal(manifest.OfflineNetworkRequested,true);
      assert.equal(manifest.OfflineOwnerConfirmed,true);
      assert.equal(manifest.CalibrationOnly,false);
      assert.equal(manifest.RecoveryDiagnostic,false);
      assert.equal(summary.Offline,true);
      assert.equal(summary.RecoveryDiagnosticRequested,false);
      const bailout=read('diagnostic-bailout.json');
      assert.equal(bailout.Status,'VERIFIED');
      assert.equal(bailout.RestrictionReleased,true);
      assert.equal(bailout.LatencySamplesPreserved,true);
      assert.equal(bailout.ConsumerRecoveryEvidence,false);
      assert.equal(bailout.AppDataCleared,false);
      assert.equal(bailout.Uninstalled,false);
      assert.equal(bailout.PermissionsAltered,false);
      const restored=read('network-restoration.json');
      assert.equal(restored.Status,'RESTORED_AND_FLAGS_VERIFIED');
      for(const phase of ['calibration','final']) {
        const safety=read(`safety-${phase}.json`), diagnostic=read(`recovery-${phase}.json`);
        assert.equal(safety.Protocol,manifest.Bundle.protocol);
        assert.equal(safety.Phase,phase);
        assert.equal(safety.HomePhysical,'PASS');
        assert.equal(safety.HoldOracle,'RESTRICTION_HELD');
        assert.equal(safety.RecoveryFile,`recovery-${phase}.json`);
        assert.equal(safety.RecoveryReason,'PHYSICAL_PASS_RECORDED');
        assert.equal(safety.ReentryPhysical,'PASS');
        assert.equal(safety.ReentryOracle,'ORDINARY_RESTRICTION_HELD');
        assert.equal(safety.ClearTouch,'FIXTURE_COUNTER_INCREMENT');
        assert.equal(safety.Result,'PHYSICAL_PASS_RECORDED');
        assert.equal(safety.IndependentExpirySamples,0);
        assert.equal(diagnostic.Protocol,manifest.Bundle.protocol);
        assert.equal(diagnostic.EqualityDiagnosticImplemented,false);
        assert.equal(diagnostic.UsesRawPackageOrComponentIdentity,false);
        assert.deepEqual(diagnostic.Phases.map(p=>[p.Name,p.PhysicalResult,p.Oracle]),[
          ['SETTINGS_ROOT','PASS','SAFE_TRANSITION_CORROBORATED'],
          ['DIGITAL_WELLBEING_ATTEMPT','FAIL','ORDINARY_REATTACHMENT_CORROBORATED'],
          ['RECOVERY_BUTTON_ATTEMPT','PASS','FRESH_SAFE_TRANSITION_CORROBORATED'],
          ['POST_RECOVERY_STATE','UNRECORDED','SAFE_STATE_OBSERVED'],
        ]);
        const recovery=diagnostic.Phases[2];
        assert(recovery.SafeTransitionElapsed>=0 && recovery.LastElapsed-recovery.SafeTransitionElapsed>=10000,'Recovery stable-safe interval is too short');
        assert.equal(recovery.LastDisposition,'SAFE_SYSTEM');
        assert.equal(recovery.LastAttached,false);
        assert.equal(recovery.ReattachedAfterSafe,false);
        assert.equal(recovery.UnknownAfterSafe,false);
        for(let i=1;i<diagnostic.Phases.length;i++) assert(diagnostic.Phases[i].AfterSequence>=diagnostic.Phases[i-1].LastSequence,'Diagnostic phases overlap');
      }
    } else {
      for(const phase of ["calibration","final"]) {
        const safety=read(`safety-${phase}.json`);
        assert.equal(safety.PhysicalHomeAndSettings,"OWNER_PASS");
        assert.equal(safety.Reentry,"OWNER_PASS");
        assert.equal(safety.ClearTouch,"FIXTURE_COUNTER_INCREMENT");
        assert.equal(safety.IndependentExpirySamples,0);
        if(manifest.Bundle.protocol==='KR003-Q2') assert.equal(safety.Oracle,'CORROBORATED');
      }
    }
    const final=read("final-metrics.json");
    assert.deepEqual(final.samples,completed.map(r=>r.LatencyMs),"Final metrics must match paired rows");
    assert.equal(final.sampleCount,100);
    assert.equal(summary.Status,stats.p95>2000 ? "FAILED_P95" : summary.Offline ? "PASSED_THIS_CONFIGURATION_ONLY" : "ONLINE_ONLY_OFFLINE_GATE_OPEN");
    assert.equal(manifest.OfflineOwnerConfirmed,summary.Offline);
  }
  return { sourceCommit:manifest.Bundle.sourceCommit,attempts:rows.length,validPairedObservations:completed.length,stats,
    status:summary.Status,physicalObserverSource:"operator entries",kr003Complete:false };
}

export function ingestRecoveryDiagnostic(directory) {
  const read = name => JSON.parse(decode(resolve(directory,name)));
  const manifest=read('manifest.json'), summary=read('summary.json'), diagnostic=read('recovery-diagnostic.json');
  assert(['KR003-Q3-RECOVERY-DIAGNOSTIC','KR003-Q4-RECOVERY-REPAIR-CALIBRATION','KR003-Q5-RECOVERY-TASK-RESET-CALIBRATION'].includes(manifest.Bundle.protocol));
  assert.equal(manifest.Bundle.diagnosticOnly,true);
  assert.equal(manifest.RecoveryDiagnostic,true);
  assert.equal(summary.QualificationRequested,false);
  assert.equal(summary.RecoveryDiagnosticRequested,true);
  assert.equal(summary.Kr003Complete,false);
  assert.equal(summary.ProductionApproved,false);
  assert.equal(diagnostic.Protocol,manifest.Bundle.protocol);
  assert.equal(diagnostic.EqualityDiagnosticImplemented,false);
  assert.equal(diagnostic.UsesRawPackageOrComponentIdentity,false);
  assert(Array.isArray(diagnostic.Phases));
  const expected=['SETTINGS_ROOT','DIGITAL_WELLBEING_ATTEMPT','RECOVERY_BUTTON_ATTEMPT','POST_RECOVERY_STATE'];
  assert.deepEqual(diagnostic.Phases.map(p=>p.Name),expected.slice(0,diagnostic.Phases.length));
  for(let i=0;i<diagnostic.Phases.length;i++) {
    const phase=diagnostic.Phases[i];
    // Q3 on Windows PowerShell 5.1 serialized the no-prompt post-state's
    // explicit null argument as "". Accept that historical representation
    // only for POST_RECOVERY_STATE and normalize it; prompted phases stay strict.
    if(phase.Name==='POST_RECOVERY_STATE' && phase.PhysicalResult==='') phase.PhysicalResult='UNRECORDED';
    assert(['PASS','FAIL','INVALID','UNRECORDED'].includes(phase.PhysicalResult));
    assert(Number.isInteger(phase.AfterSequence)&&Number.isInteger(phase.LastSequence)&&phase.LastSequence>=phase.AfterSequence);
    if(i) assert(phase.AfterSequence>=diagnostic.Phases[i-1].LastSequence,'Diagnostic phases overlap or reuse an earlier trace floor');
  }
  const bailout=read('diagnostic-bailout.json');
  assert.equal(bailout.Operation,'CLEAR_LAB_TIMER_ONLY');
  assert.equal(bailout.ConsumerRecoveryEvidence,false);
  assert.equal(bailout.AppDataCleared,false);
  assert.equal(bailout.Uninstalled,false);
  assert.equal(bailout.PermissionsAltered,false);
  if(summary.Status==='DIAGNOSTIC_COMPLETED_ONLY') {
    assert.equal(diagnostic.Phases.length,4);
    assert.equal(diagnostic.Result,'EVIDENCE_CAPTURED');
    assert.equal(bailout.Status,'VERIFIED');
    assert.equal(bailout.RestrictionReleased,true);
    assert.equal(bailout.LatencySamplesPreserved,true);
    assert.deepEqual(summary.FinalizationErrors,[]);
  }
  return {
    sourceCommit:manifest.Bundle.sourceCommit,status:summary.Status,reason:summary.Reason,
    phases:diagnostic.Phases.map(({Name,PhysicalResult,Oracle})=>({name:Name,physicalResult:PhysicalResult,oracle:Oracle})),
    bailout:bailout.Status,qualificationSamples:0,kr003Complete:false,
  };
}

export function ingestOracleTransport(directory) {
  const read=name=>JSON.parse(decode(resolve(directory,name)));
  const summary=read('summary.json'),operations=read('operations.json');
  assert.equal(summary.Protocol,'KR003-Q7-ORACLE-TRANSPORT-PREFLIGHT');
  assert.match(summary.SourceCommit,/^[a-f0-9]{40}$/);
  assert.match(summary.FixtureSha256,/^[a-f0-9]{64}$/);
  assert.equal(summary.RestrictionChanged,false);
  assert.equal(summary.RadiosChanged,false);
  assert.equal(summary.PermissionsChanged,false);
  assert.equal(summary.DestructiveAction,false);
  assert.equal(summary.Q7Samples,0);
  assert(Array.isArray(operations)&&operations.length>=4);
  const categories=['DEVICE_STATE','FIXTURE_INSTALL','FIXTURE_OPEN','FIXTURE_STATE','INPUT_TAP'];
  const classes=['NONE','SECURITY_EXCEPTION','PERMISSION_DENIAL','OTHER'];
  for(const operation of operations) {
    assert.deepEqual(Object.keys(operation),['OperationCategory','ExitCode','StderrClass']);
    assert(categories.includes(operation.OperationCategory));
    assert(Number.isInteger(operation.ExitCode));
    assert(classes.includes(operation.StderrClass));
  }
  assert(operations.some(x=>x.OperationCategory==='FIXTURE_STATE'&&x.ExitCode===0));
  assert.equal(summary.FixtureReceiverWorked,true);
  if(summary.Status==='PASSED_TRANSPORT_PREFLIGHT') {
    assert.equal(summary.Reason,'FIXTURE_COUNTER_INCREMENTED_ONCE');
    assert.equal(summary.CounterIncremented,true);
    assert.equal(summary.AfterTaps,summary.BeforeTaps+1);
    assert.equal(summary.RejectedOperation,null);
  } else if(summary.Status==='INVALID'&&summary.Reason==='ADB_OPERATION_REJECTED') {
    assert(categories.includes(summary.RejectedOperation));
    const rejected=operations.findLast(x=>x.OperationCategory===summary.RejectedOperation&&x.ExitCode===summary.RejectedExitCode&&x.StderrClass===summary.RejectedStderrClass);
    assert(rejected,'Rejected summary must match a sanitized operation record');
    assert.equal(summary.CounterIncremented,false);
  } else {
    assert.equal(summary.Status,'FAILED');
    assert.equal(summary.Reason,'INPUT_NOT_DELIVERED');
  }
  return {sourceCommit:summary.SourceCommit,status:summary.Status,reason:summary.Reason,receiverWorked:summary.FixtureReceiverWorked,
    counterIncremented:summary.CounterIncremented,rejectedOperation:summary.RejectedOperation,rejectedExitCode:summary.RejectedExitCode,
    rejectedStderrClass:summary.RejectedStderrClass,q7Samples:0,kr003Complete:false};
}

const deviceOperationCategories=['ADB_STATE','DEVICE_METADATA','BATTERY_STATE','CANDIDATE_INSTALL_STATE','USAGE_ACCESS_STATE','ACCESSIBILITY_STATE',
  'FIXTURE_INSTALL','FIXTURE_PATH','FIXTURE_PULL','FIXTURE_OPEN','FIXTURE_STATE','INPUT_TAP','CANDIDATE_INSTALL','CANDIDATE_PATH',
  'CANDIDATE_PULL','CANDIDATE_OPEN','CANDIDATE_STATE','CANDIDATE_CLEAR','CANDIDATE_ARM'];
function validateDeviceOperations(operations,allowEmpty=false) {
  assert(Array.isArray(operations)&&(allowEmpty||operations.length>0));
  for(const operation of operations) {
    assert.deepEqual(Object.keys(operation),['OperationCategory','ExitCode','StderrClass']);
    assert(deviceOperationCategories.includes(operation.OperationCategory));
    assert(Number.isInteger(operation.ExitCode));
    assert(['NONE','SECURITY_EXCEPTION','PERMISSION_DENIAL','OTHER'].includes(operation.StderrClass));
  }
}
function validateGenericDevice(device) {
  assert.deepEqual(Object.keys(device),['Schema','Manufacturer','Model','AndroidVersion','ApiLevel','SecurityPatch','BuildId','BatteryManagement','RequiredPermissionState']);
  assert.equal(device.Schema,1);
  for(const key of ['Manufacturer','Model','AndroidVersion','BuildId']) assert.match(device[key],/^[A-Za-z0-9][A-Za-z0-9 ._+()/:,-]{0,119}$/);
  assert.match(device.ApiLevel,/^[0-9]{1,3}$/);
  assert.match(device.SecurityPatch,/^20[0-9]{2}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])$/);
  assert.deepEqual(Object.keys(device.BatteryManagement),['BatterySaver','AdaptiveBattery','AppStandby','OemBatteryManagement']);
  for(const key of ['BatterySaver','AdaptiveBattery','AppStandby']) assert(['ENABLED','DISABLED','UNSPECIFIED'].includes(device.BatteryManagement[key]));
  assert.equal(device.BatteryManagement.OemBatteryManagement,'UNSPECIFIED');
  assert.deepEqual(Object.keys(device.RequiredPermissionState),['UsageAccess','AccessibilityService']);
  for(const value of Object.values(device.RequiredPermissionState)) assert(['GRANTED','NOT_GRANTED','UNSPECIFIED','NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED'].includes(value));
  for(const forbidden of ['Serial','Account','AndroidId','BuildFingerprint','PackageHistory']) assert.equal(Object.hasOwn(device,forbidden),false);
}

export function ingestDeviceTransport(directory) {
  const read=name=>JSON.parse(decode(resolve(directory,name))),summary=read('summary.json'),operations=read('operations.json');
  assert.equal(summary.Protocol,'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT');
  const deviceExists=existsSync(resolve(directory,'device.json')),device=deviceExists?read('device.json'):null;
  if(deviceExists) { validateGenericDevice(device);assert.match(summary.DeviceEvidenceSha256,/^[a-f0-9]{64}$/);assert.equal(summary.DeviceEvidenceSha256,hash(resolve(directory,'device.json'))); }
  validateDeviceOperations(operations,summary.Status==='INVALID');
  for(const key of ['CandidateInstalledByRunner','TimerUsed','RestrictionChanged','RadiosChanged','PermissionsChanged','DestructiveAction']) assert.equal(summary[key],false);
  assert.equal(summary.QualificationSamples,0);
  if(summary.Status==='PASSED_TRANSPORT_PREFLIGHT') {
    assert.match(summary.SourceCommit,/^[a-f0-9]{40}$/);assert.match(summary.FixtureSha256,/^[a-f0-9]{64}$/);assert(deviceExists);
    assert.equal(summary.AdbAuthorized,true);assert.equal(summary.MetadataComplete,true);assert.equal(summary.BundleVerified,true);
    assert(operations.some(operation=>operation.OperationCategory==='DEVICE_METADATA'&&operation.ExitCode===0));
    assert(operations.some(operation=>operation.OperationCategory==='FIXTURE_PULL'&&operation.ExitCode===0));
    assert.equal(operations.filter(operation=>operation.OperationCategory==='INPUT_TAP').length,1);
    assert.equal(summary.Reason,'FIXTURE_COUNTER_INCREMENTED_ONCE');assert.equal(summary.InstalledFixtureHashVerified,true);assert.equal(summary.FixtureReady,true);
    assert.equal(summary.CounterIncremented,true);assert.equal(summary.AfterTaps,summary.BeforeTaps+1);assert.equal(summary.RejectedOperation,null);
  } else if(summary.Status==='FAIL') {
    assert.match(summary.SourceCommit,/^[a-f0-9]{40}$/);assert.match(summary.FixtureSha256,/^[a-f0-9]{64}$/);assert(deviceExists);
    assert.equal(summary.AdbAuthorized,true);assert.equal(summary.MetadataComplete,true);assert.equal(summary.BundleVerified,true);
    assert.equal(operations.filter(operation=>operation.OperationCategory==='INPUT_TAP').length,1);
    assert.equal(summary.Reason,'INPUT_NOT_DELIVERED');assert.equal(summary.CounterIncremented,false);
  } else {
    assert.equal(summary.Status,'INVALID');if(summary.RejectedOperation!==null) assert(deviceOperationCategories.includes(summary.RejectedOperation));
  }
  return {sourceCommit:summary.SourceCommit,status:summary.Status,reason:summary.Reason,device,counterIncremented:summary.CounterIncremented,
    candidateInstalledByRunner:false,qualificationSamples:0,kr003Complete:false};
}

export function ingestOracleCalibration(directory) {
  const read=name=>JSON.parse(decode(resolve(directory,name))),summary=read('summary.json'),operations=read('operations.json');
  assert.equal(summary.Protocol,'KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION');validateDeviceOperations(operations,summary.Status==='INVALID');
  assert.equal(summary.QualificationSamples,0);assert.equal(summary.CandidateTelemetryCorroboratingOnly,true);
  for(const key of ['FixtureIndependentPackageAndUid']) assert.equal(summary[key],true);
  for(const key of ['SharedState','NodeTextContentAccess','Screenshots','NetworkChanged','PermissionsChangedByRunner','DestructiveAction']) assert.equal(summary[key],false);
  if(summary.Status==='PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY') {
    assert.match(summary.SourceCommit,/^[a-f0-9]{40}$/);assert.match(summary.CandidateSha256,/^[a-f0-9]{64}$/);assert.match(summary.FixtureSha256,/^[a-f0-9]{64}$/);
    assert.equal(summary.TransportEvidenceProtocol,'KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT');assert.match(summary.TransportDeviceEvidenceSha256,/^[a-f0-9]{64}$/);
    const device=read('device.json');validateGenericDevice(device);
    assert.equal(device.RequiredPermissionState.UsageAccess,'GRANTED');assert.equal(device.RequiredPermissionState.AccessibilityService,'GRANTED');
    assert.equal(summary.Reason,'COMPLETED');assert.equal(summary.PositiveControl,true);assert.equal(summary.BlockedControl,true);
    assert.equal(summary.ServiceContinuous,true);assert.equal(summary.PhysicalAgreement,'PASS');assert.equal(summary.CleanupVerified,true);
    assert.equal(summary.CalibrationSamples,1);assert(Number.isInteger(summary.LatencyMs)&&summary.LatencyMs>=0);
    assert(Number.isInteger(summary.Revision)&&summary.Revision>=0);assert(summary.HoldMillis>=10000);assert.equal(summary.InjectedBlockedTaps,20);
  } else assert(['FAIL','INVALID'].includes(summary.Status));
  return {sourceCommit:summary.SourceCommit,status:summary.Status,reason:summary.Reason,calibrationSamples:summary.CalibrationSamples,
    qualificationSamples:0,physicalAgreement:summary.PhysicalAgreement,kr003Complete:false};
}

export function ingestUiAutomationTransport(directory) { return ingestAlternateTransport(directory,false); }
export function ingestMonkeyTransport(directory) { return ingestAlternateTransport(directory,true); }
function ingestAlternateTransport(directory,monkey) {
  const read=name=>JSON.parse(decode(resolve(directory,name)));
  const s=read('summary.json'),ops=read('operations.json');
  assert.equal(s.Protocol,monkey?'KR003-MONKEY-TRANSPORT-PREFLIGHT':'KR003-UIAUTOMATION-TRANSPORT-PREFLIGHT');
  const touch=monkey?'MONKEY_TOUCH':'UIAUTOMATION_TAP';
  assert.match(s.SourceCommit,/^[a-f0-9]{40}$/);
  for(const key of ['FixtureSha256',monkey?'HelperSha256':'ProbeSha256']) assert.match(s[key],/^[a-f0-9]{64}$/);
  if(monkey) assert(['NOT_NEEDED','REMOVED_AND_VERIFIED','UNVERIFIED'].includes(s.HelperCleanup));
  for(const key of ['RestrictionChanged','RadiosChanged','PermissionsChanged','DestructiveAction']) assert.equal(s[key],false);
  assert.equal(s.Q7Samples,0);
  assert(Array.isArray(ops));
  for(const op of ops) {
    assert.deepEqual(Object.keys(op),['OperationCategory','ExitCode','StderrClass']);
    assert(['DEVICE_STATE','FIXTURE_INSTALL','FIXTURE_OPEN','FIXTURE_STATE',...(monkey?['MONKEY_TOOL_CHECK','HELPER_PUSH','MONKEY_TOUCH','HELPER_REMOVE','HELPER_ABSENCE']:['PROBE_INSTALL','UIAUTOMATION_TAP'])].includes(op.OperationCategory));
    assert(Number.isInteger(op.ExitCode));
    assert(['NONE','SECURITY_EXCEPTION','PERMISSION_DENIAL','OTHER'].includes(op.StderrClass));
  }
  assert(ops.filter(o=>o.OperationCategory===touch).length<=1);
  if(s.ProbeResult!==null) {
    const p=read('probe.json'); assert.deepEqual(s.ProbeResult,p);
    assert.deepEqual(Object.keys(p),['Request','Stage','Outcome','DownAccepted','UpAccepted',...(monkey?[]:['Cleanup'])]);
    assert(Number.isSafeInteger(p.Request)&&p.Request>0);
    assert(['ARGUMENTS','DOWN','UP','COMPLETE',...(monkey?['RESOLVE']:['CONNECT','CONFIGURE'])].includes(p.Stage));
    assert(['INVALID_ARGUMENTS','INJECTED','INPUT_REJECTED','SECURITY_EXCEPTION','OTHER',monkey?'UNSUPPORTED':'CONNECT_UNAVAILABLE'].includes(p.Outcome));
    assert.equal(typeof p.DownAccepted,'boolean'); assert.equal(typeof p.UpAccepted,'boolean');
    if(!monkey) assert.equal(p.Cleanup,'FRAMEWORK_FINISH');
  }
  if(s.Status==='PASSED_TRANSPORT_PREFLIGHT') {
    assert.equal(s.Reason,'FIXTURE_COUNTER_INCREMENTED_ONCE');
    assert(s.FixtureReceiverWorked&&s.CounterIncremented);
    assert.equal(s.RejectedOperation,null);
    assert(ops.every(o=>o.ExitCode===0&& !['SECURITY_EXCEPTION','PERMISSION_DENIAL'].includes(o.StderrClass)));
    assert.equal(ops.filter(o=>o.OperationCategory===touch).length,1);
    if(monkey) {
      assert.equal(s.HelperCleanup,'REMOVED_AND_VERIFIED');
      for(const category of ['HELPER_PUSH','HELPER_REMOVE','HELPER_ABSENCE']) assert.equal(ops.filter(o=>o.OperationCategory===category).length,1);
    }
    assert.equal(s.ProbeResult.Outcome,'INJECTED');
    assert(s.ProbeResult.DownAccepted&&s.ProbeResult.UpAccepted);
    const before=read('fixture-before.json'),after=read('fixture-after.json');
    assert(before.focused&&before.resumed&&before.probeReady&&after.focused&&after.resumed&&after.probeReady);
    for(const key of ['instance','probeX','probeY']) assert.equal(before[key],after[key]);
    assert(Number.isSafeInteger(before.taps)&&before.taps>=0);
    assert.equal(after.taps,before.taps+1);
    assert.equal(s.BeforeTaps,before.taps); assert.equal(s.AfterTaps,after.taps);
  } else { assert(['FAIL','INVALID'].includes(s.Status)); }
  return {sourceCommit:s.SourceCommit,status:s.Status,reason:s.Reason,probe:s.ProbeResult,counterIncremented:s.CounterIncremented,q7Samples:0,kr003Complete:false};
}

if (process.argv[1] && resolve(process.argv[1])===resolve(import.meta.filename)) {
  const [kind,first,second]=process.argv.slice(2);
  const result = kind==="checkpoint" ? ingestCheckpoint(first,second) : kind==="diagnostic" ? ingestRecoveryDiagnostic(first) : kind==="transport" ? ingestOracleTransport(first) : kind==="device" ? ingestDeviceTransport(first) : kind==="calibration" ? ingestOracleCalibration(first) : kind==="uiautomation" ? ingestUiAutomationTransport(first) : kind==="monkey" ? ingestMonkeyTransport(first) : ingestQualification(first);
  process.stdout.write(JSON.stringify(result,null,2)+"\n");
}
