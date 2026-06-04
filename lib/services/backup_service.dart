import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

class BackupService {
  static const String _dbName = 'easy_versions.db';
  static const String _snapshotsDir = 'snapshots';
  static const String _backupDbName = 'easy_versions.db';
  static const String _backupSnapshotsName = 'snapshots';
  static const String _backupSettingsName = 'settings.json';

  /// 导出数据为 ZIP 文件
  Future<String?> exportData() async {
    // 选择保存位置
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '选择备份文件保存位置',
      fileName: 'easy_versions_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null) return null;

    final encoder = ZipFileEncoder();
    encoder.create(outputPath);

    try {
      // 1. 添加数据库文件
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, _dbName));
      if (await dbFile.exists()) {
        final dbBytes = await dbFile.readAsBytes();
        encoder.addArchiveFile(
          ArchiveFile(_backupDbName, dbBytes.length, dbBytes),
        );
      }

      // 2. 添加快照文件
      final appDir = await getApplicationSupportDirectory();
      final snapshotsDir = Directory(p.join(appDir.path, _snapshotsDir));
      if (await snapshotsDir.exists()) {
        await _addDirectoryToZip(encoder, snapshotsDir, _backupSnapshotsName);
      }

      // 3. 添加配置文件
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = {
        'auto_save_interval': prefs.getInt('auto_save_interval') ?? 5,
        'auto_save_delay': prefs.getInt('auto_save_delay') ?? 10,
        'ai_api_key': prefs.getString('ai_api_key') ?? '',
        'ai_endpoint': prefs.getString('ai_endpoint') ?? '',
        'ai_model': prefs.getString('ai_model') ?? '',
      };
      final settingsBytes = settingsJson.toString().codeUnits;
      encoder.addArchiveFile(
        ArchiveFile(_backupSettingsName, settingsBytes.length, settingsBytes),
      );

      encoder.close();
      return outputPath;
    } catch (e) {
      encoder.close();
      // 删除不完整的文件
      try {
        await File(outputPath).delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// 递归添加目录到 ZIP
  Future<void> _addDirectoryToZip(
    ZipFileEncoder encoder,
    Directory dir,
    String baseName,
  ) async {
    final entities = dir.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: dir.path);
        final archivePath = p.join(baseName, relativePath).replaceAll('\\', '/');
        final bytes = await entity.readAsBytes();
        encoder.addArchiveFile(
          ArchiveFile(archivePath, bytes.length, bytes),
        );
      }
    }
  }

  /// 导入数据并提示冲突
  Future<ImportResult> importData({
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('正在选择备份文件...');

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.cancelled();
    }

    final zipPath = result.files.single.path;
    if (zipPath == null) {
      return ImportResult.error('无法获取文件路径');
    }

    onProgress?.call('正在解压备份文件...');

    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeStream(inputStream);
    inputStream.close();

    if (archive.files.isEmpty) {
      return ImportResult.error('备份文件为空');
    }

    // 临时目录解压
    final tempDir = Directory.systemTemp.createTempSync('evc_import_');
    try {
      onProgress?.call('正在提取文件...');
      for (final file in archive.files) {
        if (file.isFile) {
          final outputPath = p.join(tempDir.path, file.name);
          final outFile = File(outputPath);
          await outFile.parent.create(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        }
      }

      // 验证备份内容
      final hasDb = File(p.join(tempDir.path, _backupDbName)).existsSync();
      final hasSnapshots = Directory(p.join(tempDir.path, _backupSnapshotsName)).existsSync();

      if (!hasDb && !hasSnapshots) {
        return ImportResult.error('备份文件未包含有效数据');
      }

      onProgress?.call('正在恢复数据...');

      // 恢复数据库
      if (hasDb) {
        final dbPath = await getDatabasesPath();
        final targetDbPath = p.join(dbPath, _dbName);
        final sourceDbFile = File(p.join(tempDir.path, _backupDbName));
        await sourceDbFile.copy(targetDbPath);
      }

      // 恢复快照
      if (hasSnapshots) {
        final appDir = await getApplicationSupportDirectory();
        final targetSnapshotsDir = p.join(appDir.path, _snapshotsDir);
        final sourceSnapshotsDir = Directory(p.join(tempDir.path, _backupSnapshotsName));
        await _copyDirectory(sourceSnapshotsDir, Directory(targetSnapshotsDir));
      }

      // 恢复设置
      final settingsFile = File(p.join(tempDir.path, _backupSettingsName));
      if (await settingsFile.exists()) {
        final settingsJson = await settingsFile.readAsString();
        // 设置导入后需要重启应用生效（或手动加载）
        // 这里简单不处理，避免覆盖用户当前设置
      }

      onProgress?.call('导入完成');
      return ImportResult.success('数据导入成功');
    } finally {
      // 清理临时目录
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// 递归复制目录
  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }
}

class ImportResult {
  final bool success;
  final bool cancelled;
  final String? message;
  final String? error;

  ImportResult._({
    required this.success,
    this.cancelled = false,
    this.message,
    this.error,
  });

  factory ImportResult.success(String message) => ImportResult._(
        success: true,
        message: message,
      );

  factory ImportResult.error(String error) => ImportResult._(
        success: false,
        error: error,
      );

  factory ImportResult.cancelled() => ImportResult._(
        success: false,
        cancelled: true,
      );
}