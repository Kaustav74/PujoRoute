# ==============================================================================
# PujoRoute Production ProGuard / R8 Hardening Rules
# ==============================================================================

# 1. Strip logging statements from production release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
}

# 2. Preserve serialization models for local pandal & Panjika datasets
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 3. Flutter Engine & JNI Bridge Protection
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 4. Keep all JNI native method signatures
-keepclasseswithmembernames class * {
    native <methods>;
}

# 5. Preserve Plugin Native Implementations
-keep class com.baseflow.geolocator.** { *; }
-keep class dev.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }

# 6. Ignore harmless warnings for optional third-party components
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.google.android.play.core.**

