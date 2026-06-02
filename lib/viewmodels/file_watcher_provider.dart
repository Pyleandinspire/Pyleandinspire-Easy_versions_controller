import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/services/file_watcher_service.dart';

final fileWatcherServiceProvider = Provider<FileWatcherService>((ref) {
  final service = FileWatcherService(ref);
  
  ref.onDispose(() {
    service.stopAllWatching();
  });
  
  return service;
});
