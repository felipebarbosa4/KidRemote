plugins { id("com.android.application"); id("org.jetbrains.kotlin.plugin.compose") }
// Bounded update lab: both debug versions are built in one CI job/signing identity.
val updateVersion=providers.gradleProperty("kr008UpdateVersion").orElse("2").get().toInt().also{require(it in 1..2)}
android {
    namespace="dev.kidremote.child"
    compileSdk=37
    buildToolsVersion="37.0.0"
    defaultConfig { applicationId="dev.kidremote.child.unassigned"; minSdk=28; targetSdk=36; versionCode=updateVersion;versionName="0.0.$updateVersion-local";testInstrumentationRunner="androidx.test.runner.AndroidJUnitRunner" }
    buildTypes { debug {applicationIdSuffix=".debug"}; release {isMinifyEnabled=false} }
    buildFeatures {compose=true}
    compileOptions {sourceCompatibility=JavaVersion.VERSION_17;targetCompatibility=JavaVersion.VERSION_17}
}
java {toolchain {languageVersion=JavaLanguageVersion.of(17)}}
dependencies {
    implementation(project(":accounting-storage"))
    implementation("androidx.room:room-runtime:2.8.5")
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    implementation("com.google.zxing:core:3.5.4")
    implementation("androidx.camera:camera-camera2:1.6.2")
    implementation("androidx.camera:camera-lifecycle:1.6.2")
    implementation("androidx.camera:camera-view:1.6.2")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation(platform("androidx.compose:compose-bom:2026.09.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.4.0")
}
