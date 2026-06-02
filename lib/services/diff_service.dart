import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:git2dart/git2dart.dart';
import 'package:path/path.dart' as p;

final diffServiceProvider = Provider<DiffService>((ref) {
  return DiffService();
});

class DiffService {
  Future<List<DiffLine>> getDiffBetweenVersions({
    required String repoPath,
    required String fromOid,
    required String toOid,
    required String fileName,
  }) async {
    final repo = Repository.open(repoPath);
    
    try {
      final fromContent = await _getFileContent(repo, fromOid, fileName);
      final toContent = await _getFileContent(repo, toOid, fileName);
      
      repo.free();
      
      return _computeDiff(fromContent, toContent);
    } catch (e) {
      repo.free();
      rethrow;
    }
  }

  Future<List<DiffLine>> getDiffFromCommit({
    required String repoPath,
    required String commitOid,
    required String fileName,
  }) async {
    final repo = Repository.open(repoPath);
    
    try {
      final commit = Commit.lookup(repo: repo, oid: Oid.fromSHA(repo, commitOid));
      final toContent = await _getFileContent(repo, commitOid, fileName);
      
      List<String> fromContent;
      try {
        final parent = commit.parent(0);
        if (parent != null) {
          fromContent = await _getFileContent(repo, parent.oid.sha, fileName);
          parent.free();
        } else {
          fromContent = [];
        }
      } catch (_) {
        fromContent = [];
      }
      
      commit.free();
      repo.free();
      
      return _computeDiff(fromContent, toContent);
    } catch (e) {
      repo.free();
      rethrow;
    }
  }

  Future<List<String>> _getFileContent(Repository repo, String commitOid, String fileName) async {
    try {
      final commit = Commit.lookup(repo: repo, oid: Oid.fromSHA(repo, commitOid));
      final tree = commit.tree;
      
      final blobOid = _findBlobOid(tree, fileName);
      if (blobOid == null) {
        commit.free();
        tree.free();
        return [];
      }
      
      final blob = Blob.lookup(repo: repo, oid: blobOid);
      final content = blob.content as List<int>;
      final text = String.fromCharCodes(content);
      
      blob.free();
      tree.free();
      commit.free();
      
      return text.split('\n');
    } catch (_) {
      return [];
    }
  }

  Oid? _findBlobOid(Tree tree, String fileName) {
    final entries = tree.entries;
    for (final entry in entries) {
      if (entry.name == fileName) {
        return entry.oid;
      }
    }
    return null;
  }

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
