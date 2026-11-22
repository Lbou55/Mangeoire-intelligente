package tn.isetbizerte.mangeoire_eleveur

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import android.content.Intent

/**
 * Module 3 : widget de l'écran d'accueil (Jetpack Glance).
 * Affiche la dernière visite et la quantité mangée ; devient rouge en cas d'alerte,
 * sans ouvrir l'application. Les données viennent de DataStore (remplies par le Worker).
 */
class MangeoireWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val mesures = Stockage.mesures(context)
        val seuil = Stockage.seuil(context)
        val langue = Stockage.langue(context)
        // la vache en alerte d'abord, sinon la mesure la plus récente
        val focus = mesures.firstOrNull { it.estAlerte(seuil) } ?: mesures.maxByOrNull { it.date }
        val nbAlertes = mesures.count { it.estAlerte(seuil) }

        provideContent { Contenu(context, focus, nbAlertes, langue) }
    }

    @Composable
    private fun Contenu(context: Context, m: Mesure?, nbAlertes: Int, langue: String) {
        val ar = langue == "ar"
        val alerte = nbAlertes > 0
        val fond = if (alerte) Color(0xFFFFE4E1) else Color(0xFFEAF2FF)
        val encre = if (alerte) Color(0xFF8A1C12) else Color(0xFF0B2A5B)

        fun style(taille: Int, gras: Boolean = false) = TextStyle(
            color = ColorProvider(encre),
            fontSize = taille.sp,
            fontWeight = if (gras) FontWeight.Bold else FontWeight.Normal,
        )

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(ColorProvider(fond))
                .cornerRadius(22.dp)
                .padding(14.dp)
                .clickable(actionStartActivity(Intent(context, MainActivity::class.java))),
        ) {
            Text("Mangeoire", style = style(12, true))
            Spacer(GlanceModifier.height(4.dp))
            if (m == null) {
                Text(if (ar) "لا توجد قياسات بعد" else "Aucune mesure pour le moment", style = style(14))
            } else {
                Text(m.cowId, style = style(22, true))
                Spacer(GlanceModifier.height(2.dp))
                val visite = m.derniereVisite ?: m.date.ifEmpty { "—" }
                Text((if (ar) "آخر زيارة : " else "Dernière visite : ") + visite, style = style(13))
                Text(
                    (if (ar) "المأكول : " else "Mangé : ") + "%.2f kg".format(m.consommeG / 1000.0),
                    style = style(13),
                )
                if (alerte) {
                    Spacer(GlanceModifier.height(4.dp))
                    Text(
                        if (ar) "⚠ انخفاض الشهية ($nbAlertes)" else "⚠ Baisse d'appétit ($nbAlertes)",
                        style = style(13, true),
                    )
                }
            }
        }
    }

    companion object {
        /** Redessine tous les widgets posés sur l'écran d'accueil. */
        suspend fun rafraichir(ctx: Context) {
            MangeoireWidget().updateAll(ctx)
        }
    }
}

class MangeoireWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MangeoireWidget()
}
