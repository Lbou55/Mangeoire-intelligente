#include "esp_camera.h"
#include "img_converters.h"
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include "FS.h"
#include "SD_MMC.h"

// ====== A MODIFIER ======
const char* ssid        = "......";
const char* password    = "......";
const char* NODERED_URL = "http://192.168.1.196:1880/upload";  // IP du PC / Raspberry ou tourne Node-RED
// ========================

// Brochage AI Thinker ESP32-CAM
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

WebServer server(80);
Preferences prefs;
bool sdOK = false;

// ---------- Page web ----------
const char PAGE[] PROGMEM = R"rawliteral(
<html><head><meta name='viewport' content='width=device-width, initial-scale=1'></head>
<body style='background:#111;color:#fff;text-align:center;font-family:sans-serif'>
<h2>ESP32-CAM</h2>
<img id='cam' style='max-width:95%'><br>
<p id='st'></p>
<button style='padding:10px 20px;font-size:16px' onclick="live()">Live</button>
<button style='padding:10px 20px;font-size:16px' onclick="photo()">Photo</button>
<script>
const cam = document.getElementById('cam');
const st  = document.getElementById('st');
function live() { st.innerText = 'Live'; cam.src = '/stream'; }
async function photo() {
  cam.removeAttribute('src');
  st.innerText = '...';
  const r = await fetch('/capture?t=' + Date.now());
  st.innerText = r.headers.get('X-Status') || '';
  cam.src = URL.createObjectURL(await r.blob());
}
</script>
</body></html>
)rawliteral";

// ---------- Camera ----------
bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk  = XCLK_GPIO_NUM;
  config.pin_pclk  = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href  = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn  = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_RGB565;   // GC2145 : pas de JPEG natif
  config.frame_size   = FRAMESIZE_QVGA;     // 320x240
  config.jpeg_quality = 12;
  config.fb_count     = 1;
  config.fb_location  = CAMERA_FB_IN_PSRAM;
  config.grab_mode    = CAMERA_GRAB_WHEN_EMPTY;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera : ECHEC (0x%x)\n", err);
    return false;
  }
  return true;
}

// ---------- Carte SD ----------
bool initSD() {
  // Mode 1-bit : libere GPIO4 (flash LED)
  if (!SD_MMC.begin("/sdcard", true)) {
    Serial.println("SD : ECHEC (carte absente ou non FAT32)");
    return false;
  }
  if (SD_MMC.cardType() == CARD_NONE) {
    Serial.println("SD : aucune carte");
    return false;
  }
  pinMode(4, OUTPUT);       // eteint la LED flash
  digitalWrite(4, LOW);
  SD_MMC.mkdir("/offline");
  Serial.printf("SD : OK (%llu Mo)\n", SD_MMC.cardSize() / (1024 * 1024));
  return true;
}

// ---------- Wi-Fi ----------
const char* statutWiFi(wl_status_t s) {
  switch (s) {
    case WL_NO_SSID_AVAIL:   return "Reseau introuvable (SSID faux ou bande 5 GHz)";
    case WL_CONNECT_FAILED:  return "Connexion refusee (mot de passe ou securite)";
    case WL_CONNECTION_LOST: return "Connexion perdue";
    case WL_DISCONNECTED:    return "Deconnecte (mot de passe probablement faux)";
    case WL_IDLE_STATUS:     return "En attente";
    default:                 return "Autre";
  }
}

bool connecterWiFi(int tentatives) {
  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true);
  delay(500);

  Serial.println("Scan des reseaux Wi-Fi...");
  int n = WiFi.scanNetworks();
  Serial.printf("Reseaux trouves : %d\n", n);
  for (int i = 0; i < n; i++) {
    Serial.printf("  - [%s] (%d dBm)\n", WiFi.SSID(i).c_str(), WiFi.RSSI(i));
  }

  for (int essai = 1; essai <= tentatives; essai++) {
    Serial.printf("\nTentative %d/%d sur [%s]", essai, tentatives, ssid);
    WiFi.begin(ssid, password);

    unsigned long debut = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - debut < 10000) {
      delay(500);
      Serial.print(".");
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nWi-Fi OK");
      WiFi.setSleep(false);
      return true;
    }
    Serial.printf("\nEchec : %s (code %d)\n", statutWiFi(WiFi.status()), WiFi.status());
    WiFi.disconnect(true);
    delay(500);
  }
  return false;
}

// ---------- Photo : capture, envoi Node-RED ou SD ----------
bool captureJpeg(uint8_t **jpg, size_t *len) {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) return false;
  bool ok = frame2jpg(fb, 80, jpg, len);
  esp_camera_fb_return(fb);
  return ok;
}

String nouveauNom() {
  prefs.begin("cam", false);
  uint32_t n = prefs.getUInt("n", 0) + 1;
  prefs.putUInt("n", n);
  prefs.end();
  char buf[24];
  snprintf(buf, sizeof(buf), "photo_%05u.jpg", (unsigned)n);
  return String(buf);
}

bool envoyerNodeRED(uint8_t *data, size_t len, const String &nom) {
  if (WiFi.status() != WL_CONNECTED) return false;
  HTTPClient http;
  http.setTimeout(5000);
  if (!http.begin(NODERED_URL)) return false;
  http.addHeader("Content-Type", "image/jpeg");
  http.addHeader("X-Filename", nom);
  int code = http.POST(data, len);
  http.end();
  Serial.printf("Node-RED : HTTP %d\n", code);
  return code == 200;
}

bool sauverSD(uint8_t *data, size_t len, const String &nom) {
  if (!sdOK) return false;
  File f = SD_MMC.open("/offline/" + nom, FILE_WRITE);
  if (!f) return false;
  size_t w = f.write(data, len);
  f.close();
  return w == len;
}

const char* traiterPhoto(uint8_t *jpg, size_t len) {
  String nom = nouveauNom();
  if (envoyerNodeRED(jpg, len, nom)) return "Envoye a Node-RED";
  if (sauverSD(jpg, len, nom))       return "Sauve sur SD (hors ligne)";
  return "ECHEC (ni Node-RED ni SD)";
}

// Renvoie vers Node-RED les photos gardees sur la SD (10 max par passage)
void synchroniserSD() {
  if (!sdOK || WiFi.status() != WL_CONNECTED) return;
  File dir = SD_MMC.open("/offline");
  if (!dir) return;

  String noms[10];
  int n = 0;
  File f = dir.openNextFile();
  while (f && n < 10) {
    if (!f.isDirectory()) {
      String nm = f.name();
      nm = nm.substring(nm.lastIndexOf('/') + 1);   // compatible anciennes/nouvelles versions du core
      noms[n++] = nm;
    }
    f = dir.openNextFile();
  }
  dir.close();

  for (int i = 0; i < n; i++) {
    String chemin = "/offline/" + noms[i];
    File fi = SD_MMC.open(chemin, FILE_READ);
    if (!fi) continue;
    size_t len = fi.size();
    uint8_t *buf = (uint8_t*)ps_malloc(len);
    if (!buf) { fi.close(); continue; }
    fi.read(buf, len);
    fi.close();

    bool ok = envoyerNodeRED(buf, len, noms[i]);
    free(buf);
    if (ok) {
      SD_MMC.remove(chemin);
      Serial.printf("Sync : %s envoye et supprime de la SD\n", noms[i].c_str());
    } else {
      break;   // Node-RED injoignable, on reessaiera plus tard
    }
  }
}

// ---------- Commande Serial : tape 'p' pour prendre une photo ----------
void serieLoop() {
  static unsigned long dernier = 0;

  bool demande = false;
  while (Serial.available()) {
    if (Serial.read() == 'p') demande = true;
  }

  if (demande && millis() - dernier > 1500) {
    dernier = millis();
    uint8_t *jpg = NULL;
    size_t len = 0;
    if (captureJpeg(&jpg, &len)) {
      Serial.printf("Photo (serial) : %s\n", traiterPhoto(jpg, len));
      free(jpg);
    } else {
      Serial.println("Photo (serial) : capture echec");
    }
  }
}

// ---------- Handlers web ----------
void handleRoot() {
  server.send_P(200, "text/html", PAGE);
}

void handleCapture() {
  uint8_t *jpg = NULL;
  size_t jpgLen = 0;
  if (!captureJpeg(&jpg, &jpgLen)) {
    server.send(500, "text/plain", "Capture echec");
    return;
  }

  const char* statut = traiterPhoto(jpg, jpgLen);
  Serial.printf("Photo : %s\n", statut);

  server.sendHeader("Cache-Control", "no-cache");
  server.sendHeader("X-Status", statut);
  server.send_P(200, "image/jpeg", (const char*)jpg, jpgLen);
  free(jpg);
}

void handleStream() {
  WiFiClient client = server.client();
  client.print("HTTP/1.1 200 OK\r\n"
               "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n");

  while (client.connected()) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) break;

    uint8_t *jpg = NULL;
    size_t jpgLen = 0;
    bool ok = frame2jpg(fb, 70, &jpg, &jpgLen);
    esp_camera_fb_return(fb);
    if (!ok) break;

    client.printf("--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n", (unsigned)jpgLen);
    size_t w = client.write(jpg, jpgLen);
    client.print("\r\n");
    free(jpg);

    if (w == 0) break;   // le client a ferme la connexion
    serieLoop();         // 'p' marche aussi pendant le live
    delay(1);
  }
  client.stop();
}

// ---------- Setup / Loop ----------
void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("\n===== ESP32-CAM : STREAM + NODE-RED + SD =====");
  Serial.println("Tape 'p' dans le Serial Monitor pour prendre une photo.");

  if (!initCamera()) return;
  Serial.println("Camera : OK");

  sdOK = initSD();

  if (connecterWiFi(2)) {
    Serial.print("Ouvre dans le navigateur : http://");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nPas de Wi-Fi : mode hors ligne (photos sur SD via 'p').");
  }

  server.on("/", handleRoot);
  server.on("/capture", handleCapture);
  server.on("/stream", handleStream);
  server.begin();
}

void loop() {
  server.handleClient();
  serieLoop();

  static unsigned long dernierCheck = 0;
  static bool etaitConnecte = false;

  if (millis() - dernierCheck > 30000) {
    dernierCheck = millis();
    bool connecte = (WiFi.status() == WL_CONNECTED);

    if (!connecte) {
      Serial.println("Wi-Fi absent, nouvelle tentative...");
      WiFi.disconnect(true);
      WiFi.begin(ssid, password);
    } else {
      if (!etaitConnecte) {
        Serial.print("Wi-Fi revenu : http://");
        Serial.println(WiFi.localIP());
      }
      synchroniserSD();   // envoie les photos gardees pendant la coupure
    }
    etaitConnecte = connecte;
  }
}
