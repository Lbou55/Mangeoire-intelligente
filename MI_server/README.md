# Mangeoire Intelligente – Serveur (FastAPI + MongoDB Atlas)

Base `farm` (collections : `superadmin`, `admins`, `eleveurs`, `invites`, `cow_profiles`,
`alerts`, `feeders`, `subscription_requests`, `feed_dispatch`, `daily_summaries`, `realtime_readings`).

## Rôles
| Rôle | Ce qu'il peut faire |
|---|---|
| superadmin | crée des admins (e-mail + mot de passe envoyés par mail), voit la liste (en attente / acceptés), approuve les renouvellements |
| admin | possède la ferme : invite des éleveurs (QR/code 24 h), gère les vaches (seul à pouvoir les modifier), envoie des alertes. Abonnement 30 jours |
| eleveur | s'inscrit par QR/code + nom, empreinte sur le téléphone, lit les vaches et les alertes (lecture seule) |

## Déploiement (gratuit, toujours réveillé)
1. Pousser ce dossier `server/` sur GitHub (sans `.env`).
2. Render → New → Blueprint → choisir le dépôt (il lit `render.yaml`).
3. Renseigner les variables : `MONGO_URI`, `PUBLIC_URL` (l'URL Render), SMTP\_*.
4. **UptimeRobot** (gratuit) : monitor HTTP(s) sur `https://<url>/health`, toutes les 5 min.
   Cela évite l'endormissement de Render (≈ 744 h/mois, sous la limite gratuite de 750 h).
5. Une fois : `python -m scripts.seed_superadmin` (en local, avec `.env`), puis
   `python -m scripts.seed_cows <email_admin>` pour rattacher les 7 vaches.

## Lancer en local
```
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env      (puis remplir)
uvicorn app.main:app --reload
```
Docs interactives : `http://localhost:8000/docs`.

## Mangeoires
- `GET /feeders` — liste des mangeoires de la ferme (admin / éleveur)
- `GET /feeders/{id}` — détail d'une mangeoire
- `POST /feeders` — créer une mangeoire (admin)
- `PUT /feeders/{id}` — modifier une mangeoire (admin)
- `DELETE /feeders/{id}` — supprimer une mangeoire (admin)
- `POST /feeders/{id}/refill` — remplir ou ajouter une quantité (admin)
- `POST /ingest/feeder` — mise à jour matérielle avec `X-Ingest-Key`

Initialiser l'exemple :
`python -m scripts.seed_feeders <email_admin>`

## Mesures du Raspberry Pi
- `POST /ingest` avec l'en-tête `X-Ingest-Key: <INGEST_KEY>` et le JSON `{"esp32": {...}, "model": {...}}`
  (ce que publie `MI_module_AI_Forest/service.py`). C'est la voie la plus simple sur l'hébergement gratuit.
- ou file RabbitMQ si `AMQP_URL` est renseignée.

## Erreurs
Toutes les erreurs : `{"error": "<code>", "detail": "<message>"}` – codes utilisés par les apps :
`invalid_credentials`, `password_change_required` (403), `account_pending` (403),
`subscription_expired` (402), `invalid_invite`, `cow_exists`, `tag_unknown`, `token_expired`…

## Prédiction (optionnelle)
`GET /predict/{cow_id}` nécessite `pip install -r requirements-ai.txt` (LightGBM). Sans cela : 501.
