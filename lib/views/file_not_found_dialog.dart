import 'package:flutter/material.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';

class FileNotFoundDialog extends StatefulWidget {
  final String fileName;
  final String lastKnownPath;
  final VoidCallback onAbandon;
  final Future<String?> Function() onScan;
  final Future<String?> Function() onProvidePath;

  const FileNotFoundDialog({
    super.key,
    required this.fileName,
    required this.lastKnownPath,
    required this.onAbandon,
    required this.onScan,
    required this.onProvidePath,
  });

  @override
  State<FileNotFoundDialog> createState() => _FileNotFoundDialogState();
}

class _FileNotFoundDialogState extends State<FileNotFoundDialog> {
  bool _isScanning = false;

  Future<void> _handleScan() async {
    setState(() => _isScanning = true);
    final foundPath = await widget.onScan();
    if (!mounted) return;
    setState(() => _isScanning = false);

    if (foundPath != null) {
      Navigator.of(context).pop(foundPath);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('扫描超时，未找到文件'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleProvidePath() async {
    final newPath = await widget.onProvidePath();
    if (!mounted) return;
    if (newPath != null) {
      Navigator.of(context).pop(newPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Text('文件未找到', style: AppTextStyles.heading3),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件 "${widget.fileName}" 无法找到，可能已被移动或删除。', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Text('上次已知路径：', style: AppTextStyles.caption),
          Text(widget.lastKnownPath, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isScanning ? null : () {
            widget.onAbandon();
            Navigator.of(context).pop(null);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('放弃追踪'),
        ),
        TextButton(
          onPressed: _isScanning ? null : _handleProvidePath,
          child: const Text('提供路径'),
        ),
        ElevatedButton(
          onPressed: _isScanning ? null : _handleScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          child: _isScanning
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('自动扫描'),
        ),
      ],
    );
  }
}
