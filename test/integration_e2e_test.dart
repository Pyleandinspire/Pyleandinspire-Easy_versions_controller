import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_versions_controller/services/database_service.dart';
import 'package:easy_versions_controller/services/snapshot_service.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/models/snapshot.dart';

/// 端到端集成测试
/// 验证：添加文件 → 编辑文件 → 自动保存 → 查看时间轴 → 查看差异 → 回退版本
void main() {
  // 初始化 sqflite FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('端到端集成测试', () {
    late ProviderContainer container;
    late DatabaseService dbService;
    late SnapshotService snapshotService;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('e2e_test_').path;
      container = ProviderContainer();
      dbService = container.read(databaseServiceProvider);

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

    test('场景1: 添加文件 → 创建快照 → 修改文件 → 自动保存 → 查看时间轴', () async {
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);

      final filePath = p.join(testDataDir, 'test_doc.txt');
      final file = File(filePath);
      await file.writeAsString('Hello World\nLine 2\n');

      final fileId = Uuid().v4();
      const fileName = 'test_doc.txt';

      final trackedFile = TrackedFile(
        id: fileId,
        filePath: filePath,
        fileName: fileName,
        createdAt: DateTime.now(),
      );
      await dbService.insertTrackedFile(trackedFile);

      final initialSnapshot = await snapshotService.createInitialSnapshot(
        fileId: fileId,
        filePath: filePath,
        fileName: fileName,
      );

      expect(initialSnapshot.fileId, equals(fileId));
      expect(initialSnapshot.message, equals('初始版本'));

      // 修改文件
      await file.writeAsString('Hello World Modified\nLine 2\nLine 3\n');

      final autoSnapshot = await snapshotService.createAutoSnapshot(
        fileId: fileId,
        filePath: filePath,
        fileName: fileName,
      );

      expect(autoSnapshot, isNotNull);
      expect(autoSnapshot!.message, equals('自动保存'));

      final snapshots = await dbService.getSnapshotsByFileId(fileId);
      expect(snapshots.length, equals(2));
      expect(snapshots[0].timestamp.isAfter(snapshots[1].timestamp), isTrue);
    });

    test('场景2: 多文件管理 - 每个文件独立', () async {
      final testDataDir = p.join(tempDir, 'test_data2');
      Directory(testDataDir).createSync(recursive: true);

      final file1Path = p.join(testDataDir, 'doc1.txt');
      final file2Path = p.join(testDataDir, 'doc2.txt');
      await File(file1Path).writeAsString('File 1 content');
      await File(file2Path).writeAsString('File 2 content');

      final file1Id = Uuid().v4();
      final file2Id = Uuid().v4();

      await dbService.insertTrackedFile(
        TrackedFile(
          id: file1Id,
          filePath: file1Path,
          fileName: 'doc1.txt',
          createdAt: DateTime.now(),
        ),
      );
      await dbService.insertTrackedFile(
        TrackedFile(
          id: file2Id,
          filePath: file2Path,
          fileName: 'doc2.txt',
          createdAt: DateTime.now(),
        ),
      );

      await snapshotService.createInitialSnapshot(
        fileId: file1Id,
        filePath: file1Path,
        fileName: 'doc1.txt',
      );
      await snapshotService.createInitialSnapshot(
        fileId: file2Id,
        filePath: file2Path,
        fileName: 'doc2.txt',
      );

      final snapshots1 = await dbService.getSnapshotsByFileId(file1Id);
      final snapshots2 = await dbService.getSnapshotsByFileId(file2Id);

      expect(snapshots1.length, equals(1));
      expect(snapshots2.length, equals(1));
      expect(snapshots1.first.fileId, equals(file1Id));
      expect(snapshots2.first.fileId, equals(file2Id));
    });

    test('场景3: 删除文件 → 数据清理', () async {
      final testDataDir = p.join(tempDir, 'test_data3');
      Directory(testDataDir).createSync(recursive: true);

      final filePath = p.join(testDataDir, 'to_delete.txt');
      await File(filePath).writeAsString('Delete me');

      final fileId = Uuid().v4();

      await dbService.insertTrackedFile(
        TrackedFile(
          id: fileId,
          filePath: filePath,
          fileName: 'to_delete.txt',
          createdAt: DateTime.now(),
        ),
      );
      await snapshotService.createInitialSnapshot(
        fileId: fileId,
        filePath: filePath,
        fileName: 'to_delete.txt',
      );

      await snapshotService.deleteSnapshotFiles(fileId);
      await dbService.deleteTrackedFile(fileId);

      final trackedFiles = await dbService.getAllTrackedFiles();
      expect(trackedFiles.where((f) => f.id == fileId), isEmpty);

      final snapshots = await dbService.getSnapshotsByFileId(fileId);
      expect(snapshots, isEmpty);
    });

    test('场景4: 版本回退完整流程', () async {
      final testDataDir = p.join(tempDir, 'test_data4');
      Directory(testDataDir).createSync(recursive: true);

      final filePath = p.join(testDataDir, 'rollback_test.txt');
      final file = File(filePath);
      await file.writeAsString('Version 1: Original content\nline 2\n');

      final fileId = Uuid().v4();

      await dbService.insertTrackedFile(
        TrackedFile(
          id: fileId,
          filePath: filePath,
          fileName: 'rollback_test.txt',
          createdAt: DateTime.now(),
        ),
      );

      final v1 = await snapshotService.createInitialSnapshot(
        fileId: fileId,
        filePath: filePath,
        fileName: 'rollback_test.txt',
      );

      // 修改文件并自动保存
      await file.writeAsString(
        'Version 2: Modified content\nline 2 modified\n',
      );
      await snapshotService.createAutoSnapshot(
        fileId: fileId,
        filePath: filePath,
        fileName: 'rollback_test.txt',
      );

      // 回退到 v1
      await snapshotService.restoreSnapshot(
        fileId: fileId,
        filePath: filePath,
        fileName: 'rollback_test.txt',
        snapshot: v1,
      );

      final restoredContent = await file.readAsString();
      expect(restoredContent, contains('Version 1: Original content'));

      final snapshots = await dbService.getSnapshotsByFileId(fileId);
      expect(snapshots.any((s) => s.message!.contains('回退')), isTrue);
    });
  });
}
