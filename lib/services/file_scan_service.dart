import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

class FileScanService {
  Future<String?> scanForFile({
    required String fileName,
    required Duration timeout,
  }) async {
    String? foundPath;

    final scanFuture = _scanDirectories(fileName);

    try {
      foundPath = await scanFuture.timeout(timeout);
    } on TimeoutException {
      foundPath = null;
    }

    return foundPath;
  }

  Future<String?> _scanDirectories(String fileName) async {
    // 第一步：扫描常见目录（桌面、文档、下载）
    final commonDirs = await _getCommonDirectories();
    for (final dir in commonDirs) {
      final result = await _scanDirectory(dir, fileName, shallowOnly: false);
      if (result != null) return result;
    }

    // 第二步：扩展到根目录扫描
    for (final root in _getRootDirectories()) {
      // 跳过已经扫描过的常见目录
      final rootPath = root.absolute.path;
      final alreadyScanned = commonDirs.any((d) => d.absolute.path.startsWith(p.normalize(rootPath)));
      if (!alreadyScanned) {
        final result = await _scanDirectory(root, fileName, shallowOnly: true);
        if (result != null) return result;
      }
    }
    return null;
  }

  Future<List<Directory>> _getCommonDirectories() async {
    final dirs = <Directory>[];
    final homePath = _getHomeDir();

    // Windows 常见目录
    if (Platform.isWindows) {
      final desktop = Directory(p.join(homePath, 'Desktop'));
      final documents = Directory(p.join(homePath, 'Documents'));
      final downloads = Directory(p.join(homePath, 'Downloads'));
      if (desktop.existsSync()) dirs.add(desktop);
      if (documents.existsSync()) dirs.add(documents);
      if (downloads.existsSync()) dirs.add(downloads);
    }

    // macOS 常见目录
    if (Platform.isMacOS || Platform.isLinux) {
      final desktop = Directory(p.join(homePath, 'Desktop'));
      final documents = Directory(p.join(homePath, 'Documents'));
      final downloads = Directory(p.join(homePath, 'Downloads'));
      if (desktop.existsSync()) dirs.add(desktop);
      if (documents.existsSync()) dirs.add(documents);
      if (downloads.existsSync()) dirs.add(downloads);
    }

    return dirs;
  }

  Future<String?> _scanDirectory(Directory dir, String fileName, {bool shallowOnly = false}) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final entityFileName = p.basename(entity.path);
          if (entityFileName == fileName) {
            return entity.path;
          }
        } else if (entity is Directory && !shallowOnly) {
          final result = await _scanDirectory(entity, fileName);
          if (result != null) return result;
        }
      }
    } catch (_) {}
    return null;
  }

  String _getHomeDir() {
    if (Platform.isWindows) {
      return 'C:\\Users\\${Platform.environment['USERNAME'] ?? ''}';
    }
    final home = Platform.environment['HOME'] ?? '/';
    return home;
  }

  List<Directory> _getRootDirectories() {
    if (Platform.isMacOS) {
      return [Directory('/Users')];
    } else if (Platform.isLinux) {
      return [Directory('/home')];
    } else if (Platform.isWindows) {
      return [Directory('C:\\Users')];
    }
    return [Directory.current];
  }

  bool fileExists(String filePath) {
    return File(filePath).existsSync();
  }
}