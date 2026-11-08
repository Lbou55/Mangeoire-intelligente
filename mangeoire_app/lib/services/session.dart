import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/vache.dart';
import 'api.dart';

/// Qui est connecté, le jeton, et les notifications en direct.
/// Il n'y en a qu'un seul dans toute l'application : Session.instance.
class Session {
  Session._();
  static final Session instance = Session._();

  static const _stockage = FlutterSecureStorage();

  final ApiClient api = ApiClient();
  Map<String, dynamic>? utilisateur;

  /// Pour afficher un message ou ouvrir une page de n'importe où (notification reçue).
  final GlobalKey<ScaffoldMessengerState> messagerie = GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> navigateur = GlobalKey<NavigatorState>();

  /// Rempli par main.dart (évite que ce fichier connaisse les pages).
  void Function(String signalementId)? ouvrirSignalement;
  VoidCallback? versConnexion;

  /// Le nombre sur la pastille de la cloche.
  final ValueNotifier<int> nonLus = ValueNotifier<int>(0);
  final StreamController<Notif> _flux = StreamController<Notif>.broadcast();
  Stream<Notif> get notifications => _flux.stream;

  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _ecoute;
  Timer? _reconnexion;
  bool _actif = false;

  bool get connecte => utilisateur != null;
  bool get estProprietaire => utilisateur?['role'] == 'owner';
  String get nom => (utilisateur?['name'] as String?) ?? '';
  String get email => (utilisateur?['email'] as String?) ?? '';
  String get roleFr => estProprietaire ? 'Propriétaire' : 'Agriculteur';

  /// Au démarrage : y a-t-il un jeton enregistré, et est-il encore valable ?
  Future<bool> restaurer() async {
    api.onNonAutorise = _sessionExpiree;
    try {
      final jeton = await _stockage.read(key: 'jeton');
      if (jeton == null) return false;
      api.token = jeton;
      utilisateur = Map<String, dynamic>.from(await api.get('/auth/me') as Map);
      return true;
    } catch (_) {
      api.token = null;
      utilisateur = null;
      return false;
    }
  }

  Future<void> connexion(String email, String motDePasse) async {
    final r = await api.post('/auth/login', {'email': email.trim(), 'password': motDePasse});
    await _enregistrer(r as Map);
  }

  Future<void> inscription(String nom, String email, String motDePasse) async {
    final r = await api.post('/auth/register', {
      'name': nom.trim(),
      'email': email.trim(),
      'password': motDePasse,
    });
    await _enregistrer(r as Map);
  }

  Future<void> _enregistrer(Map r) async {
    api.token = r['access_token'] as String;
    utilisateur = Map<String, dynamic>.from(r['user'] as Map);
    await _stockage.write(key: 'jeton', value: api.token);
  }

  Future<void> deconnexion() async {
    _arreterNotifications();
    api.token = null;
    utilisateur = null;
    nonLus.value = 0;
    try {
      await _stockage.delete(key: 'jeton');
    } catch (_) {}
  }

  void _sessionExpiree() {
    if (!connecte) return;
    deconnexion();
    messagerie.currentState?.showSnackBar(
      const SnackBar(content: Text('Session expirée, reconnectez-vous.')),
    );
    versConnexion?.call();
  }

  // ---------------- notifications en direct ----------------

  Future<void> demarrerNotifications() async {
    if (_actif) return;
    _actif = true;
    await rafraichirNonLus();
    _connecter();
  }

  void _arreterNotifications() {
    _actif = false;
    _reconnexion?.cancel();
    _ecoute?.cancel();
    _canal?.sink.close();
    _canal = null;
  }

  Future<void> rafraichirNonLus() async {
    try {
      final r = await api.get('/notifications/unread-count') as Map;
      nonLus.value = (r['count'] as num).toInt();
    } catch (_) {}
  }

  void _connecter() {
    if (!_actif || api.token == null) return;
    try {
      final canal = WebSocketChannel.connect(
        Uri.parse('$wsBase/api/ws/notifications?token=${api.token}'),
      );
      _canal = canal;
      _ecoute = canal.stream.listen(
        _recu,
        onDone: _replanifier,
        onError: (_) => _replanifier(),
        cancelOnError: true,
      );
    } catch (_) {
      _replanifier();
    }
  }

  void _replanifier() {
    if (!_actif) return;
    _reconnexion?.cancel();
    _reconnexion = Timer(const Duration(seconds: 4), () {
      rafraichirNonLus();
      _connecter();
    });
  }

  void _recu(dynamic message) {
    try {
      final m = jsonDecode(message as String) as Map<String, dynamic>;
      if (m['type'] != 'notification') return;
      final n = Notif(Map<String, dynamic>.from(m['notification'] as Map));
      nonLus.value = nonLus.value + 1;
      _flux.add(n);
      _bandeau(n);
    } catch (_) {}
  }

  /// Bandeau en haut/bas de l'écran quand une notification arrive (application ouverte).
  void _bandeau(Notif n) {
    final messager = messagerie.currentState;
    if (messager == null) return;
    messager.hideCurrentSnackBar();
    messager.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('${n.titre}\n${n.corps}', maxLines: 3, overflow: TextOverflow.ellipsis),
        action: n.signalementId == null
            ? null
            : SnackBarAction(label: 'Voir', onPressed: () => ouvrirSignalement?.call(n.signalementId!)),
      ),
    );
  }
}
