# Mangeoire Admin (Super Admin + Admin)

One app, two roles. The server decides which one you are at login (log out to switch).

| Rôle | Écrans |
|---|---|
| Super admin | Admins (liste acceptés / en attente, ajout par e-mail), Renouvellements (approuver / refuser), Profil |
| Admin | Accueil, Vaches (ajout avec scan NFC, modification, suppression), Éleveurs + invitations QR, Alertes (messages personnalisés), Profil (abonnement, langue, mot de passe) |

Abonnement terminé → tous les onglets sauf **Profil** affichent un pop-up « Abonnement expiré » qui renvoie vers le profil.
Langue FR / العربية modifiable à tout moment (bouton globe, ou Profil).

## Installer (PC Windows)
```bash
flutter create --org tn.isetbizerte --project-name mangeoire_admin --platforms android mangeoire_admin
```
Puis **copier par-dessus** (remplacer) le contenu de ce dossier dans `mangeoire_admin/` :
`lib/`, `assets/`, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`
et `android/app/src/main/kotlin/tn/isetbizerte/mangeoire_admin/` (MainActivity.kt + NfcLecteur.kt).

```bash
cd mangeoire_admin
flutter pub get
flutter run --dart-define=API_BASE_URL=https://VOTRE-SERVEUR.onrender.com
```
(ou modifier la valeur par défaut dans `lib/core/config.dart`).

> Après toute modification du Kotlin ou du Manifest : arrêter l'app et relancer `flutter run` (le hot reload ne suffit pas).

## Icônes
Les icônes sont des PNG dans `assets/icons/` (même nom = même icône, remplacez le fichier pour changer).
Nouvelles icônes *provisoires* dessinées pour cette version — à remplacer par les vôtres, même nom, fond transparent, trait noir, 256×256 :
`add`, `delete`, `edit`, `qr_code`, `language`, `calendar`, `nav_users`, `send`, `copy`, `phone`, `refresh`, `check`.

## Code natif (Kotlin)
| Canal | Type | Méthodes | Fichier |
|---|---|---|---|
| `nfc/tag` | Method | `disponible`, `lire(delai)`, `annuler`, `parametres` | `NfcLecteur.kt` |
