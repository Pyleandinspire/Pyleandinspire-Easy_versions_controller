import 'dart:async';
import 'dart:io';

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
    for (final root in _getRootDirectories()) {
      final result = await _scanDirectory(root, fileName);
      if (result != null) return result;
    }
    return null;
  }

  Future<String?> _scanDirectory(Directory dir, String fileName) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final entityFileName = entity.path.split(Platform.pathSeparator).last;
          if (entityFileName == fileName) {
            return entity.path;
          }
        } else if (entity is Directory) {
          final result = await _scanDirectory(entity, fileName);
          if (result != null) return result;
        }
      }
    } catch (_) {}
    return null;
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
