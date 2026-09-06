import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, cpSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { ingestCheckpoint, ingestQualification } from "./ingest.mjs";
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
  save('summary.json',{...summary,ValidPairedObservations:0});
  assert.equal(ingestQualification(dir).validPairedObservations,0);
  save('summary.json',{...summary,Status:'PASSED_THIS_CONFIGURATION_ONLY',ValidPairedObservations:0});
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
