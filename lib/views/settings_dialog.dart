import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';

final settingsProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

class SettingsService {
  static const String _autoSaveIntervalKey = 'auto_save_interval';
  static const String _autoSaveDelayKey = 'auto_save_delay';
  static const String _aiApiKeyKey = 'ai_api_key';
  static const String _aiEndpointKey = 'ai_endpoint';
  
  int _autoSaveInterval = 5;
  int _autoSaveDelay = 10;
  String _aiApiKey = '';
  String _aiEndpoint = 'https://api.openai.com/v1/chat/completions';

  int get autoSaveInterval => _autoSaveInterval;
  int get autoSaveDelay => _autoSaveDelay;
  String get aiApiKey => _aiApiKey;
  String get aiEndpoint => _aiEndpoint;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSaveInterval = prefs.getInt(_autoSaveIntervalKey) ?? 5;
    _autoSaveDelay = prefs.getInt(_autoSaveDelayKey) ?? 10;
    _aiApiKey = prefs.getString(_aiApiKeyKey) ?? '';
    _aiEndpoint = prefs.getString(_aiEndpointKey) ?? 'https://api.openai.com/v1/chat/completions';
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
  bool apiKeyVisible = false;
  ConnectionStatus connectionStatus = ConnectionStatus.none;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    intervalController = TextEditingController(text: settings.autoSaveInterval.toString());
    delayController = TextEditingController(text: settings.autoSaveDelay.toString());
    apiKeyController = TextEditingController(text: settings.aiApiKey);
    endpointController = TextEditingController(text: settings.aiEndpoint);
  }

  @override
  void dispose() {
    intervalController.dispose();
    delayController.dispose();
    apiKeyController.dispose();
    endpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildAutoSaveSection(settings),
                    const SizedBox(height: AppSpacing.xl),
                    _buildAiConfigSection(settings),
                  ],
                ),
              ),
            ),
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

  Widget _buildAutoSaveSection(SettingsService settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自动保存设置',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: AppSpacing.md),
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自动保存间隔',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: intervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '分钟',
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
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '每隔指定分钟自动保存一次（0表示关闭）',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '延迟保存时间',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: delayController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '秒',
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
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '用户停止编辑后延迟保存',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiConfigSection(SettingsService settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI 配置',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: AppSpacing.md),
        
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Key',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
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
          ],
        ),
        
        const SizedBox(height: AppSpacing.md),
        
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Endpoint',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              '默认：https://api.openai.com/v1/chat/completions',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        
        const SizedBox(height: AppSpacing.md),
        
        Row(
          children: [
            ElevatedButton(
              onPressed: () async {
                setState(() => connectionStatus = ConnectionStatus.checking);
                
                await Future.delayed(const Duration(seconds: 2));
                
                setState(() {
                  connectionStatus = settings.hasAiConfig 
                      ? ConnectionStatus.success 
                      : ConnectionStatus.failed;
                });
              },
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
    );
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
