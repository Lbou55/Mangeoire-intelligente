import '../models/models.dart';
import 'api_client.dart';
import 'session.dart';

List<Map<String, dynamic>> _list(dynamic data) => [
      if (data is List)
        for (final e in data)
          if (e is Map) Map<String, dynamic>.from(e)
    ];

String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The invitation QR contains "MANGEOIRE:CODE"; a typed code is accepted too.
String extractInviteCode(String raw) {
  var c = raw.trim();
  if (c.toUpperCase().startsWith('MANGEOIRE:')) c = c.substring(10);
  return c.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
}

class AuthApi {
  AuthApi._();
  static final AuthApi instance = AuthApi._();
  final ApiClient _api = ApiClient.instance;

  /// Joins the farm of the admin who made the invitation. The eleveur has no
  /// password: the phone keeps a long-lived token, protected by the fingerprint.
  Future<AppUser> register(String inviteCode, String name) async {
    final r = await _api.postPublic('/auth/eleveur/register',
        body: {'invite_code': extractInviteCode(inviteCode), 'name': name.trim()});
    final user = AppUser.fromJson(Map<String, dynamic>.from(r['user'] as Map));
    await Session.instance.saveToken(r['token'] as String);
    Session.instance.currentUser.value = user;
    return user;
  }

  Future<AppUser> me() async {
    final r = await _api.get('/auth/me');
    final user = AppUser.fromJson(Map<String, dynamic>.from(r['user'] as Map));
    Session.instance.currentUser.value = user;
    return user;
  }

  Future<void> logout() => Session.instance.clear();
}

/// Read-only: only the admin can modify cows.
class FarmApi {
  FarmApi._();
  static final FarmApi instance = FarmApi._();
  final ApiClient _api = ApiClient.instance;

  Future<List<Feeder>> feeders() async =>
      _list(await _api.get('/feeders')).map(Feeder.fromJson).toList();
  Future<Feeder> feeder(String id) async =>
      Feeder.fromJson(Map<String, dynamic>.from(await _api.get('/feeders/$id') as Map));

  Future<List<Cow>> cows() async =>
      _list(await _api.get('/profiles')).map(Cow.fromJson).toList();

  Future<Cow> cow(String cowId) async =>
      Cow.fromJson(Map<String, dynamic>.from(await _api.get('/profiles/$cowId') as Map));

  /// 404 (tag_unknown) when no cow of the farm carries this tag.
  Future<Cow> cowByNfc(String uid) async =>
      Cow.fromJson(Map<String, dynamic>.from(await _api.get('/profiles/by-nfc/$uid') as Map));

  Future<Map<String, Appetite?>> appetiteByCow() async {
    final r = await _api.get('/home/appetite');
    final out = <String, Appetite?>{};
    if (r is Map && r['appetite'] is Map) {
      for (final e in (r['appetite'] as Map).entries) {
        final v = e.value;
        out['${e.key}'] = v is Map ? parseAppetite(v['appetite']) : null;
      }
    }
    return out;
  }

  Future<List<DailySummary>> daily(String cowId, {int limit = 14}) async =>
      _list(await _api.get('/daily/$cowId', query: {'limit': limit}))
          .map(DailySummary.fromJson)
          .toList();

  Future<List<Dispatch>> dispatch(String cowId, {int limit = 14}) async =>
      _list(await _api.get('/dispatch/$cowId', query: {'limit': limit}))
          .map(Dispatch.fromJson)
          .toList();

  /// null when the server has no prediction model (501).
  Future<double?> predictedIntakeKg(String cowId) async {
    try {
      final r = await _api.get('/predict/$cowId');
      if (r is Map && r['predicted_intake_kg_dm'] is num) {
        return (r['predicted_intake_kg_dm'] as num).toDouble();
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 501 || e.statusCode == 502 || e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<AlertItem>> alerts({String? status, int limit = 100}) async =>
      _list(await _api.get('/alerts', query: {'status': status, 'limit': limit}))
          .map(AlertItem.fromJson)
          .toList();

  Future<int> unreadCount() async {
    final r = await _api.get('/alerts/unread-count');
    return r is Map && r['count'] is num ? (r['count'] as num).toInt() : 0;
  }

  Future<void> markAlertRead(String id) => _api.patch('/alerts/$id/read');
}
