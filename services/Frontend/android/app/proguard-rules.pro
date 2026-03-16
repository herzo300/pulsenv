# Flutter-specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep WebView JavaScript interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# Keep HTTP/network classes
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Google Play Core (referenced by Flutter but not used without deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# TensorFlow Lite GPU symbols can be referenced by the plugin even when the
# app only uses CPU/XNNPack delegates.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# ML Kit text recognizer options are resolved dynamically by the plugin.
# Keep R8 from failing release minification when optional script packages
# are not bundled in the app.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# Reduce useful metadata for reverse engineering.
-adaptclassstrings
-repackageclasses
-renamesourcefileattribute SourceFile
