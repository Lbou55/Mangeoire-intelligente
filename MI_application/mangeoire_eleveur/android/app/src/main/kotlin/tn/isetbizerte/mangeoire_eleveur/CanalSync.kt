package tn.isetbizerte.mangeoire_eleveur

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * Canal "sync/planifier" (modules 2 et 3) : planification WorkManager, permission de notification,
 * seuils / mesures hors ligne (DataStore) et ouverture de l'application depuis une notification.
 */
class CanalSync(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CODE_PERMISSION = 4201
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val ctx get() = activity.applicationContext

    /** Canal utilisé pour prévenir Flutter (Kotlin -> Dart : "surAction"). */
    var canal: MethodChannel? = null

    private var actionEnAttente: String? = null
    private var permissionResult: MethodChannel.Result? = null

    // ---------------------------------------------------- ouverture depuis une notification
    /** [chaud] = l'application était déjà ouverte (onNewIntent) ; sinon démarrage à froid. */
    fun recevoirIntent(intent: Intent?, chaud: Boolean) {
        if (intent?.action != Alertes.ACTION_VOIR) return
        val cow = intent.getStringExtra(Alertes.EXTRA_COW) ?: ""
        intent.action = null // ne pas rejouer l'action à la prochaine rotation
        if (cow.isEmpty()) return
        if (chaud) canal?.invokeMethod("surAction", cow) else actionEnAttente = cow
    }

    // ----------------------------------------------------------------- permission POST_NOTIFICATIONS
    fun surResultatPermission(code: Int, resultats: IntArray) {
        if (code != CODE_PERMISSION) return
        val r = permissionResult ?: return
        permissionResult = null
        r.success(resultats.isNotEmpty() && resultats[0] == PackageManager.PERMISSION_GRANTED)
    }

    // ------------------------------------------------------------------------------ appels Dart
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "demanderPermission" -> demanderPermission(result)
            "permissionAccordee" -> result.success(Alertes.permissionAccordee(ctx))

            "planifier" -> {
                val url = call.argument<String>("base_url")
                val token = call.argument<String>("token")
                if (url.isNullOrBlank() || token.isNullOrBlank()) {
                    result.error("ARGUMENT_INVALIDE", "base_url et token sont obligatoires.", null)
                    return
                }
                val seuil = call.argument<Int>("seuil_pct") ?: Stockage.SEUIL_DEFAUT
                val langue = call.argument<String>("langue") ?: "fr"
                repondre(result) {
                    Stockage.sauverConfig(ctx, url, token)
                    Stockage.definirSeuil(ctx, seuil)
                    Stockage.definirLangue(ctx, langue)
                    planifierHoraire()
                    null
                }
            }

            "annuler" -> repondre(result) {
                WorkManager.getInstance(ctx).cancelUniqueWork(VerificationWorker.NOM_PERIODIQUE)
                Stockage.effacerTout(ctx)
                MangeoireWidget.rafraichir(ctx)
                null
            }

            "verifierMaintenant" -> {
                val silencieux = call.argument<Boolean>("silencieux") ?: false
                val demande = OneTimeWorkRequestBuilder<VerificationWorker>()
                    .setConstraints(contraintes())
                    .setInputData(
                        workDataOf(
                            VerificationWorker.ENTREE_SILENCIEUX to silencieux,
                            VerificationWorker.ENTREE_MANUEL to !silencieux,
                        ),
                    )
                    .build()
                WorkManager.getInstance(ctx)
                    .enqueueUniqueWork(VerificationWorker.NOM_IMMEDIAT, ExistingWorkPolicy.REPLACE, demande)
                result.success(null)
            }

            // bonus : seuils + dernières mesures (DataStore)
            "lireSeuil" -> repondre(result) { Stockage.seuil(ctx) }
            "definirSeuil" -> {
                val pct = call.argument<Int>("seuil_pct") ?: Stockage.SEUIL_DEFAUT
                repondre(result) {
                    Stockage.definirSeuil(ctx, pct)
                    MangeoireWidget.rafraichir(ctx) // la couleur du widget dépend du seuil
                    null
                }
            }
            "definirLangue" -> {
                val langue = call.argument<String>("langue") ?: "fr"
                repondre(result) {
                    Stockage.definirLangue(ctx, langue)
                    MangeoireWidget.rafraichir(ctx)
                    null
                }
            }
            "dernieresMesures" -> repondre(result) { Stockage.mesuresJson(ctx) }

            // démarrage à froid depuis une notification
            "actionInitiale" -> {
                val cow = actionEnAttente
                actionEnAttente = null
                result.success(cow)
            }

            else -> result.notImplemented()
        }
    }

    private fun demanderPermission(result: MethodChannel.Result) {
        if (Alertes.permissionAccordee(ctx)) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(false) // désactivées dans les réglages du téléphone
            return
        }
        if (permissionResult != null) {
            result.error("DEJA_EN_COURS", "Une demande de permission est déjà en cours.", null)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), CODE_PERMISSION,
        )
    }

    private fun contraintes() =
        Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

    /** Toutes les heures, avec réseau ; UPDATE remplace la planification précédente. */
    private fun planifierHoraire() {
        val demande = PeriodicWorkRequestBuilder<VerificationWorker>(1, TimeUnit.HOURS)
            .setConstraints(contraintes())
            .build()
        WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(
            VerificationWorker.NOM_PERIODIQUE, ExistingPeriodicWorkPolicy.UPDATE, demande,
        )
    }

    private fun repondre(result: MethodChannel.Result, bloc: suspend () -> Any?) {
        scope.launch {
            try {
                val valeur = withContext(Dispatchers.IO) { bloc() }
                result.success(valeur)
            } catch (e: Exception) {
                result.error("SYNC_ERREUR", e.message ?: "Erreur de synchronisation.", null)
            }
        }
    }

    fun liberer() {
        permissionResult = null
        scope.cancel()
    }
}
