import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../core/config.dart';
import 'session.dart';

/// Real-time alerts while the app is open (WebSocket /ws/cows).
/// Reconnects by itself (the free server may be asleep for a few seconds).
/// When the app is closed, the WorkManager check (Kotlin) takes over.
class LiveService {
  LiveService._();
  static final LiveService instance = LiveService._();

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  bool _running = false;
  int _failures = 0;
  WebSocket? _socket;
  Timer? _ping;

  void start() {
    if (_running) return;
    _running = true;
    _loop();
  }

  void stop() {
    _running = false;
    _ping?.cancel();
    _socket?.close();
    _socket = null;
  }

  Future<void> _loop() async {
    while (_running) {
      final token = await Session.instance.readToken();
      if (token == null) break;
      try {
        final ws = await WebSocket.connect(
          AppConfig.wsUri('/ws/cows', {'token': token}).toString(),
        ).timeout(const Duration(seconds: 25));
        _socket = ws;
        _failures = 0;
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
      } catch (_) {
        // network down or server waking: retry below
      }
      _ping?.cancel();
      _socket = null;
      if (!_running) break;
      _failures = min(_failures + 1, 6);
      await Future<void>.delayed(Duration(seconds: 2 << _failures)); // 4 s ... 128 s
    }
    _running = false;
  }
}
