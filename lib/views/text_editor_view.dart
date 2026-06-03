import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';

final editorProvider = Provider<TextEditorService>((ref) {
  return TextEditorService(ref);
});

class TextEditorService {
  final Ref _ref;

  TextEditorService(this._ref);

  Future<String> readFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<void> writeFile(String filePath, String content) async {
    final file = File(filePath);
    await file.writeAsString(content);
  }

  Future<void> autoSave(
    String repoPath,
    String fileName,
    String originalFilePath,
  ) async {
    // TODO: 实现快照保存逻辑 (步骤 2.6.4)
    // 当前暂不执行任何 Git 操作
  }
}

class TextEditorView extends ConsumerStatefulWidget {
  final TrackedFile file;

  const TextEditorView({super.key, required this.file});

  @override
  ConsumerState<TextEditorView> createState() => _TextEditorViewState();
}

class _TextEditorViewState extends ConsumerState<TextEditorView> {
  late TextEditingController _textController;
  final ScrollController _lineScrollController = ScrollController();
  final ScrollController _textScrollController = ScrollController();
  bool _isSyncingScroll = false;
  bool _hasChanges = false;
  bool _isSaving = false;
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _loadFileContent();
    _textController.addListener(_onTextChanged);
    _lineScrollController.addListener(_syncFromLineScroll);
    _textScrollController.addListener(_syncFromTextScroll);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _lineScrollController.removeListener(_syncFromLineScroll);
    _textScrollController.removeListener(_syncFromTextScroll);
    _textController.dispose();
    _lineScrollController.dispose();
    _textScrollController.dispose();
    super.dispose();
  }

  void _syncFromLineScroll() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    _textScrollController.jumpTo(_lineScrollController.offset);
    _isSyncingScroll = false;
  }

  void _syncFromTextScroll() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    _lineScrollController.jumpTo(_textScrollController.offset);
    _isSyncingScroll = false;
  }

  Future<void> _loadFileContent() async {
    final editorService = ref.read(editorProvider);
    final content = await editorService.readFile(widget.file.filePath);
    _textController.text = content;
    _history.clear();
    _history.add(content);
    _historyIndex = 0;
  }

  void _onTextChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  void _saveToHistory() {
    _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(_textController.text);
    _historyIndex = _history.length - 1;

    if (_history.length > 50) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _textController.text = _history[_historyIndex];
      setState(() => _hasChanges = _historyIndex != _history.length - 1);
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _textController.text = _history[_historyIndex];
      setState(() => _hasChanges = _historyIndex != _history.length - 1);
    }
  }

  Future<void> _saveFile() async {
    if (!_hasChanges) return;

    setState(() => _isSaving = true);

    try {
      final editorService = ref.read(editorProvider);
      await editorService.writeFile(widget.file.filePath, _textController.text);

      if (widget.file.snapshotDir != null) {
        await editorService.autoSave(
          widget.file.snapshotDir!,
          widget.file.fileName,
          widget.file.filePath,
        );
      }

      _saveToHistory();
      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存成功')));
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

  List<int> _getLineNumbers() {
    final lines = _textController.text.split('\n');
    return List.generate(lines.length, (index) => index + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildEditor(),
      floatingActionButton: _buildSaveButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.edit_note, size: 24, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              widget.file.fileName,
              style: AppTextStyles.heading2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_hasChanges)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.undo, size: 20),
          tooltip: '撤销',
          onPressed: _historyIndex > 0 ? _undo : null,
          disabledColor: AppColors.textSecondary,
        ),
        IconButton(
          icon: const Icon(Icons.redo, size: 20),
          tooltip: '重做',
          onPressed: _historyIndex < _history.length - 1 ? _redo : null,
          disabledColor: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
      color: AppColors.primary,
      child: Row(
        children: [
          _buildLineNumbers(),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(child: _buildTextArea()),
        ],
      ),
    );
  }

  Widget _buildLineNumbers() {
    final lineNumbers = _getLineNumbers();

    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(color: AppColors.secondary),
      child: ListView.builder(
        controller: _lineScrollController,
        itemCount: lineNumbers.length,
        itemBuilder: (context, index) {
          return SizedBox(
            height: 20,
            child: Text(
              '${lineNumbers[index]}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextArea() {
    return SingleChildScrollView(
      controller: _textScrollController,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: TextField(
          controller: _textController,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '开始编辑...',
          ),
          style: AppTextStyles.body,
          textCapitalization: TextCapitalization.none,
          autofocus: true,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return FloatingActionButton(
      onPressed: _saveFile,
      backgroundColor: _hasChanges ? AppColors.accent : AppColors.textSecondary,
      foregroundColor: Colors.white,
      child: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save),
      tooltip: '保存',
    );
  }
}
