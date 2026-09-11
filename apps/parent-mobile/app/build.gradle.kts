plugins { id("com.android.application"); id("org.jetbrains.kotlin.plugin.compose") }
android {
    namespace = "dev.kidremote.parent"
    compileSdk = 37
    buildToolsVersion = "37.0.0"
    defaultConfig {
        applicationId = "dev.kidremote.parent.unassigned"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.0.1-local"
    }
    buildTypes { debug { applicationIdSuffix = ".debug" }; release { isMinifyEnabled = false } }
    buildFeatures { compose = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    testOptions { unitTests.isReturnDefaultValues = false }
}
java { toolchain { languageVersion = JavaLanguageVersion.of(17) } }
dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    testImplementation("junit:junit:4.13.2")
}
