import 'package:flutter_test/flutter_test.dart';
import 'package:newtechmms/pages/location_master_page.dart';

void main() {
  group('LocationMaster Dynamic Date & Glow Tests', () {
    test('formatDisplayDate converts DateTime properly', () {
      final dt = DateTime(2026, 9, 9);
      final formatted = LocationMaster.formatDisplayDate(dt);
      expect(formatted, equals('09 Sep 2026'));
    });

    test('formatDisplayDate parses ISO date string', () {
      const iso = '2026-11-25T14:30:00Z';
      final formatted = LocationMaster.formatDisplayDate(iso);
      expect(formatted, equals('25 Nov 2026'));
    });

    test('replaces hardcoded 03 Aug 2026 with current date', () {
      final formatted = LocationMaster.formatDisplayDate('03 Aug 2026');
      final todayFormatted = LocationMaster.formatDisplayDate(DateTime.now());
      expect(formatted, equals(todayFormatted));
    });

    test('replaces null or empty date with current date', () {
      final fromNull = LocationMaster.formatDisplayDate(null);
      final fromEmpty = LocationMaster.formatDisplayDate('');
      final todayFormatted = LocationMaster.formatDisplayDate(DateTime.now());
      expect(fromNull, equals(todayFormatted));
      expect(fromEmpty, equals(todayFormatted));
    });

    test('fromJson creates valid dynamic date when null or legacy', () {
      final json = {
        'locCode': 101,
        'locName': 'Main Branch',
        'locPrefix': 'MB',
        'createdDate': null,
      };
      final model = LocationMaster.fromJson(json);
      expect(model.locCode, equals(101));
      expect(model.locName, equals('Main Branch'));
      expect(model.locPrefix, equals('MB'));
      expect(model.createdDate, isNot('03 Aug 2026'));
      expect(model.createdDate, equals(LocationMaster.formatDisplayDate(DateTime.now())));
    });
  });
}
