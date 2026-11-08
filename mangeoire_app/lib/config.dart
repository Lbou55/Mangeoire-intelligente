/// Adresse du serveur FastAPI.
///
/// On la change au lancement, sans toucher au code :
///   flutter run --dart-define=API_BASE=http://192.168.1.20:8000   (téléphone réel : IP de votre PC)
///   flutter run -d edge --dart-define=API_BASE=http://localhost:8000
/// Par défaut : 10.0.2.2 = "le PC" vu depuis l'émulateur Android.
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000',
);

/// http -> ws et https -> wss (pour les notifications en direct).
String get wsBase => apiBase.replaceFirst('http', 'ws');
