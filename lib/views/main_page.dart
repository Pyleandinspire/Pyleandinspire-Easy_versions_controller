import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/views/file_not_found_dialog.dart';
import 'package:easy_versions_controller/viewmodels/tracked_file_provider.dart';
import 'package:easy_versions_controller/viewmodels/file_picker_provider.dart';
import 'package:easy_versions_controller/viewmodels/git_provider.dart';
import 'package:easy_versions_controller/views/settings_dialog.dart';
import 'package:easy_versions_controller/views/help_dialog.dart';
import 'package:easy_versions_controller/views/compare_view.dart';
import 'package:easy_versions_controller/views/commit_dialog.dart';
import 'package:easy_versions_controller/views/ai_agent_view.dart';
import 'package:easy_versions_controller/views/text_editor_view.dart';

final commitHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, TrackedFile?>((ref, file) async {
  if (file == null) return [];
  final gitService = ref.read(gitServiceProvider);
  return gitService.getCommitHistory(repoPath: file.repoPath ?? '');
});

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  TrackedFile? _selectedFile;

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(trackedFileListProvider);
    final commitHistory = ref.watch(commitHistoryProvider(_selectedFile));

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                _buildLeftPanel(filesAsync),
                _buildCenterPanel(),
                _buildRightPanel(commitHistory),
              ],
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Text('简控', style: AppTextStyles.heading2),
            const SizedBox(width: AppSpacing.lg),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 20),
              tooltip: '使用说明',
              onPressed: () => _showHelpDialog(),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              tooltip: 'AI 助手',
              onPressed: () => _showAiAgentView(),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: '设置',
              onPressed: () => _showSettingsDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel(AsyncValue<List<TrackedFile>> filesAsync) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Text('文件列表', style: AppTextStyles.heading3),
                const Spacer(),
                const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
          Expanded(
            child: filesAsync.when(
              data: (files) => files.isEmpty ? _buildEmptyState() : _buildFileList(files),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e', style: AppTextStyles.bodySecondary)),
            ),
          ),
          _buildAddFileButton(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open, size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: AppSpacing.md),
          Text('暂无追踪文件', style: AppTextStyles.bodySecondary),
          const SizedBox(height: AppSpacing.xs),
          Text('点击下方按钮添加文件', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildFileList(List<TrackedFile> files) {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final fileExists = File(file.filePath).existsSync();
        final isSelected = _selectedFile?.id == file.id;

        return Material(
          child: ListTile(
            dense: true,
            leading: Icon(
              fileExists ? Icons.insert_drive_file : Icons.error_outline,
              size: 20,
              color: fileExists ? AppColors.textSecondary : AppColors.error,
            ),
            title: Text(
              file.fileName,
              style: AppTextStyles.body.copyWith(
                color: fileExists ? AppColors.textPrimary : AppColors.error,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.filePath,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (file.lastAccessedAt != null)
                  Text(
                    '最近访问: ${DateFormat('MM-dd HH:mm').format(file.lastAccessedAt!)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
            selected: isSelected,
            selectedColor: AppColors.accent,
            selectedTileColor: AppColors.secondary,
            onTap: () => _onFileTap(file),
          ),
        );
      },
    );
  }

  Future<void> _onFileTap(TrackedFile file) async {
    final fileExists = File(file.filePath).existsSync();
    if (!fileExists) {
      await _showFileNotFoundDialog(file);
    } else {
      await ref.read(trackedFileListProvider.notifier).updateLastAccessed(file.id);
      setState(() {
        _selectedFile = file;
      });
    }
  }

  Future<void> _showFileNotFoundDialog(TrackedFile file) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FileNotFoundDialog(
        fileName: file.fileName,
        lastKnownPath: file.filePath,
        onAbandon: () {
          ref.read(trackedFileListProvider.notifier).removeFile(file.id);
          if (_selectedFile?.id == file.id) {
            setState(() {
              _selectedFile = null;
            });
          }
        },
        onScan: () => ref.read(trackedFileListProvider.notifier).scanForFile(file.fileName),
        onProvidePath: () async {
          final pickerService = ref.read(filePickerServiceProvider);
          final paths = await pickerService.pickFiles();
          if (paths.isNotEmpty) return paths.first;
          return null;
        },
      ),
    );

    if (result != null) {
      await ref.read(trackedFileListProvider.notifier).updateFilePath(file.id, result);
      setState(() {
        _selectedFile = TrackedFile(
          id: file.id,
          filePath: result,
          fileName: result.split('/').last,
          repoPath: file.repoPath,
          addedAt: file.addedAt,
          lastAccessedAt: DateTime.now(),
        );
      });
    }
  }

  Widget _buildAddFileButton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton.icon(
          onPressed: () async {
            await ref.read(trackedFileListProvider.notifier).addFiles();
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加文件'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterPanel() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: _selectedFile == null 
            ? _buildNoSelectionPreview()
            : _buildFilePreview(),
      ),
    );
  }

  Widget _buildNoSelectionPreview() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.file_open, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: AppSpacing.md),
          Text('选择文件进行预览', style: AppTextStyles.bodySecondary),
          const SizedBox(height: AppSpacing.sm),
          Text('在左侧列表中选择一个文件查看内容', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.file_open, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _selectedFile?.fileName ?? '',
                  style: AppTextStyles.heading3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_note, size: 18),
                tooltip: '编辑',
                onPressed: _selectedFile != null ? () => _showEditorView() : null,
                disabledColor: AppColors.textSecondary,
              ),
              IconButton(
                icon: const Icon(Icons.compare_arrows, size: 18),
                tooltip: '对比',
                onPressed: _selectedFile != null ? () => _showCompareView(ref.watch(commitHistoryProvider(_selectedFile))) : null,
                disabledColor: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _selectedFile != null 
              ? _FilePreviewContent(file: _selectedFile!)
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildRightPanel(AsyncValue<List<Map<String, dynamic>>> commitHistory) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(
          left: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Text('时间轴', style: AppTextStyles.heading3),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _selectedFile == null
                ? _buildNoSelectionTimeline()
                : commitHistory.when(
                    data: (commits) => commits.isEmpty ? _buildEmptyTimeline(_selectedFile!) : _buildTimeline(commits),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('加载失败', style: AppTextStyles.caption),),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSelectionState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: AppSpacing.md),
          Text('选择文件查看版本历史', style: AppTextStyles.bodySecondary),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: () async {
              await ref.read(trackedFileListProvider.notifier).addFiles();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加文件'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTimeline(TrackedFile file) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: AppSpacing.md),
          Text('${file.fileName} 暂无版本记录', style: AppTextStyles.bodySecondary),
          const SizedBox(height: AppSpacing.xs),
          Text('修改文件后会自动保存版本', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> commits) {
    return ListView.builder(
      itemCount: commits.length,
      itemBuilder: (context, index) {
        final commit = commits[index];
        final message = commit['message'] as String;
        final timestamp = commit['time'] as int;
        final oid = commit['oid'] as String;

        return ListTile(
          leading: const Icon(Icons.commit, size: 20, color: AppColors.accent),
          title: Text(
            message.trim(),
            style: AppTextStyles.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)),
                style: AppTextStyles.timestamp,
              ),
              Text(
                oid.substring(0, 7),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Text('就绪', style: AppTextStyles.caption),
            const Spacer(),
            const Icon(Icons.check_circle, size: 14, color: AppColors.success),
            const SizedBox(width: AppSpacing.xs),
            Text('已保存', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => const HelpDialog(),
    );
  }

  void _showCompareView(AsyncValue<List<Map<String, dynamic>>> commitHistory) {
    if (_selectedFile != null && commitHistory is AsyncData<List<Map<String, dynamic>>>) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompareView(
            file: _selectedFile!,
            commits: commitHistory.value ?? [],
          ),
        ),
      );
    }
  }

  Future<void> _showCommitDialog() async {
    if (_selectedFile == null) return;

    final commitDialog = ref.read(commitDialogProvider);
    final result = await commitDialog.show(
      context: context,
      repoPath: _selectedFile!.repoPath ?? '',
      diff: '',
      fileName: _selectedFile!.fileName,
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提交成功')),
      );
    }
  }

  void _showAiAgentView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiAgentView(file: _selectedFile),
      ),
    );
  }

  void _showEditorView() {
    if (_selectedFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TextEditorView(file: _selectedFile!),
        ),
      );
    }
  }

  Widget _buildNoSelectionTimeline() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 32, color: Color(0xFFCBD5E1)),
          const SizedBox(height: AppSpacing.sm),
          Text('选择文件查看历史', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _FilePreviewContent extends StatefulWidget {
  final TrackedFile file;

  const _FilePreviewContent({required this.file});

  @override
  State<_FilePreviewContent> createState() => _FilePreviewContentState();
}

class _FilePreviewContentState extends State<_FilePreviewContent> {
  String _content = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  @override
  void didUpdateWidget(covariant _FilePreviewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id) {
      _loadFileContent();
    }
  }

  Future<void> _loadFileContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.file.filePath);
      if (await file.exists()) {
        _content = await file.readAsString();
      } else {
        _error = '文件不存在';
      }
    } catch (e) {
      _error = '读取文件失败: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: AppTextStyles.bodySecondary),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Text(
          _content,
          style: AppTextStyles.body.copyWith(fontFamily: 'Monaco', fontSize: 13),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}
