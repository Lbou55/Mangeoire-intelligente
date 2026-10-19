#include <WiFi.h>
#include <WiFiUdp.h>
#include <SPI.h>
#include <MFRC522.h>
#include <coap-simple.h>
#include <time.h>

// ===================== RESEAU / COAP =====================
const char* WIFI_SSID = "LAPTOP-DN7PQP13 5891";          // Nom du WiFi (2,4 GHz)
const char* WIFI_PASS = "";  // Mot de passe

const char* NODE_ID = "N1";                    // Identifiant de ce noeud

// IP de la machine qui execute Node-RED (PAS 127.0.0.1 !)
//   - Test  : IP du PC          (commande "ipconfig" sous Windows)
//   - Final : IP du Raspberry   (commande "hostname -I" sur le Pi)
IPAddress NODE_RED_IP(192, 168, 137, 1);
const int COAP_PORT = 5683;

const bool SEND_COAP = true;                   // false = affichage serie seulement

// ===================== PARAMETRES SIMULATION =====================
const float POIDS_MAX_G = 25000.0;   // Poids mangeoire pleine (g)
const float POIDS_MIN_G = 2000.0;    // Seuil bas : le servo passe a ON (g)

const unsigned long WEIGHT_PERIOD_MS = 30000;  // Mise a jour du poids toutes les 30 s
const unsigned long RFID_DEBOUNCE_MS = 3000;   // Ignore la meme carte pendant 3 s
const unsigned long SERVO_ON_MS      = 5000;   // Duree pendant laquelle le servo reste ON (ms)

// ===================== PINS RFID =====================
#define SS_PIN  5
#define RST_PIN 22
MFRC522 rfid(SS_PIN, RST_PIN);

// ===================== COAP =====================
WiFiUDP udp;
Coap coap(udp);
bool coapDemarre = false;       // true quand WiFi connecte et CoAP lance
uint32_t nbEnvoyes = 0;         // messages CoAP envoyes
uint32_t nbAcks = 0;            // reponses recues de Node-RED

// ===================== VACHES (tags enregistres) =====================
// Vitesse de consommation propre a chaque vache (g par minute)
struct Vache {
  const char* tag;
  const char* nom;
  float vitesse_g_min;
  int   nbVisites;     // visites du "jour" (comme nb_visits du dataset)
  float totalG;        // total consomme (comme total_consumed_g)
};

Vache vaches[] = {
  {"3C43FA39", "VACHE_1", 250.0, 0, 0},
  {"CC8B7922", "VACHE_2", 320.0, 0, 0},
  {"92EBEA51", "VACHE_3", 400.0, 0, 0},
  {"822D4251", "VACHE_4", 480.0, 0, 0},
  {"EC954B17", "VACHE_5", 560.0, 0, 0},
  {"92B47151", "VACHE_6", 650.0, 0, 0},
  {"EDFF4D24", "VACHE_7", 350.0, 0, 0}
};
const int NB_VACHES = sizeof(vaches) / sizeof(vaches[0]);

// ===================== ETAT DU SYSTEME =====================
float poids = POIDS_MAX_G;      // Poids actuel (fixe tant que personne ne mange)
int   vacheActive = -1;         // -1 = personne, sinon index de la vache presente

// Donnees de la visite en cours
unsigned long debutVisite = 0;
float consommeVisite = 0;

// Servo SIMULE : simple variable (true = ON/ouvert, false = OFF/ferme)
bool servoOn = false;
unsigned long servoDebut = 0;

// ===================== HORODATAGE (NTP) =====================
void initialiserHeure() {
  configTime(0, 0, "pool.ntp.org", "time.google.com");   // heure UTC
  struct tm t;
  if (getLocalTime(&t, 8000)) {
    Serial.println("[NTP] Heure synchronisee");
  } else {
    Serial.println("[NTP] Echec : horodatage 1970 (pas d'Internet ?)");
  }
}

String horodatage() {
  struct tm t;
  if (!getLocalTime(&t, 10)) return "1970-01-01T00:00:00Z";
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &t);
  return String(buf);
}

// ===================== WIFI / COAP : connexion =====================
// Reponse de Node-RED (ACK) : affiche le code CoAP (2.04, 2.05... = OK)
void reponseCoap(CoapPacket &packet, IPAddress ip, int port) {
  nbAcks++;
  Serial.printf("[COAP] Reponse de %s : code %d.%02d\n",
                ip.toString().c_str(), packet.code >> 5, packet.code & 0x1F);
}

// Lance CoAP + NTP des que le WiFi est connecte (une seule fois)
void demarrerReseau() {
  if (coapDemarre || WiFi.status() != WL_CONNECTED) return;
  coap.response(reponseCoap);
  coap.start();
  coapDemarre = true;
  Serial.printf("[WIFI] Connecte, IP ESP32 = %s\n", WiFi.localIP().toString().c_str());
  Serial.printf("[COAP] Cible Node-RED = %s:%d\n", NODE_RED_IP.toString().c_str(), COAP_PORT);
  initialiserHeure();
}

void connecterWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("[WIFI] Connexion");
  unsigned long debut = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - debut < 20000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    demarrerReseau();
  } else {
    Serial.println("[WIFI] Echec : on continue en mode serie, nouvelle tentative en arriere-plan");
  }
}

// Reconnexion non bloquante si le WiFi tombe
void surveillerWiFi() {
  static unsigned long dernier = 0;
  if (WiFi.status() != WL_CONNECTED) {
    if (millis() - dernier > 10000) {
      dernier = millis();
      Serial.println("[WIFI] Non connecte, tentative de reconnexion...");
      WiFi.reconnect();
    }
  } else {
    demarrerReseau();   // au cas ou le WiFi arrive apres le demarrage
  }
}

// ===================== ENVOI COAP =====================
void envoyerCoap(const char* chemin, const char* payload) {
  Serial.printf("[TX] /%s %s\n", chemin, payload);
  if (!SEND_COAP) return;
  if (!coapDemarre) {
    Serial.println("[COAP] Reseau non pret : message NON envoye");
    return;
  }
#ifdef COAP_BUF_MAX_SIZE
  // Protection : la bibliotheque limite la taille totale du message
  if (strlen(payload) + 40 >= COAP_BUF_MAX_SIZE) {
    Serial.printf("[COAP] ERREUR : message trop long (%d) pour COAP_BUF_MAX_SIZE=%d -> augmenter dans coap-simple.h\n",
                  (int)strlen(payload), (int)COAP_BUF_MAX_SIZE);
    return;
  }
#endif
  // Message confirmable (CON) en POST vers coap://NODE_RED_IP:5683/<chemin>
  coap.send(NODE_RED_IP, COAP_PORT, (char*)chemin, COAP_CON, COAP_POST,
            NULL, 0, (uint8_t*)payload, strlen(payload));
  nbEnvoyes++;
}

// --- /rfid : donnee brute (tag lu) ---
void envoyerRFID(const String &tag) {
  char buf[200];
  snprintf(buf, sizeof(buf),
           "{\"node_id\":\"%s\",\"tag_id\":\"%s\",\"ts\":\"%s\"}",
           NODE_ID, tag.c_str(), horodatage().c_str());
  envoyerCoap("rfid", buf);
}

// --- /weight : poids toutes les 30 s ---
void envoyerPoids() {
  const char* nom = (vacheActive >= 0) ? vaches[vacheActive].nom : "aucune";
  char buf[240];
  snprintf(buf, sizeof(buf),
           "{\"node_id\":\"%s\",\"weight_g\":%.1f,\"vache_sim\":\"%s\",\"servo\":\"%s\",\"ts\":\"%s\"}",
           NODE_ID, poids, nom, servoOn ? "ON" : "OFF", horodatage().c_str());
  envoyerCoap("weight", buf);
}

// --- /visite : resume de fin de visite (valeurs de simulation) ---
void envoyerVisite(int idx, unsigned long dureeS, float consomme) {
  char buf[300];
  snprintf(buf, sizeof(buf),
           "{\"node_id\":\"%s\",\"tag_id\":\"%s\",\"vache_sim\":\"%s\",\"duree_s\":%lu,"
           "\"consomme_g\":%.0f,\"nb_visits\":%d,\"total_g\":%.0f,\"ts\":\"%s\"}",
           NODE_ID, vaches[idx].tag, vaches[idx].nom, dureeS, consomme,
           vaches[idx].nbVisites, vaches[idx].totalG, horodatage().c_str());
  envoyerCoap("visite", buf);
}

// --- /alert : AUTRE_VACHE ou TAG_INCONNU ---
void envoyerAlerte(const char* type, const String &tag) {
  const char* presente = (vacheActive >= 0) ? vaches[vacheActive].nom : "aucune";
  char buf[240];
  snprintf(buf, sizeof(buf),
           "{\"node_id\":\"%s\",\"type\":\"%s\",\"tag_id\":\"%s\",\"vache_presente\":\"%s\",\"ts\":\"%s\"}",
           NODE_ID, type, tag.c_str(), presente, horodatage().c_str());
  envoyerCoap("alert", buf);
}

// --- /servo : changement d'etat du servo simule ---
void envoyerServo() {
  char buf[200];
  snprintf(buf, sizeof(buf),
           "{\"node_id\":\"%s\",\"servo\":\"%s\",\"weight_g\":%.1f,\"ts\":\"%s\"}",
           NODE_ID, servoOn ? "ON" : "OFF", poids, horodatage().c_str());
  envoyerCoap("servo", buf);
}

// ===================== OUTILS RFID =====================
// Retourne l'index de la vache selon le tag, -1 si inconnu
int trouverVache(const String &tag) {
  for (int i = 0; i < NB_VACHES; i++) {
    if (tag == vaches[i].tag) return i;
  }
  return -1;
}

// Lit un tag RFID (retourne true si une nouvelle carte est lue)
bool lireRFID(String &tagId) {
  static String dernierTag = "";
  static unsigned long dernierTemps = 0;

  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return false;

  String id = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) id += "0";
    id += String(rfid.uid.uidByte[i], HEX);
  }
  id.toUpperCase();
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  // Anti-rebond : meme carte lue plusieurs fois de suite
  if (id == dernierTag && millis() - dernierTemps < RFID_DEBOUNCE_MS) return false;
  dernierTag = id;
  dernierTemps = millis();
  tagId = id;
  return true;
}

// ===================== SERVO SIMULE =====================
// Remplace la commande du vrai servomoteur : affiche seulement ON ou OFF
void commanderServo(bool etat) {
  servoOn = etat;
  if (etat) {
    servoDebut = millis();
    Serial.println("[SERVO] ON  (ouvert) : poids <= MIN, recharge de la mangeoire");
  } else {
    Serial.println("[SERVO] OFF (ferme)");
  }
  envoyerServo();
}

void gererServo() {
  // Apres SERVO_ON_MS : recharge, poids = MAX, servo OFF
  if (servoOn && millis() - servoDebut >= SERVO_ON_MS) {
    poids = POIDS_MAX_G;
    commanderServo(false);
    Serial.printf("[SERVO] Mangeoire rechargee, poids = %.1f g\n", poids);
  }
}

// ===================== GESTION DES TAGS =====================
void traiterTag(const String &tag) {
  int idx = trouverVache(tag);

  // Tag inconnu
  if (idx < 0) {
    Serial.printf("[ALERTE] Tag INCONNU : %s (non enregistre)\n", tag.c_str());
    envoyerAlerte("TAG_INCONNU", tag);
    return;
  }

  // Cas 1 : personne ne mange -> la vache entre, le poids commence a baisser
  if (vacheActive < 0) {
    vacheActive = idx;
    debutVisite = millis();
    consommeVisite = 0;
    Serial.printf("[RFID] %s (%s) detectee -> DEBUT visite, poids %.1f g, vitesse %.0f g/min\n",
                  vaches[idx].nom, tag.c_str(), poids, vaches[idx].vitesse_g_min);
    return;
  }

  // Cas 2 : meme tag relu -> la vache part, le poids redevient fixe
  if (idx == vacheActive) {
    unsigned long dureeS = (millis() - debutVisite) / 1000;
    vaches[idx].nbVisites++;
    vaches[idx].totalG += consommeVisite;

    Serial.printf("[RFID] %s detectee a nouveau -> FIN visite, poids fixe a %.1f g\n",
                  vaches[idx].nom, poids);
    Serial.printf("[VISITE] %s | duree %.1f min | consomme %.0f g | nb_visits=%d | total_consumed_g=%.0f\n",
                  vaches[idx].nom, dureeS / 60.0, consommeVisite,
                  vaches[idx].nbVisites, vaches[idx].totalG);
    envoyerVisite(idx, dureeS, consommeVisite);
    vacheActive = -1;
    return;
  }

  // Cas 3 : autre tag pendant qu'une vache mange -> ALERTE (1 seule vache par place)
  Serial.printf("[ALERTE] %s (%s) detectee alors que %s est a la mangeoire ! (1 seule vache par place)\n",
                vaches[idx].nom, tag.c_str(), vaches[vacheActive].nom);
  envoyerAlerte("AUTRE_VACHE", tag);
}

// ===================== MISE A JOUR DU POIDS =====================
void mettreAJourPoids() {
  // Si personne ne mange : poids fixe, aucune variation
  if (vacheActive >= 0 && !servoOn) {
    float dureeMin = WEIGHT_PERIOD_MS / 60000.0;
    // Vitesse propre a la vache, avec une petite variation aleatoire (+/- 10 %)
    float facteur = 1.0 + random(-10, 11) / 100.0;
    float baisse = vaches[vacheActive].vitesse_g_min * dureeMin * facteur;

    poids -= baisse;
    consommeVisite += baisse;

    if (poids <= POIDS_MIN_G) {
      poids = POIDS_MIN_G;      // le poids ne descend pas sous MIN
      commanderServo(true);     // servo ON
    }
  }

  // Affichage periodique
  String etat = (vacheActive >= 0) ? String(vaches[vacheActive].nom) : String("aucune");
  Serial.printf("[POIDS] %.1f g | vache presente : %s | servo : %s\n",
                poids, etat.c_str(), servoOn ? "ON" : "OFF");
  envoyerPoids();

  // Compteurs CoAP : si "acks" reste a 0 -> probleme reseau / Node-RED
  Serial.printf("[COAP] envoyes=%lu | reponses=%lu\n",
                (unsigned long)nbEnvoyes, (unsigned long)nbAcks);
}

// ===================== SETUP / LOOP =====================
void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();
  randomSeed(esp_random());

  Serial.println("=== Simulation mangeoire intelligente (CoAP -> Node-RED) ===");
  Serial.printf("Poids MAX = %.0f g | MIN = %.0f g | periode poids = %lu s\n",
                POIDS_MAX_G, POIDS_MIN_G, WEIGHT_PERIOD_MS / 1000);
  Serial.printf("%d vaches enregistrees. Approchez un tag RFID.\n", NB_VACHES);

  if (SEND_COAP) {
    connecterWiFi();
  } else {
    Serial.println("[COAP] SEND_COAP = false : affichage serie seulement");
  }

  commanderServo(false);
  Serial.printf("[POIDS] %.1f g | vache presente : aucune | servo : OFF\n", poids);
  envoyerPoids();
}

void loop() {
  if (SEND_COAP) {
    surveillerWiFi();
    if (coapDemarre) coap.loop();     // traite les reponses de Node-RED
  }

  // 1) Lecture RFID
  String tag;
  if (lireRFID(tag)) {
    envoyerRFID(tag);   // donnee brute envoyee a chaque lecture
    traiterTag(tag);    // logique de simulation
  }

  // 2) Mise a jour du poids toutes les 30 s
  static unsigned long dernierPoids = 0;
  if (millis() - dernierPoids >= WEIGHT_PERIOD_MS) {
    dernierPoids = millis();
    mettreAJourPoids();
  }

  // 3) Gestion du servo simule (retour a OFF + recharge)
  gererServo();
}
