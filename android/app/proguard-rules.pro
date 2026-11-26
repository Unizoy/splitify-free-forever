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
