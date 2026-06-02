import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/services/ai_service.dart';
import 'package:easy_versions_controller/services/git_service.dart';

final commitDialogProvider = Provider<CommitDialog>((ref) {
  return CommitDialog(ref);
});

class CommitDialog {
  final Ref _ref;

  CommitDialog(this._ref);

  Future<bool?> show({
    required BuildContext context,
    required String repoPath,
    required String diff,
    required String fileName,
  }) async {
    final aiService = _ref.read(aiServiceProvider);
    String? aiMessage;
    
    try {
      aiMessage = await aiService.generateCommitMessage(diff);
    } catch (_) {
      aiMessage = null;
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => _CommitDialogContent(
        repoPath: repoPath,
        diff: diff,
        initialMessage: aiMessage ?? aiService.getDefaultCommitMessage(),
        fileName: fileName,
      ),
    );
  }
}

class _CommitDialogContent extends StatefulWidget {
  final String repoPath;
  final String diff;
  final String initialMessage;
  final String fileName;

  const _CommitDialogContent({
    required this.repoPath,
    required this.diff,
    required this.initialMessage,
    required this.fileName,
  });

  @override
  State<_CommitDialogContent> createState() => _CommitDialogContentState();
}

class _CommitDialogContentState extends State<_CommitDialogContent> {
  late TextEditingController _messageController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleCommit() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final gitService = GitService();
      await gitService.addFile(widget.repoPath, widget.fileName);
      await gitService.commit(widget.repoPath, _messageController.text.trim());
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
        Navigator.of(context).pop(false);
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  String _formatDiffPreview(String diff) {
    final lines = diff.split('\n').take(10).toList();
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.md),
            _buildMessageInput(),
            const SizedBox(height: AppSpacing.md),
            _buildDiffPreview(),
            const SizedBox(height: AppSpacing.xl),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.commit, size: 24, color: AppColors.accent),
        const SizedBox(width: AppSpacing.md),
        Text('提交更改', style: AppTextStyles.heading2),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '提交消息',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _messageController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '输入提交消息...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDiffPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '更改预览',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '(显示前10行)',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          height: 120,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: Text(
              widget.diff.isNotEmpty ? _formatDiffPreview(widget.diff) : '没有更改',
              style: AppTextStyles.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        const SizedBox(width: AppSpacing.sm),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleCommit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: _isSubmitting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('提交'),
        ),
      ],
    );
  }
}
