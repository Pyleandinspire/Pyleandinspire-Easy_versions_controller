import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_versions_controller/services/database_service.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/models/snapshot.dart';

void main() {
  group('DatabaseService', () {
    late ProviderContainer container;
    late DatabaseService dbService;

    setUp(() {
      container = ProviderContainer();
      dbService = container.read(databaseServiceProvider);
    });

    tearDown(() async {
      await dbService.close();
      container.dispose();
    });

    test('can be instantiated', () {
      expect(dbService, isNotNull);
      expect(dbService, isA<DatabaseService>());
    });

    test('tracked_files CRUD operations', () async {
      final uid = Uuid().v4();
      final file = TrackedFile(
        id: uid,
        filePath: '/test/path/$uid/doc.txt',
        fileName: 'doc.txt',
        createdAt: DateTime.now(),
      );

      // Insert
      final insertedId = await dbService.insertTrackedFile(file);
      expect(insertedId, uid);

      // Get by ID
      final retrieved = await dbService.getTrackedFileById(uid);
      expect(retrieved, isNotNull);
      expect(retrieved!.filePath, '/test/path/$uid/doc.txt');
      expect(retrieved.fileName, 'doc.txt');

      // Get by path
      final byPath = await dbService.getTrackedFileByPath(
        '/test/path/$uid/doc.txt',
      );
      expect(byPath, isNotNull);
      expect(byPath!.id, uid);

      // Get all (should have at least our file)
      final all = await dbService.getAllTrackedFiles();
      expect(all.any((f) => f.id == uid), isTrue);

      // Update
      final updated = file.copyWith(
        snapshotDir: '/snapshots/$uid',
        updatedAt: DateTime.now(),
      );
      await dbService.updateTrackedFile(updated);
      final afterUpdate = await dbService.getTrackedFileById(uid);
      expect(afterUpdate!.snapshotDir, '/snapshots/$uid');

      // Delete
      await dbService.deleteTrackedFile(uid);
      final afterDelete = await dbService.getTrackedFileById(uid);
      expect(afterDelete, isNull);
    });

    test('snapshots CRUD operations', () async {
      final uid = Uuid().v4();
      // 先插入一个追踪文件
      final file = TrackedFile(
        id: uid,
        filePath: '/test/path/$uid/doc.txt',
        fileName: 'doc.txt',
        createdAt: DateTime.now(),
      );
      await dbService.insertTrackedFile(file);

      final now = DateTime.now();
      final snapshot = Snapshot(
        id: Uuid().v4(),
        fileId: uid,
        snapshotPath: '/snapshots/$uid/20260603_120000_doc.txt',
        timestamp: now,
        fileSize: 1024,
        sha256Hash: 'abc123def456',
        message: 'Initial snapshot',
      );

      // Insert
      final snapId = await dbService.insertSnapshot(snapshot);
      expect(snapId, snapshot.id);

      // Get by ID
      final retrieved = await dbService.getSnapshotById(snapshot.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.fileId, uid);
      expect(retrieved.fileSize, 1024);
      expect(retrieved.sha256Hash, 'abc123def456');

      // Get by file ID
      final byFileId = await dbService.getSnapshotsByFileId(uid);
      expect(byFileId.length, 1);
      expect(byFileId.first.id, snapshot.id);

      // Get latest
      final latest = await dbService.getLatestSnapshot(uid);
      expect(latest, isNotNull);
      expect(latest!.id, snapshot.id);

      // Get count
      final count = await dbService.getSnapshotCount(uid);
      expect(count, 1);

      // Insert second snapshot
      final snapshot2 = Snapshot(
        id: Uuid().v4(),
        fileId: uid,
        snapshotPath: '/snapshots/$uid/20260603_120500_doc.txt',
        timestamp: now.add(const Duration(minutes: 5)),
        fileSize: 2048,
        sha256Hash: 'xyz789',
        message: 'Updated',
      );
      await dbService.insertSnapshot(snapshot2);

      // Verify latest is now snap-002
      final latest2 = await dbService.getLatestSnapshot(uid);
      expect(latest2!.id, snapshot2.id);

      final count2 = await dbService.getSnapshotCount(uid);
      expect(count2, 2);

      // Delete one snapshot
      await dbService.deleteSnapshot(snapshot.id);
      final afterDelete = await dbService.getSnapshotById(snapshot.id);
      expect(afterDelete, isNull);
      final count3 = await dbService.getSnapshotCount(uid);
      expect(count3, 1);

      // Delete by file ID
      await dbService.deleteSnapshotsByFileId(uid);
      final count4 = await dbService.getSnapshotCount(uid);
      expect(count4, 0);

      // Cleanup
      await dbService.deleteTrackedFile(uid);
    });

    test('deleteTrackedFile cascades to snapshots', () async {
      final uid = Uuid().v4();
      final file = TrackedFile(
        id: uid,
        filePath: '/test/path/$uid/doc.txt',
        fileName: 'doc.txt',
        createdAt: DateTime.now(),
      );
      await dbService.insertTrackedFile(file);

      final snapshot = Snapshot(
        id: Uuid().v4(),
        fileId: uid,
        snapshotPath: '/snapshots/$uid/doc.txt',
        timestamp: DateTime.now(),
        fileSize: 100,
        sha256Hash: 'hash123',
        message: 'Test snapshot',
      );
      await dbService.insertSnapshot(snapshot);

      // Verify snapshot exists
      expect(await dbService.getSnapshotById(snapshot.id), isNotNull);

      // Delete tracked file should cascade
      await dbService.deleteTrackedFile(uid);

      // Verify snapshot is also deleted
      expect(await dbService.getSnapshotById(snapshot.id), isNull);
    });
  });
}
