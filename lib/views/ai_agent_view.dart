import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/services/ai_service.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';

final aiAgentProvider = Provider<AiAgentService>((ref) {
  return AiAgentService(ref);
});

class AiAgentService {
  final Ref _ref;

  AiAgentService(this._ref);

  Future<String?> askQuestion(String question, {TrackedFile? file}) async {
    final aiService = _ref.read(aiServiceProvider);
    return aiService.askQuestion(question);
  }

  Future<String?> explainCode(String code) async {
    final aiService = _ref.read(aiServiceProvider);
    return aiService.rewriteText(code, '请解释这段代码的功能和实现逻辑：');
  }

  Future<String?> suggestOptimization(String code) async {
    final aiService = _ref.read(aiServiceProvider);
    return aiService.rewriteText(code, '请优化这段代码并说明优化理由：');
  }

  List<FAQItem> get faqItems => [
        FAQItem(
          question: '如何恢复到之前的版本？',
          category: '版本恢复',
        ),
        FAQItem(
          question: '如何比较两个版本的差异？',
          category: '版本对比',
        ),
        FAQItem(
          question: '自动保存是如何工作的？',
          category: '自动保存',
        ),
        FAQItem(
          question: '如何删除不需要的版本？',
          category: '版本管理',
        ),
        FAQItem(
          question: '如何导出版本历史？',
          category: '数据导出',
        ),
        FAQItem(
          question: '支持哪些文件类型？',
          category: '文件支持',
        ),
      ];
}

class FAQItem {
  final String question;
  final String category;

  FAQItem({
    required this.question,
    required this.category,
  });
}

class AiAgentView extends ConsumerStatefulWidget {
  final TrackedFile? file;

  const AiAgentView({
    super.key,
    this.file,
  });

  @override
  ConsumerState<AiAgentView> createState() => _AiAgentViewState();
}

class _AiAgentViewState extends ConsumerState<AiAgentView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isTyping) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final aiAgent = ref.read(aiAgentProvider);
      final response = await aiAgent.askQuestion(message, file: widget.file);

      setState(() {
        _messages.add(ChatMessage(
          text: response ?? '抱歉，我无法回答这个问题。请检查 AI 配置。',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    } catch (_) {
      setState(() {
        _messages.add(ChatMessage(
          text: '抱歉，发生了错误。请稍后重试。',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleFaqTap(String question) {
    _messageController.text = question;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 24, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md),
            Text('AI 助手', style: AppTextStyles.heading2),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildChatArea(),
          ),
          _buildQuickQuestions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _messages.length + (_isTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isTyping && index == _messages.length) {
            return _buildTypingIndicator();
          }
          return _buildMessage(_messages[index]);
        },
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.accent : AppColors.secondary,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: message.isUser 
                  ? AppTextStyles.body.copyWith(color: Colors.white)
                  : AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatTime(message.timestamp),
              style: AppTextStyles.caption.copyWith(
                color: message.isUser ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('正在思考...', style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQuestions() {
    final aiAgent = ref.read(aiAgentProvider);
    final faqItems = aiAgent.faqItems;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('快速提问', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: faqItems.map((item) {
              return ElevatedButton(
                onPressed: () => _handleFaqTap(item.question),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(item.question),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: '输入问题...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
