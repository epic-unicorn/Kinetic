# flutter_local_notifications uses Gson with TypeToken for serializing scheduled
# notifications. R8 strips generic signatures by default, which breaks TypeToken
# at runtime with "TypeToken must be created with a type argument" error.
# These rules preserve the signatures Gson needs.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep the flutter_local_notifications receiver and its dependencies.
-keep class com.dexterous.** { *; }

# SQLite3MultipleCiphers / JNI used by package:sqlite3 encryption.
-keep class com.jetradarmobile.sqlite.** { *; }
-dontwarn org.sqlite.**
