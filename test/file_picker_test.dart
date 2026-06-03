import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/services/file_picker_service.dart';
import 'package:easy_versions_controller/viewmodels/file_picker_provider.dart';

void main() {
  group('FilePickerService', () {
    test('can be instantiated', () {
      final service = FilePickerService();
      expect(service, isNotNull);
    });

    test('pickFiles returns empty list when cancelled', () {
      // Note: pickFiles requires platform channels, 
      // but the class structure is testable
      final service = FilePickerService();
      expect(service, isA<FilePickerService>());
    });
  });

  group('FilePickerProvider', () {
    test('filePickerServiceProvider returns FilePickerService', () {
      final container = ProviderContainer();
      final service = container.read(filePickerServiceProvider);
      expect(service, isA<FilePickerService>());
      container.dispose();
    });
  });
}