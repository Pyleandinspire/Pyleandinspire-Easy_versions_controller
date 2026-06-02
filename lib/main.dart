import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'utils/app_theme.dart';
import 'views/main_page.dart';
import 'viewmodels/file_watcher_provider.dart';
import 'viewmodels/tracked_file_provider.dart';
import 'views/settings_dialog.dart';
import 'models/tracked_file.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: '简控',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(trackedFileListProvider, (_, state) {
      if (state is AsyncData<List<TrackedFile>>) {
        final files = state.value;
        if (files != null) {
          final watcherService = ref.read(fileWatcherServiceProvider);
          for (final file in files) {
            watcherService.startWatching(file);
          }
        }
      }
    });

    ref.read(settingsProvider).loadSettings();

    return MaterialApp(
      title: '简控',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const MainPage(),
    );
  }
}
