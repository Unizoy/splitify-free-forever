import java.util.Properties

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

// Release signing (phase 19, S-201): the first of secrets/release-key.properties and secrets/key.properties
// (both git-ignored) with storeFile, storePassword, keyAlias, keyPassword. storeFile may be absolute or relative to
// the properties file. Without either file, release builds are signed with the debug key so CI and contributors
// can still build them.
val releaseKeyFile = listOf("release-key.properties", "key.properties")
    .map { rootProject.file("../secrets/$it") }
    .firstOrNull { it.exists() }
val releaseKey = Properties().apply { releaseKeyFile?.inputStream()?.use { load(it) } }

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

    signingConfigs {
        if (releaseKeyFile != null) {
            create("release") {
                storeFile = releaseKeyFile.parentFile.resolve(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    // Compress the native libraries inside the APK (S-201): the APKs are downloaded from GitHub Releases, so
    // download size matters more than the small install-time cost of extracting them.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (releaseKeyFile != null) "release" else "debug")
            // R8 shrinking + resource shrinking; keep rules in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
}
