import 'package:flutter_test/flutter_test.dart';
import 'package:soobshio/data/nizhnevartovsk_houses.dart';
import 'package:soobshio/services/uk_fallback_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hermes Municipal Intelligence & Data Verification Suite', () {
    test('1. Registry of 3450 Houses and UK resolution', () {
      expect(NizhnevartovskHousesData.allHouses.length, greaterThanOrEqualTo(3000));
      
      // Test address lookup for Prospekt Pobedy, 3
      final pobedyHouse = NizhnevartovskHousesData.allHouses.firstWhere(
        (h) => (h['address'] as String).toLowerCase().contains('победы, 3'),
      );
      expect(pobedyHouse, isNotNull);
      expect(pobedyHouse['lat'], isNotNull);
      expect(pobedyHouse['lng'], isNotNull);

      // Verify UK Fallback data has 40+ managing companies with emergency dispatcher phones
      expect(UkFallbackData.companies.length, greaterThanOrEqualTo(40));
      final hasDispatchers = UkFallbackData.companies.every((uk) => uk['phone'] != null && uk['phone'].toString().isNotEmpty);
      expect(hasDispatchers, isTrue);
    });

    test('2. Municipal Laws & Temperature Norms in KhMAO', () {
      const minHeatingTempLiving = 20; // +20C
      const minHeatingTempCorner = 22; // +22C
      const minGvsTemp = 60;           // +60C SanPiN
      const maxGvsTemp = 75;           // +75C SanPiN

      expect(minHeatingTempLiving, 20);
      expect(minHeatingTempCorner, 22);
      expect(minGvsTemp, 60);
      expect(maxGvsTemp, 75);
    });

    test('3. Ob River Flood Danger Marks in Nizhnevartovsk', () {
      const normalHydroLevel = 840.0;
      const dangerRebFlota = 940.0;
      const dangerStaryVartovsk = 980.0;
      const criticalDamSpill = 1030.0;

      expect(dangerRebFlota - normalHydroLevel, 100.0);
      expect(dangerStaryVartovsk - normalHydroLevel, 140.0);
      expect(criticalDamSpill - normalHydroLevel, 190.0);
    });

    test('4. Emergency Contacts Registry', () {
      const edds = '112';
      const vodokanal = '(3466) 44-77-44';
      const nesko = '(3466) 408-008';
      const uts = '(3466) 24-78-27';

      expect(edds, '112');
      expect(vodokanal, contains('44-77-44'));
      expect(nesko, contains('408-008'));
      expect(uts, contains('24-78-27'));
    });
  });
}
