import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/services/file_picker_service.dart';

final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return FilePickerService();
});
