import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// Things the whole app must react to, whichever screen triggered them.
enum AuthEvent { loggedOut, subscriptionExpired, passwordChangeRequired }

class Session {
  Session._();
  static final Session instance = Session._();

  static const _tokenKey = 'admin_auth_token';
  static const _storage = FlutterSecureStorage();

  final ValueNotifier<AppUser?> currentUser = ValueNotifier<AppUser?>(null);
  final StreamController<AuthEvent> _events = StreamController<AuthEvent>.broadcast();
  Stream<AuthEvent> get events => _events.stream;

  void emit(AuthEvent e) => _events.add(e);

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clear() async {
    currentUser.value = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }
}
