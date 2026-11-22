package tn.isetbizerte.mangeoire_eleveur

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var nfc: NfcLecteur? = null
    private var sync: CanalSync? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messager = flutterEngine.dartExecutor.binaryMessenger

        // M1 : lecture d'un tag NFC (vache)
        val lecteur = NfcLecteur(this)
        nfc = lecteur
        MethodChannel(messager, "nfc/tag").setMethodCallHandler(lecteur)

        // QR code d'invitation (ML Kit code scanner)
        MethodChannel(messager, "qr/scanner").setMethodCallHandler(QrScanner(this))

        // Empreinte digitale
        MethodChannel(messager, "biometrie/auth").setMethodCallHandler(BiometrieLecteur(this))

        // M2 + M3 : alertes en arrière-plan, widget, seuils, mesures hors ligne
        val canal = MethodChannel(messager, "sync/planifier")
        val canalSync = CanalSync(this)
        canalSync.canal = canal
        canal.setMethodCallHandler(canalSync)
        sync = canalSync
        Alertes.creerCanal(this)

        // démarrage à froid depuis le bouton « Voir la fiche » d'une notification
        canalSync.recevoirIntent(intent, chaud = false)
    }

    // application déjà ouverte : (launchMode singleTop) la notification arrive ici
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sync?.recevoirIntent(intent, chaud = true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        sync?.surResultatPermission(requestCode, grantResults)
    }

    override fun onPause() {
        nfc?.liberer()
        super.onPause()
    }

    override fun onDestroy() {
        nfc?.liberer()
        sync?.liberer()
        super.onDestroy()
    }
}
