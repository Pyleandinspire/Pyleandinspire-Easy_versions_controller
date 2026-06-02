import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/services/file_scan_service.dart';

final fileScanServiceProvider = Provider<FileScanService>((ref) {
  return FileScanService();
});
