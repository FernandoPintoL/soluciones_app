# Reglas de ProGuard para ML Kit y mobile_scanner
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.mlkit.vision.barcode.** { *; }
-keep class com.google.mlkit.vision.** { *; }
-keep class com.google.mlkit.common.** { *; }

# Mantener inyección de dependencias de ML Kit
-keep class **.MlKitInitProvider { *; }
-keep class **.MlKitComponentImpl { *; }
-keep class **.MlKitInitProvider$* { *; }

# Mantener clases internas de ML Kit
-keepclassmembers class ** {
    public <init>(...);
    public <methods>;
}

# Mantener enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Mantener anotaciones
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Mantener clases de la cámara
-keep class android.hardware.camera** { *; }

# No renombrar clases de ML Kit
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**