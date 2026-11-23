library;

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

// ---------------------------------------------------------------- feeders

class Feeder {
  const Feeder({
    required this.id,
    required this.name,
    required this.capacityG,
    required this.currentG,
    required this.levelPct,
    required this.online,
    required this.status,
    this.lastRefillAt,
  });

  final String id;
  final String name;
  final double capacityG;
  final double currentG;
  final double levelPct;
  final DateTime? lastRefillAt;
  final bool online;
  final String status;

  factory Feeder.fromJson(Map<String, dynamic> j) => Feeder(
        id: _str(j['id']) ?? '',
        name: _str(j['name']) ?? '',
        capacityG: _num(j['capacity_g']),
        currentG: _num(j['current_quantity_g']),
        levelPct: _num(j['level_pct']).clamp(0, 100).toDouble(),
        lastRefillAt: _date(j['last_refill_at']),
        online: j['online'] == true,
        status: _str(j['status']) ?? 'critical',
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

// ------------------------------------------- last measures kept on the phone

/// Snapshot saved by the Kotlin side (DataStore) so the last measures are
/// readable without network.
class LastMeasure {
  const LastMeasure({
    required this.cowId,
    required this.date,
    required this.consumedG,
    this.lastVisit,
    this.appetite,
    this.decreasePct,
  });
  final String cowId;
  final String date;
  final double consumedG;
  final String? lastVisit;
  final Appetite? appetite;
  final double? decreasePct;

  factory LastMeasure.fromJson(Map<String, dynamic> j) => LastMeasure(
        cowId: _str(j['cow_id']) ?? '?',
        date: _str(j['date']) ?? '',
        consumedG: _num(j['consumed_g']),
        lastVisit: _str(j['last_visit']),
        appetite: parseAppetite(j['appetite']),
        decreasePct: j['decrease_pct'] is num ? (j['decrease_pct'] as num).toDouble() : null,
      );
}
