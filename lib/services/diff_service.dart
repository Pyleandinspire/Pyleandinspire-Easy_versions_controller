import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final diffServiceProvider = Provider<DiffService>((ref) {
  return DiffService();
});

/// 纯 Dart 实现的文件差异对比服务
/// 使用 LCS (Longest Common Subsequence) 算法进行行级对比
class DiffService {
  /// 对比两个文本文件的内容差异
  Future<List<DiffLine>> getDiffBetweenFiles({
    required String fromFilePath,
    required String toFilePath,
  }) async {
    final fromFile = File(fromFilePath);
    final toFile = File(toFilePath);

    final fromContent = fromFile.existsSync()
        ? (await fromFile.readAsString()).split('\n')
        : <String>[];
    final toContent = toFile.existsSync()
        ? (await toFile.readAsString()).split('\n')
        : <String>[];

    return _computeDiff(fromContent, toContent);
  }

  /// 对比两个文本字符串的差异
  List<DiffLine> getDiffBetweenTexts({
    required String fromText,
    required String toText,
  }) {
    final fromLines = fromText.split('\n');
    final toLines = toText.split('\n');
    return _computeDiff(fromLines, toLines);
  }

  /// 计算两段文本的行级差异
  List<DiffLine> _computeDiff(List<String> oldLines, List<String> newLines) {
    final lines = <DiffLine>[];
    final oldLength = oldLines.length;
    final newLength = newLines.length;

    final lcs = _computeLCS(oldLines, newLines);

    int oldIdx = 0;
    int newIdx = 0;
    int lcsIdx = 0;

    while (oldIdx < oldLength || newIdx < newLength) {
      if (lcsIdx < lcs.length &&
          oldIdx < oldLength &&
          newIdx < newLength &&
          oldLines[oldIdx] == lcs[lcsIdx] &&
          newLines[newIdx] == lcs[lcsIdx]) {
        lines.add(DiffLine(
          content: oldLines[oldIdx],
          type: DiffLineType.same,
          oldLineNumber: oldIdx + 1,
          newLineNumber: newIdx + 1,
        ));
        oldIdx++;
        newIdx++;
        lcsIdx++;
      } else if (oldIdx < oldLength &&
          (lcsIdx >= lcs.length || oldLines[oldIdx] != lcs[lcsIdx])) {
        lines.add(DiffLine(
          content: oldLines[oldIdx],
          type: DiffLineType.removed,
          oldLineNumber: oldIdx + 1,
          newLineNumber: -1,
        ));
        oldIdx++;
      } else if (newIdx < newLength &&
          (lcsIdx >= lcs.length || newLines[newIdx] != lcs[lcsIdx])) {
        lines.add(DiffLine(
          content: newLines[newIdx],
          type: DiffLineType.added,
          oldLineNumber: -1,
          newLineNumber: newIdx + 1,
        ));
        newIdx++;
      }
    }

    return lines;
  }

  /// 计算最长公共子序列
  List<String> _computeLCS(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    final lcs = <String>[];
    int i = m, j = n;
    while (i > 0 && j > 0) {
      if (a[i - 1] == b[j - 1]) {
        lcs.insert(0, a[i - 1]);
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    return lcs;
  }
}

enum DiffLineType {
  added,
  removed,
  same,
  context,
}

class DiffLine {
  final String content;
  final DiffLineType type;
  final int oldLineNumber;
  final int newLineNumber;

  DiffLine({
    required this.content,
    required this.type,
    required this.oldLineNumber,
    required this.newLineNumber,
  });
}