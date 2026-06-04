import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/services/ai_service.dart';
import 'package:easy_versions_controller/services/diff_service.dart';
import 'package:easy_versions_controller/services/database_service.dart';

final aiCommitServiceProvider = Provider<AiCommitService>((ref) {
  return AiCommitService(ref);
});

/// 负责在自动保存时调用 AI 生成版本描述消息
class AiCommitService {
  final Ref _ref;

  AiCommitService(this._ref);

  /// 尝试为自动保存生成 AI 消息
  /// 返回 AI 生成的消息，如果无法生成则返回 null
  Future<String?> generateAutoSaveMessage({
    required String fileId,
    required String filePath,
    required String fileName,
  }) async {
    final aiService = _ref.read(aiServiceProvider);
    final dbService = _ref.read(databaseServiceProvider);

    // 获取最新快照
    final latestSnapshot = await dbService.getLatestSnapshot(fileId);
    if (latestSnapshot == null) {
      return null;
    }

    // 尝试读取 diff
    final snapshotFile = File(latestSnapshot.snapshotPath);
    final currentFile = File(filePath);

    if (!snapshotFile.existsSync() || !currentFile.existsSync()) {
      return null;
    }

    try {
      final oldContent = await snapshotFile.readAsString();
      final newContent = await currentFile.readAsString();

      final diffService = _ref.read(diffServiceProvider);
      final diffs = diffService.getDiffBetweenTexts(
        fromText: oldContent,
        toText: newContent,
      );

      // 只统计变更摘要
      final added = diffs.where((d) => d.type == DiffLineType.added).length;
      final removed = diffs.where((d) => d.type == DiffLineType.removed).length;
      final totalChanges = added + removed;

      if (totalChanges == 0) return null;

      // 构建简要的 diff 摘要发送给 AI
      final diffSummary = StringBuffer();
      diffSummary.writeln('文件: $fileName');
      diffSummary.writeln('变更: +$added 行 -$removed 行');

      if (totalChanges <= 20) {
        // 变更较少，发送完整 diff
        diffSummary.writeln('\n具体变更:');
        for (final d in diffs.where((d) => d.type != DiffLineType.same)) {
          final prefix = d.type == DiffLineType.added ? '+' : '-';
          diffSummary.writeln('$prefix ${d.content}');
        }
      }

      final message = await aiService.generateCommitMessage(diffSummary.toString());
      return message;
    } catch (_) {
      return null;
    }
  }
}