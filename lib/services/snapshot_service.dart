import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:easy_versions_controller/models/snapshot.dart';
import 'package:easy_versions_controller/services/database_service.dart';

final snapshotServiceProvider = Provider<SnapshotService>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  return SnapshotService(dbService: dbService);
});

class SnapshotService {
  final DatabaseService _dbService;
  static const String _snapshotsRoot = 'snapshots';
  final Uuid _uuid = const Uuid();
  final String? _overrideRootPath;

  SnapshotService({
    required DatabaseService dbService,
    String? overrideRootPath,
  }) : _dbService = dbService,
       _overrideRootPath = overrideRootPath;

  Future<String> getSnapshotsRootPath() async {
    if (_overrideRootPath != null) {
      return p.join(_overrideRootPath!, _snapshotsRoot);
    }
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, _snapshotsRoot);
  }

  Future<String> initSnapshotDir(String fileId) async {
    final rootPath = await getSnapshotsRootPath();
    final dirPath = p.join(rootPath, fileId);

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    return dirPath;
  }

  Future<Snapshot> createInitialSnapshot({
    required String fileId,
    required String filePath,
    required String fileName,
  }) async {
    final snapshotDir = await initSnapshotDir(fileId);
    final now = DateTime.now();
    final timestamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(now);
    final snapshotName = '${timestamp}_${p.basename(fileName)}';
    final snapshotPath = p.join(snapshotDir, snapshotName);

    final sourceFile = File(filePath);
    if (!sourceFile.existsSync()) {
      throw Exception('源文件不存在: $filePath');
    }
    await sourceFile.copy(snapshotPath);

    final fileBytes = await sourceFile.readAsBytes();
    final fileSize = fileBytes.length;
    final hash = sha256.convert(fileBytes).toString();

    final snapshot = Snapshot(
      id: _uuid.v4(),
      fileId: fileId,
      snapshotPath: snapshotPath,
      timestamp: now,
      fileSize: fileSize,
      sha256Hash: hash,
      message: '初始版本',
    );

    await _dbService.insertSnapshot(snapshot);

    return snapshot;
  }

  Future<void> deleteSnapshotFiles(String fileId) async {
    final rootPath = await getSnapshotsRootPath();
    final dirPath = p.join(rootPath, fileId);
    final dir = Directory(dirPath);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// 回退到指定快照版本
  /// 回退前会先保存当前文件为新快照（防丢失），然后覆盖原文件
  Future<Snapshot> restoreSnapshot({
    required String fileId,
    required String filePath,
    required String fileName,
    required Snapshot snapshot,
  }) async {
    final targetFile = File(filePath);
    final snapshotFile = File(snapshot.snapshotPath);

    if (!snapshotFile.existsSync()) {
      throw Exception('快照文件不存在: ${snapshot.snapshotPath}');
    }

    // 1. 先保存当前文件为新快照（防丢失）
    if (targetFile.existsSync()) {
      final currentBytes = await targetFile.readAsBytes();
      final currentHash = sha256.convert(currentBytes).toString();

      // 如果当前内容和要回退的快照一样，跳过
      final latestSnapshot = await _dbService.getLatestSnapshot(fileId);
      if (latestSnapshot == null || latestSnapshot.sha256Hash != currentHash) {
        final snapshotDir = await initSnapshotDir(fileId);
        final now = DateTime.now();
        final preTimestamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(now);
        final preSnapshotName = '${preTimestamp}_${p.basename(fileName)}';
        final preSnapshotPath = p.join(snapshotDir, preSnapshotName);

        await targetFile.copy(preSnapshotPath);

        final preSnapshot = Snapshot(
          id: _uuid.v4(),
          fileId: fileId,
          snapshotPath: preSnapshotPath,
          timestamp: now,
          fileSize: currentBytes.length,
          sha256Hash: currentHash,
          message: '回退前自动保存',
        );

        await _dbService.insertSnapshot(preSnapshot);
      }
    }

    // 2. 复制快照内容覆盖原文件
    final snapshotBytes = await snapshotFile.readAsBytes();
    await targetFile.writeAsBytes(snapshotBytes);

    // 3. 创建回退快照记录
    final snapshotDir = await initSnapshotDir(fileId);
    final now = DateTime.now();
    final rollbackTimestamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(now);
    final rollbackName = '${rollbackTimestamp}_${p.basename(fileName)}';
    final rollbackPath = p.join(snapshotDir, rollbackName);

    await targetFile.copy(rollbackPath);

    final rollbackSnapshot = Snapshot(
      id: _uuid.v4(),
      fileId: fileId,
      snapshotPath: rollbackPath,
      timestamp: now,
      fileSize: snapshotBytes.length,
      sha256Hash: snapshot.sha256Hash,
      message: '回退到版本 ${DateFormat('MM-dd HH:mm').format(snapshot.timestamp)}',
    );

    await _dbService.insertSnapshot(rollbackSnapshot);

    return rollbackSnapshot;
  }

  Future<Snapshot?> createAutoSnapshot({
    required String fileId,
    required String filePath,
    required String fileName,
    String? message,
  }) async {
    final sourceFile = File(filePath);
    if (!sourceFile.existsSync()) {
      throw Exception('源文件不存在: $filePath');
    }

    final fileBytes = await sourceFile.readAsBytes();
    final fileSize = fileBytes.length;
    final hash = sha256.convert(fileBytes).toString();

    // 获取最新快照，对比哈希值
    final latestSnapshot = await _dbService.getLatestSnapshot(fileId);
    if (latestSnapshot != null && latestSnapshot.sha256Hash == hash) {
      // 内容无变化，跳过
      return null;
    }

    final snapshotDir = await initSnapshotDir(fileId);
    final now = DateTime.now();
    final timestamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(now);
    final snapshotName = '${timestamp}_${p.basename(fileName)}';
    final snapshotPath = p.join(snapshotDir, snapshotName);

    await sourceFile.copy(snapshotPath);

    final snapshot = Snapshot(
      id: _uuid.v4(),
      fileId: fileId,
      snapshotPath: snapshotPath,
      timestamp: now,
      fileSize: fileSize,
      sha256Hash: hash,
      message: message ?? '自动保存',
    );

    await _dbService.insertSnapshot(snapshot);

    return snapshot;
  }
}
