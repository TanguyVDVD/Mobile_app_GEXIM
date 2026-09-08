plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "be.gexim.firestop_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "be.gexim.firestop_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// -----------------------------------------------------------------------------
// Plancher de compatibilité
// -----------------------------------------------------------------------------
//
// **Android 7.0 (2016)**, épinglé ici volontairement.
//
// Posé après le bloc `android { }`, et non dans `defaultConfig` : l'outil
// Flutter **réécrit** ce bloc à chaque `flutter build` et y restaure
// `minSdk = flutter.minSdkVersion`. Une valeur inscrite dedans disparaîtrait
// silencieusement à la compilation suivante, et l'APK sortirait avec un autre
// plancher sans que rien ne le signale.
//
// Pourquoi 24 et pas plus bas — les tablettes de chantier sont souvent
// anciennes, la question s'est posée :
//
//   * `camera_android_camerax` exige 23 ;
//   * `app_links`, tiré par `supabase_flutter` pour les liens profonds, exige
//     **24**, et c'est lui qui fixe le plancher. Le contourner par
//     `tools:overrideLibrary` ferait planter à l'exécution : cette
//     bibliothèque est initialisée au démarrage de Supabase.
//
// Descendre sous 24 imposerait donc de se passer de `supabase_flutter`, pour
// gagner Android 6.0 — moins de 1 % du parc, et un magasin d'autorités de
// certification qui commence à poser problème.
//
// L'épingler malgré tout a une utilité : une montée de version de Flutter qui
// relèverait son défaut à 26 ou 28 couperait sinon des tablettes en service,
// sans que personne ne s'en aperçoive avant le chantier.
android.defaultConfig.minSdk = 24
