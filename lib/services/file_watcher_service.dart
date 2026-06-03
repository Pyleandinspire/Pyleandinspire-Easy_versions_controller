import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watcher/watcher.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/views/settings_dialog.dart';
import 'package:easy_versions_controller/services/auto_save_timer_service.dart';
import 'package:easy_versions_controller/services/snapshot_service.dart';
import 'package:easy_versions_controller/viewmodels/auto_save_status_provider.dart';

final fileWatcherProvider = Provider<FileWatcherService>((ref) {
  return FileWatcherService(ref);
});

class FileWatcherService {
  final Ref _ref;
  final Map<String, DirectoryWatcher> _watchers = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, DateTime> _lastModified = {};
  final Map<String, Timer> _debounceTimers = {};

  FileWatcherService(this._ref);

  void startWatching(TrackedFile file) {
    if (_watchers.containsKey(file.id)) return;

    final directory = File(file.filePath).parent;
    final watcher = DirectoryWatcher(directory.path);

    final subscription = watcher.events.listen((event) {
      if (event.path == file.filePath) {
        _handleFileChange(file, event);
      }
    });

    _watchers[file.id] = watcher;
    _subscriptions[file.id] = subscription;
  }

  void stopWatching(String fileId) {
    final subscription = _subscriptions.remove(fileId);
    if (subscription != null) {
      subscription.cancel();
    }

    _watchers.remove(fileId);

    final timer = _debounceTimers.remove(fileId);
    if (timer != null) {
      timer.cancel();
    }

    _lastModified.remove(fileId);
  }

  void stopAllWatching() {
    _subscriptions.values.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();

    _watchers.clear();

    _debounceTimers.values.forEach((timer) => timer.cancel());
    _debounceTimers.clear();

    _lastModified.clear();
  }

  void _handleFileChange(TrackedFile file, WatchEvent event) {
    if (event.type == ChangeType.MODIFY) {
      final now = DateTime.now();
      final lastTime = _lastModified[file.id];

      if (lastTime != null && now.difference(lastTime).inSeconds < 1) {
        return;
      }

      _lastModified[file.id] = now;

      // 标记文件已修改，通知长计时器
      final autoSaveTimer = _ref.read(autoSaveTimerProvider);
      autoSaveTimer.markFileChanged(file);

      final existingTimer = _debounceTimers[file.id];
      if (existingTimer != null) {
        existingTimer.cancel();
      }

      final settings = _ref.read(settingsProvider);
      final delaySeconds = settings.autoSaveDelay;

      _debounceTimers[file.id] = Timer(Duration(seconds: delaySeconds), () {
        _triggerAutoSave(file);
      });
    }
  }

  Future<void> _triggerAutoSave(TrackedFile file) async {
    final statusNotifier = _ref.read(autoSaveStatusProvider.notifier);
    statusNotifier.markSaving();

    try {
      final snapshotService = _ref.read(snapshotServiceProvider);
      await snapshotService.createAutoSnapshot(
        fileId: file.id,
        filePath: file.filePath,
        fileName: file.fileName,
      );

      final autoSaveTimer = _ref.read(autoSaveTimerProvider);
      autoSaveTimer.markFileSaved(file);

      statusNotifier.markSaved();
    } catch (e) {
      print('Auto save failed: $e');
      statusNotifier.markFailed(e.toString());
    }
  }
}
