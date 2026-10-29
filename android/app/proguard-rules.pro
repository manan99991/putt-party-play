-keep class com.google.android.gms.ads.** { *; }
-keep class com.android.vending.billing.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.android.gms.**
# pdfbox-android (Word Finder) optionally references a JPEG-2000 decoder we don't ship.
-dontwarn com.gemalto.jp2.**
-dontwarn org.bouncycastle.**
-dontwarn org.apache.fontbox.**
-keep class com.tom_roush.pdfbox.** { *; }
