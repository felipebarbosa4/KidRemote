// Goal: produce one immutable 100-cycle qualification bundle bound to the approved Samsung calibration evidence.
// Context: runner-v5 calibration passed on the exact SM-X400 / Android 16 / API 36 / build BP4A.251205.006 configuration.
// Constraints: strict evidence ingestion, exact APK/configuration binding, no device command, overwrite, physical claim, raw output or KR-004 work.
// Done when: clean committed source and calibration provenance are verified, all payloads are hashed, and physicalExecution remains NOT_RUN.
import { mkdirSync, copyFileSync, readFileSync, writeFileSync } from "node:fs";
import { resolve, basename } from "node:path";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import assert from "node:assert/strict";

const root=resolve(import.meta.dirname,"../.."),git=(...args)=>execFileSync("git",args,{cwd:root,encoding:"utf8"}).trim();
const sha256=path=>createHash("sha256").update(readFileSync(path)).digest("hex");
const readJson=path=>JSON.parse(readFileSync(path,"utf8").replace(/^\uFEFF/,""));
assert.equal(git("status","--porcelain"),"","Commit all changes before making a qualification bundle");
const commit=git("rev-parse","HEAD"),destination=process.argv[2],calibrationArgument=process.argv[3];
assert(destination,"Provide a new output directory (no overwrite)");
assert(calibrationArgument,"Provide the approved calibration evidence directory");
const calibrationDirectory=resolve(calibrationArgument);
assert.equal(basename(calibrationDirectory),"calibration-20260908-231756-97a0855b","Use only the approved Samsung calibration directory");
const ingestion=JSON.parse(execFileSync(process.execPath,[resolve(root,"tools/kr003/ingest.mjs"),"calibration",calibrationDirectory],{cwd:root,encoding:"utf8"}));
assert.deepEqual(ingestion,{
  sourceCommit:"4690d3951d0952fefe43eab9de0799599c6ea903",status:"PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY",reason:"COMPLETED",
  calibrationSamples:1,qualificationSamples:0,physicalAgreement:"PASS",permissionVerificationPassed:true,
  hostStage:"COMPLETED",hostStageSource:"CAPTURED_RUNNER_V3",exceptionClass:"NONE",finalizationStatus:"COMPLETED",cleanupStatus:"VERIFIED",kr003Complete:false,
});
const calibrationSummary=readJson(resolve(calibrationDirectory,"summary.json")),calibrationDevice=readJson(resolve(calibrationDirectory,"device.json"));
const approvedConfiguration={schema:1,manufacturer:"samsung",model:"SM-X400",androidVersion:"16",apiLevel:"36",securityPatch:"2026-07-05",buildId:"BP4A.251205.006"};
assert.deepEqual({
  schema:1,manufacturer:calibrationDevice.Manufacturer,model:calibrationDevice.Model,androidVersion:calibrationDevice.AndroidVersion,
  apiLevel:calibrationDevice.ApiLevel,securityPatch:calibrationDevice.SecurityPatch,buildId:calibrationDevice.BuildId,
},approvedConfiguration,"Calibration device metadata does not match the approved configuration");
assert.equal(sha256(resolve(calibrationDirectory,"summary.json")),"c1119705a0bb30acbccc0caee6fb293815cfc3901a285fd346275321129f4a61","Calibration summary changed");
assert.equal(sha256(resolve(calibrationDirectory,"device.json")),"5e1c89c0cddcc8dc2b1b86bfe5b5e5ed2c61d4170d71318ceafc0c94906b6c23","Calibration metadata changed");

const output=resolve(destination);mkdirSync(output,{recursive:false});
const spike=resolve(root,"spikes/android-enforcement");
execFileSync(resolve(spike,"gradlew"),["--no-daemon",":app:testDebugUnitTest","lintDebug","assembleDebug","lintRelease","assembleRelease"],{cwd:spike,stdio:"inherit"});
execFileSync(process.execPath,[resolve(root,"tools/validate.mjs")],{cwd:root,stdio:"inherit"});
execFileSync(process.execPath,[resolve(root,"tools/kr003/audit-build.mjs")],{cwd:root,stdio:"inherit"});
const mapping={
  "Start-KR003.ps1":"tools/kr003/Start-KR003.ps1",
  "Clear-KR003-Lab.ps1":"tools/kr003/Clear-KR003-Lab.ps1",
  "Qualification.psm1":"tools/kr003/Qualification.psm1",
  "DevicePreflight.psm1":"tools/kr003/DevicePreflight.psm1",
  "protocol.md":"docs/test-plans/KR-003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION.md",
  "candidate.apk":"spikes/android-enforcement/app/build/outputs/apk/debug/app-debug.apk",
  "ordinary-fixture.apk":"spikes/android-enforcement/ordinary-fixture/build/outputs/apk/debug/ordinary-fixture-debug.apk",
};
const files=Object.entries(mapping).map(([name,source])=>{
  copyFileSync(resolve(root,source),resolve(output,name));
  return {name,sha256:sha256(resolve(output,name))};
});
const candidateSha256=files.find(file=>file.name==="candidate.apk").sha256;
const fixtureSha256=files.find(file=>file.name==="ordinary-fixture.apk").sha256;
assert.equal(candidateSha256,calibrationSummary.CandidateSha256,"Candidate differs from the passed calibration");
assert.equal(fixtureSha256,calibrationSummary.FixtureSha256,"Fixture differs from the passed calibration");
const calibratedBy={
  protocol:calibrationSummary.Protocol,sourceCommit:calibrationSummary.SourceCommit,runDirectory:basename(calibrationDirectory),
  status:calibrationSummary.Status,reason:calibrationSummary.Reason,summarySha256:sha256(resolve(calibrationDirectory,"summary.json")),
  deviceSha256:sha256(resolve(calibrationDirectory,"device.json")),transportDeviceEvidenceSha256:calibrationSummary.TransportDeviceEvidenceSha256,
  calibrationSamples:calibrationSummary.CalibrationSamples,qualificationSamples:calibrationSummary.QualificationSamples,
  physicalAgreement:calibrationSummary.PhysicalAgreement,candidateSha256,fixtureSha256,
};
const manifest={
  schema:1,protocol:"KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION",sourceCommit:commit,runnerVersion:9,
  diagnosticOnly:false,requiresOffline:true,createdUtc:new Date().toISOString(),candidateSha256,fixtureSha256,files,
  approvedConfiguration,ownerProvidedLabels:{device:"Galaxy Tab S10 Lite",software:"One UI 8.5"},
  physicalExecution:"NOT_RUN",calibratedBy,oracleModel:"ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS",
  networkCapabilityModel:"ANDROID_SYSTEM_FEATURES_WIFI_AND_TELEPHONY_DATA",
  humanCheckpointMaximum:3,qualificationCycles:100,resumeAllowed:false,poolingAllowed:false,
};
assert.equal(git("status","--porcelain"),"","Build unexpectedly changed tracked source");
writeFileSync(resolve(output,"bundle.json"),JSON.stringify(manifest,null,2)+"\n",{flag:"wx"});
process.stdout.write(JSON.stringify({output,bundle:basename(output),...manifest},null,2)+"\n");
