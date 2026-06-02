import 'package:flutter/material.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.xl),
            _buildContent(),
            const SizedBox(height: AppSpacing.xl),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.help_outline, size: 24, color: AppColors.accent),
        const SizedBox(width: AppSpacing.md),
        Text('使用说明', style: AppTextStyles.heading2),
      ],
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureSection(
            icon: Icons.add_circle_outline,
            title: '添加文件',
            description: '点击左侧面板的"添加文件"按钮，选择需要版本追踪的文件。系统会自动创建Git仓库并开始追踪该文件的版本变化。',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildFeatureSection(
            icon: Icons.list,
            title: '管理文件',
            description: '在左侧文件列表中可以查看所有已追踪的文件。点击文件可以查看其版本历史记录。',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildFeatureSection(
            icon: Icons.history,
            title: '查看历史',
            description: '选择文件后，右侧时间轴会显示该文件的所有版本记录。点击历史版本可以查看该版本的详细信息。',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildFeatureSection(
            icon: Icons.autorenew,
            title: '自动保存',
            description: '系统会自动监听文件变化，当文件被修改时自动保存新版本。您可以在设置中调整自动保存的时间间隔。',
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildFeatureSection(
            icon: Icons.settings,
            title: '自定义设置',
            description: '点击右上角设置图标，可以配置自动保存的时间间隔。设置为0表示关闭自动保存功能。',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading3),
              const SizedBox(height: AppSpacing.sm),
              Text(description, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}
