import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/services/git_service.dart';
import 'package:easy_versions_controller/views/settings_dialog.dart';
import 'package:easy_versions_controller/viewmodels/tracked_file_provider.dart';

final autoSaveTimerProvider = Provider<AutoSaveTimerService>((ref) {
  return AutoSaveTimerService(ref);
});

class AutoSaveTimerService {
  final Ref _ref;
  Timer? _forceSaveTimer;
  final Map<String, DateTime> _lastSaveTime = {};
  final Map<String, bool> _hasChanges = {};

  AutoSaveTimerService(this._ref);

  void startForceSaveTimer() {
    stopForceSaveTimer();

    final settings = _ref.read(settingsProvider);
    final intervalMinutes = settings.autoSaveInterval;

    if (intervalMinutes <= 0) return;

    _forceSaveTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _checkAndSaveAll(),
    );
  }

  void stopForceSaveTimer() {
    _forceSaveTimer?.cancel();
    _forceSaveTimer = null;
  }

  void markFileChanged(TrackedFile file) {
    _hasChanges[file.id] = true;
  }

  void markFileSaved(TrackedFile file) {
    _hasChanges[file.id] = false;
    _lastSaveTime[file.id] = DateTime.now();
  }

  Future<void> _checkAndSaveAll() async {
    final trackedFiles = _ref.read(trackedFileListProvider);
    final files = trackedFiles.value ?? [];

    for (final file in files) {
      if (_hasChanges[file.id] == true) {
        await _triggerForceSave(file);
      }
    }
  }

  Future<void> _triggerForceSave(TrackedFile file) async {
    try {
      final gitService = GitService();
      await gitService.commitChanges(
        repoPath: file.repoPath ?? '',
        fileName: file.fileName,
        originalFilePath: file.filePath,
      );
      
      markFileSaved(file);
    } catch (e) {
      print('Force save failed: $e');
    }
  }

  void dispose() {
    stopForceSaveTimer();
  }
}