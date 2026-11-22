// Fake UPI handler for emulator tests (phase 11 T5, planning/research/06-upi-release-ci.md §2).
// Debug-only helper, never shipped: answers `upi://pay` links, logs them with tag FAKE_UPI and returns.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "fake_upi_app"
include(":app")
