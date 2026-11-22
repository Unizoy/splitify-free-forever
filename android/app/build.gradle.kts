plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Push (phase 13, D-020): only when the owner has put the Firebase file in the git-ignored secrets/ folder.
// It is copied next to this script (also git-ignored) and the Google Services plugin turns it into resources,
// so Firebase.initializeApp() works without firebase_options.dart. Without it the app runs with push off.
val firebaseConfig = rootProject.file("../secrets/google-services.json")
if (firebaseConfig.exists()) {
    firebaseConfig.copyTo(file("google-services.json"), overwrite = true)
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.unizoy.splitify"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.unizoy.splitify"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Payment capture core tests (phase 18b): plain JVM JUnit; org.json is only a stub in android.jar.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
