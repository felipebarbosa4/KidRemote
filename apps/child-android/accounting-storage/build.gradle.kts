plugins { id("com.android.library") }
android {
    namespace="dev.kidremote.accounting.storage"
    compileSdk=37
    defaultConfig { minSdk=28 }
    compileOptions { sourceCompatibility=JavaVersion.VERSION_17;targetCompatibility=JavaVersion.VERSION_17 }
}
dependencies {
    api("androidx.room:room-runtime:2.8.5")
    annotationProcessor("androidx.room:room-compiler:2.8.5")
}
