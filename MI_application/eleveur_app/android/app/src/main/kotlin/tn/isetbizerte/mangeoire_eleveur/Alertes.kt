package tn.isetbizerte.mangeoire_eleveur

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/** Module 2 : notifications de baisse d'appétit (affichées même application fermée). */
object Alertes {
    const val CANAL = "alertes_appetit"
    const val ACTION_VOIR = "tn.isetbizerte.mangeoire_eleveur.VOIR_FICHE"
    const val ACTION_IGNORER = "tn.isetbizerte.mangeoire_eleveur.IGNORER"
    const val EXTRA_COW = "cow_id"
    const val EXTRA_NOTIF = "notif_id"

    /** Textes de la notification (français / arabe, langue choisie dans l'app). */
    class Textes(
        val titre: String,
        val voir: String,
        val ignorer: String,
        private val une: String,
        private val plusieurs: String,
    ) {
        fun pourVache(cow: String, pct: Double?): String =
            une.replace("{cow}", cow).replace("{pct}", pct?.let { "%.0f".format(it) } ?: "?")

        fun pourPlusieurs(n: Int): String = plusieurs.replace("{n}", n.toString())
    }

    fun textes(langue: String): Textes =
        if (langue == "ar") {
            Textes(
                "انخفاض الشهية", "عرض البطاقة", "تجاهل",
                "{cow} تأكل أقل من المعتاد (احتمال {pct} ٪).",
                "{n} أبقار تأكل أقل من المعتاد.",
            )
        } else {
            Textes(
                "Baisse d'appétit", "Voir la fiche", "Ignorer",
                "{cow} mange moins que d'habitude (probabilité {pct} %).",
                "{n} vaches mangent moins que d'habitude.",
            )
        }

    /** À appeler avant la première notification (Android 8+). */
    fun creerCanal(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel(CANAL, "Alertes d'appétit", NotificationManager.IMPORTANCE_HIGH)
        canal.description = "Baisse d'appétit détectée par l'intelligence artificielle"
        ctx.getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
    }

    /** Android 13+ : permission POST_NOTIFICATIONS ; avant : notifications activées dans les réglages. */
    fun permissionAccordee(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        return NotificationManagerCompat.from(ctx).areNotificationsEnabled()
    }

    /** [cowId] vide = notification groupée (ouvre simplement l'application). */
    fun afficher(ctx: Context, cowId: String, titre: String, texte: String, textes: Textes) {
        if (!permissionAccordee(ctx)) return
        creerCanal(ctx)
        val idNotif = if (cowId.isEmpty()) 1 else (cowId.hashCode() and 0x7fffffff) % 100000 + 10

        // « Voir la fiche » -> ramène dans l'application, sur la fiche de la vache
        val voir = Intent(ctx, MainActivity::class.java).apply {
            action = ACTION_VOIR
            putExtra(EXTRA_COW, cowId)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pVoir = PendingIntent.getActivity(
            ctx, idNotif, voir, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // « Ignorer » -> simple fermeture de la notification (BroadcastReceiver)
        val ignorer = Intent(ctx, AlerteReceiver::class.java).apply {
            action = ACTION_IGNORER
            putExtra(EXTRA_NOTIF, idNotif)
        }
        val pIgnorer = PendingIntent.getBroadcast(
            ctx, idNotif, ignorer, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notif = NotificationCompat.Builder(ctx, CANAL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(titre)
            .setContentText(texte)
            .setStyle(NotificationCompat.BigTextStyle().bigText(texte))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setAutoCancel(true)
            .setContentIntent(pVoir)
            .addAction(0, textes.voir, pVoir)
            .addAction(0, textes.ignorer, pIgnorer)
            .build()

        try {
            NotificationManagerCompat.from(ctx).notify(idNotif, notif)
        } catch (e: SecurityException) {
            // permission retirée entre-temps : on n'affiche rien
        }
    }
}

/** Bouton « Ignorer » de la notification. */
class AlerteReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Alertes.ACTION_IGNORER) {
            val id = intent.getIntExtra(Alertes.EXTRA_NOTIF, -1)
            if (id >= 0) NotificationManagerCompat.from(context).cancel(id)
        }
    }
}
