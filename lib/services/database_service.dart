import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';

class DatabaseService {
  static const String _dbName = 'easy_versions_controller.db';
  static const int _dbVersion = 1;
  static const String _tableTrackedFiles = 'tracked_files';

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
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableTrackedFiles (
        id TEXT PRIMARY KEY,
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        repoPath TEXT,
        addedAt TEXT NOT NULL,
        lastAccessedAt TEXT
      )
    ''');
  }

  Future<String> insertTrackedFile(TrackedFile file) async {
    final db = await database;
    await db.insert(_tableTrackedFiles, file.toMap());
    return file.id;
  }

  Future<List<TrackedFile>> getAllTrackedFiles() async {
    final db = await database;
    final maps = await db.query(
      _tableTrackedFiles,
      orderBy: 'addedAt DESC',
    );
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
    return await db.delete(
      _tableTrackedFiles,
      where: 'id = ?',
      whereArgs: [id],
    );
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
