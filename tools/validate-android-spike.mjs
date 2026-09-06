import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
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

  const sourcePaths = [
    "LabTimer.kt", "LabTimerStore.kt", "DeviceSignals.kt", "BootReceiver.kt", "MainActivity.kt", "EnforcementAccessibilityService.kt",
    "EnforcementTraceRecord.kt",
  ].map(name => `${spikeRoot}/app/src/main/kotlin/dev/kidremote/spike/enforcement/${name}`);
  const sources = sourcePaths.map(read).join("\n");
  for (const forbidden of [
    ".rootInActiveWindow", ".getSource()", ".source", "dispatchGesture(", "takeScreenshot(", "performGlobalAction(", "Log.",
  ]) check(!sources.includes(forbidden), `Android spike source contains unapproved access: ${forbidden}`);
  const debugTrace = read(`${spikeRoot}/app/src/debug/kotlin/dev/kidremote/spike/enforcement/EnforcementTrace.kt`);
  const releaseTrace = read(`${spikeRoot}/app/src/release/kotlin/dev/kidremote/spike/enforcement/EnforcementTrace.kt`);
  check(debugTrace.includes('private const val TRACE_TAG = "KidRemoteKR003"'), "Debug trace tag changed");
  check(debugTrace.includes("Log.i(TRACE_TAG, record.toLogLine())"), "Debug trace must log only the typed sanitized record");
  check(!debugTrace.includes("packageName") && !debugTrace.includes("AccessibilityEvent"), "Debug trace accepts sensitive/raw input");
  check(!releaseTrace.includes("android.util.Log") && !releaseTrace.includes("toLogLine"), "Release trace must remain a no-op");
  check(sources.includes("SystemClock.elapsedRealtime()"), "Android spike must use the monotonic Android clock");
  check(sources.includes("UNKNOWN_FAIL_OPEN"), "Android spike must preserve the unknown-surface fail-open safety path");
  return errors;
}
