import 'package:flutter_test/flutter_test.dart';
import 'package:agrimed_link/services/gemini_scanner_service.dart';
import 'package:agrimed_link/services/crop_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CropService.isTestMode = true;
  });

  group('GeminiScannerService Tests', () {
    test('API Key configuration is accessible', () {
      expect(GeminiScannerService.geminiApiKey, isNotNull);
    });

    test('Diagnoses healthy crop specimen with botanical profile', () async {
      final diagnosis = await GeminiScannerService.instance.diagnose(
        imageAssetOrPath: 'assets/images/crop_moringa.jpg',
        labelHint: 'Moringa Leaf',
      );

      expect(diagnosis['name'], contains('Moringa'));
      expect(diagnosis['botanical'], contains('Moringa oleifera'));
      expect(diagnosis['family'], 'Moringaceae');
      expect(diagnosis['isHealthy'], isTrue);
      expect(diagnosis['compounds'], contains('Quercetin'));
      expect(diagnosis['basePriceUSD'], greaterThan(0));
      expect(diagnosis['treatment'], isNotNull);
      expect(diagnosis['aiModel'], isNotNull);
    });

    test('Diagnoses diseased plant with pathogen alert and treatment remedy', () async {
      final diagnosis = await GeminiScannerService.instance.diagnose(
        imageAssetOrPath: 'assets/images/crop_moringa.jpg',
        labelHint: 'Blight Diseased Foliage',
      );

      expect(diagnosis['isHealthy'], isFalse);
      expect(diagnosis['healthStatus'], contains('Pathogen Alert'));
      expect(diagnosis['pathogen'], contains('Alternaria'));
      expect(diagnosis['treatment'], contains('fungicide'));
    });
  });
}
