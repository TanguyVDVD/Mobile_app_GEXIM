package be.gexim.firestop_tracker

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    // Copie en attente de l'accord de stockage (Android 9 et antérieurs).
    private var enAttente: (() -> Unit)? = null
    private var refus: (() -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Voir `lib/features/capture/galerie.dart`.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_GALERIE)
            .setMethodCallHandler { call, result ->
                if (call.method != "ajouter") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val chemin = call.argument<String>("chemin")
                val nom = call.argument<String>("nom")
                if (chemin == null || nom == null) {
                    result.error("argument", "chemin ou nom manquant", null)
                    return@setMethodCallHandler
                }

                val copier = {
                    // Hors du fil d'affichage : c'est une écriture disque.
                    Thread {
                        try {
                            ajouterALaGalerie(File(chemin), nom)
                            runOnUiThread { result.success(null) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("copie", e.message ?: e.toString(), null)
                            }
                        }
                    }.start()
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ||
                    checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                    PackageManager.PERMISSION_GRANTED
                ) {
                    copier()
                } else if (enAttente != null) {
                    result.error("accord", "une demande d'accès est déjà en cours", null)
                } else {
                    enAttente = copier
                    refus = {
                        result.error("accord", "accès au stockage refusé", null)
                    }
                    requestPermissions(
                        arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                        DEMANDE_STOCKAGE,
                    )
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != DEMANDE_STOCKAGE) return

        val accorde = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        val suite = if (accorde) enAttente else refus
        enAttente = null
        refus = null
        suite?.invoke()
    }

    private fun ajouterALaGalerie(source: File, nom: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val valeurs = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, nom)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/" + ALBUM,
                )
                // Invisible tant que l'écriture n'est pas finie : la galerie ne
                // montre jamais une image à moitié copiée.
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val collection =
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = contentResolver.insert(collection, valeurs)
                ?: throw IllegalStateException("la galerie a refusé l'image")
            try {
                val sortie = contentResolver.openOutputStream(uri)
                    ?: throw IllegalStateException("la galerie a refusé l'image")
                sortie.use { source.inputStream().use { entree -> entree.copyTo(it) } }
                valeurs.clear()
                valeurs.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, valeurs, null, null)
            } catch (e: Exception) {
                contentResolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val dossier = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                ALBUM,
            )
            if (!dossier.exists() && !dossier.mkdirs()) {
                throw IllegalStateException("dossier de la galerie inaccessible")
            }
            val cible = File(dossier, nom)
            source.copyTo(cible, overwrite = true)
            // Sans cela l'image n'apparaît dans la galerie qu'au redémarrage.
            MediaScannerConnection.scanFile(
                this, arrayOf(cible.absolutePath), arrayOf("image/jpeg"), null,
            )
        }
    }

    private companion object {
        const val CANAL_GALERIE = "be.gexim.firestop_tracker/galerie"
        const val ALBUM = "FireStop"
        const val DEMANDE_STOCKAGE = 4107
    }
}
