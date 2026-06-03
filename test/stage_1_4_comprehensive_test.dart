import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_versions_controller/services/database_service.dart';
import 'package:easy_versions_controller/services/snapshot_service.dart';
import 'package:easy_versions_controller/services/diff_service.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/models/snapshot.dart';

/// 阶段 1-4 综合测试
/// 验证所有服务层功能的正确性和完整性
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('===== 阶段一: 项目基础 =====', () {
    late ProviderContainer container;
    late DatabaseService dbService;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('evc_stage_').path;
      container = ProviderContainer();
      dbService = container.read(databaseServiceProvider);
    });

    tearDown(() async {
      await dbService.close();
      container.dispose();
      if (Directory(tempDir).existsSync()) {
        Directory(tempDir).deleteSync(recursive: true);
      }
    });

    test('S1-01: DatabaseService 实例化', () {
      expect(dbService, isNotNull);
      expect(dbService, isA<DatabaseService>());
    });

    test('S1-02: TrackedFile 模型创建', () {
      final file = TrackedFile(
        id: 'test-id',
        filePath: '/path/file.txt',
        fileName: 'file.txt',
        createdAt: DateTime.now(),
      );

      expect(file.id, 'test-id');
      expect(file.fileName, 'file.txt');
      expect(file.createdAt, isNotNull);
    });

    test('S1-03: Snapshot 模型创建', () {
      final snapshot = Snapshot(
        id: 'snap-id',
        fileId: 'file-id',
        snapshotPath: '/path/snapshot.txt',
        timestamp: DateTime.now(),
        fileSize: 1024,
        sha256Hash: 'abcdef',
        message: '测试快照',
      );

      expect(snapshot.fileId, 'file-id');
      expect(snapshot.fileSize, 1024);
      expect(snapshot.sha256Hash, 'abcdef');
      expect(snapshot.message, '测试快照');
    });

    test('S1-04: TrackedFile 插入和查询', () async {
      final uid = Uuid().v4();
      final file = TrackedFile(
        id: uid,
        filePath: '/test/$uid/doc.txt',
        fileName: 'doc.txt',
        createdAt: DateTime.now(),
      );

      await dbService.insertTrackedFile(file);
      final retrieved = await dbService.getTrackedFileById(uid);
      expect(retrieved, isNotNull);
      expect(retrieved!.filePath, file.filePath);

      await dbService.deleteTrackedFile(uid);
    });

    test('S1-05: TrackedFile 更新', () async {
      final uid = Uuid().v4();
      final file = TrackedFile(
        id: uid,
        filePath: '/test/$uid/doc.txt',
        fileName: 'doc.txt',
        createdAt: DateTime.now(),
      );
      await dbService.insertTrackedFile(file);

      final updated = file.copyWith(
        snapshotDir: '/snapshots/$uid',
        updatedAt: DateTime.now(),
      );
      await dbService.updateTrackedFile(updated);

      final retrieved = await dbService.getTrackedFileById(uid);
      expect(retrieved!.snapshotDir, '/snapshots/$uid');
      expect(retrieved.updatedAt, isNotNull);

      await dbService.deleteTrackedFile(uid);
    });

    test('S1-06: TrackedFile 按路径查询', () async {
      final uid = Uuid().v4();
      final filePath = '/test/$uid/unique.txt';
      final file = TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'unique.txt',
        createdAt: DateTime.now(),
      );
      await dbService.insertTrackedFile(file);

      final byPath = await dbService.getTrackedFileByPath(filePath);
      expect(byPath, isNotNull);
      expect(byPath!.id, uid);

      await dbService.deleteTrackedFile(uid);
    });

    test('S1-07: Snapshot 插入和查询', () async {
      final uid = Uuid().v4();
      final file = TrackedFile(
        id: uid,
        filePath: '/test/$uid/doc.txt',
        fileName: 'doc.txt',
        createdAt: DateTime.now(),
      );
      await dbService.insertTrackedFile(file);

      final snapshot = Snapshot(
        id: Uuid().v4(),
        fileId: uid,
        snapshotPath: '/snapshots/$uid/v1.txt',
        timestamp: DateTime.now(),
        fileSize: 500,
        sha256Hash: 'hash123',
        message: '初始版本',
      );
      await dbService.insertSnapshot(snapshot);

      final retrieved = await dbService.getSnapshotById(snapshot.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.fileId, uid);
      expect(retrieved.message, '初始版本');

      // Cleanup
      await dbService.deleteSnapshot(snapshot.id);
      await dbService.deleteTrackedFile(uid);
    });

    test('S1-08: 级联删除（删除文件时自动删除快照）', () async {
      final uid = Uuid().v4();
      final file = TrackedFile(
        id: uid,
        filePath: '/test/$uid/doc.txt',
        fileName: 'doc.txt',
        createdAt: DateTime.now(),
      );
      await dbService.insertTrackedFile(file);

      final snapshot = Snapshot(
        id: Uuid().v4(),
        fileId: uid,
        snapshotPath: '/snapshots/$uid/v1.txt',
        timestamp: DateTime.now(),
        fileSize: 100,
        sha256Hash: 'hash',
        message: '快照',
      );
      await dbService.insertSnapshot(snapshot);

      // 删除文件
      await dbService.deleteTrackedFile(uid);

      // 快照也应被删除
      final snapAfter = await dbService.getSnapshotById(snapshot.id);
      expect(snapAfter, isNull);

      final fileAfter = await dbService.getTrackedFileById(uid);
      expect(fileAfter, isNull);
    });

    test('S1-09: 获取所有追踪文件', () async {
      final uid1 = Uuid().v4();
      final uid2 = Uuid().v4();

      await dbService.insertTrackedFile(TrackedFile(
        id: uid1,
        filePath: '/test/$uid1/a.txt',
        fileName: 'a.txt',
        createdAt: DateTime.now(),
      ));
      await dbService.insertTrackedFile(TrackedFile(
        id: uid2,
        filePath: '/test/$uid2/b.txt',
        fileName: 'b.txt',
        createdAt: DateTime.now(),
      ));

      final all = await dbService.getAllTrackedFiles();
      expect(all.any((f) => f.id == uid1), isTrue);
      expect(all.any((f) => f.id == uid2), isTrue);

      await dbService.deleteTrackedFile(uid1);
      await dbService.deleteTrackedFile(uid2);
    });
  });

  group('===== 阶段二/三: 添加追踪 + 列表管理 =====', () {
    late ProviderContainer container;
    late DatabaseService dbService;
    late SnapshotService snapshotService;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('evc_stage23_').path;
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

    test('S2-01: 添加文件并创建初始快照', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'hello.txt');
      await File(filePath).writeAsString('Hello World');

      // 插入追踪记录
      await dbService.insertTrackedFile(TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'hello.txt',
        createdAt: DateTime.now(),
      ));

      // 创建初始快照
      final snapshot = await snapshotService.createInitialSnapshot(
        fileId: uid,
        filePath: filePath,
        fileName: 'hello.txt',
      );

      expect(snapshot.fileId, uid);
      expect(snapshot.message, '初始版本');
      expect(File(snapshot.snapshotPath).existsSync(), isTrue);

      // 清理
      await dbService.deleteSnapshot(snapshot.id);
      await snapshotService.deleteSnapshotFiles(uid);
      await dbService.deleteTrackedFile(uid);
    });

    test('S2-02: 重复添加同一文件不应创建重复记录', () async {
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'duplicate.txt');
      await File(filePath).writeAsString('Test');

      final uid = Uuid().v4();
      await dbService.insertTrackedFile(TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'duplicate.txt',
        createdAt: DateTime.now(),
      ));

      // 检查按路径查重
      final existing = await dbService.getTrackedFileByPath(filePath);
      expect(existing, isNotNull);
      expect(existing!.id, uid);

      await dbService.deleteTrackedFile(uid);
    });

    test('S2-03: 文件列表显示所有追踪文件', () async {
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);

      final uid1 = Uuid().v4();
      final uid2 = Uuid().v4();
      final uid3 = Uuid().v4();

      final files = [
        TrackedFile(id: uid1, filePath: p.join(testDataDir, 'a.txt'),
            fileName: 'a.txt', createdAt: DateTime.now()),
        TrackedFile(id: uid2, filePath: p.join(testDataDir, 'b.txt'),
            fileName: 'b.txt', createdAt: DateTime.now()),
        TrackedFile(id: uid3, filePath: p.join(testDataDir, 'c.txt'),
            fileName: 'c.txt', createdAt: DateTime.now()),
      ];

      for (final f in files) {
        await File(f.filePath).writeAsString(f.fileName);
        await dbService.insertTrackedFile(f);
      }

      final all = await dbService.getAllTrackedFiles();
      // 至少包含我们刚插入的文件
      final ourFiles = all.where((f) =>
          f.id == uid1 || f.id == uid2 || f.id == uid3);
      expect(ourFiles.length, 3);

      for (final f in files) {
        await dbService.deleteTrackedFile(f.id);
      }
    });

    test('S3-01: 删除追踪文件（保留快照）', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'to_delete.txt');
      await File(filePath).writeAsString('Delete me');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'to_delete.txt',
        createdAt: DateTime.now(),
      ));

      await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'to_delete.txt',
      );

      // 删除（不删除快照文件）
      await dbService.deleteTrackedFile(uid);

      final after = await dbService.getTrackedFileById(uid);
      expect(after, isNull);

      final snapshots = await dbService.getSnapshotsByFileId(uid);
      expect(snapshots, isEmpty); // 级联删除
    });

    test('S3-02: 删除追踪文件（同时删除快照文件目录）', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'full_delete.txt');
      await File(filePath).writeAsString('Full delete');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'full_delete.txt',
        createdAt: DateTime.now(),
      ));

      await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'full_delete.txt',
      );

      // 获取快照目录
      final rootPath = await snapshotService.getSnapshotsRootPath();
      final snapshotDir = p.join(rootPath, uid);
      expect(Directory(snapshotDir).existsSync(), isTrue);

      // 删除快照文件 + 追踪记录
      await snapshotService.deleteSnapshotFiles(uid);
      await dbService.deleteTrackedFile(uid);

      expect(Directory(snapshotDir).existsSync(), isFalse);
      expect(await dbService.getTrackedFileById(uid), isNull);
    });
  });

  group('===== 阶段四: 自动保存 + 差异对比 + 版本回退 =====', () {
    late ProviderContainer container;
    late DatabaseService dbService;
    late SnapshotService snapshotService;
    late DiffService diffService;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('evc_stage4_').path;
      container = ProviderContainer();
      dbService = container.read(databaseServiceProvider);
      snapshotService = SnapshotService(
        dbService: dbService,
        overrideRootPath: tempDir,
      );
      diffService = DiffService();
    });

    tearDown(() async {
      await dbService.close();
      container.dispose();
      if (Directory(tempDir).existsSync()) {
        Directory(tempDir).deleteSync(recursive: true);
      }
    });

    test('S4-01: 自动保存 - 文件修改后创建新快照', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'auto_save.txt');
      final file = File(filePath);
      await file.writeAsString('初始内容');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'auto_save.txt',
        createdAt: DateTime.now(),
      ));

      await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'auto_save.txt',
      );

      // 修改文件
      await file.writeAsString('修改后的内容 v2');

      // 自动保存
      final autoSnapshot = await snapshotService.createAutoSnapshot(
        fileId: uid, filePath: filePath, fileName: 'auto_save.txt',
      );

      expect(autoSnapshot, isNotNull);
      expect(autoSnapshot!.message, '自动保存');

      // 验证快照内容不含自动保存（自动保存不影响 snapshotService）
      final allSnapshots = await dbService.getSnapshotsByFileId(uid);
      expect(allSnapshots.length, 2);

      await dbService.deleteTrackedFile(uid);
    });

    test('S4-02: 自动保存 - 内容无变化时跳过', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'no_change.txt');
      await File(filePath).writeAsString('不变的内容');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'no_change.txt',
        createdAt: DateTime.now(),
      ));

      await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'no_change.txt',
      );

      // 不修改文件，直接自动保存
      final autoSnapshot = await snapshotService.createAutoSnapshot(
        fileId: uid, filePath: filePath, fileName: 'no_change.txt',
      );

      // 内容无变化，应返回 null
      expect(autoSnapshot, isNull);

      final allSnapshots = await dbService.getSnapshotsByFileId(uid);
      expect(allSnapshots.length, 1);

      await dbService.deleteTrackedFile(uid);
    });

    test('S4-03: 差异对比 - 简单文本差异', () {
      const v1 = 'Hello\nWorld\nFoo';
      const v2 = 'Hello\nBar\nBaz';

      final diffs = diffService.getDiffBetweenTexts(fromText: v1, toText: v2);

      final sameLines = diffs.where((d) => d.type == DiffLineType.same);
      final changedLines = diffs.where((d) => d.type != DiffLineType.same);

      expect(sameLines.length, 1); // "Hello"
      expect(sameLines.first.content, 'Hello');
      expect(changedLines.length, 4); // World(removed), Foo(removed), Bar(added), Baz(added)
    });

    test('S4-04: 差异对比 - 文件对比', () async {
      final v1Path = p.join(tempDir, 'v1.txt');
      final v2Path = p.join(tempDir, 'v2.txt');
      await File(v1Path).writeAsString('line1\nline2\nline3');
      await File(v2Path).writeAsString('line1\nmodified\nline3');

      final diffs = await diffService.getDiffBetweenFiles(
        fromFilePath: v1Path,
        toFilePath: v2Path,
      );

      final changed = diffs.where((d) => d.type != DiffLineType.same);
      expect(changed.length, 2); // 1 removed + 1 added
    });

    test('S4-05: 差异对比 - 不存在的文件', () async {
      final diffs = await diffService.getDiffBetweenFiles(
        fromFilePath: p.join(tempDir, 'nonexistent.txt'),
        toFilePath: p.join(tempDir, 'nonexistent2.txt'),
      );

      // 两个文件都不存在，应返回空列表
      expect(diffs, isEmpty);
    });

    test('S4-06: 版本回退 - 完整流程', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'rollback.txt');
      final file = File(filePath);
      await file.writeAsString('版本1: 原始内容\n行2\n行3');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'rollback.txt',
        createdAt: DateTime.now(),
      ));

      final v1Snapshot = await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'rollback.txt',
      );

      // 修改文件
      await file.writeAsString('版本2: 修改后的内容\n行2已修改\n行3已修改');
      await snapshotService.createAutoSnapshot(
        fileId: uid, filePath: filePath, fileName: 'rollback.txt',
      );

      // 回退到 v1
      final restoredSnapshot = await snapshotService.restoreSnapshot(
        fileId: uid,
        filePath: filePath,
        fileName: 'rollback.txt',
        snapshot: v1Snapshot,
      );

      expect(restoredSnapshot.message, isNotNull);
      expect(restoredSnapshot.message!.contains('回退'), isTrue);

      // 验证文件内容已恢复
      final content = await file.readAsString();
      expect(content, contains('版本1: 原始内容'));
      expect(content, isNot(contains('版本2')));

      // 验证回退记录存在
      final allSnapshots = await dbService.getSnapshotsByFileId(uid);
      final rollbackSnap = allSnapshots.where((s) => s.message!.contains('回退'));
      expect(rollbackSnap.isNotEmpty, isTrue);

      await dbService.deleteTrackedFile(uid);
    });

    test('S4-07: 版本回退 - 回退前自动保存当前状态', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'rollback_save.txt');
      final file = File(filePath);
      await file.writeAsString('版本1: 原始内容');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid,
        filePath: filePath,
        fileName: 'rollback_save.txt',
        createdAt: DateTime.now(),
      ));

      final v1Snapshot = await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'rollback_save.txt',
      );

      await file.writeAsString('版本2: 修改后的内容');
      // 不自动保存，直接回退

      final snapshotsBefore = await dbService.getSnapshotsByFileId(uid);
      final countBefore = snapshotsBefore.length;

      await snapshotService.restoreSnapshot(
        fileId: uid,
        filePath: filePath,
        fileName: 'rollback_save.txt',
        snapshot: v1Snapshot,
      );

      // 回退前应自动保存了「版本2」
      final snapshotsAfter = await dbService.getSnapshotsByFileId(uid);
      expect(snapshotsAfter.length, greaterThan(countBefore));
      expect(snapshotsAfter.any((s) => s.message == '回退前自动保存'), isTrue);

      await dbService.deleteTrackedFile(uid);
    });

    test('S4-08: 快照时间轴 - 按时间排序', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'timeline.txt');
      final file = File(filePath);
      await file.writeAsString('版本1');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid, filePath: filePath,
        fileName: 'timeline.txt', createdAt: DateTime.now(),
      ));

      await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'timeline.txt',
      );
      await Future.delayed(const Duration(milliseconds: 10));

      await file.writeAsString('版本2');
      await snapshotService.createAutoSnapshot(
        fileId: uid, filePath: filePath, fileName: 'timeline.txt',
      );
      await Future.delayed(const Duration(milliseconds: 10));

      await file.writeAsString('版本3');
      await snapshotService.createAutoSnapshot(
        fileId: uid, filePath: filePath, fileName: 'timeline.txt',
      );

      final snapshots = await dbService.getSnapshotsByFileId(uid);
      // 检查数量
      expect(snapshots.length, 3);
      // 检查降序排列（最新的在前）
      for (int i = 1; i < snapshots.length; i++) {
        expect(
          snapshots[i - 1].timestamp.isAfter(snapshots[i].timestamp) ||
          snapshots[i - 1].timestamp.isAtSameMomentAs(snapshots[i].timestamp),
          isTrue,
        );
      }

      await dbService.deleteTrackedFile(uid);
    });

    test('S4-09: 快照计数', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'count.txt');
      final file = File(filePath);
      await file.writeAsString('v1');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid, filePath: filePath,
        fileName: 'count.txt', createdAt: DateTime.now(),
      ));

      await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'count.txt',
      );
      expect(await dbService.getSnapshotCount(uid), 1);

      await file.writeAsString('v2');
      await snapshotService.createAutoSnapshot(
        fileId: uid, filePath: filePath, fileName: 'count.txt',
      );
      expect(await dbService.getSnapshotCount(uid), 2);

      await dbService.deleteTrackedFile(uid);
    });

    test('S4-10: 获取最新快照', () async {
      final uid = Uuid().v4();
      final testDataDir = p.join(tempDir, 'test_data');
      Directory(testDataDir).createSync(recursive: true);
      final filePath = p.join(testDataDir, 'latest.txt');
      final file = File(filePath);
      await file.writeAsString('v1');

      await dbService.insertTrackedFile(TrackedFile(
        id: uid, filePath: filePath,
        fileName: 'latest.txt', createdAt: DateTime.now(),
      ));

      await snapshotService.createInitialSnapshot(
        fileId: uid, filePath: filePath, fileName: 'latest.txt',
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await file.writeAsString('v2');
      final v2 = await snapshotService.createAutoSnapshot(
        fileId: uid, filePath: filePath, fileName: 'latest.txt',
      );

      final latest = await dbService.getLatestSnapshot(uid);
      expect(latest, isNotNull);
      expect(latest!.id, v2!.id);

      await dbService.deleteTrackedFile(uid);
    });
  });
}