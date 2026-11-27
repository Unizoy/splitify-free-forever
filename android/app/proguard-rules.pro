# R8 keep rules for release builds (phase 19, S-201). Flutter, Firebase, WorkManager, ML Kit and androidx ship
# their own consumer rules; Supabase, JSON and the money engine are Dart code and need none.

# Our own Kotlin (home-screen widget providers, channels): small, and some classes are
# only reached from the manifest or by name, so keep it whole.
-keep class com.unizoy.splitify.** { *; }

# Flutter's deferred-components support references Play Core, which this app does not ship.
-dontwarn com.google.android.play.core.**

# Keep line numbers for readable native stack traces; hide the original file names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Receipt scanning (D-034, S-370) bundles only the Latin text model; the plugin also references the Chinese,
# Devanagari, Japanese and Korean recognisers (compileOnly), which this app does not ship.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
