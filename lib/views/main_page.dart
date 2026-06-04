import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:easy_versions_controller/viewmodels/auto_save_status_provider.dart';
import 'package:easy_versions_controller/viewmodels/snapshot_timeline_provider.dart';
import 'package:easy_versions_controller/services/snapshot_service.dart';
import 'package:easy_versions_controller/services/notification_service.dart';
import 'package:easy_versions_controller/utils/platform_utils.dart';
import 'package:easy_versions_controller/services/editor_service.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  TrackedFile? _selectedFile;
  Snapshot? _previewingSnapshot;
  bool _isEditing = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _editorController = TextEditingController();
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _lineNumberScrollController = ScrollController();
  String _searchQuery = '';
  bool _hasChanges = false;
  bool _isSaving = false;
  List<String> _history = [];
  int _historyIndex = -1;
  int _currentLine = 1;
  int _currentColumn = 1;

  @override
  void dispose() {
    _searchController.dispose();
    _editorController.dispose();
    _editorScrollController.dispose();
    _lineNumberScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _editorScrollController.addListener(_syncScroll);
    _editorController.addListener(_onTextChanged);
  }

  void _syncScroll() {
    _lineNumberScrollController.jumpTo(_editorScrollController.offset);
  }

  void _onTextChanged() {
    setState(() {
      _hasChanges = true;
      _updateCursorPosition();
    });
  }

  void _updateCursorPosition() {
    final text = _editorController.text;
    final selection = _editorController.selection;
    if (selection.start != -1) {
      final beforeCursor = text.substring(0, selection.start);
      final lines = beforeCursor.split('\n');
      _currentLine = lines.length;
      _currentColumn = lines.isNotEmpty ? lines.last.length + 1 : 1;
    }
  }

  void _saveToHistory() {
    _history = _history.sublist(0, _historyIndex + 1);
    _history.add(_editorController.text);
    _historyIndex = _history.length - 1;
    if (_history.length > 50) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _editorController.text = _history[_historyIndex];
      setState(() => _hasChanges = _historyIndex != _history.length - 1);
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _editorController.text = _history[_historyIndex];
      setState(() => _hasChanges = _historyIndex != _history.length - 1);
    }
  }

  Future<void> _loadFileContent(TrackedFile file) async {
    try {
      final content = await File(file.filePath).readAsString();
      _editorController.text = content;
      _history = [content];
      _historyIndex = 0;
      setState(() => _hasChanges = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('读取文件失败: $e')));
      }
    }
  }

  Future<void> _saveFile() async {
    if (!_hasChanges || _selectedFile == null) return;

    setState(() => _isSaving = true);

    try {
      final editorService = ref.read(editorProvider);
      await editorService.writeFile(
        _selectedFile!.filePath,
        _editorController.text,
      );

      final snapshotService = ref.read(snapshotServiceProvider);
      await snapshotService.createAutoSnapshot(
        fileId: _selectedFile!.id,
        filePath: _selectedFile!.filePath,
        fileName: _selectedFile!.fileName,
        message: '手动保存',
      );

      _saveToHistory();
      setState(() => _hasChanges = false);

      // 刷新缓存并重新加载时间轴
      await ref.read(refreshSnapshotCacheProvider)(_selectedFile!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存成功，已创建新版本快照'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _toggleEditMode() {
    if (_selectedFile == null) return;

    if (!_isEditing) {
      _loadFileContent(_selectedFile!);
    }
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing && _hasChanges) {
        _showSaveConfirmDialog();
      }
    });
  }

  void _exitSnapshotPreview() {
    setState(() => _previewingSnapshot = null);
  }

  Future<void> _showSaveConfirmDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存更改'),
        content: const Text('文件已修改，是否保存更改？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('不保存'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveFile();
    } else if (result == 'discard') {
      setState(() => _hasChanges = false);
    }
  }

  void _previewSnapshot(Snapshot snapshot) {
    setState(() => _previewingSnapshot = snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(trackedFileListProvider);

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
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
              _saveFile(),
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
              _undo(),
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): () =>
              _redo(),
        },
        child: FocusScope(
          child: Column(
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
        ),
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
        _isEditing = false;
        _previewingSnapshot = null;
        _hasChanges = false;
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
      // 清除该文件的缓存
      ref.read(clearSnapshotCacheProvider)(file.id);
      if (_selectedFile?.id == file.id) {
        setState(() => _selectedFile = null);
      }
    } else if (result == 'delete_all') {
      ref
          .read(trackedFileListProvider.notifier)
          .removeFile(file.id, deleteSnapshots: true);
      // 清除该文件的缓存
      ref.read(clearSnapshotCacheProvider)(file.id);
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
            : _previewingSnapshot != null
            ? _buildSnapshotPreview()
            : _isEditing
            ? _buildEditorView()
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
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _toggleEditMode,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('编辑'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.compare_arrows, size: 20),
                tooltip: '版本对比',
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

  Widget _buildSnapshotPreview() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: '返回当前版本',
                onPressed: _exitSnapshotPreview,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.history, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedFile?.fileName} - 历史版本',
                      style: AppTextStyles.heading3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_previewingSnapshot != null)
                      Text(
                        '${DateFormat('yyyy-MM-dd HH:mm:ss').format(_previewingSnapshot!.timestamp)} - ${_previewingSnapshot!.message ?? ''}',
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.compare_arrows, size: 20),
                tooltip: '与当前版本对比',
                onPressed: _selectedFile != null && _previewingSnapshot != null
                    ? () => _showCompareView(snapshot: _previewingSnapshot)
                    : null,
                disabledColor: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _previewingSnapshot != null
              ? _SnapshotPreviewContent(snapshot: _previewingSnapshot!)
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildEditorView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: '返回预览',
                onPressed: _toggleEditMode,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.edit_note, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedFile?.fileName ?? '',
                        style: AppTextStyles.heading3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_hasChanges)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.circle, size: 10, color: Colors.red),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                tooltip: '用系统程序打开',
                onPressed: _selectedFile != null
                    ? () => openFileWithDefaultApp(_selectedFile!.filePath)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.undo, size: 18),
                tooltip: '撤销',
                onPressed: _historyIndex > 0 ? _undo : null,
                disabledColor: AppColors.textSecondary,
              ),
              IconButton(
                icon: const Icon(Icons.redo, size: 18),
                tooltip: '重做',
                onPressed: _historyIndex < _history.length - 1 ? _redo : null,
                disabledColor: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveFile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: Container(
            color: AppColors.primary,
            child: Row(
              children: [
                _buildLineNumbers(),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: _buildTextArea()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineNumbers() {
    final lines = _editorController.text.split('\n');
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.secondary,
      child: ListView.builder(
        controller: _lineNumberScrollController,
        itemCount: lines.length,
        itemBuilder: (context, index) {
          return Text(
            '${index + 1}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.right,
          );
        },
      ),
    );
  }

  Widget _buildTextArea() {
    return TextField(
      controller: _editorController,
      scrollController: _editorScrollController,
      keyboardType: TextInputType.multiline,
      maxLines: null,
      style: AppTextStyles.body.copyWith(fontFamily: 'Monaco', fontSize: 13),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(12),
      ),
      autofocus: true,
    );
  }

  Widget _buildRightPanel() {
    return Container(
      width: 280,
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

            return Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: ListTile(
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye, size: 16),
                      tooltip: '预览此版本',
                      onPressed: () => _previewSnapshot(snapshot),
                      color: AppColors.accent,
                    ),
                  ],
                ),
                onTap: () => _showSnapshotActions(file, snapshot),
              ),
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
                _previewSnapshot(snapshot);
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
        // 刷新缓存并重新加载时间轴
        await ref.read(refreshSnapshotCacheProvider)(file.id);
        if (_isEditing) {
          await _loadFileContent(file);
        }
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
            if (_isEditing) ...[
              Text(
                '行 $_currentLine, 列 $_currentColumn',
                style: AppTextStyles.caption,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '字数 ${_editorController.text.length}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '行数 ${_editorController.text.split('\n').length}',
                style: AppTextStyles.caption,
              ),
            ] else ...[
              Text('就绪', style: AppTextStyles.caption),
            ],
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
            if (_hasChanges) ...[
              const SizedBox(width: AppSpacing.md),
              const Icon(Icons.circle, size: 10, color: Colors.red),
              const SizedBox(width: AppSpacing.xs),
              Text('未保存', style: AppTextStyles.caption),
            ],
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
          setState(() {
            _isBinary = true;
            _isLoading = false;
          });
          return;
        }

        if (!_isTextFile(widget.file.filePath)) {
          setState(() {
            _isBinary = true;
            _isLoading = false;
          });
          return;
        }

        final bytes = await file.readAsBytes();
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
            onPressed: () => openFileWithDefaultApp(widget.file.filePath),
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

class _SnapshotPreviewContent extends StatefulWidget {
  final Snapshot snapshot;

  const _SnapshotPreviewContent({required this.snapshot});

  @override
  State<_SnapshotPreviewContent> createState() =>
      _SnapshotPreviewContentState();
}

class _SnapshotPreviewContentState extends State<_SnapshotPreviewContent> {
  String _content = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSnapshotContent();
  }

  Future<void> _loadSnapshotContent() async {
    setState(() => _isLoading = true);

    try {
      final file = File(widget.snapshot.snapshotPath);
      if (await file.exists()) {
        _content = await file.readAsString();
      } else {
        _error = '快照文件不存在';
      }
    } catch (e) {
      _error = '读取快照失败: $e';
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
          style: AppTextStyles.body.copyWith(
            fontFamily: 'Monaco',
            fontSize: 13,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}
