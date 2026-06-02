import 'dart:async';
import 'dart:io';
import 'package:watcher/watcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/viewmodels/git_provider.dart';
import 'package:easy_versions_controller/viewmodels/tracked_file_provider.dart';

class FileWatcherService {
  final Ref _ref;
  final Map<String, DirectoryWatcher> _watchers = {};
  Timer? _checkTimer;

  FileWatcherService(this._ref);

  Future<void> startWatching(TrackedFile file) async {
    if (_watchers.containsKey(file.id)) {
      return;
    }

    final fileDirectory = Directory(file.filePath).parent.path;
    final watcher = DirectoryWatcher(fileDirectory);

    watcher.events.listen((event) async {
      if (event.path == file.filePath && event.type != ChangeType.REMOVE) {
        await _handleFileChange(file);
      }
    });

    _watchers[file.id] = watcher;
  }

  void stopWatching(String fileId) {
    _watchers.remove(fileId);
  }

  void stopAllWatching() {
    _watchers.clear();
    _checkTimer?.cancel();
  }

  Future<void> _handleFileChange(TrackedFile file) async {
    try {
      final gitService = _ref.read(gitServiceProvider);
      
      await gitService.commitChanges(
        repoPath: file.repoPath ?? '',
        fileName: file.fileName,
        originalFilePath: file.filePath,
      );

      await _ref.read(trackedFileListProvider.notifier).updateLastAccessed(file.id);
    } catch (e) {
      print('Error auto-saving file ${file.fileName}: $e');
    }
  }

  void startPeriodicCheck(Duration interval) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(interval, (_) async {
      await _checkAllFiles();
    });
  }

  Future<void> _checkAllFiles() async {
    final filesAsync = _ref.read(trackedFileListProvider);
    if (filesAsync is AsyncData<List<TrackedFile>>) {
      for (final file in filesAsync.value) {
        if (File(file.filePath).existsSync()) {
          startWatching(file);
        }
      }
    }
  }
}
