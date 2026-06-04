import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditorService {
  Future<void> writeFile(String filePath, String content) async {
    final file = File(filePath);
    await file.writeAsString(content);
  }

  Future<String> readFile(String filePath) async {
    final file = File(filePath);
    return file.readAsString();
  }
}

final editorProvider = Provider<EditorService>((ref) {
  return EditorService();
});