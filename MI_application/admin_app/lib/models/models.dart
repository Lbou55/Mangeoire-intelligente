/// Data models (JSON from the server). Parsing is tolerant: a missing optional
/// field never crashes a screen.

DateTime? _date(Object? v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
  return null;
}

double _num(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

// ---------------------------------------------------------------- users

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    this.email,
    this.phone,
    this.mustChangePassword = false,
    this.subscriptionExpiresAt,
    this.subscriptionActive = true,
  });

  final String id;
  final String role; // superadmin | admin
  final String name;
  final String? email;
  final String? phone;
  final bool mustChangePassword;
  final DateTime? subscriptionExpiresAt;
  final bool subscriptionActive;

  bool get isSuperAdmin => role == 'superadmin';

  int get daysLeft {
    final e = subscriptionExpiresAt;
    if (e == null) return 0;
    final diff = e.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return diff.inDays + (diff.inHours % 24 > 0 ? 1 : 0);
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: '${j['id']}',
        role: _str(j['role']) ?? 'admin',
        name: _str(j['name']) ?? '',
        email: _str(j['email']),
        phone: _str(j['phone']),
        mustChangePassword: j['must_change_password'] == true,
        subscriptionExpiresAt: _date(j['subscription_expires_at']),
        subscriptionActive: j['subscription_active'] != false,
      );
}

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    this.phone,
    this.createdAt,
    this.acceptedAt,
    this.subscriptionExpiresAt,
  });

  final String id;
  final String name;
  final String email;
  final String status; // pending | active | suspended
  final String? phone;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? subscriptionExpiresAt;

  bool get accepted => status == 'active';

  factory AdminAccount.fromJson(Map<String, dynamic> j) => AdminAccount(
        id: '${j['id']}',
        name: _str(j['name']) ?? '',
        email: _str(j['email']) ?? '',
        status: _str(j['status']) ?? 'pending',
        phone: _str(j['phone']),
        createdAt: _date(j['created_at']),
        acceptedAt: _date(j['accepted_at']),
        subscriptionExpiresAt: _date(j['subscription_expires_at']),
      );
}

class CreateAdminResult {
  const CreateAdminResult({
    required this.admin,
    required this.emailSent,
    this.acceptUrl,
  });
  final AdminAccount admin;
  final bool emailSent;
  final String? acceptUrl;
}

class Eleveur {
  const Eleveur({required this.id, required this.name, this.createdAt});
  final String id;
  final String name;
  final DateTime? createdAt;

  factory Eleveur.fromJson(Map<String, dynamic> j) => Eleveur(
        id: '${j['id']}',
        name: _str(j['name']) ?? '',
        createdAt: _date(j['created_at']),
      );
}

class Invite {
  const Invite({
    required this.id,
    required this.status,
    this.createdAt,
    this.expiresAt,
    this.usedByName,
  });
  final String id;
  final String status; // active | used | expired
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? usedByName;

  factory Invite.fromJson(Map<String, dynamic> j) => Invite(
        id: '${j['id']}',
        status: _str(j['status']) ?? 'expired',
        createdAt: _date(j['created_at']),
        expiresAt: _date(j['expires_at']),
        usedByName: _str(j['used_by_name']),
      );
}

class NewInvite {
  const NewInvite({
    required this.id,
    required this.code,
    required this.qrPayload,
    required this.expiresAt,
  });
  final String id;
  final String code;
  final String qrPayload;
  final DateTime? expiresAt;

  factory NewInvite.fromJson(Map<String, dynamic> j) => NewInvite(
        id: '${j['id']}',
        code: _str(j['code']) ?? '',
        qrPayload: _str(j['qr_payload']) ?? _str(j['code']) ?? '',
        expiresAt: _date(j['expires_at']),
      );
}

// ------------------------------------------------------------------ cows

enum CowType { dairy, beef, dual }

CowType parseCowType(String? v) => switch (v) {
      'dairy' => CowType.dairy,
      'beef' => CowType.beef,
      _ => CowType.dual,
    };

const breedsByType = <CowType, List<String>>{
  CowType.dairy: ['Holstein', 'Jersey'],
  CowType.beef: ['Angus', 'Limousin', 'Charolais'],
  CowType.dual: ['Simmental'],
};

enum Appetite { decreasing, stable, increasing }

Appetite? parseAppetite(Object? v) => switch (v is String ? v.toLowerCase() : null) {
      'decreasing' || 'decreased' || 'low' => Appetite.decreasing,
      'stable' || 'normal' => Appetite.stable,
      'increasing' || 'increased' || 'high' => Appetite.increasing,
      _ => null,
    };

class Cow {
  const Cow({
    required this.cowId,
    required this.nfcUid,
    required this.breed,
    required this.type,
    required this.weightKg,
    required this.birthDate,
    required this.ageMonths,
  });

  final String cowId;
  final String nfcUid;
  final String breed;
  final CowType type;
  final double weightKg;
  final DateTime? birthDate;
  final int ageMonths;

  factory Cow.fromJson(Map<String, dynamic> j) => Cow(
        cowId: _str(j['cow_id']) ?? '?',
        nfcUid: _str(j['nfc_uid']) ?? '',
        breed: _str(j['breed']) ?? '',
        type: parseCowType(_str(j['type'])),
        weightKg: _num(j['weight_kg']),
        birthDate: DateTime.tryParse(_str(j['birth_date']) ?? ''),
        ageMonths: (j['age_months'] is num) ? (j['age_months'] as num).round() : 0,
      );
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.consumedG,
    required this.offeredG,
    required this.eatingMinutes,
    required this.visits,
    required this.noFoodVisits,
    required this.avgMealMin,
    this.appetite,
    this.appetitePct,
  });

  final String date;
  final double consumedG;
  final double offeredG;
  final double eatingMinutes;
  final double visits;
  final double noFoodVisits;
  final double avgMealMin;
  final Appetite? appetite;
  final Map<String, double>? appetitePct;

  factory DailySummary.fromJson(Map<String, dynamic> j) {
    Map<String, double>? pct;
    final raw = j['appetite_pct'];
    if (raw is Map) {
      pct = {
        for (final e in raw.entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble()
      };
    }
    return DailySummary(
      date: _str(j['date']) ?? '',
      consumedG: _num(j['total_food_consumed_g'] ?? j['food_consumed_g']),
      offeredG: _num(j['total_feed_offered_g'] ?? j['feed_offered_g']),
      eatingMinutes: _num(j['total_eating_minutes'] ?? j['eating_minutes']),
      visits: _num(j['visits']),
      noFoodVisits: _num(j['no_food_visits']),
      avgMealMin: _num(j['avg_meal_duration_min']),
      appetite: parseAppetite(j['appetite_class']),
      appetitePct: pct,
    );
  }
}

class Dispatch {
  const Dispatch({required this.date, required this.foodG, this.servedAt});
  final String date;
  final double foodG;
  final DateTime? servedAt;

  factory Dispatch.fromJson(Map<String, dynamic> j) => Dispatch(
        date: _str(j['date']) ?? '',
        foodG: _num(j['food_g']),
        servedAt: _date(j['served_at']),
      );
}

// ---------------------------------------------------------------- alerts

enum Severity { info, warning, critical }

Severity parseSeverity(Object? v) => switch (v) {
      'critical' => Severity.critical,
      'warning' => Severity.warning,
      _ => Severity.info,
    };

class AlertItem {
  const AlertItem({
    required this.id,
    required this.type,
    required this.message,
    required this.severity,
    required this.read,
    this.cowId,
    this.action,
    this.appetite,
    this.createdAt,
  });

  final String id;
  final String type; // custom_message | appetite
  final String message;
  final Severity severity;
  final bool read;
  final String? cowId;
  final String? action; // sell | vet | butcher
  final Appetite? appetite;
  final DateTime? createdAt;

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: '${j['id']}',
        type: _str(j['type']) ?? 'custom_message',
        message: _str(j['message']) ?? '',
        severity: parseSeverity(j['severity']),
        read: j['status'] == 'read',
        cowId: _str(j['cow_id']),
        action: _str(j['action']),
        appetite: parseAppetite(j['appetite_class']),
        createdAt: _date(j['created_at']),
      );
}

// ---------------------------------------------------------- subscription

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.active,
    required this.daysLeft,
    required this.pendingRequest,
    this.expiresAt,
  });
  final bool active;
  final int daysLeft;
  final bool pendingRequest;
  final DateTime? expiresAt;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
        active: j['active'] == true,
        daysLeft: (j['days_left'] is num) ? (j['days_left'] as num).toInt() : 0,
        pendingRequest: j['pending_request'] == true,
        expiresAt: _date(j['expires_at']),
      );
}

class RenewalRequest {
  const RenewalRequest({
    required this.id,
    required this.adminName,
    required this.adminEmail,
    required this.status,
    this.createdAt,
  });
  final String id;
  final String adminName;
  final String adminEmail;
  final String status; // pending | approved | rejected
  final DateTime? createdAt;

  factory RenewalRequest.fromJson(Map<String, dynamic> j) => RenewalRequest(
        id: '${j['id']}',
        adminName: _str(j['admin_name']) ?? '',
        adminEmail: _str(j['admin_email']) ?? '',
        status: _str(j['status']) ?? 'pending',
        createdAt: _date(j['created_at']),
      );
}
