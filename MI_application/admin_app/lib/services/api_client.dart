import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'session.dart';

/// Error from the server or the network. [code] is a stable key the UI
/// translates (French / Arabic), e.g. `invalid_credentials`.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, [this.detail]);
  final int? statusCode; // null = network problem
  final String code;
  final String? detail;

  @override
  String toString() => 'ApiException($statusCode, $code, $detail)';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  /// True while a request has been waiting for more than a few seconds:
  /// the free Render instance is probably waking up.
  final ValueNotifier<bool> serverIsWakingUp = ValueNotifier<bool>(false);
  int _pending = 0;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);
  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    final token = authenticated ? await Session.instance.readToken() : null;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = AppConfig.uri(path, query);

    _pending++;
    final hint = Timer(AppConfig.wakingHintAfter, () {
      if (_pending > 0) serverIsWakingUp.value = true;
    });
    try {
      http.Response? response;
      Object? lastError;
      for (var attempt = 0; attempt < 2 && response == null; attempt++) {
        try {
          final request = http.Request(method, uri)..headers.addAll(headers);
          if (body != null) request.body = jsonEncode(body);
          final streamed = await _http.send(request).timeout(AppConfig.requestTimeout);
          response = await http.Response.fromStream(streamed);
        } on TimeoutException catch (e) {
          lastError = e;
        } on SocketException catch (e) {
          lastError = e;
          await Future<void>.delayed(const Duration(seconds: 2));
        } on http.ClientException catch (e) {
          lastError = e;
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (response == null) {
        throw ApiException(null, lastError is TimeoutException ? 'timeout' : 'network');
      }
      return _handle(response);
    } finally {
      hint.cancel();
      _pending--;
      if (_pending == 0) serverIsWakingUp.value = false;
    }
  }

  dynamic _handle(http.Response r) {
    dynamic data;
    if (r.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        data = null;
      }
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return data;

    var code = 'server_error';
    String? detail;
    if (data is Map) {
      code = '${data['error'] ?? code}';
      detail = data['detail'] is String ? data['detail'] as String : null;
    }
    final error = ApiException(r.statusCode, code, detail);

    final session = Session.instance;
    if (r.statusCode == 401 && code != 'invalid_credentials') {
      session.emit(AuthEvent.loggedOut);
    } else if (r.statusCode == 402) {
      session.emit(AuthEvent.subscriptionExpired);
    } else if (r.statusCode == 403 && code == 'password_change_required') {
      session.emit(AuthEvent.passwordChangeRequired);
    }
    throw error;
  }

  /// Login does not carry a token and must not trigger the 401 logout flow.
  Future<dynamic> postPublic(String path, {Object? body}) =>
      _send('POST', path, body: body, authenticated: false);
}
