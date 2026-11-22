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

// -------------------------------------------------------------------- auth

class AuthApi {
  AuthApi._();
  static final AuthApi instance = AuthApi._();
  final ApiClient _api = ApiClient.instance;

  Future<AppUser> login(String email, String password) async {
    final r = await _api.postPublic('/auth/login', body: {'email': email.trim(), 'password': password});
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

  Future<AppUser> changePassword(String current, String next) async {
    final r = await _api.post('/auth/change-password',
        body: {'current_password': current, 'new_password': next});
    final user = AppUser.fromJson(Map<String, dynamic>.from(r['user'] as Map));
    Session.instance.currentUser.value = user;
    return user;
  }

  Future<void> logout() => Session.instance.clear();
}

// -------------------------------------------------------------- superadmin

class SuperAdminApi {
  SuperAdminApi._();
  static final SuperAdminApi instance = SuperAdminApi._();
  final ApiClient _api = ApiClient.instance;

  Future<List<AdminAccount>> admins({String? status}) async =>
      _list(await _api.get('/admins', query: {'status': status}))
          .map(AdminAccount.fromJson)
          .toList();

  Future<CreateAdminResult> createAdmin({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final r = Map<String, dynamic>.from(await _api.post('/admins', body: {
      'name': name,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    }) as Map);
    return CreateAdminResult(
      admin: AdminAccount.fromJson(r),
      emailSent: r['email_sent'] == true,
      acceptUrl: r['accept_url'] as String?,
    );
  }

  /// Returns the new acceptance link when the e-mail could not be sent.
  Future<({bool emailSent, String? acceptUrl})> resend(String id, String password) async {
    final r = Map<String, dynamic>.from(
        await _api.post('/admins/$id/resend', body: {'password': password}) as Map);
    return (emailSent: r['email_sent'] == true, acceptUrl: r['accept_url'] as String?);
  }

  Future<void> deletePending(String id) => _api.delete('/admins/$id');

  Future<List<RenewalRequest>> renewals({String? status}) async =>
      _list(await _api.get('/subscription/requests', query: {'status': status}))
          .map(RenewalRequest.fromJson)
          .toList();

  Future<void> approve(String id) => _api.post('/subscription/requests/$id/approve');
  Future<void> reject(String id) => _api.post('/subscription/requests/$id/reject');
}

// ------------------------------------------------------------------- admin

class SubscriptionApi {
  SubscriptionApi._();
  static final SubscriptionApi instance = SubscriptionApi._();
  final ApiClient _api = ApiClient.instance;

  Future<SubscriptionInfo> mine() async =>
      SubscriptionInfo.fromJson(Map<String, dynamic>.from(await _api.get('/subscription/me') as Map));

  Future<void> requestRenewal({String? note}) =>
      _api.post('/subscription/requests', body: {if (note != null) 'note': note});
}

class FarmApi {
  FarmApi._();
  static final FarmApi instance = FarmApi._();
  final ApiClient _api = ApiClient.instance;

  // eleveurs
  Future<List<Eleveur>> eleveurs() async =>
      _list(await _api.get('/eleveurs')).map(Eleveur.fromJson).toList();
  Future<void> deleteEleveur(String id) => _api.delete('/eleveurs/$id');

  // invites
  Future<NewInvite> createInvite() async =>
      NewInvite.fromJson(Map<String, dynamic>.from(await _api.post('/invites') as Map));
  Future<List<Invite>> invites() async =>
      _list(await _api.get('/invites')).map(Invite.fromJson).toList();
  Future<void> deleteInvite(String id) => _api.delete('/invites/$id');

  // cows (only the admin writes)
  Future<List<Cow>> cows() async =>
      _list(await _api.get('/profiles')).map(Cow.fromJson).toList();

  Future<Cow> createCow({
    required String cowId,
    required String nfcUid,
    required DateTime birthDate,
    required double weightKg,
    required CowType type,
    required String breed,
  }) async =>
      Cow.fromJson(Map<String, dynamic>.from(await _api.post('/profiles', body: {
        'cow_id': cowId,
        if (nfcUid.isNotEmpty) 'nfc_uid': nfcUid,
        'birth_date': dateOnly(birthDate),
        'weight_kg': weightKg,
        'type': type.name,
        'breed': breed,
      }) as Map));

  Future<Cow> updateCow({
    required String cowId,
    required String nfcUid,
    required DateTime birthDate,
    required double weightKg,
    required CowType type,
    required String breed,
  }) async =>
      Cow.fromJson(Map<String, dynamic>.from(await _api.put('/profiles/$cowId', body: {
        'birth_date': dateOnly(birthDate),
        'weight_kg': weightKg,
        'type': type.name,
        'breed': breed,
        if (nfcUid.isNotEmpty) 'nfc_uid': nfcUid,
      }) as Map));

  Future<void> deleteCow(String cowId) => _api.delete('/profiles/$cowId');

  // measures
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

  // alerts
  Future<List<AlertItem>> alerts({String? status, int limit = 100}) async =>
      _list(await _api.get('/alerts', query: {'status': status, 'limit': limit}))
          .map(AlertItem.fromJson)
          .toList();

  Future<AlertItem> sendAlert({
    required String message,
    required Severity severity,
    String? cowId,
    String? action,
  }) async =>
      AlertItem.fromJson(Map<String, dynamic>.from(await _api.post('/alerts', body: {
        'message': message,
        'severity': severity.name,
        if (cowId != null) 'cow_id': cowId,
        if (action != null) 'action': action,
      }) as Map));

  Future<void> markAlertRead(String id) => _api.patch('/alerts/$id/read');
}
