import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/models/snapshot.dart';
import 'package:easy_versions_controller/services/database_service.dart';

/// 加载指定文件的快照时间轴数据
final snapshotTimelineProvider =
    FutureProvider.family<List<Snapshot>, String>((ref, fileId) async {
  final dbService = ref.read(databaseServiceProvider);
  return dbService.getSnapshotsByFileId(fileId);
});