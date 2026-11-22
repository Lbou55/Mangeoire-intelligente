package tn.isetbizerte.mangeoire_eleveur

import android.app.Activity
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import android.os.CancellationSignal
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Canal "biometrie/auth" : empreinte digitale avec la boîte de dialogue du système
 * (android.hardware.biometrics.BiometricPrompt, Android 9+, sans bibliothèque ni thème AppCompat).
 *  - disponible()    -> true si le téléphone a un capteur ET au moins une empreinte enregistrée
 *  - authentifier()  -> true = reconnue, false = annulée ; erreur BIO_ERREUR sinon
 */
class BiometrieLecteur(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val lock = Any()
    private var pending: MethodChannel.Result? = null
    private var signal: CancellationSignal? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "disponible" -> result.success(empreintePrete())
            "authentifier" -> authentifier(call, result)
            "annuler" -> {
                signal?.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun empreintePrete(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)) return false
        return try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                    val m = activity.getSystemService(BiometricManager::class.java)
                    m.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK) ==
                        BiometricManager.BIOMETRIC_SUCCESS
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                    activity.getSystemService(BiometricManager::class.java).canAuthenticate() ==
                        BiometricManager.BIOMETRIC_SUCCESS
                }
                else -> {
                    val f = activity.getSystemService(FingerprintManager::class.java)
                    f != null && f.isHardwareDetected && f.hasEnrolledFingerprints()
                }
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun authentifier(call: MethodCall, result: MethodChannel.Result) {
        if (!empreintePrete()) {
            result.error("BIO_INDISPONIBLE", "Aucune empreinte disponible sur ce téléphone.", null)
            return
        }
        val accepted = synchronized(lock) {
            if (pending != null) false else { pending = result; true }
        }
        if (!accepted) {
            result.error("DEJA_EN_COURS", "Une vérification est déjà en cours.", null)
            return
        }

        val titre = call.argument<String>("titre") ?: "Empreinte digitale"
        val sousTitre = call.argument<String>("sous_titre") ?: ""
        val annuler = call.argument<String>("annuler") ?: "Annuler"
        val executeur = activity.mainExecutor
        val cancel = CancellationSignal().also { signal = it }

        try {
            val prompt = BiometricPrompt.Builder(activity)
                .setTitle(titre)
                .setSubtitle(sousTitre)
                .setNegativeButton(annuler, executeur) { _, _ -> finir { it.success(false) } }
                .build()

            prompt.authenticate(cancel, executeur, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult?) {
                    finir { it.success(true) }
                }

                override fun onAuthenticationError(code: Int, message: CharSequence?) {
                    // 5 = annulé par le système, 10 = annulé par l'utilisateur
                    if (code == 5 || code == 10) finir { it.success(false) }
                    else finir { it.error("BIO_ERREUR", message?.toString() ?: "Erreur $code", null) }
                }
                // onAuthenticationFailed : doigt non reconnu, la boîte de dialogue reste ouverte
            })
        } catch (e: Exception) {
            finir { it.error("BIO_ERREUR", e.message ?: "Impossible de lancer la vérification.", null) }
        }
    }

    private fun finir(reponse: (MethodChannel.Result) -> Unit) {
        val r = synchronized(lock) { pending.also { pending = null } } ?: return
        signal = null
        reponse(r)
    }
}
