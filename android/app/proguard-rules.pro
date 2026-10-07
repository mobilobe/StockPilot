# Keep Flutter and plugin entry points discovered through reflection.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter references Play Core split-compat support when available; this app
# does not package that optional API.
-dontwarn com.google.android.play.core.**
