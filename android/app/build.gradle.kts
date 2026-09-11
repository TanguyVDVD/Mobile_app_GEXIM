import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// -----------------------------------------------------------------------------
// Clé de signature
// -----------------------------------------------------------------------------
//
// Lue depuis `android/key.properties`, hors du dépôt (`.gitignore`) — le
// keystore et ses mots de passe ne sont pas du code source.
//
// Le fichier est **facultatif** : absent, la compilation debug et `flutter run`
// continuent de fonctionner normalement. Seule une compilation release y perd
// sa signature, et le garde-fou en fin de fichier l'arrête alors avec un
// message explicite plutôt que de retomber en silence sur la clé de débogage.
val proprietesCle = Properties().apply {
    val fichier = rootProject.file("key.properties")
    if (fichier.exists()) fichier.inputStream().use { load(it) }
}
val cleDisponible = proprietesCle.getProperty("storeFile") != null

android {
    namespace = "be.gexim.firestop_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "be.gexim.firestop_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (cleDisponible) {
                storeFile = file(proprietesCle.getProperty("storeFile"))
                storePassword = proprietesCle.getProperty("storePassword")
                keyAlias = proprietesCle.getProperty("keyAlias")
                keyPassword = proprietesCle.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Jamais la clé de débogage — voir le garde-fou en fin de fichier.
            //
            // Sans keystore, on laisse `null` plutôt que de retomber sur la clé
            // de débogage : un APK signé debug s'installe, se lance et paraît
            // sain, mais sa clé est propre à la machine qui l'a produit. Aucune
            // mise à jour ne pourra jamais s'installer par-dessus sur les
            // tablettes — il faudrait désinstaller, donc perdre la base locale
            // et tout relevé non synchronisé.
            signingConfig = if (cleDisponible) signingConfigs.getByName("release") else null
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

// -----------------------------------------------------------------------------
// Garde-fou de signature
// -----------------------------------------------------------------------------
//
// À l'exécution du graphe de tâches, pas à la configuration. Le bloc
// `buildTypes` ci-dessus est évalué à **chaque** invocation de Gradle, y
// compris pour un `flutter run` en debug : une vérification posée dedans
// casserait le développement quotidien sur un poste sans keystore.
//
// Sans ce garde-fou, une release non signée ne produirait pas d'erreur claire —
// l'AGP sortirait un `app-release-unsigned.apk` et l'outil Flutter se
// plaindrait seulement de ne pas trouver l'APK attendu.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } && !cleDisponible) {
        throw GradleException(
            "Compilation release demandée sans clé de signature. " +
            "Créer android/key.properties (voir android/key.properties.example) " +
            "et le keystore qu'il désigne."
        )
    }
}
