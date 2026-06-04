import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/models/snapshot.dart';
import 'package:easy_versions_controller/services/database_service.dart';

/// 快照列表缓存，按 fileId 存储
final _snapshotCacheProvider =
    NotifierProvider<_SnapshotCacheNotifier, Map<String, List<Snapshot>>>(
      _SnapshotCacheNotifier.new,
    );

class _SnapshotCacheNotifier extends Notifier<Map<String, List<Snapshot>>> {
  @override
  Map<String, List<Snapshot>> build() {
    return {};
  }

  void update(String fileId, List<Snapshot> snapshots) {
    state = {...state, fileId: snapshots};
  }

  void remove(String fileId) {
    final newState = Map<String, List<Snapshot>>.from(state);
    newState.remove(fileId);
    state = newState;
  }

  void clear() {
    state = {};
  }
}

/// 加载指定文件的快照时间轴数据（带缓存）
final snapshotTimelineProvider = FutureProvider.family<List<Snapshot>, String>((
  ref,
  fileId,
) async {
  // 先检查缓存
  final cache = ref.read(_snapshotCacheProvider);
  if (cache.containsKey(fileId)) {
    return cache[fileId]!;
  }

  // 从数据库加载
  final dbService = ref.read(databaseServiceProvider);
  final snapshots = await dbService.getSnapshotsByFileId(fileId);

  // 更新缓存
  ref.read(_snapshotCacheProvider.notifier).update(fileId, snapshots);

  return snapshots;
});

/// 手动刷新指定文件的快照缓存
final refreshSnapshotCacheProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (fileId) async {
    final dbService = ref.read(databaseServiceProvider);
    final snapshots = await dbService.getSnapshotsByFileId(fileId);

    ref.read(_snapshotCacheProvider.notifier).update(fileId, snapshots);

    // 触发重新监听
    ref.invalidate(snapshotTimelineProvider(fileId));
  };
});

/// 清除指定文件的快照缓存
final clearSnapshotCacheProvider = Provider<void Function(String)>((ref) {
  return (fileId) {
    ref.read(_snapshotCacheProvider.notifier).remove(fileId);
  };
});

/// 清除所有快照缓存
final clearAllSnapshotCacheProvider = Provider<void Function()>((ref) {
  return () {
    ref.read(_snapshotCacheProvider.notifier).clear();
  };
});
