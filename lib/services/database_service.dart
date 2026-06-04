import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/models/snapshot.dart';

class DatabaseService {
  static const String _dbName = 'easy_versions_controller.db';
  static const int _dbVersion = 2;
  static const String _tableTrackedFiles = 'tracked_files';
  static const String _tableSnapshots = 'snapshots';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableTrackedFiles (
        id TEXT PRIMARY KEY,
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        snapshotDir TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tableSnapshots (
        id TEXT PRIMARY KEY,
        fileId TEXT NOT NULL,
        snapshotPath TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        fileSize INTEGER NOT NULL,
        sha256Hash TEXT,
        message TEXT,
        FOREIGN KEY (fileId) REFERENCES $_tableTrackedFiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_snapshots_fileId ON $_tableSnapshots(fileId)
    ''');
    await db.execute('''
      CREATE INDEX idx_snapshots_timestamp ON $_tableSnapshots(timestamp)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 迁移旧表：添加 snapshots 表，重命名 repoPath 为 snapshotDir
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableSnapshots (
          id TEXT PRIMARY KEY,
          fileId TEXT NOT NULL,
          snapshotPath TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          fileSize INTEGER NOT NULL,
          sha256Hash TEXT,
          message TEXT,
          FOREIGN KEY (fileId) REFERENCES $_tableTrackedFiles(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_snapshots_fileId ON $_tableSnapshots(fileId)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_snapshots_timestamp ON $_tableSnapshots(timestamp)
      ''');

      // 尝试重命名旧列（如果存在）
      try {
        await db.execute(
          'ALTER TABLE $_tableTrackedFiles RENAME COLUMN repoPath TO snapshotDir',
        );
      } catch (_) {
        // 旧列不存在或已重命名，忽略
      }
      try {
        await db.execute(
          'ALTER TABLE $_tableTrackedFiles RENAME COLUMN addedAt TO createdAt',
        );
      } catch (_) {
        // 忽略
      }
      try {
        await db.execute(
          'ALTER TABLE $_tableTrackedFiles RENAME COLUMN lastAccessedAt TO updatedAt',
        );
      } catch (_) {
        // 忽略
      }
    }
  }

  // ==================== tracked_files CRUD ====================

  Future<String> insertTrackedFile(TrackedFile file) async {
    final db = await database;
    await db.insert(_tableTrackedFiles, file.toMap());
    return file.id;
  }

  Future<List<TrackedFile>> getAllTrackedFiles() async {
    final db = await database;
    final maps = await db.query(_tableTrackedFiles, orderBy: 'createdAt DESC');
    return maps.map((map) => TrackedFile.fromMap(map)).toList();
  }

  Future<TrackedFile?> getTrackedFileById(String id) async {
    final db = await database;
    final maps = await db.query(
      _tableTrackedFiles,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TrackedFile.fromMap(maps.first);
  }

  Future<TrackedFile?> getTrackedFileByPath(String filePath) async {
    final db = await database;
    final maps = await db.query(
      _tableTrackedFiles,
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
    if (maps.isEmpty) return null;
    return TrackedFile.fromMap(maps.first);
  }

  Future<int> updateTrackedFile(TrackedFile file) async {
    final db = await database;
    return await db.update(
      _tableTrackedFiles,
      file.toMap(),
      where: 'id = ?',
      whereArgs: [file.id],
    );
  }

  Future<int> deleteTrackedFile(String id) async {
    final db = await database;
    // 先删除关联的快照记录
    await db.delete(_tableSnapshots, where: 'fileId = ?', whereArgs: [id]);
    // 再删除文件记录
    return await db.delete(
      _tableTrackedFiles,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== snapshots CRUD ====================

  Future<String> insertSnapshot(Snapshot snapshot) async {
    final db = await database;
    await db.insert(_tableSnapshots, snapshot.toMap());
    return snapshot.id;
  }

  Future<List<Snapshot>> getSnapshotsByFileId(String fileId) async {
    final db = await database;
    final maps = await db.query(
      _tableSnapshots,
      where: 'fileId = ?',
      whereArgs: [fileId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Snapshot.fromMap(map)).toList();
  }

  Future<Snapshot?> getLatestSnapshot(String fileId) async {
    final db = await database;
    final maps = await db.query(
      _tableSnapshots,
      where: 'fileId = ?',
      whereArgs: [fileId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Snapshot.fromMap(maps.first);
  }

  Future<Snapshot?> getSnapshotById(String id) async {
    final db = await database;
    final maps = await db.query(
      _tableSnapshots,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Snapshot.fromMap(maps.first);
  }

  Future<int> deleteSnapshot(String id) async {
    final db = await database;
    return await db.delete(_tableSnapshots, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSnapshotsByFileId(String fileId) async {
    final db = await database;
    return await db.delete(
      _tableSnapshots,
      where: 'fileId = ?',
      whereArgs: [fileId],
    );
  }

  Future<int> getSnapshotCount(String fileId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableSnapshots WHERE fileId = ?',
      [fileId],
    );
    return result.first['count'] as int;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
