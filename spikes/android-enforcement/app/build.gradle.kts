plugins {
    id("com.android.application")
}

android {
    namespace = "dev.kidremote.spike.enforcement"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.kidremote.spike.enforcement"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.0.1-spike"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = false
    }
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
