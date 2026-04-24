##-------------------------------------------------------------------------------
## flutter_local_notifications
## Keeps the broadcast receivers and services that schedule/deliver notifications.
## Without these rules R8 strips the classes in release builds, silently breaking
## all notification scheduling and delivery.
##-------------------------------------------------------------------------------
-keep class com.dexterous.** { *; }

##-------------------------------------------------------------------------------
## Flutter engine & plugin registrant
##-------------------------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

##-------------------------------------------------------------------------------
## General: keep all classes referenced only via reflection / JNI
##-------------------------------------------------------------------------------
-keepattributes *Annotation*
-keepattributes Signature
