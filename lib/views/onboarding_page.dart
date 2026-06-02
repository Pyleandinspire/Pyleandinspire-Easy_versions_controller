import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';

final onboardingProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

class OnboardingService {
  static const String _hasShownOnboarding = 'has_shown_onboarding';

  Future<bool> hasShownOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasShownOnboarding) ?? false;
  }

  Future<void> markOnboardingShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownOnboarding, true);
  }

  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownOnboarding, false);
  }
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: '欢迎使用简控',
      description: '简单、智能的文件版本控制工具',
      icon: Icons.folder_open,
    ),
    OnboardingStep(
      title: '添加文件',
      description: '点击"+ 添加文件"按钮，选择要追踪的文件',
      icon: Icons.add_circle,
    ),
    OnboardingStep(
      title: '自动保存',
      description: '文件修改后自动保存，再也不用担心丢失',
      icon: Icons.save,
    ),
    OnboardingStep(
      title: '查看历史',
      description: '时间轴展示所有版本，随时查看和对比',
      icon: Icons.history,
    ),
    OnboardingStep(
      title: 'AI 辅助',
      description: '智能生成提交消息，AI 助手随时待命',
      icon: Icons.psychology,
    ),
    OnboardingStep(
      title: '开始使用',
      description: '点击下方按钮，开始您的版本控制之旅',
      icon: Icons.rocket_launch,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _completeOnboarding() async {
    final onboardingService = ref.read(onboardingProvider);
    await onboardingService.markOnboardingShown();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildPage(_steps[index]);
                },
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            step.icon,
            size: 120,
            color: AppColors.accent,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            step.title,
            style: AppTextStyles.heading1.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            step.description,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _steps.length,
              (index) => _buildPageIndicator(index),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              if (_currentPage < _steps.length - 1)
                TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    '跳过',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                ),
                child: Text(
                  _currentPage == _steps.length - 1 ? '开始使用' : '下一步',
                  style: AppTextStyles.button,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent : AppColors.textSecondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}