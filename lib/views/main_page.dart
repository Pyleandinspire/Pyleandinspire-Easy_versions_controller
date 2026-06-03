import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/models/snapshot.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/views/file_not_found_dialog.dart';
import 'package:easy_versions_controller/viewmodels/tracked_file_provider.dart';
import 'package:easy_versions_controller/viewmodels/file_picker_provider.dart';
import 'package:easy_versions_controller/views/settings_dialog.dart';
import 'package:easy_versions_controller/views/help_dialog.dart';
import 'package:easy_versions_controller/views/compare_view.dart';
import 'package:easy_versions_controller/views/ai_agent_view.dart';
import 'package:easy_versions_controller/views/text_editor_view.dart';
import 'package:easy_versions_controller/viewmodels/auto_save_status_provider.dart';
import 'package:easy_versions_controller/viewmodels/snapshot_timeline_provider.dart';
import 'package:easy_versions_controller/services/snapshot_service.dart';
import 'package:easy_versions_controller/services/notification_service.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  TrackedFile? _selectedFile;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(trackedFileListProvider);

    // 监听自动保存状态变化，保存失败时弹出通知
    ref.listen<AutoSaveState>(autoSaveStatusProvider, (prev, next) {
      if (next.status == AutoSaveStatus.failed &&
          prev?.status != AutoSaveStatus.failed) {
        final notificationService = NotificationService();
        notificationService.show(
          context: context,
          message: next.errorMessage ?? '保存失败',
          type: AppNotificationType.error,
          onTap: () {
            notificationService.dismiss();
            _showAiAgentView();
          },
        );
      }
    });

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                _buildLeftPanel(filesAsync),
                _buildCenterPanel(),
                _buildRightPanel(),
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
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
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
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(children: [Text('文件列表', style: AppTextStyles.heading3)]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: '搜索文件名...',
                hintStyle: AppTextStyles.caption,
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: filesAsync.when(
              data: (files) {
                final filtered = _searchQuery.isEmpty
                    ? files
                    : files
                          .where(
                            (f) =>
                                f.fileName.toLowerCase().contains(_searchQuery),
                          )
                          .toList();
                return filtered.isEmpty
                    ? _buildEmptyState()
                    : _buildFileList(filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('加载失败: $e', style: AppTextStyles.bodySecondary),
              ),
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
                if (file.updatedAt != null)
                  Text(
                    '最近访问: ${DateFormat('MM-dd HH:mm').format(file.updatedAt!)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
              tooltip: '删除追踪',
              onPressed: () => _showDeleteConfirmDialog(file),
            ),
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
      await ref
          .read(trackedFileListProvider.notifier)
          .updateLastAccessed(file.id);
      setState(() {
        _selectedFile = file;
      });
    }
  }

  Future<void> _showDeleteConfirmDialog(TrackedFile file) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('是否删除对 "${file.fileName}" 的版本追踪？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('remove_only'),
            child: const Text('仅移除追踪'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete_all'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('完全删除'),
          ),
        ],
      ),
    );

    if (result == 'remove_only') {
      ref.read(trackedFileListProvider.notifier).removeFile(file.id);
      if (_selectedFile?.id == file.id) {
        setState(() => _selectedFile = null);
      }
    } else if (result == 'delete_all') {
      ref
          .read(trackedFileListProvider.notifier)
          .removeFile(file.id, deleteSnapshots: true);
      if (_selectedFile?.id == file.id) {
        setState(() => _selectedFile = null);
      }
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
        onScan: () => ref
            .read(trackedFileListProvider.notifier)
            .scanForFile(file.fileName),
        onProvidePath: () async {
          final pickerService = ref.read(filePickerServiceProvider);
          final paths = await pickerService.pickFiles();
          if (paths.isNotEmpty) return paths.first;
          return null;
        },
      ),
    );

    if (result != null) {
      await ref
          .read(trackedFileListProvider.notifier)
          .updateFilePath(file.id, result);
      setState(() {
        _selectedFile = TrackedFile(
          id: file.id,
          filePath: result,
          fileName: result.split('/').last,
          createdAt: file.createdAt,
          updatedAt: DateTime.now(),
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
                onPressed: _selectedFile != null
                    ? () => _showEditorView()
                    : null,
                disabledColor: AppColors.textSecondary,
              ),
              IconButton(
                icon: const Icon(Icons.compare_arrows, size: 18),
                tooltip: '对比',
                onPressed: _selectedFile != null
                    ? () => _showCompareView()
                    : null,
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

  Widget _buildRightPanel() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(left: BorderSide(color: AppColors.border, width: 1)),
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
                : _buildSnapshotTimeline(_selectedFile!),
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

  Widget _buildSnapshotTimeline(TrackedFile file) {
    final snapshotsAsync = ref.watch(snapshotTimelineProvider(file.id));

    return snapshotsAsync.when(
      data: (snapshots) {
        if (snapshots.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, size: 48, color: Color(0xFFCBD5E1)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${file.fileName} 暂无版本记录',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('修改文件后会自动保存版本', style: AppTextStyles.caption),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshots.length,
          itemBuilder: (context, index) {
            final snapshot = snapshots[index];
            final isLatest = index == 0;

            return ListTile(
              leading: Icon(
                isLatest ? Icons.fiber_manual_record : Icons.circle_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              title: Text(
                snapshot.message ?? '',
                style: AppTextStyles.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                DateFormat('yyyy-MM-dd HH:mm:ss').format(snapshot.timestamp),
                style: AppTextStyles.timestamp,
              ),
              onTap: () => _showSnapshotActions(file, snapshot),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('加载失败: $e', style: AppTextStyles.bodySecondary)),
    );
  }

  void _showSnapshotActions(TrackedFile file, Snapshot snapshot) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.preview),
              title: Text('预览: ${snapshot.message ?? ''}'),
              subtitle: Text(
                DateFormat('yyyy-MM-dd HH:mm:ss').format(snapshot.timestamp),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                // TODO: 打开预览
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('与当前版本对比'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showCompareView(snapshot: snapshot);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore, color: AppColors.warning),
              title: const Text('回退到此版本'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showRollbackConfirm(file, snapshot);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRollbackConfirm(TrackedFile file, Snapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认回退'),
        content: Text(
          '确定要将 "${file.fileName}" 回退到以下版本？\n\n'
          '版本: ${snapshot.message ?? ''}\n'
          '时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(snapshot.timestamp)}\n\n'
          '当前内容将被自动保存为一个新快照，不会丢失。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('确认回退'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final snapshotService = ref.read(snapshotServiceProvider);
        await snapshotService.restoreSnapshot(
          fileId: file.id,
          filePath: file.filePath,
          fileName: file.fileName,
          snapshot: snapshot,
        );
        // 刷新时间轴
        ref.invalidate(snapshotTimelineProvider(file.id));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已回退到选中版本')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('回退失败: $e')));
        }
      }
    }
  }

  Widget _buildStatusBar() {
    final saveState = ref.watch(autoSaveStatusProvider);

    IconData statusIcon;
    Color statusColor;
    String statusText;
    String tooltip;

    switch (saveState.status) {
      case AutoSaveStatus.saved:
        statusIcon = Icons.check_circle;
        statusColor = AppColors.success;
        statusText = '已保存';
        break;
      case AutoSaveStatus.saving:
        statusIcon = Icons.circle;
        statusColor = AppColors.warning;
        statusText = '正在保存...';
        break;
      case AutoSaveStatus.failed:
        statusIcon = Icons.warning;
        statusColor = AppColors.error;
        statusText = '保存失败';
        break;
    }

    if (saveState.lastSaveTime != null) {
      tooltip =
          '上次保存: ${DateFormat('HH:mm:ss').format(saveState.lastSaveTime!)}';
    } else {
      tooltip = statusText;
    }

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Text('就绪', style: AppTextStyles.caption),
            const Spacer(),
            Tooltip(
              message: tooltip,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: AppSpacing.xs),
                  Text(statusText, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(context: context, builder: (context) => const SettingsDialog());
  }

  void _showHelpDialog() {
    showDialog(context: context, builder: (context) => const HelpDialog());
  }

  void _showCompareView({Snapshot? snapshot}) {
    if (_selectedFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CompareView(file: _selectedFile!, snapshot: snapshot),
        ),
      );
    }
  }

  void _showAiAgentView() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AiAgentView(file: _selectedFile)),
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
  bool _isBinary = false;

  // 常见文本文件扩展名
  static const _textExtensions = {
    'txt',
    'md',
    'markdown',
    'dart',
    'py',
    'js',
    'ts',
    'tsx',
    'jsx',
    'java',
    'c',
    'cpp',
    'h',
    'hpp',
    'cs',
    'go',
    'rs',
    'rb',
    'php',
    'html',
    'css',
    'scss',
    'less',
    'xml',
    'json',
    'yaml',
    'yml',
    'toml',
    'ini',
    'cfg',
    'conf',
    'sh',
    'bash',
    'zsh',
    'bat',
    'sql',
    'gitignore',
    'env',
    'log',
    'csv',
    'tsv',
    'swift',
    'kt',
    'scala',
    'r',
    'lua',
    'pl',
    'ex',
    'exs',
    'vue',
    'svelte',
    'astro',
    'makefile',
    'dockerfile',
  };

  // 图片文件扩展名
  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'svg',
    'ico',
  };

  bool _isTextFile(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    // 无扩展名的文件视为文本
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
      _isBinary = false;
    });

    try {
      final file = File(widget.file.filePath);
      if (await file.exists()) {
        if (_isImageFile(widget.file.filePath)) {
          // 图片文件用 Image 组件显示
          setState(() {
            _isBinary = true; // 标记为特殊类型，但不是错误
            _isLoading = false;
          });
          return;
        }

        if (!_isTextFile(widget.file.filePath)) {
          // 非文本文件，不尝试读取内容
          setState(() {
            _isBinary = true;
            _isLoading = false;
          });
          return;
        }

        // 文本文件，尝试读取
        final bytes = await file.readAsBytes();
        // 检测是否包含空字节（二进制文件标志）
        bool hasNullBytes = false;
        for (int i = 0; i < bytes.length && i < 8192; i++) {
          if (bytes[i] == 0) {
            hasNullBytes = true;
            break;
          }
        }

        if (hasNullBytes) {
          setState(() {
            _isBinary = true;
            _isLoading = false;
          });
          return;
        }

        _content = String.fromCharCodes(bytes);
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

    if (_isBinary) {
      if (_isImageFile(widget.file.filePath)) {
        return Center(
          child: Image.file(
            File(widget.file.filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildBinaryPlaceholder(),
          ),
        );
      }
      return _buildBinaryPlaceholder();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Text(
          _content,
          style: AppTextStyles.body.copyWith(
            fontFamily: 'Monaco',
            fontSize: 13,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildBinaryPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file,
            size: 48,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('不支持预览此文件类型', style: AppTextStyles.bodySecondary),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: () => Process.run('open', [widget.file.filePath]),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('使用系统默认程序打开'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
