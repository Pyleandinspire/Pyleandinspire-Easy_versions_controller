import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/services/git_service.dart';

final gitServiceProvider = Provider<GitService>((ref) {
  return GitService();
});
