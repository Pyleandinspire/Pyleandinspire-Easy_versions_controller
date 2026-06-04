import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_versions_controller/models/snapshot.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';

/// 快照预览页面 — 只读展示快照文件内容
class SnapshotPreviewView extends StatelessWidget {
  final Snapshot snapshot;
  final String fileName;

  const SnapshotPreviewView({
    super.key,
    required this.snapshot,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('快照预览: ${snapshot.message ?? fileName}'),
        backgroundColor: AppColors.secondary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Text(
                DateFormat('yyyy-MM-dd HH:mm:ss').format(snapshot.timestamp),
                style: AppTextStyles.caption,
              ),
            ),
          ),
        ],
      ),
      body: _SnapshotContent(snapshot: snapshot),
    );
  }
}

class _SnapshotContent extends StatefulWidget {
  final Snapshot snapshot;
  const _SnapshotContent({required this.snapshot});

  @override
  State<_SnapshotContent> createState() => _SnapshotContentState();
}

class _SnapshotContentState extends State<_SnapshotContent> {
  String _content = '';
  bool _isLoading = true;
  String? _error;
  bool _isBinary = false;

  static const _textExtensions = {
    'txt', 'md', 'markdown', 'dart', 'py', 'js', 'ts', 'tsx', 'jsx',
    'java', 'c', 'cpp', 'h', 'hpp', 'cs', 'go', 'rs', 'rb', 'php',
    'html', 'css', 'scss', 'less', 'xml', 'json', 'yaml', 'yml', 'toml',
    'ini', 'cfg', 'conf', 'sh', 'bash', 'zsh', 'bat', 'sql', 'gitignore',
    'env', 'log', 'csv', 'tsv', 'swift', 'kt', 'scala', 'r', 'lua', 'pl',
    'ex', 'exs', 'vue', 'svelte', 'astro',
  };

  static const _imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico',
  };

  bool _isTextFile(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    if (!filePath.contains('.')) return true;
    return _textExtensions.contains(ext);
  }

  bool _isImageFile(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _imageExtensions.contains(ext);
  }

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final file = File(widget.snapshot.snapshotPath);
    if (!await file.exists()) {
      setState(() {
        _isLoading = false;
        _error = '快照文件不存在';
      });
      return;
    }

    if (_isImageFile(widget.snapshot.snapshotPath)) {
      setState(() {
        _isBinary = true;
        _isLoading = false;
      });
      return;
    }

    if (!_isTextFile(widget.snapshot.snapshotPath)) {
      setState(() {
        _isBinary = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      bool hasNull = false;
      for (int i = 0; i < bytes.length && i < 8192; i++) {
        if (bytes[i] == 0) {
          hasNull = true;
          break;
        }
      }
      if (hasNull) {
        setState(() {
          _isBinary = true;
          _isLoading = false;
        });
        return;
      }
      _content = String.fromCharCodes(bytes);
    } catch (e) {
      _error = '读取失败: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: AppTextStyles.bodySecondary),
      );
    }
    if (_isBinary) {
      if (_isImageFile(widget.snapshot.snapshotPath)) {
        return Center(
          child: Image.file(File(widget.snapshot.snapshotPath), fit: BoxFit.contain),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: AppSpacing.md),
            Text('此快照为二进制文件，不支持预览', style: AppTextStyles.bodySecondary),
          ],
        ),
      );
    }
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Text(
          _content,
          style: AppTextStyles.body.copyWith(fontFamily: 'Monaco', fontSize: 13),
        ),
      ),
    );
  }
}