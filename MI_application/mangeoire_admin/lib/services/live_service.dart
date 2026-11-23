import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/config.dart';
import 'session.dart';

class LiveService {
  LiveService._();
  static final LiveService instance = LiveService._();

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  bool _running = false;
  Timer? _ping;

  void start() {
    if (_running) return;
    _running = true;
    _loop();
  }

  Future<void> _loop() async {
    while (_running) {
      final token = await Session.instance.readToken();
      if (token == null) break;
      try {
        final ws = await WebSocket.connect(
          AppConfig.wsUri('/ws/cows', {'token': token}).toString(),
        ).timeout(const Duration(seconds: 25));
        _ping?.cancel();
        _ping = Timer.periodic(const Duration(seconds: 30), (_) {
          try {
            ws.add('ping');
          } catch (_) {}
        });
        await for (final message in ws) {
          if (message is! String || message == 'pong') continue;
          try {
            final data = jsonDecode(message);
            if (data is Map) _events.add(Map<String, dynamic>.from(data));
          } catch (_) {}
        }
      } catch (_) {}
      _ping?.cancel();
      if (_running) await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
}
