import test from "node:test";
import assert from "node:assert/strict";
import {mkdtempSync,writeFileSync,mkdirSync,rmSync,readFileSync} from "node:fs";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {ingestVisualCalibration} from "./ingest.mjs";

const sha=value=>value.repeat(64).slice(0,64);
const write=(directory,name,value)=>writeFileSync(join(directory,name),JSON.stringify(value));

function makeEvidence(){
  const directory=mkdtempSync(join(tmpdir(),"kr003-visual-ingest-"));
  const configuration={schema:1,manufacturer:"samsung",model:"SM-X400",androidVersion:"16",apiLevel:"36",securityPatch:"2026-07-05",buildId:"BP4A.251205.006"};
  const device={Manufacturer:"samsung",Model:"SM-X400",Android:"16",Api:"36",Patch:"2026-07-05",BuildId:"BP4A.251205.006",wifi_on:"1",mobile_data:"0",airplane_mode_on:"0",auto_time:"1",auto_time_zone:"1",low_power:"0"};
  const calibratedBy={protocol:"KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION",sourceCommit:"a".repeat(40),runDirectory:"calibration-20260908-231756-97a0855b",status:"PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY",reason:"COMPLETED",summarySha256:sha("a"),deviceSha256:sha("b"),transportDeviceEvidenceSha256:sha("c"),calibrationSamples:1,qualificationSamples:0,physicalAgreement:"PASS",candidateSha256:sha("d"),fixtureSha256:sha("e")};
  const bundle={schema:1,protocol:"KR003-VISUAL-CHANNEL-CALIBRATION",sourceCommit:"f".repeat(40),runnerVersion:1,diagnosticOnly:true,diagnosticScope:"VISUAL_CHANNEL_ONLY",requiresOffline:false,networkIsolation:"NOT_REQUIRED_AND_NOT_PERFORMED",physicalExecution:"NOT_RUN",oracleModel:"ADB_INPUT_PLUS_INDEPENDENT_FIXTURE_COUNTER_AND_FOCUS",awakeStateModel:"ANDROID_STAY_ON_WHILE_PLUGGED_IN_PLUS_POWER_SOURCE",captureModel:"ADB_EXEC_OUT_SCREENCAP_PNG_WITH_HOST_MONOTONIC_INTERVALS",classifierModel:"DETERMINISTIC_FULL_FRAME_RGB_GRID_NEAREST_PROTOTYPE",rawMediaPolicy:"OWNER_LOCAL_ONLY_EXCLUDED_FROM_REPOSITORY_CLOUD_AND_TOOL_OUTPUT",qualificationCycles:0,time04Rows:0,matrixContribution:"NONE",humanCheckpointMaximum:0,resumeAllowed:false,poolingAllowed:false,approvedConfiguration:configuration,calibratedBy,candidateSha256:sha("d"),fixtureSha256:sha("e")};
  write(directory,"manifest.json",{Schema:1,Bundle:bundle,InitialDevice:device,Device:device,VisualCalibration:true,OfflineNetworkRequested:false,NetworkMutationAllowed:false,EvidenceModel:"EXCLUDED_LOCAL_ONLY_VISUAL_CHANNEL_CALIBRATION",QualificationRows:0,Time04Rows:0,MatrixContribution:"NONE"});
  write(directory,"summary.json",{Status:"PASSED_VISUAL_CHANNEL_CALIBRATION_THIS_CONFIGURATION_ONLY",Reason:"ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED",QualificationRequested:false,VisualCalibrationRequested:true,DualHomeDiagnosticRequested:false,QualificationRows:0,Time04Rows:0,MatrixContribution:"NONE",EvidenceModel:"EXCLUDED_LOCAL_ONLY_VISUAL_CHANNEL_CALIBRATION",HumanCheckpointSessions:0,PhysicalExpiryObservations:0,Kr003Complete:false,ProductionApproved:false,Offline:false,VisualCaptureStatus:"COMPLETED",VisualAnalysisStatus:"PASS",VisualAnalysisReason:"ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED",VisualCleanupStatus:"VERIFIED",FinalizationErrors:[],SafetyChecksPassed:true});
  write(directory,"attempts.json",[]);write(directory,"human-checkpoints.json",[]);write(directory,"network-restoration.json",{Status:"NOT_CHANGED",Settings:[]});write(directory,"end-device.json",device);
  write(directory,"permission-verification.json",{UsageAccessRunner:"ENABLED",AccessibilityRunner:"ENABLED",ServiceHeartbeat:"FRESH",CandidateHealth:"HEALTHY",CandidateEligible:"ELIGIBLE"});
  const phases=[{Name:"ORDINARY_BEFORE",StartTicks:0,EndTicks:3000,Oracle:"FIXTURE_FOCUSED_RESUMED_INPUT_VERIFIED"},{Name:"EXPIRY_TRANSITION",StartTicks:3000,EndTicks:4000,Oracle:"FRESH_EXPIRY_ATTACHED"},{Name:"RESTRICTED",StartTicks:4000,EndTicks:15000,Oracle:"RESTRICTION_AND_INDEPENDENT_BLOCKED_INPUT_HELD"},{Name:"CLEAR_TRANSITION",StartTicks:15000,EndTicks:16000,Oracle:"CLEAR_AND_ORDINARY_FOCUS_ESTABLISHED"},{Name:"ORDINARY_AFTER",StartTicks:16000,EndTicks:19000,Oracle:"ORDINARY_FOCUSED_RESUMED_TAP_VERIFIED"}];
  write(directory,"visual-phases.json",{Schema:1,Frequency:1000,Phases:phases,QualificationRows:0,Time04Rows:0,MatrixContribution:"NONE"});
  const frameStarts=[0,1000,2500,4000,5000,6000,7000,8000,9000,10000,11000,12000,13000,14000,16000,17000,18500];
  const journal=frameStarts.map((start,index)=>({Schema:1,Index:index+1,FileName:`frame-${String(index+1).padStart(6,"0")}.png`,StartTicks:start,EndTicks:start+100,Sha256:(index+1).toString(16).padStart(64,"0"),Bytes:1000,ExitCode:0,StderrClass:"NONE"}));
  writeFileSync(join(directory,"frame-journal.jsonl"),journal.map(value=>JSON.stringify(value)).join("\n")+"\n");
  write(directory,"capture-worker.json",{Schema:1,Status:"COMPLETED",Reason:"STOP_SENTINEL_OBSERVED",FrameCount:journal.length,Frequency:1000,UpdatedUtc:"2026-09-10T00:00:00Z"});
  write(directory,"visual-capture-preflight.json",{Schema:1,Capability:"SUPPORTED_THIS_CONFIGURATION_ONLY",Mechanism:"ADB_EXEC_OUT_SCREENCAP_PNG",AcceptedFrames:2,Dimensions:"1600x2560",BlankOrProtected:false,SecureContentBypassRequested:false,RawContentEmitted:false,VerifiedUtc:"2026-09-10T00:00:00Z"});
  write(directory,"visual-restriction.json",{Phase:"EXCLUDED_VISUAL_CALIBRATION",QualificationRows:0,Time04Rows:0,Status:"RESTRICTION_ESTABLISHED",Restriction:true,Attached:true,Disposition:"ORDINARY_APP"});
  write(directory,"visual-independent-oracle.json",{Schema:1,Status:"PASS",InjectedBlockedTaps:20,HoldMillis:10500,CandidateContinuity:"RESTRICTION_ATTACHED_HEALTHY_ELIGIBLE",FixtureFocusRegain:"NONE",FixtureInputLeak:"NONE",ServiceContinuity:"VERIFIED"});
  write(directory,"visual-cleanup.json",{Status:"VERIFIED",ClearAttempted:true,CandidateState:"UNARMED_UNRESTRICTED_UNATTACHED",CandidateHealth:"HEALTHY_ELIGIBLE",FixtureOrdinaryUse:"FOCUSED_RESUMED_TAP_VERIFIED"});
  const classifications=journal.filter(frame=>(frame.StartTicks<3000)||(frame.StartTicks>=4000&&frame.StartTicks<15000)||(frame.StartTicks>=16000)).map(frame=>({Index:frame.Index,Phase:frame.StartTicks<3000?"ORDINARY_BEFORE":frame.StartTicks<15000?"RESTRICTED":"ORDINARY_AFTER",Classification:frame.StartTicks>=4000&&frame.StartTicks<15000?"RESTRICTED":"ORDINARY",Margin:0.2,Sha256:frame.Sha256}));
  write(directory,"visual-analysis.json",{Schema:1,Status:"PASS",Reason:"ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED",ClassifierModel:bundle.classifierModel,TimestampModel:"HOST_MONOTONIC_CAPTURE_REQUEST_INTERVALS",GridWidth:24,GridHeight:24,FrameCount:journal.length,OrdinaryBeforeFrames:3,RestrictedFrames:11,OrdinaryAfterFrames:3,BlankFrames:0,RepeatedImageHashes:0,BetweenClassDistance:0.2,OrdinaryRoundTripDistance:0,ChangedTileFraction:0.5,ChangedHorizontalSpan:0.8,ChangedVerticalSpan:0.7,RestrictedTemporalCoverage:{FrameCount:11,WindowMillis:11000,ObservedSpanMillis:10100,SpanCoverageRatio:0.918,MaximumCaptureDurationMillis:100,TimestampAlignmentUncertaintyMillis:50,WorstCaseSamplingGapMillis:1100,DefensibleInterruptionDetectionBoundMillis:1100},Classifications:classifications,CaptureLiveness:"CONTROLLED_ORDINARY_RESTRICTED_ORDINARY_TRANSITIONS_VERIFIED",QualificationRows:0,Time04Rows:0,MatrixContribution:"NONE",HumanObservationSerialized:false,RawMediaIncluded:false,RawMediaLocation:"OWNER_LOCAL_RUN_DIRECTORY_ONLY"});
  write(directory,"visual-retention.json",{RepositoryUploadAllowed:false,CloudUploadAllowed:false,ToolContentOutputAllowed:false,AutomaticDeletion:false,FailedOrInvalidRetention:"PRESERVE_UNTIL_ROOT_CAUSE_DISPOSITION",Deletion:"EXPLICIT_OWNER_ACTION_ONLY"});
  write(directory,"stay-awake.json",{Schema:1,Mechanism:"ANDROID_STAY_ON_WHILE_PLUGGED_IN",OriginalSetting:15,AppliedSetting:15,Changed:false,PowerSourceBefore:"USB",PowerSourceAfter:"USB",Establishment:"VERIFIED",VerificationSource:"GLOBAL_SETTING_PLUS_DUMPSYS_BATTERY",VerificationCount:2,LastPowerSource:"USB",LastVerifiedUtc:"2026-09-10T00:00:00Z"});
  write(directory,"stay-awake-restoration.json",{Schema:1,Status:"RESTORED_AND_SETTING_VERIFIED",OriginalSetting:15,ObservedSetting:15,Changed:false,VerificationSource:"GLOBAL_SETTING_READBACK",AtUtc:"2026-09-10T00:01:00Z"});
  write(directory,"diagnostic-bailout.json",{Status:"VERIFIED",RestrictionReleased:true});
  mkdirSync(join(directory,"raw-frames"));writeFileSync(join(directory,"raw-frames","do-not-read.png"),"not an image");
  return directory;
}

test("visual calibration ingestion accepts only sanitized zero-row evidence without reading raw media",()=>{
  const directory=makeEvidence();
  try{assert.deepEqual(ingestVisualCalibration(directory),{sourceCommit:"f".repeat(40),status:"PASSED_VISUAL_CHANNEL_CALIBRATION_THIS_CONFIGURATION_ONLY",reason:"ORDINARY_RESTRICTED_ORDINARY_DISTINGUISHED",qualificationRows:0,time04Rows:0,matrixContribution:"NONE",humanObservations:0,rawMediaRead:false,kr003Complete:false});}
  finally{rmSync(directory,{recursive:true,force:true});}
});

test("visual calibration ingestion rejects upload permission and qualification contribution",()=>{
  const directory=makeEvidence();
  try{
    const manifest=JSON.parse(readFileSync(join(directory,"manifest.json"),"utf8"));manifest.Bundle.rawMediaPolicy="UPLOAD_ALLOWED";write(directory,"manifest.json",manifest);
    assert.throws(()=>ingestVisualCalibration(directory));
    manifest.Bundle.rawMediaPolicy="OWNER_LOCAL_ONLY_EXCLUDED_FROM_REPOSITORY_CLOUD_AND_TOOL_OUTPUT";manifest.MatrixContribution="PASS";write(directory,"manifest.json",manifest);
    assert.throws(()=>ingestVisualCalibration(directory));
  }finally{rmSync(directory,{recursive:true,force:true});}
});
