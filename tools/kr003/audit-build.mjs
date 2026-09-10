import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { execFileSync } from "node:child_process";
import assert from "node:assert/strict";

const root = resolve(import.meta.dirname, "../..");
const spike = resolve(root, "spikes/android-enforcement");
const list = path => readdirSync(path, { withFileTypes: true }).flatMap(e => e.isDirectory() ? list(resolve(path,e.name)) : [resolve(path,e.name)]);
const resultFiles = list(resolve(spike,"app/build/test-results/testDebugUnitTest")).filter(p=>p.endsWith(".xml"));
const expectedSources = list(resolve(spike,"app/src")).filter(p=>/\/(test|testDebug)\//.test(p)&&p.endsWith(".kt"));
const expected = expectedSources.reduce((n,p)=>n+(readFileSync(p,"utf8").match(/@Test\b/g)??[]).length,0);
const results = resultFiles.map(p=>readFileSync(p,"utf8")).join("\n");
const actual = (results.match(/<testcase\b/g)??[]).length;
assert(expected >= 18 && actual === expected, "JVM execution mismatch: " + actual + "/" + expected);
assert(!/<failure\b|<error\b|<skipped\b/.test(results), "JVM tests must all execute and pass");

for (const module of ["app","ordinary-fixture","input-probe"]) {
  for (const variant of ["debug","release"]) {
    const base = resolve(spike,module,"build");
    const task = "process" + (variant === "debug" ? "Debug" : "Release") + "Manifest";
    const manifest = readFileSync(resolve(base,"intermediates/merged_manifests",variant,task,"AndroidManifest.xml"),"utf8");
    const permissions = [...manifest.matchAll(/<uses-permission[^>]*android:name="([^"]+)"/g)].map(m=>m[1]).sort();
    assert.deepEqual(permissions, module==="app" ? ["android.permission.PACKAGE_USAGE_STATS","android.permission.RECEIVE_BOOT_COMPLETED"] : []);
    if (variant==="release") {
      assert(!/LabControlReceiver|FixtureReceiver|OneTouchInstrumentation|<instrumentation|android.permission.DUMP|android:debuggable="true"/.test(manifest), "Release manifest contains lab access");
    } else if (module === "input-probe") {
      assert(manifest.includes('android:targetPackage="dev.kidremote.spike.inputprobe"'), "Probe must target itself, never fixture/candidate");
      assert(!/sharedUserId/.test(manifest), "Probe must have independent UID");
    } else {
      assert(manifest.includes('android:permission="android.permission.DUMP"'), "Debug sender protection missing");
    }
    const apk = resolve(base,"outputs/apk",variant,module+"-"+variant+(variant==="release" ? "-unsigned" : "")+".apk");
    const names = execFileSync("unzip",["-Z1",apk],{encoding:"utf8"}).trim().split("\n").filter(p=>/^classes\d*\.dex$/.test(p));
    const dex = Buffer.concat(names.map(name=>execFileSync("unzip",["-p",apk,name],{maxBuffer:32*1024*1024})));
    if (variant==="release") {
      for (const name of ["LabControlReceiver","FixtureReceiver","LabProbe","TraceJournal","KidRemoteKR003","KR003:","OneTouchInstrumentation","injectInputEvent","kr003_probe","MonkeyTouchMain","KR003_MONKEY:"]) {
        assert(!dex.includes(Buffer.from(name)), "Release DEX contains " + name);
      }
    } else {
      assert(dex.includes(Buffer.from(module==="app" ? "LabControlReceiver" : module==="input-probe" ? "OneTouchInstrumentation" : "FixtureReceiver")), "Debug control absent");
    }
    process.stdout.write(module+"/"+variant+": merged permissions, receiver protection and release DEX isolation passed\n");
  }
}
process.stdout.write("JVM execution verified: "+actual+"/"+expected+"; no physical result implied.\n");
