package tn.isetbizerte.mangeoire_admin

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var nfc: NfcLecteur? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messager = flutterEngine.dartExecutor.binaryMessenger
        val lecteur = NfcLecteur(this)
        nfc = lecteur
        // Canal "nfc/tag" : lire le tag NFC d'une vache (uid) pour l'enregistrer
        MethodChannel(messager, "nfc/tag").setMethodCallHandler(lecteur)
    }

    override fun onDestroy() {
        nfc?.liberer() // libère le lecteur NFC
        super.onDestroy()
    }
}
