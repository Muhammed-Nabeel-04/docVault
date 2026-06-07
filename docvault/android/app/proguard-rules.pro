# encrypt package (PointyCastle)
-keep class org.bouncycastle.** { *; }
-keep class com.ionspin.kotlin.bignum.** { *; }

# flutter_secure_storage
-keep class androidx.security.crypto.** { *; }

# General
-dontwarn okhttp3.**
-dontwarn java.lang.invoke.**
