# Mangeoire Éleveur

Application de l'éleveur (téléphone Android). Elle rejoint la ferme d'un admin avec un **QR d'invitation**,
puis ne demande plus que l'**empreinte digitale**. Lecture seule : seul l'admin modifie les vaches.

| Écran | Contenu |
|---|---|
| Accueil | Vaches à surveiller, répartition de l'appétit, alertes non lues (mesures enregistrées si pas de réseau) |
| Vaches | Liste, recherche, filtre d'appétit, **bouton NFC** (approcher le tag → fiche de la vache) |
| Alertes | Alertes IA + messages de l'admin, action conseillée (vendre / vétérinaire / boucher), lecture au toucher |
| Profil | Langue FR/العربية, verrouillage par empreinte, seuil d'alerte, notifications, test, déconnexion |

Temps réel : WebSocket quand l'app est ouverte ; WorkManager chaque heure quand elle est fermée.
Abonnement de l'admin terminé → page « Abonnement de la ferme expiré ».

## Installer (PC Windows)
```bash
flutter create --org tn.isetbizerte --project-name mangeoire_eleveur --platforms android mangeoire_eleveur
```
Copier **par-dessus** (remplacer) dans `mangeoire_eleveur/` : `lib/`, `assets/`, `pubspec.yaml`,
`patch_gradle.py`, et tout le dossier `android/app/src/main/` (AndroidManifest.xml, `kotlin/`, `res/`).

Puis, dans `mangeoire_eleveur/` :
```bash
python patch_gradle.py        # ajoute plugin Compose, WorkManager, DataStore, Glance, scanner QR, minSdk 26
flutter pub get
flutter run --dart-define=API_BASE_URL=https://VOTRE-SERVEUR.onrender.com
```
> Après toute modification du Kotlin, du Manifest ou de Gradle : arrêter l'app et relancer `flutter run`.

### Si `patch_gradle.py` dit « format inattendu » : Gradle à la main
`android/settings.gradle.kts`, bloc `plugins { }` (même version que la ligne `org.jetbrains.kotlin.android`) :
```kotlin
id("org.jetbrains.kotlin.plugin.compose") version "2.3.20" apply false
```
`android/app/build.gradle.kts` : ajouter `id("org.jetbrains.kotlin.plugin.compose")` dans `plugins { }`,
mettre `minSdk = maxOf(flutter.minSdkVersion, 26)` et dans `dependencies { }` :
```kotlin
implementation("androidx.core:core-ktx:1.15.0")
implementation("androidx.work:work-runtime-ktx:2.10.0")
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
implementation("androidx.datastore:datastore-preferences:1.1.1")
implementation("androidx.glance:glance-appwidget:1.1.1")
implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
```
(versions des TP plus récentes possibles : `core-ktx 1.19.0`, `work 2.12.0`, `coroutines 1.11.0`.)

## Code natif (Kotlin) – un fichier par module
| Canal | Module | Méthodes | Fichier |
|---|---|---|---|
| `nfc/tag` | **M1** NFC | `disponible`, `lire(delai)` → uid, `annuler`, `parametres` | `NfcLecteur.kt` |
| `sync/planifier` | **M2** alerte en arrière-plan | `demanderPermission`, `permissionAccordee`, `planifier(base_url, token, seuil_pct, langue)`, `annuler`, `verifierMaintenant(silencieux)`, `actionInitiale` ; Kotlin → Dart : `surAction(cowId)` | `CanalSync.kt`, `Alertes.kt`, `VerificationWorker.kt` |
| (widget) | **M3** widget Glance | aucun appel Dart : le Worker met à jour le widget | `MangeoireWidget.kt` |
| `sync/planifier` | **Bonus** DataStore | `lireSeuil`, `definirSeuil`, `definirLangue`, `dernieresMesures` | `Stockage.kt` |
| `qr/scanner` | QR d'invitation | `scanner` → texte ou null | `QrScanner.kt` |
| `biometrie/auth` | Empreinte | `disponible`, `authentifier(titre, sous_titre, annuler)`, `annuler` | `BiometrieLecteur.kt` |

Aucun plugin Flutter pour M1, M2, M3 : tout passe par `lib/native/canaux.dart` (classe `CanauxNatifs`).

**Codes d'erreur** : `NFC_ABSENT`, `NFC_DESACTIVE`, `DELAI_DEPASSE`, `DEJA_EN_COURS`, `ARGUMENT_INVALIDE`,
`SCAN_ECHEC`, `BIO_INDISPONIBLE`, `BIO_ERREUR`, `SYNC_ERREUR`.

**Permissions** : `NFC`, `INTERNET`, `POST_NOTIFICATIONS` (demandée à l'exécution, Android 13+), `USE_BIOMETRIC`.

### Comment M2 fonctionne
1. À l'ouverture, Flutter envoie l'adresse du serveur + le jeton (`planifier`) ; WorkManager planifie un contrôle **toutes les heures** (réseau requis, `UPDATE`).
2. `VerificationWorker` appelle le serveur lui-même (`/home/appetite`, `/latest/{vache}`), enregistre les mesures dans DataStore, met à jour le widget, puis notifie si `appétit = baisse` et probabilité ≥ seuil (Profil → seuil, 50 % par défaut). Pas de réseau → `Result.retry()`.
3. La notification a deux boutons : **Voir la fiche** (ouvre l'app sur la vache, démarrage à froid via `actionInitiale`, app ouverte via `surAction`) et **Ignorer**.

### Tester vite
* **Alerte** : Profil → *Vérifier maintenant* (ignore la règle « une fois par jour »). Il faut qu'une vache ait `appetite_class = decreasing` dans `daily_summaries`.
* **Widget** : appui long sur l'écran d'accueil → Widgets → *Mangeoire* ; il se remplit après la première ouverture de l'app, devient rouge s'il y a une alerte.
* **NFC** : Vaches → bouton tag, approcher un tag déjà associé à une vache par l'admin.
* **Hors ligne** : mode avion → Accueil affiche les dernières mesures enregistrées.
* **Empreinte** : demandée à l'ouverture ; désactivable dans le Profil.

## Icônes
Mêmes PNG que l'app admin (`assets/icons/`, remplacez le fichier pour changer l'icône).
