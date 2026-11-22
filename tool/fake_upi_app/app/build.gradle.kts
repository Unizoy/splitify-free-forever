plugins {
    id("com.android.application")
}

android {
    namespace = "dev.splitify.fakeupi"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.splitify.fakeupi"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
