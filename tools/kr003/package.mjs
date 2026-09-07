// Goal: produce an immutable owner-run Q7 active-oracle Mi 8 qualification bundle from a clean source commit.
// Context: KR-003 only; Q5 calibrated the candidate and Q7 adds a disposable fixture input oracle. Constraints: no device execution, secrets or overwrite.
// Done when: all artefacts are hashed, the candidate matches Q5, and the fixture matches the reviewed Q7 oracle build.
import { mkdirSync, copyFileSync, readFileSync, writeFileSync } from "node:fs";
import { resolve, basename } from "node:path";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import assert from "node:assert/strict";
const root = resolve(import.meta.dirname, "../..");
const git = (...args) => execFileSync("git",args,{cwd:root,encoding:"utf8"}).trim();
assert.equal(git("status","--porcelain"), "", "Commit all changes before making a qualification bundle");
const commit = git("rev-parse","HEAD");
const destination = process.argv[2];
assert(destination, "Provide a new output directory (no overwrite)");
const output = resolve(destination);
mkdirSync(output, {recursive:false});
const spike = resolve(root,"spikes/android-enforcement");
execFileSync(resolve(spike,"gradlew"),["--no-daemon",":app:testDebugUnitTest","lintDebug","assembleDebug","lintRelease","assembleRelease"],{cwd:spike,stdio:"inherit"});
execFileSync(process.execPath,[resolve(root,"tools/validate.mjs")],{cwd:root,stdio:"inherit"});
execFileSync(process.execPath,[resolve(root,"tools/kr003/audit-build.mjs")],{cwd:root,stdio:"inherit"});
const mapping = {
  "Start-KR003.ps1": "tools/kr003/Start-KR003.ps1",
  "Clear-KR003-Lab.ps1": "tools/kr003/Clear-KR003-Lab.ps1",
  "Qualification.psm1": "tools/kr003/Qualification.psm1",
  "protocol.md": "docs/test-plans/KR-003-Q7-AUTOMATED-QUALIFICATION.md",
  "candidate.apk": "spikes/android-enforcement/app/build/outputs/apk/debug/app-debug.apk",
  "ordinary-fixture.apk": "spikes/android-enforcement/ordinary-fixture/build/outputs/apk/debug/ordinary-fixture-debug.apk",
};
const files = Object.entries(mapping).map(([name, source])=>{
  copyFileSync(resolve(root,source),resolve(output,name));
  return { name, sha256:createHash("sha256").update(readFileSync(resolve(output,name))).digest("hex") };
});
const manifest = {
  schema:1, protocol:"KR003-Q7-MI8-ACTIVE-ORACLE-QUALIFICATION", sourceCommit:commit, runnerVersion:7,
  diagnosticOnly:false, requiresOffline:true,
  createdUtc:new Date().toISOString(), candidateSha256:files.find(f=>f.name==="candidate.apk").sha256,
  fixtureSha256:files.find(f=>f.name==="ordinary-fixture.apk").sha256, files,
  ownerDevice:{model:"Xiaomi Mi 8",miui:"MIUI Global 12.0.3",api:29,codename:"dipper"},
  physicalExecution:"NOT_RUN", previousFixCommit:"de941a9",
  candidateCalibratedBy:{protocol:"KR003-Q5-RECOVERY-TASK-RESET-CALIBRATION",sourceCommit:"97173d207c8076219c6c4c8d780db43d8f9fc566",runId:"run-20260906-171929-69a3abda"},
  oracleModel:"ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS",
  humanCheckpointMaximum:3,
};
assert.equal(manifest.candidateSha256,"5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b","Candidate APK no longer matches Q5 physical calibration");
assert.equal(manifest.fixtureSha256,"223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc","Fixture APK no longer matches the reviewed Q7 active-oracle build");
assert.equal(git("status","--porcelain"), "", "Build unexpectedly changed tracked source");
writeFileSync(resolve(output,"bundle.json"),JSON.stringify(manifest,null,2)+"\n",{flag:"wx"});
process.stdout.write(JSON.stringify({output,bundle:basename(output),...manifest},null,2)+"\n");
