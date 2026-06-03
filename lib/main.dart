import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'utils/app_theme.dart';
import 'views/main_page.dart';
import 'viewmodels/file_watcher_provider.dart';
import 'viewmodels/tracked_file_provider.dart';
import 'views/settings_dialog.dart';
import 'models/tracked_file.dart';
import 'services/auto_save_timer_service.dart';
import 'views/onboarding_page.dart';

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

    // 启动自动保存长计时器
    ref.read(autoSaveTimerProvider).startForceSaveTimer();

    return MaterialApp(
      title: '简控',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const _AppEntryPoint(),
    );
  }
}

/// 应用入口：判断是否首次使用，决定显示 Onboarding 还是主页面
class _AppEntryPoint extends ConsumerStatefulWidget {
  const _AppEntryPoint();

  @override
  ConsumerState<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends ConsumerState<_AppEntryPoint> {
  bool? _hasShownOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final onboardingService = ref.read(onboardingProvider);
    final hasShown = await onboardingService.hasShownOnboarding();
    setState(() {
      _hasShownOnboarding = hasShown;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 还在加载中
    if (_hasShownOnboarding == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 首次使用，显示 Onboarding
    if (!_hasShownOnboarding!) {
      return OnboardingPage(
        onComplete: () {
          setState(() {
            _hasShownOnboarding = true;
          });
        },
      );
    }

    // 非首次使用，显示主页面
    return const MainPage();
  }
}
