# Keep flutter_local_notifications classes
# -keep class io.flutter.plugins.localnotifications.* { *; }
# -keep class com.dexterous.flutterlocalnotifications.* { *; }
# -keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
# -keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }

# Jaga semua class dan method plugin notifikasi
-keep class com.dexterous.** { *; }

# Jaga semua class dan method Flutter engine
-keep class io.flutter.** { *; }

# Hindari rename receiver
-keepclassmembers class * {
    public <init>(...);
}

# Jaga fungsi yang di-tag dengan @Keep
-keep @androidx.annotation.Keep class * {*;}
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Menghentikan R8 dari mengeluh tentang class-class Google Play Core yang tidak digunakan
-dontwarn com.google.android.play.**

# Keep the notification icon drawable from being stripped by R8/ProGuard
-keep public class com.example.medimate.R$drawable {
    public static final int ic_notification;
}

# Pastikan attributes yang dibutuhkan oleh refleksi Gson tidak dihilangkan
-keepattributes Signature
-keepattributes InnerClasses

# Aturan spesifik untuk Gson guna mencegah penghapusan informasi jenis generik
# Ini sangat penting untuk deserialisasi objek kompleks yang digunakan oleh plugin notifikasi
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-keep class com.google.gson.internal.** { *; }
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter { *; }
-keep class * implements com.google.gson.ExclusionStrategy { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }
-keep class com.google.gson.reflect.TypeToken { *; }