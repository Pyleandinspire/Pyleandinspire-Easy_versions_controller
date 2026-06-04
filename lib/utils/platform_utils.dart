import 'dart:io';

/// 跨平台用系统默认程序打开文件
Future<ProcessResult> openFileWithDefaultApp(String filePath) async {
  if (Platform.isMacOS) {
    return Process.run('open', [filePath]);
  } else if (Platform.isWindows) {
    return Process.run('start', ['""', filePath], runInShell: true);
  } else if (Platform.isLinux) {
    return Process.run('xdg-open', [filePath]);
  } else {
    throw UnsupportedError('不支持的操作系统');
  }
}