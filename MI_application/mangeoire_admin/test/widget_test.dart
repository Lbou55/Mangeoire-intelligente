// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mangeoire_admin/main.dart';
import 'package:mangeoire_admin/models/models.dart';

void main() {
  test('Feeder.fromJson defaults missing and malformed fields', () {
    final feeder = Feeder.fromJson({
      'capacity_g': 'invalid',
      'current_quantity_g': <String, dynamic>{},
      'level_pct': null,
      'last_refill_at': 'invalid date',
      'online': 'true',
      'status': 12,
    });

    expect(feeder.id, '');
    expect(feeder.name, '');
    expect(feeder.capacityG, 0);
    expect(feeder.currentG, 0);
    expect(feeder.levelPct, 0);
    expect(feeder.lastRefillAt, isNull);
    expect(feeder.online, isFalse);
    expect(feeder.status, 'critical');
  });

  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MangeoireAdminApp(startDark: false));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
