package tn.isetbizerte.mangeoire_eleveur

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject

private val Context.donnees: DataStore<Preferences> by preferencesDataStore(name = "mangeoire")

/** Adresse du serveur + jeton, transmis par Flutter pour que le Worker appelle le serveur seul. */
data class Config(val baseUrl: String, val token: String)

/** Dernière mesure d'une vache (gardée sur le téléphone : lisible hors ligne, affichée dans le widget). */
data class Mesure(
    val cowId: String,
    val date: String,
    val consommeG: Double,
    val derniereVisite: String?,
    val appetit: String?,      // decreasing | stable | increasing | null
    val pctBaisse: Double?,    // probabilité de baisse d'appétit (%)
) {
    /** Alerte = appétit en baisse ET probabilité >= seuil choisi par l'éleveur. */
    fun estAlerte(seuilPct: Int): Boolean =
        appetit == "decreasing" && (pctBaisse == null || pctBaisse >= seuilPct)

    fun toJson(): JSONObject = JSONObject()
        .put("cow_id", cowId)
        .put("date", date)
        .put("consumed_g", consommeG)
        .put("last_visit", derniereVisite ?: JSONObject.NULL)
        .put("appetite", appetit ?: JSONObject.NULL)
        .put("decrease_pct", pctBaisse ?: JSONObject.NULL)

    companion object {
        fun fromJson(o: JSONObject) = Mesure(
            cowId = o.optString("cow_id"),
            date = o.optString("date"),
            consommeG = o.optDouble("consumed_g", 0.0),
            derniereVisite = if (o.isNull("last_visit")) null else o.optString("last_visit"),
            appetit = if (o.isNull("appetite")) null else o.optString("appetite"),
            pctBaisse = if (o.isNull("decrease_pct")) null else o.optDouble("decrease_pct"),
        )
    }
}

/** Bonus : seuils + dernières mesures dans DataStore (Preferences). */
object Stockage {
    const val SEUIL_DEFAUT = 50

    private val BASE_URL = stringPreferencesKey("base_url")
    private val TOKEN = stringPreferencesKey("token")
    private val SEUIL = intPreferencesKey("seuil_pct")
    private val LANGUE = stringPreferencesKey("langue")
    private val MESURES = stringPreferencesKey("mesures_json")
    private val NOTIFIES = stringSetPreferencesKey("notifies")

    suspend fun sauverConfig(ctx: Context, baseUrl: String, token: String) {
        ctx.donnees.edit { it[BASE_URL] = baseUrl; it[TOKEN] = token }
    }

    suspend fun config(ctx: Context): Config? {
        val p = ctx.donnees.data.first()
        val url = p[BASE_URL]
        val token = p[TOKEN]
        return if (url.isNullOrBlank() || token.isNullOrBlank()) null else Config(url, token)
    }

    /** Déconnexion : on oublie le jeton et les mesures. */
    suspend fun effacerTout(ctx: Context) {
        ctx.donnees.edit {
            it.remove(BASE_URL); it.remove(TOKEN); it.remove(MESURES); it.remove(NOTIFIES)
        }
    }

    suspend fun seuil(ctx: Context): Int = ctx.donnees.data.first()[SEUIL] ?: SEUIL_DEFAUT
    suspend fun definirSeuil(ctx: Context, pct: Int) {
        ctx.donnees.edit { it[SEUIL] = pct.coerceIn(0, 100) }
    }

    suspend fun langue(ctx: Context): String = ctx.donnees.data.first()[LANGUE] ?: "fr"
    suspend fun definirLangue(ctx: Context, code: String) {
        ctx.donnees.edit { it[LANGUE] = if (code == "ar") "ar" else "fr" }
    }

    suspend fun sauverMesures(ctx: Context, mesures: List<Mesure>) {
        val json = JSONArray().also { a -> mesures.forEach { a.put(it.toJson()) } }.toString()
        ctx.donnees.edit { it[MESURES] = json }
    }

    suspend fun mesuresJson(ctx: Context): String = ctx.donnees.data.first()[MESURES] ?: "[]"

    suspend fun mesures(ctx: Context): List<Mesure> = try {
        val a = JSONArray(mesuresJson(ctx))
        (0 until a.length()).map { Mesure.fromJson(a.getJSONObject(it)) }
    } catch (e: Exception) {
        emptyList()
    }

    /** Évite de renotifier la même vache le même jour. */
    suspend fun dejaNotifies(ctx: Context): Set<String> = ctx.donnees.data.first()[NOTIFIES] ?: emptySet()
    suspend fun marquerNotifies(ctx: Context, cles: Set<String>) {
        ctx.donnees.edit { p ->
            val tous = ((p[NOTIFIES] ?: emptySet()) + cles).toList().takeLast(60)
            p[NOTIFIES] = tous.toSet()
        }
    }
}
