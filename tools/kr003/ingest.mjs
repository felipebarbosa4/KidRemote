import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { createHash } from "node:crypto";
import assert from "node:assert/strict";
const decode = path => readFileSync(path,"utf8").replace(/^\uFEFF/,"");
const hash = path => createHash("sha256").update(readFileSync(path)).digest("hex");

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
  assert(["KR003-Q1","KR003-Q2"].includes(manifest.Bundle.protocol));
  assert.match(manifest.Bundle.sourceCommit,/^[a-f0-9]{40}$/);
  assert(Array.isArray(rows),"Attempt journal must be an array");
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
    if(manifest.Bundle.protocol==='KR003-Q2') {
      assert.equal(summary.QualificationRequested,true);
      assert.deepEqual(rows.filter(r=>r.Phase==='CALIBRATION'),[calibration],"Calibration must survive in the attempt journal");
      assert.deepEqual(summary.FinalizationErrors,[],"Cleanup/reporting failure cannot qualify");
      const restored=read('network-restoration.json');
      assert(!String(restored.Status).includes('FAILED'),"Radio restoration must not be silently unverified");
    }
    for(const phase of ["calibration","final"]) {
      const safety=read(`safety-${phase}.json`);
      assert.equal(safety.PhysicalHomeAndSettings,"OWNER_PASS");
      assert.equal(safety.Reentry,"OWNER_PASS");
      assert.equal(safety.ClearTouch,"FIXTURE_COUNTER_INCREMENT");
      assert.equal(safety.IndependentExpirySamples,0);
      if(manifest.Bundle.protocol==='KR003-Q2') assert.equal(safety.Oracle,'CORROBORATED');
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

if (process.argv[1] && resolve(process.argv[1])===resolve(import.meta.filename)) {
  const [kind,first,second]=process.argv.slice(2);
  const result = kind==="checkpoint" ? ingestCheckpoint(first,second) : kind==="diagnostic" ? ingestRecoveryDiagnostic(first) : ingestQualification(first);
  process.stdout.write(JSON.stringify(result,null,2)+"\n");
}
