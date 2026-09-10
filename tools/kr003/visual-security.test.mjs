import test from "node:test";
import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";

const root=resolve(import.meta.dirname,"../..");
const tracked=execFileSync("git",["ls-files"],{cwd:root,encoding:"utf8"}).trim().split(/\r?\n/).filter(Boolean);
const approvedDesignMedia=new Set([
  "docs/design/assets/store-01-devices.png",
  "docs/design/assets/store-02-add-time.png",
  "docs/design/assets/store-03-no-surveillance.png",
]);

test("raw visual media is absent from tracked repository paths",()=>{
  const raw=tracked.filter(path=>/\.(?:png|jpe?g|webp|mp4|mkv|h264)$/i.test(path)&&!approvedDesignMedia.has(path));
  assert.deepEqual(raw,[]);
});

test("visual runner has local-only capture and no upload or OCR path",()=>{
  const files=["tools/kr003/Start-KR003.ps1","tools/kr003/Capture-KR003-Frames.ps1","tools/kr003/VisualCalibration.psm1","tools/kr003/package.mjs"];
  const source=files.map(file=>readFileSync(resolve(root,file),"utf8")).join("\n");
  assert.match(source,/C:\\platform-tools\\kr003-visual-calibration/);
  assert.match(source,/exec-out screencap -p/);
  assert.doesNotMatch(source,/Invoke-WebRequest|Invoke-RestMethod|curl(?:\.exe)?\b|github\.com\/repos|api\.openai\.com|base64|OCR|AccessibilityNodeInfo/i);
  assert.match(source,/QualificationRows=0/);
  assert.match(source,/Time04Rows=0/);
  assert.match(source,/MatrixContribution='NONE'/);
  assert.match(source,/HumanObservationSerialized=\$false/);
});

test("synthetic dedup prototype is not wired into physical runner and emits no pixels",()=>{
  const module=readFileSync(resolve(root,"tools/kr003/VisualCalibration.psm1"),"utf8");
  const runner=readFileSync(resolve(root,"tools/kr003/Start-KR003.ps1"),"utf8");
  assert.doesNotMatch(runner,/Invoke-KRVisualDedupPrototype/);
  assert.match(module,/if\(-not \$SyntheticOnly\)\{throw 'INVALID:SYNTHETIC_ONLY_PROTOTYPE'\}/);
  const prototype=module.slice(module.indexOf("function Invoke-KRVisualDedupPrototype"));
  assert.doesNotMatch(prototype,/Get-KRVisualCentroid|Get-KRVisualPngFeature|Get-Content|ReadAllBytes|WriteAllBytes|Out-File|Set-Content/);
  assert.match(prototype,/CheckpointSubstitutionAllowed=\$false/);
  const result=prototype.slice(prototype.indexOf("$watch.Stop()"));
  assert.doesNotMatch(result,/Pixels|\.Bytes|\.Ordinary|\.Restricted/);
});
