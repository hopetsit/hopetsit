# v23.1 part 125 — Phase 2 audit B3.
# Règles R8 / ProGuard activées via isMinifyEnabled=true + isShrinkResources=true.
# Le code Dart est déjà AOT-compilé donc invisible à R8 ; ces règles
# concernent les libs Kotlin / Java embarquées par Flutter plugins.

# ─── Garde-fous généraux ─────────────────────────────────────────────────
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses, SourceFile, LineNumberTable
# Préserve les stack traces pour Crashlytics / Sentry.
-renamesourcefileattribute SourceFile

# ─── Flutter engine ──────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase (Auth, Messaging, Crashlytics) ─────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keepclassmembers class * {
    @com.google.firebase.firestore.IgnoreExtraProperties <fields>;
}

# ─── Google Maps + Geolocator + Geocoding ────────────────────────────────
-keep class com.google.android.libraries.maps.** { *; }
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.google.android.libraries.maps.**

# ─── Socket.IO client ────────────────────────────────────────────────────
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# ─── OkHttp / Okio (transport de plusieurs libs) ─────────────────────────
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ─── Airwallex (webview HPP — pas de SDK natif, mais on garde par sécurité)
-keep class com.airwallex.** { *; }
-dontwarn com.airwallex.**

# ─── Stripe (resté en .env pour rollback, jamais appelé) ─────────────────
-keep class com.stripe.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.stripe.**

# ─── Cloudinary upload + URL signing ─────────────────────────────────────
-keep class com.cloudinary.** { *; }
-dontwarn com.cloudinary.**

# ─── flutter_local_notifications (reflection sur les pending intents) ───
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ─── pdf / printing / file_picker / image_picker ─────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ─── webview_flutter ─────────────────────────────────────────────────────
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# ─── url_launcher / app_links / share_plus ───────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class com.llfbandit.app_links.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# ─── Sentry Flutter (besoin de SourceFile + Line + classes d'exception) ──
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# ─── Parcelize ───────────────────────────────────────────────────────────
-dontwarn kotlinx.parcelize.Parceler$DefaultImpls
-dontwarn kotlinx.parcelize.Parceler
-dontwarn kotlinx.parcelize.Parcelize

# ─── Kotlin coroutines (reflection sur Continuations) ────────────────────
-dontwarn kotlinx.coroutines.**
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ─── Sign-in providers (Google + Apple via webview) ──────────────────────
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }
-dontwarn com.aboutyou.dart_packages.sign_in_with_apple.**

# ─── Sentry / Crashlytics keep stack trace cleanliness ───────────────────
-keep class com.google.firebase.crashlytics.** { *; }
-keepattributes LineNumberTable, SourceFile

# ─── Kotlin reflection (utilisé par certaines libs de serialization) ─────
-dontwarn kotlin.reflect.**

# ─── Suppression d'avertissements pour libs facultatives non incluses ────
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
