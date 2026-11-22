package tn.isetbizerte.mangeoire_eleveur

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class JetonInvalideException : Exception("Jeton refusé (401)")
class AbonnementExpireException : Exception("Abonnement expiré (402)")
class DonneeAbsenteException : Exception("Aucune donnée (404)")

/** Appels HTTP du Worker (aucune bibliothèque : HttpURLConnection sur Dispatchers.IO). */
object ClientServeur {
    private fun get(cfg: Config, chemin: String): String {
        val url = URL(cfg.baseUrl.trimEnd('/') + chemin)
        val c = url.openConnection() as HttpURLConnection
        try {
            c.requestMethod = "GET"
            c.connectTimeout = 30_000
            c.readTimeout = 60_000 // le serveur gratuit peut mettre du temps à se réveiller
            c.setRequestProperty("Authorization", "Bearer ${cfg.token}")
            c.setRequestProperty("Accept", "application/json")
            return when (val code = c.responseCode) {
                200 -> c.inputStream.bufferedReader().use { it.readText() }
                401 -> throw JetonInvalideException()
                402 -> throw AbonnementExpireException()
                404 -> throw DonneeAbsenteException()
                else -> throw IOException("HTTP $code")
            }
        } finally {
            c.disconnect()
        }
    }

    private fun texte(o: JSONObject, cle: String): String? =
        if (!o.has(cle) || o.isNull(cle)) null else o.get(cle).toString().takeIf { it.isNotBlank() }

    /** Dernière mesure de chaque vache : appétit (IA) + dernière visite + quantité mangée. */
    suspend fun mesures(cfg: Config): List<Mesure> = withContext(Dispatchers.IO) {
        val appetit = JSONObject(get(cfg, "/home/appetite")).optJSONObject("appetite") ?: JSONObject()
        val vaches = appetit.keys().asSequence().toList().sorted().take(20)
        val out = mutableListOf<Mesure>()
        for (cow in vaches) {
            val classe = appetit.optJSONObject(cow)?.let { texte(it, "appetite") }
            val dernier = try {
                JSONObject(get(cfg, "/latest/$cow"))
            } catch (e: DonneeAbsenteException) {
                null
            }
            val pct = dernier?.optJSONObject("appetite_pct")?.let { p ->
                p.keys().asSequence().filter { it.startsWith("decreas") }
                    .map { p.optDouble(it) }.maxOrNull()
            }
            out += Mesure(
                cowId = cow,
                date = dernier?.let { texte(it, "date") } ?: "",
                consommeG = dernier?.optDouble("total_food_consumed_g", 0.0) ?: 0.0,
                derniereVisite = dernier?.let { texte(it, "last_visit_hour") },
                appetit = classe,
                pctBaisse = pct,
            )
        }
        out
    }
}

/**
 * Module 2 : vérification toutes les heures (WorkManager), même application fermée.
 *  - lit les dernières mesures sur le serveur ;
 *  - les garde sur le téléphone (hors ligne) et met le widget à jour ;
 *  - affiche une notification si l'appétit baisse au-delà du seuil.
 */
class VerificationWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result {
        val ctx = applicationContext
        val silencieux = inputData.getBoolean(ENTREE_SILENCIEUX, false)
        val manuel = inputData.getBoolean(ENTREE_MANUEL, false)
        val cfg = Stockage.config(ctx) ?: return Result.success() // déconnecté : rien à faire

        return try {
            val mesures = ClientServeur.mesures(cfg)
            Stockage.sauverMesures(ctx, mesures)
            MangeoireWidget.rafraichir(ctx)
            if (!silencieux) notifier(ctx, mesures, forcer = manuel)
            Result.success()
        } catch (e: IOException) {
            // pas de réseau / serveur qui dort : on réessaie (3 fois), puis on attend l'heure suivante
            if (runAttemptCount < 3) Result.retry() else Result.success()
        } catch (e: JetonInvalideException) {
            Result.success()
        } catch (e: AbonnementExpireException) {
            Result.success()
        }
    }

    private suspend fun notifier(ctx: Context, mesures: List<Mesure>, forcer: Boolean) {
        if (!Alertes.permissionAccordee(ctx)) return
        val seuil = Stockage.seuil(ctx)
        val textes = Alertes.textes(Stockage.langue(ctx))
        val deja = if (forcer) emptySet() else Stockage.dejaNotifies(ctx)

        val aAlerter = mesures.filter { it.estAlerte(seuil) && "${it.cowId}|${it.date}" !in deja }
        if (aAlerter.isEmpty()) return

        if (aAlerter.size <= 3) {
            aAlerter.forEach { Alertes.afficher(ctx, it.cowId, textes.titre, textes.pourVache(it.cowId, it.pctBaisse), textes) }
        } else {
            Alertes.afficher(ctx, "", textes.titre, textes.pourPlusieurs(aAlerter.size), textes)
        }
        Stockage.marquerNotifies(ctx, aAlerter.map { "${it.cowId}|${it.date}" }.toSet())
    }

    companion object {
        const val NOM_PERIODIQUE = "verification_appetit"
        const val NOM_IMMEDIAT = "verification_immediate"
        const val ENTREE_SILENCIEUX = "silencieux"
        const val ENTREE_MANUEL = "manuel"
    }
}
