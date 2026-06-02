import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:git2dart/git2dart.dart';
import 'package:path_provider/path_provider.dart';

class GitService {
  static const String _repoBaseDir = 'easy_versions_repos';

  Future<String> getRepoBasePath() async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, _repoBaseDir);
  }

  Future<String> initRepoForFile({
    required String filePath,
    required String fileId,
  }) async {
    final basePath = await getRepoBasePath();
    final repoPath = p.join(basePath, fileId);

    final repoDir = Directory(repoPath);
    if (!repoDir.existsSync()) {
      repoDir.createSync(recursive: true);
    }

    final repo = Repository.init(path: repoPath);

    final fileName = p.basename(filePath);
    final destPath = p.join(repoPath, fileName);
    await File(filePath).copy(destPath);

    final index = repo.index;
    index.add(fileName);
    index.write();

    final treeOid = index.writeTree();
    final tree = Tree.lookup(repo: repo, oid: treeOid);
    index.free();

    final signature = Signature.create(
      name: '简控',
      email: 'easy_versions_controller@local',
    );

    Commit.create(
      repo: repo,
      updateRef: 'HEAD',
      message: '初始版本: $fileName',
      author: signature,
      committer: signature,
      tree: tree,
      parents: [],
    );

    signature.free();
    tree.free();
    repo.free();

    return repoPath;
  }

  Future<String> commitFileChange({
    required String repoPath,
    required String filePath,
    required String message,
  }) async {
    final repo = Repository.open(repoPath);

    final fileName = p.basename(filePath);
    final destPath = p.join(repoPath, fileName);
    await File(filePath).copy(destPath);

    final index = repo.index;
    index.add(fileName);
    index.write();

    final treeOid = index.writeTree();
    final tree = Tree.lookup(repo: repo, oid: treeOid);
    index.free();

    final head = repo.head;
    final parentCommit = Commit.lookup(repo: repo, oid: head.target);
    head.free();

    final signature = Signature.create(
      name: '简控',
      email: 'easy_versions_controller@local',
    );

    final commitOid = Commit.create(
      repo: repo,
      updateRef: 'HEAD',
      message: message,
      author: signature,
      committer: signature,
      tree: tree,
      parents: [parentCommit],
    );

    signature.free();
    parentCommit.free();
    tree.free();
    repo.free();

    return commitOid.sha;
  }

  Future<List<Map<String, dynamic>>> getCommitHistory({
    required String repoPath,
    int maxCount = 50,
  }) async {
    final repo = Repository.open(repoPath);
    final commits = <Map<String, dynamic>>[];

    try {
      final walker = RevWalk(repo);
      walker.sorting({GitSort.time});
      walker.pushHead();

      final walkCommits = walker.walk(limit: maxCount);
      for (final commit in walkCommits) {
        commits.add({
          'oid': commit.oid.sha,
          'message': commit.message,
          'author': commit.author.name,
          'time': commit.time,
        });
        commit.free();
      }
      walker.free();
    } catch (_) {}

    repo.free();
    return commits;
  }

  Future<String> getFileContentAtCommit({
    required String repoPath,
    required String commitSha,
    required String fileName,
  }) async {
    final repo = Repository.open(repoPath);
    final oid = Oid.fromSHA(repo, commitSha);
    final commit = Commit.lookup(repo: repo, oid: oid);
    final tree = commit.tree;

    final entry = tree[fileName];
    final blob = Blob.lookup(repo: repo, oid: entry.oid);

    final content = blob.content;

    blob.free();
    entry.free();
    tree.free();
    commit.free();
    repo.free();

    return content;
  }

  Future<bool> hasChanges({
    required String repoPath,
    required String filePath,
  }) async {
    final repo = Repository.open(repoPath);
    final fileName = p.basename(filePath);
    final destPath = p.join(repoPath, fileName);

    await File(filePath).copy(destPath);

    final status = repo.statusFile(fileName);
    final hasModified = status.any((s) => s != GitStatus.current);

    repo.free();
    return hasModified;
  }

  Future<void> restoreFileFromCommit({
    required String repoPath,
    required String commitSha,
    required String fileName,
    required String targetFilePath,
  }) async {
    final content = await getFileContentAtCommit(
      repoPath: repoPath,
      commitSha: commitSha,
      fileName: fileName,
    );

    final file = File(targetFilePath);
    await file.writeAsString(content);
  }

  Future<String> commitChanges({
    required String repoPath,
    required String fileName,
    required String originalFilePath,
  }) async {
    final repo = Repository.open(repoPath);

    final destPath = p.join(repoPath, fileName);
    await File(originalFilePath).copy(destPath);

    final index = repo.index;
    index.add(fileName);
    index.write();

    final treeOid = index.writeTree();
    final tree = Tree.lookup(repo: repo, oid: treeOid);
    index.free();

    final head = repo.head;
    final parentCommit = Commit.lookup(repo: repo, oid: head.target);
    head.free();

    final signature = Signature.create(
      name: '简控',
      email: 'easy_versions_controller@local',
    );

    final now = DateTime.now();
    final timeStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final commitOid = Commit.create(
      repo: repo,
      updateRef: 'HEAD',
      message: '自动保存: $timeStr',
      author: signature,
      committer: signature,
      tree: tree,
      parents: [parentCommit],
    );

    signature.free();
    parentCommit.free();
    tree.free();
    repo.free();

    return commitOid.sha;
  }
}
