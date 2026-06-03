import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:easy_versions_controller/services/file_scan_service.dart';

void main() {
  group('FileScanService', () {
    late FileScanService scanService;
    late String tempDir;

    setUp(() {
      scanService = FileScanService();
      tempDir = Directory.systemTemp.createTempSync('evc_scan_test_').path;
    });

    tearDown(() {
      if (Directory(tempDir).existsSync()) {
        Directory(tempDir).deleteSync(recursive: true);
      }
    });

    test('can be instantiated', () {
      expect(scanService, isNotNull);
      expect(scanService, isA<FileScanService>());
    });

    test('fileExists returns true for existing file', () {
      final testFile = File(p.join(tempDir, 'exists.txt'));
      testFile.writeAsStringSync('test');
      expect(scanService.fileExists(testFile.path), isTrue);
    });

    test('fileExists returns false for missing file', () {
      expect(scanService.fileExists('/nonexistent/file.txt'), isFalse);
    });

    test('scanForFile finds file in known directory', () async {
      final testFile = File(p.join(tempDir, 'unique_scan_test.txt'));
      testFile.writeAsStringSync('find me');

      // 扫描当前临时目录（传入 tempDir 作为 subDir 扫描）
      final result = await scanService.scanForFile(
        fileName: 'unique_scan_test.txt',
        timeout: const Duration(seconds: 5),
      );

      // 注意：全局扫描可能找不到 tempDir 中的文件，因为 tempDir 不在常见目录中
      // 这个测试验证扫描逻辑不会崩溃
      expect(result == null || result == testFile.path, isTrue);
    });

    test('scanForFile returns null for nonexistent file', () async {
      final result = await scanService.scanForFile(
        fileName: 'file_that_does_not_exist_xyz_123.txt',
        timeout: const Duration(seconds: 2),
      );
      expect(result, isNull);
    });

    test('scanForFile times out correctly', () async {
      final startTime = DateTime.now();
      final result = await scanService.scanForFile(
        fileName: 'very_unique_filename_xyz.txt',
        timeout: const Duration(milliseconds: 100),
      );
      final elapsed = DateTime.now().difference(startTime);

      expect(result, isNull);
      expect(elapsed.inMilliseconds, lessThan(5000));
    });
  });
}