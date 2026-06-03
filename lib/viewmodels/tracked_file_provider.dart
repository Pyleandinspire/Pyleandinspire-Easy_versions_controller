import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/services/database_service.dart';
import 'package:easy_versions_controller/services/snapshot_service.dart';
import 'package:easy_versions_controller/viewmodels/file_picker_provider.dart';
import 'package:easy_versions_controller/viewmodels/file_scan_provider.dart';

final trackedFileListProvider =
    AsyncNotifierProvider<TrackedFileListNotifier, List<TrackedFile>>(
      TrackedFileListNotifier.new,
    );

class TrackedFileListNotifier extends AsyncNotifier<List<TrackedFile>> {
  final Uuid _uuid = const Uuid();

  @override
  Future<List<TrackedFile>> build() async {
    final dbService = ref.read(databaseServiceProvider);
    return dbService.getAllTrackedFiles();
  }

  Future<void> addFiles() async {
    final pickerService = ref.read(filePickerServiceProvider);
    final dbService = ref.read(databaseServiceProvider);
    final snapshotService = ref.read(snapshotServiceProvider);

    final paths = await pickerService.pickFiles();
    if (paths.isEmpty) return;

    for (final filePath in paths) {
      final existing = await dbService.getTrackedFileByPath(filePath);
      if (existing != null) continue;

      final fileId = _uuid.v4();
      final fileName = filePath.split('/').last;

      final trackedFile = TrackedFile(
        id: fileId,
        filePath: filePath,
        fileName: fileName,
        createdAt: DateTime.now(),
      );

      await dbService.insertTrackedFile(trackedFile);

      // 创建初始快照
      await snapshotService.createInitialSnapshot(
        fileId: fileId,
        filePath: filePath,
        fileName: fileName,
      );
    }

    state = AsyncData(await dbService.getAllTrackedFiles());
  }

  Future<void> removeFile(String fileId, {bool deleteSnapshots = false}) async {
    final dbService = ref.read(databaseServiceProvider);
    if (deleteSnapshots) {
      final snapshotService = ref.read(snapshotServiceProvider);
      await snapshotService.deleteSnapshotFiles(fileId);
    }
    await dbService.deleteTrackedFile(fileId);
    state = AsyncData(await dbService.getAllTrackedFiles());
  }

  Future<void> updateLastAccessed(String fileId) async {
    final dbService = ref.read(databaseServiceProvider);
    final file = await dbService.getTrackedFileById(fileId);
    if (file != null) {
      final updated = file.copyWith(updatedAt: DateTime.now());
      await dbService.updateTrackedFile(updated);
      state = AsyncData(await dbService.getAllTrackedFiles());
    }
  }

  bool checkFileExists(TrackedFile file) {
    return File(file.filePath).existsSync();
  }

  Future<String?> scanForFile(String fileName) async {
    final scanService = ref.read(fileScanServiceProvider);
    return scanService.scanForFile(
      fileName: fileName,
      timeout: const Duration(minutes: 5),
    );
  }

  Future<void> updateFilePath(String fileId, String newPath) async {
    final dbService = ref.read(databaseServiceProvider);
    final file = await dbService.getTrackedFileById(fileId);
    if (file != null) {
      final updated = file.copyWith(
        filePath: newPath,
        fileName: newPath.split('/').last,
        updatedAt: DateTime.now(),
      );
      await dbService.updateTrackedFile(updated);
      state = AsyncData(await dbService.getAllTrackedFiles());
    }
  }

  List<TrackedFile> getMissingFiles(List<TrackedFile> files) {
    return files.where((f) => !File(f.filePath).existsSync()).toList();
  }
}
