import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";

const spikeRoot = "spikes/android-enforcement";

export function validateAndroidSpike(root) {
  const errors = [];
  const check = (condition, message) => { if (!condition) errors.push(message); };
  const read = path => readFileSync(resolve(root, path), "utf8");
  const required = [
    `${spikeRoot}/README.md`,
    `${spikeRoot}/settings.gradle.kts`,
    `${spikeRoot}/build.gradle.kts`,
    `${spikeRoot}/gradle/wrapper/gradle-wrapper.jar`,
    `${spikeRoot}/gradle/wrapper/gradle-wrapper.properties`,
    `${spikeRoot}/app/build.gradle.kts`,
    `${spikeRoot}/app/src/main/AndroidManifest.xml`,
    `${spikeRoot}/app/src/main/res/xml/accessibility_service_config.xml`,
  ];
  for (const path of required) check(existsSync(resolve(root, path)), `Android spike missing ${path}`);
  if (errors.length) return errors;

  const rootBuild = read(`${spikeRoot}/build.gradle.kts`);
  const appBuild = read(`${spikeRoot}/app/build.gradle.kts`);
  const wrapper = read(`${spikeRoot}/gradle/wrapper/gradle-wrapper.properties`);
  check(rootBuild.includes('id("com.android.application") version "9.4.0"'), "Android spike must pin AGP 9.4.0");
  check(appBuild.includes("compileSdk = 36") && appBuild.includes("targetSdk = 36") && appBuild.includes("minSdk = 28"),
    "Android spike SDK contract changed without documentation");
  check(appBuild.includes("JavaLanguageVersion.of(17)"), "Android spike must pin the Java 17 toolchain");
  check(wrapper.includes("gradle-9.6.0-bin.zip"), "Android spike must use Gradle 9.6.0");
  check(wrapper.includes("distributionSha256Sum=bbaeb2fef8710818cf0e261201dab964c572f92b942812df0c3620d62a529a01"),
    "Android spike Gradle distribution checksum is missing or changed");
  const wrapperJar = readFileSync(resolve(root, `${spikeRoot}/gradle/wrapper/gradle-wrapper.jar`));
  check(createHash("sha256").update(wrapperJar).digest("hex") === "497c8c2a7e5031f6aa847f88104aa80a93532ec32ee17bdb8d1d2f67a194a9c7",
    "Android spike wrapper JAR checksum does not match Gradle 9.6.0");

  const manifest = read(`${spikeRoot}/app/src/main/AndroidManifest.xml`);
  check(manifest.includes("android.permission.PACKAGE_USAGE_STATS"), "Android spike Usage Access declaration missing");
  check(manifest.includes("android.permission.RECEIVE_BOOT_COMPLETED"), "Android spike boot receiver permission missing");
  check(manifest.includes('android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"'),
    "Android spike service must be protected by BIND_ACCESSIBILITY_SERVICE");
  for (const forbidden of [
    "android.permission.INTERNET",
    "android.permission.QUERY_ALL_PACKAGES",
    "android.permission.SYSTEM_ALERT_WINDOW",
    "android.permission.BIND_DEVICE_ADMIN",
    "android.permission.CAMERA",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.RECORD_AUDIO",
  ]) check(!manifest.includes(forbidden), `Android spike must not request ${forbidden}`);

  const serviceConfig = read(`${spikeRoot}/app/src/main/res/xml/accessibility_service_config.xml`);
  check(serviceConfig.includes('android:canRetrieveWindowContent="false"'), "Accessibility content retrieval must stay disabled");
  check(serviceConfig.includes('android:isAccessibilityTool="false"'), "Spike must not claim to be an accessibility tool");
  check(serviceConfig.includes('android:accessibilityEventTypes="typeWindowStateChanged"'),
    "Accessibility event subscription must remain narrow and reviewed");
  for (const forbidden of ["canPerformGestures", "flagRetrieveInteractiveWindows", "typeViewTextChanged", "typeViewClicked"])
    check(!serviceConfig.includes(forbidden), `Accessibility config contains unapproved capability ${forbidden}`);

  function walk(path) {
    return readdirSync(resolve(root, path), { withFileTypes: true }).flatMap(entry => {
      const next = `${path}/${entry.name}`;
      return entry.isDirectory() ? walk(next) : [next];
    });
  }
  const shipped = ["app", "ordinary-fixture", "input-probe"].flatMap(module =>
    walk(`${spikeRoot}/${module}/src`).filter(path => /\/src\/(main|debug|release)\//.test(path)));
  const tracePath = `${spikeRoot}/app/src/debug/kotlin/dev/kidremote/spike/enforcement/EnforcementTrace.kt`;
  const monkeyPath = `${spikeRoot}/input-probe/src/debug/kotlin/dev/kidremote/spike/inputprobe/MonkeyTouchMain.kt`;
  const monkey = read(monkeyPath);
  const stdoutSink = 'System.out.println("KR003_MONKEY:v1,$request,$stage,$outcome,$down,$up")';
  check(monkey.split(stdoutSink).length === 2, "Monkey tool must have exactly one typed result sink");
  const sourcePaths = shipped.filter(path => path.endsWith(".kt") && path !== tracePath);
  const sources = sourcePaths.map(path => path === monkeyPath ? read(path).replace(stdoutSink, "") : read(path)).join("\n");
  const debugTrace = read(tracePath);
  for (const forbidden of [
    ".rootInActiveWindow", ".getSource()", ".source", "dispatchGesture(", "takeScreenshot(", "performGlobalAction(", "Log.",
    "import android.view.accessibility.AccessibilityNodeInfo", "getRootInActiveWindow(", "getWindows(", "getText(",
    "getContentDescription(", "System.out", "println(", "java.net.", "Build.SERIAL", "getSerial(",
  ]) check(!(forbidden === "Log." ? sources : sources + "\n" + debugTrace).includes(forbidden),
    `Android spike source contains unapproved access: ${forbidden}`);
  const releaseTrace = read(`${spikeRoot}/app/src/release/kotlin/dev/kidremote/spike/enforcement/EnforcementTrace.kt`);
  check(debugTrace.includes('private const val TRACE_TAG = "KidRemoteKR003"'), "Debug trace tag changed");
  check(debugTrace.includes("Log.i(TRACE_TAG, record.toLogLine())"), "Debug trace must log only the typed sanitized record");
  check(!debugTrace.includes("packageName") && !debugTrace.includes("AccessibilityEvent"), "Debug trace accepts sensitive/raw input");
  check(!releaseTrace.includes("android.util.Log") && !releaseTrace.includes("toLogLine"), "Release trace must remain a no-op");
  check((releaseTrace.match(/= Unit/g) ?? []).length === 2 && !releaseTrace.includes("LabProbe"), "Release observation hooks must be no-ops");
  check(!/windowVisibility|hasWindowFocus|isAttachedToWindow/.test(releaseTrace), "Release trace must not read debug window diagnostics");
  check((debugTrace.match(/Log\./g) ?? []).length === 1, "Only one typed debug logging call is allowed");
  for (const module of ["app", "ordinary-fixture"]) {
    const debugManifest = read(`${spikeRoot}/${module}/src/debug/AndroidManifest.xml`);
    check((debugManifest.match(/<receiver /g) ?? []).length === 1 &&
      debugManifest.includes('android:permission="android.permission.DUMP"'), `${module}: protect the one debug receiver with sender DUMP permission`);
    check(!debugManifest.includes("<uses-permission") && !debugManifest.includes("<activity"), `${module}: debug must not add privileges or control activities`);
    const main = read(`${spikeRoot}/${module}/src/main/AndroidManifest.xml`);
    check(!/LabControlReceiver|FixtureReceiver|android.permission.DUMP/.test(main), `${module}: debug control leaked into main manifest`);
  }
  for (const path of shipped.filter(path => path.endsWith("AndroidManifest.xml"))) {
    const permissions = [...read(path).matchAll(/<uses-permission[^>]*android:name="([^"]+)"/g)].map(m => m[1]);
    const allowed = path === `${spikeRoot}/app/src/main/AndroidManifest.xml`
      ? ["android.permission.PACKAGE_USAGE_STATS", "android.permission.RECEIVE_BOOT_COMPLETED"] : [];
    check(JSON.stringify(permissions.sort()) === JSON.stringify(allowed.sort()), `Unexpected permission set: ${path}`);
  }
  const probeManifest = read(`${spikeRoot}/input-probe/src/debug/AndroidManifest.xml`);
  check(probeManifest.includes('android:targetPackage="dev.kidremote.spike.inputprobe"') &&
    (probeManifest.match(/<instrumentation\b/g) ?? []).length === 1 && !/<activity|<receiver|<service|sharedUserId/.test(probeManifest),
    "Input probe must have only one self-targeted debug instrumentation entry");
  check(!/instrumentation|sharedUserId|<activity|<receiver|<service/.test(read(`${spikeRoot}/input-probe/src/main/AndroidManifest.xml`)),
    "Input probe entry must not leak into main/release");
  const probe = read(`${spikeRoot}/input-probe/src/debug/kotlin/dev/kidremote/spike/inputprobe/OneTouchInstrumentation.kt`);
  check(probe.includes("FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES") && probe.includes("info.eventTypes = 0") &&
    probe.includes("finish(if (outcome"), "Input probe must preserve services, avoid events and finish");
  for (const forbidden of ["getUiAutomation()", "setOnAccessibilityEventListener", "executeShellCommand", "adoptShellPermissionIdentity",
    "sendPointerSync", "performClick", "FixtureState", "LabProbe", "getPackageManager", "sendBroadcast", "startActivity", "getSharedPreferences"])
    check(!probe.includes(forbidden), `Input probe contains unapproved coupling/access: ${forbidden}`);
  for (const forbidden of ["setActivityController", "freezeRotation", "thawRotation", "Settings.", "FixtureState", "LabProbe", "printStackTrace",
    "getUiAutomation", "getRootInActiveWindow", "getWindows(", "getDeclaredMethod", "setAccessible", "Runtime.getRuntime", "ProcessBuilder"])
    check(!monkey.includes(forbidden), `Monkey tool contains unapproved access: ${forbidden}`);
  check(monkey.includes('Class.forName("com.android.commands.monkey.MonkeyTouchEvent")') &&
    !monkey.includes('Class.forName("com.android.commands.monkey.Monkey")'), "Monkey tool may call only the touch-event class");
  check(sources.includes("SystemClock.elapsedRealtime()"), "Android spike must use the monotonic Android clock");
  check(sources.includes("UNKNOWN_FAIL_OPEN"), "Android spike must preserve the unknown-surface fail-open safety path");
  return errors;
}
