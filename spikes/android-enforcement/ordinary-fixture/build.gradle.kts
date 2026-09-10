plugins { id("com.android.application") }

android {
    namespace = "dev.kidremote.spike.ordinary"
    compileSdk = 36
    defaultConfig {
        applicationId = "dev.kidremote.spike.ordinary"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.0.1-fixture"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
java { toolchain { languageVersion = JavaLanguageVersion.of(17) } }
