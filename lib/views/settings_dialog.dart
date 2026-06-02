import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';

final settingsProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

class SettingsService {
  static const String _autoSaveIntervalKey = 'auto_save_interval';
  
  int _autoSaveInterval = 5;

  int get autoSaveInterval => _autoSaveInterval;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSaveInterval = prefs.getInt(_autoSaveIntervalKey) ?? 5;
  }

  Future<void> saveAutoSaveInterval(int minutes) async {
    _autoSaveInterval = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoSaveIntervalKey, minutes);
  }
}

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final textController = TextEditingController(text: settings.autoSaveInterval.toString());

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.xl),
            _buildAutoSaveIntervalSection(settings, textController),
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
        const Icon(Icons.settings, size: 24, color: AppColors.accent),
        const SizedBox(width: AppSpacing.md),
        Text('设置', style: AppTextStyles.heading2),
      ],
    );
  }

  Widget _buildAutoSaveIntervalSection(SettingsService settings, TextEditingController textController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自动保存间隔',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '设置文件自动保存的时间间隔（分钟）',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '输入分钟数',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (value) {
                  final intValue = int.tryParse(value) ?? 5;
                  if (intValue > 0) {
                    settings.saveAutoSaveInterval(intValue);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('分钟', style: AppTextStyles.bodySecondary),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '提示：设置为0表示关闭自动保存',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        const SizedBox(width: AppSpacing.sm),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
