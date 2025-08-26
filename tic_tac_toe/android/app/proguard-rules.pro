# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Google Play Core classes
-keep class com.google.android.play.core.** { *; }

# Keep audio player classes
-keep class xyz.luan.audioplayers.** { *; }

# Keep confetti classes
-keep class nl.dionsegijn.konfetti.** { *; }

# Keep Lottie classes
-keep class com.airbnb.lottie.** { *; }

# Preserve line number information for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
-renamesourcefileattribute SourceFile

# Disable R8 full mode for compatibility
-dontoptimize
