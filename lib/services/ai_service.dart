import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:easy_versions_controller/views/settings_dialog.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(ref);
});

class AiService {
  final Ref _ref;

  AiService(this._ref);

  Future<String?> generateCommitMessage(String diff) async {
    final settings = _ref.read(settingsProvider);
    
    if (!settings.hasAiConfig) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(settings.aiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.aiApiKey}',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个代码提交消息生成助手。请根据提供的代码差异(diff)，生成一个简洁、清晰的git commit消息。消息应遵循常规的commit消息格式：简短的标题（不超过50个字符），然后是详细描述。',
            },
            {
              'role': 'user',
              'content': '根据以下代码差异生成commit消息：\n\n$diff',
            },
          ],
          'max_tokens': 100,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['choices'][0]['message']['content'] as String;
        return message.trim();
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> askQuestion(String question) async {
    final settings = _ref.read(settingsProvider);
    
    if (!settings.hasAiConfig) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(settings.aiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.aiApiKey}',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个Git助手，专门帮助用户解决Git相关问题。请提供清晰、有用的回答。',
            },
            {
              'role': 'user',
              'content': question,
            },
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['choices'][0]['message']['content'] as String;
        return answer.trim();
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> rewriteText(String text, String instruction) async {
    final settings = _ref.read(settingsProvider);
    
    if (!settings.hasAiConfig) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(settings.aiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.aiApiKey}',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个文本处理助手。根据用户的指示对文本进行处理。',
            },
            {
              'role': 'user',
              'content': '$instruction\n\n文本：$text',
            },
          ],
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['choices'][0]['message']['content'] as String;
        return result.trim();
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  String getDefaultCommitMessage() {
    return 'Update file';
  }
}
