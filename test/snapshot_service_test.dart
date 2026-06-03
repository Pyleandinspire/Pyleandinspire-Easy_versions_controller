import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:easy_versions_controller/services/snapshot_service.dart';
import 'package:easy_versions_controller/services/database_service.dart';

void main() {
  group('SnapshotService', () {
    late ProviderContainer container;
    late SnapshotService snapshotService;
    late DatabaseService dbService;
    late String tempDir;

    setUp(() async {
      container = ProviderContainer();
      dbService = container.read(databaseServiceProvider);

      tempDir = Directory.systemTemp.createTempSync('evc_test_').path;

      snapshotService = SnapshotService(
        dbService: dbService,
        overrideRootPath: tempDir,
      );
    });

    tearDown(() async {
      await dbService.close();
      container.dispose();
      if (Directory(tempDir).existsSync()) {
        Directory(tempDir).deleteSync(recursive: true);
      }
    });

    test('can be instantiated', () {
      expect(snapshotService, isNotNull);
      expect(snapshotService, isA<SnapshotService>());
    });

    test('getSnapshotsRootPath returns valid path', () async {
      final rootPath = await snapshotService.getSnapshotsRootPath();
      expect(rootPath.isNotEmpty, isTrue);
      expect(rootPath.contains('snapshots'), isTrue);
      expect(rootPath.contains(tempDir), isTrue);
    });

    test('initSnapshotDir creates directory', () async {
      final dirId = Uuid().v4();
      final dirPath = await snapshotService.initSnapshotDir(dirId);
      expect(Directory(dirPath).existsSync(), isTrue);
    });

    test('createInitialSnapshot creates snapshot file and db record', () async {
      final uid = Uuid().v4();
      final testFilePath = p.join(tempDir, 'test_doc.txt');
      final testFile = File(testFilePath);
      await testFile.writeAsString('Hello World - Test Content');

      final snapshot = await snapshotService.createInitialSnapshot(
        fileId: uid,
        filePath: testFilePath,
        fileName: 'test_doc.txt',
      );

      expect(snapshot.fileId, uid);
      expect(snapshot.message, '初始版本');
      expect(snapshot.fileSize, greaterThan(0));
      expect(snapshot.sha256Hash, isNotNull);

      final snapshotFile = File(snapshot.snapshotPath);
      expect(snapshotFile.existsSync(), isTrue);

      final snapshotContent = await snapshotFile.readAsString();
      expect(snapshotContent, 'Hello World - Test Content');

      // 文件名格式: yyyyMMdd_HHmmss_SSS_filename
      final fileName = p.basename(snapshot.snapshotPath);
      final pattern = RegExp(r'^\d{8}_\d{6}_\d{3}_test_doc\.txt$');
      expect(pattern.hasMatch(fileName), isTrue);

      final dbSnapshot = await dbService.getSnapshotById(snapshot.id);
      expect(dbSnapshot, isNotNull);
      expect(dbSnapshot!.fileId, uid);

      await dbService.deleteSnapshot(snapshot.id);
    });

    test('deleteSnapshotFiles removes directory', () async {
      final dirId = Uuid().v4();
      await snapshotService.initSnapshotDir(dirId);
      final rootPath = await snapshotService.getSnapshotsRootPath();
      final targetDir = p.join(rootPath, dirId);
      expect(Directory(targetDir).existsSync(), isTrue);

      await snapshotService.deleteSnapshotFiles(dirId);
      expect(Directory(targetDir).existsSync(), isFalse);
    });
  });
}