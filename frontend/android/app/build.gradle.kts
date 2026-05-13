import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// v23.1 part 125 — Phase 2 audit B1/B8 :
// Lit le keystore release depuis android/key.properties (gitignored).
// Si le fichier est absent (cas dev local sans cert), on retombe sur
// le keystore debug pour que `flutter run` continue de marcher. Le
// release CI/Play Store doit IMPÉRATIVEMENT avoir key.properties.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
val hasReleaseKeystore = keyPropertiesFile.exists()
if (hasReleaseKeystore) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.hopetsit.app"
    compileSdk = flutter.compileSdkVersion
    // v20.0.6 — Pinned NDK to 27.0.12077973 (stable on Windows). NDK 28.2
    // had a CMake bug "CMAKE_CXX_COMPILER not set, after EnableLanguage"
    // that broke `flutter build apk --release` on Windows builds.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.hopetsit.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // v23.1 part 125 — Phase 2 audit B1 : keystore release distinct.
    // Voir android/key.properties.example pour le format attendu.
    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // v23.1 part 125 — Phase 2 audit B1/B2 :
            //  - Signing : keystore release si key.properties existe,
            //    debug sinon (dev local seulement, JAMAIS pour le Play Store).
            //  - minify + shrinkResources : code Dart est déjà AOT, mais R8
            //    élimine le bytecode Kotlin / Java mort (Stripe purgé, etc.)
            //    et obfuscit les noms — extraction APK 5× plus dure.
            //  - proguard-rules.pro maintient les classes de
            //    Firebase / Cloudinary / socket.io / Geolocator / etc.
            //    qui font de la reflection runtime.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // Debug build : pas de minify, sinon `flutter run` casse les
            // hot reloads et l'attachement du debugger.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for Java 8+ APIs (desugaring)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Useful to have latest AndroidX extensions
    implementation("androidx.core:core-ktx:1.15.0")
}
