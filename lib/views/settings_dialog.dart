import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/services/ai_service.dart';

final settingsProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

class SettingsService {
  static const String _autoSaveIntervalKey = 'auto_save_interval';
  static const String _autoSaveDelayKey = 'auto_save_delay';
  static const String _aiApiKeyKey = 'ai_api_key';
  static const String _aiEndpointKey = 'ai_endpoint';
  static const String _aiModelKey = 'ai_model';
  
  int _autoSaveInterval = 5;
  int _autoSaveDelay = 10;
  String _aiApiKey = '';
  String _aiEndpoint = 'https://api.openai.com/v1/chat/completions';
  String _aiModel = 'gpt-3.5-turbo';

  int get autoSaveInterval => _autoSaveInterval;
  int get autoSaveDelay => _autoSaveDelay;
  String get aiApiKey => _aiApiKey;
  String get aiEndpoint => _aiEndpoint;
  String get aiModel => _aiModel;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSaveInterval = prefs.getInt(_autoSaveIntervalKey) ?? 5;
    _autoSaveDelay = prefs.getInt(_autoSaveDelayKey) ?? 10;
    _aiApiKey = prefs.getString(_aiApiKeyKey) ?? '';
    _aiEndpoint = prefs.getString(_aiEndpointKey) ?? 'https://api.openai.com/v1/chat/completions';
    _aiModel = prefs.getString(_aiModelKey) ?? 'gpt-3.5-turbo';
  }

  Future<void> saveAutoSaveInterval(int minutes) async {
    _autoSaveInterval = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoSaveIntervalKey, minutes);
  }

  Future<void> saveAutoSaveDelay(int seconds) async {
    _autoSaveDelay = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoSaveDelayKey, seconds);
  }

  Future<void> saveAiApiKey(String apiKey) async {
    _aiApiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiApiKeyKey, apiKey);
  }

  Future<void> saveAiEndpoint(String endpoint) async {
    _aiEndpoint = endpoint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiEndpointKey, endpoint);
  }

  Future<void> saveAiModel(String model) async {
    _aiModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiModelKey, model);
  }

  bool get hasAiConfig => _aiApiKey.isNotEmpty && _aiEndpoint.isNotEmpty;
}

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late TextEditingController intervalController;
  late TextEditingController delayController;
  late TextEditingController apiKeyController;
  late TextEditingController endpointController;
  late TextEditingController modelController;
  bool apiKeyVisible = false;
  ConnectionStatus connectionStatus = ConnectionStatus.none;
  int _selectedCategory = 0; // 0: 通用, 1: 自动保存, 2: AI配置

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    intervalController = TextEditingController(text: settings.autoSaveInterval.toString());
    delayController = TextEditingController(text: settings.autoSaveDelay.toString());
    apiKeyController = TextEditingController(text: settings.aiApiKey);
    endpointController = TextEditingController(text: settings.aiEndpoint);
    modelController = TextEditingController(text: settings.aiModel);
  }

  @override
  void dispose() {
    intervalController.dispose();
    delayController.dispose();
    apiKeyController.dispose();
    endpointController.dispose();
    modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Container(
        width: 650,
        height: 480,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSideNav(),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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

  Widget _buildSideNav() {
    final categories = [
      ('通用', Icons.tune),
      ('自动保存', Icons.save),
      ('AI 配置', Icons.psychology),
    ];

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: List.generate(categories.length, (index) {
          final (label, icon) = categories[index];
          final isSelected = _selectedCategory == index;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = index),
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: isSelected ? AppColors.accent : AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        color: isSelected ? AppColors.accent : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedCategory) {
      case 0:
        return _buildGeneralSection();
      case 1:
        return _buildAutoSaveSection(ref.read(settingsProvider));
      case 2:
        return _buildAiConfigSection(ref.read(settingsProvider));
      default:
        return const SizedBox();
    }
  }

  Widget _buildGeneralSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('通用设置', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.lg),
          _buildSettingItem(
            label: '应用名称',
            child: Text('简控 - Easy Versions Controller', style: AppTextStyles.bodySecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSettingItem(
            label: '数据存储位置',
            child: Text('应用安装目录/easy_versions_repos', style: AppTextStyles.bodySecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSettingItem(
            label: '版本',
            child: Text('0.1.0', style: AppTextStyles.bodySecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('关于', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.md),
          Text(
            '简控是一款简单、智能的文件版本控制工具。\n通过内置Git功能，让版本控制变得简单易用。',
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }

  Widget _buildAutoSaveSection(SettingsService settings) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('自动保存设置', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.lg),
          
          _buildSettingItem(
            label: '延迟保存时间',
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: delayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '10',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) {
                      final intValue = int.tryParse(value) ?? 10;
                      if (intValue >= 0) {
                        settings.saveAutoSaveDelay(intValue);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('秒', style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '用户停止编辑后延迟指定秒数自动保存',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          _buildSettingItem(
            label: '强制保存间隔',
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: intervalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '5',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) {
                      final intValue = int.tryParse(value) ?? 5;
                      if (intValue >= 0) {
                        settings.saveAutoSaveInterval(intValue);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('分钟', style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '每隔指定分钟检查并保存一次（0表示关闭）',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAiConfigSection(SettingsService settings) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 配置', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.lg),
          
          _buildSettingItem(
            label: 'API Key',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: apiKeyController,
                    obscureText: !apiKeyVisible,
                    decoration: const InputDecoration(
                      hintText: '输入 API Key',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) {
                      settings.saveAiApiKey(value);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: Icon(
                    apiKeyVisible ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => apiKeyVisible = !apiKeyVisible);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          _buildSettingItem(
            label: 'API Endpoint',
            child: TextField(
              controller: endpointController,
              decoration: const InputDecoration(
                hintText: '输入 API 地址',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (value) {
                settings.saveAiEndpoint(value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '默认：https://api.openai.com/v1/chat/completions',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          _buildSettingItem(
            label: '模型名称',
            child: TextField(
              controller: modelController,
              decoration: const InputDecoration(
                hintText: 'gpt-3.5-turbo',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (value) {
                settings.saveAiModel(value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '默认：gpt-3.5-turbo，支持自定义模型',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _testConnection(settings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: const Text('测试连接'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildConnectionStatus(connectionStatus),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection(SettingsService settings) async {
    if (!settings.hasAiConfig) {
      setState(() => connectionStatus = ConnectionStatus.failed);
      return;
    }

    setState(() => connectionStatus = ConnectionStatus.checking);

    try {
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.askQuestion('Hello, are you available?');

      setState(() {
        connectionStatus = result != null
            ? ConnectionStatus.success
            : ConnectionStatus.failed;
      });
    } catch (e) {
      setState(() => connectionStatus = ConnectionStatus.failed);
    }
  }

  Widget _buildConnectionStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.none:
        return const SizedBox();
      case ConnectionStatus.checking:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ConnectionStatus.success:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: 4),
            Text('连接成功', style: AppTextStyles.caption.copyWith(color: AppColors.success)),
          ],
        );
      case ConnectionStatus.failed:
        return Row(
          children: [
            const Icon(Icons.error, color: AppColors.error, size: 20),
            const SizedBox(width: 4),
            Text('连接失败', style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ],
        );
    }
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

enum ConnectionStatus {
  none,
  checking,
  success,
  failed,
}
