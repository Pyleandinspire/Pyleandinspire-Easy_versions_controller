import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/services/snapshot_service.dart';
import 'package:easy_versions_controller/services/ai_commit_service.dart';
import 'package:easy_versions_controller/utils/platform_utils.dart';

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
  final FocusNode _focusNode = FocusNode();
  bool _isSyncingScroll = false;
  bool _hasChanges = false;
  bool _isSaving = false;
  int _cursorLine = 1;
  int _cursorColumn = 1;
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _showFindReplace = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();

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
    _focusNode.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
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
      _updateCursorPosition();
    });
  }

  void _updateCursorPosition() {
    final offset = _textController.selection.baseOffset;
    final text = _textController.text;
    var line = 1;
    var col = 1;
    for (var i = 0; i < offset && i < text.length; i++) {
      if (text[i] == '\n') {
        line++;
        col = 1;
      } else {
        col++;
      }
    }
    _cursorLine = line;
    _cursorColumn = col;
  }

  int get _wordCount {
    return _textController.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int get _lineCount {
    return '\n'.allMatches(_textController.text).length + 1;
  }

  int get _charCount {
    return _textController.text.length;
  }

  String get _fileType => widget.file.fileName.split('.').last.toUpperCase();

  void _findNext() {
    final query = _findController.text;
    if (query.isEmpty) return;
    final text = _textController.text;
    final currentPos = _textController.selection.baseOffset;
    final index = text.indexOf(query, currentPos);
    if (index >= 0) {
      _textController.selection = TextSelection(
        baseOffset: index,
        extentOffset: index + query.length,
      );
    } else {
      // Wrap around
      final wrapIndex = text.indexOf(query, 0);
      if (wrapIndex >= 0) {
        _textController.selection = TextSelection(
          baseOffset: wrapIndex,
          extentOffset: wrapIndex + query.length,
        );
      }
    }
  }

  void _replaceCurrent() {
    final query = _findController.text;
    final replacement = _replaceController.text;
    if (query.isEmpty) return;
    final selection = _textController.selection;
    if (!selection.isValid) return;
    final selected = _textController.text.substring(selection.start, selection.end);
    if (selected == query) {
      _textController.value = _textController.value.replaced(
        TextRange(start: selection.start, end: selection.end),
        replacement,
      );
      _saveToHistory();
    }
    _findNext();
  }

  void _replaceAll() {
    final query = _findController.text;
    final replacement = _replaceController.text;
    if (query.isEmpty) return;
    final newText = _textController.text.replaceAll(query, replacement);
    _textController.text = newText;
    _saveToHistory();
    setState(() => _hasChanges = true);
  }

  void _toggleFindReplace() {
    setState(() => _showFindReplace = !_showFindReplace);
    if (_showFindReplace) {
      _findFocusNode.requestFocus();
    }
  }

  Widget _buildFindReplaceBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        border: Border(top: BorderSide(color: AppColors.accent)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: TextField(
              controller: _findController,
              focusNode: _findFocusNode,
              style: AppTextStyles.caption,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '查找...',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _replaceController,
              style: AppTextStyles.caption,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '替换...',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.search, size: 18),
            onPressed: _findNext,
            tooltip: '查找下一个',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.find_replace, size: 18),
            onPressed: _replaceCurrent,
            tooltip: '替换当前',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.done_all, size: 18), 
            onPressed: _replaceAll,
            tooltip: '全部替换',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _toggleFindReplace,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
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

      // 保存后自动创建快照
      final aiCommitService = ref.read(aiCommitServiceProvider);
      final aiMessage = await aiCommitService.generateAutoSaveMessage(
        fileId: widget.file.id,
        filePath: widget.file.filePath,
        fileName: widget.file.fileName,
      );

      final snapshotService = ref.read(snapshotServiceProvider);
      await snapshotService.createAutoSnapshot(
        fileId: widget.file.id,
        filePath: widget.file.filePath,
        fileName: widget.file.fileName,
        message: aiMessage,
      );

      _saveToHistory();
      setState(() => _hasChanges = false);

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

  List<int> _getLineNumbers() {
    final lines = _textController.text.split('\n');
    return List.generate(lines.length, (index) => index + 1);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveFile,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleFindReplace,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          appBar: _buildAppBar(),
          body: Column(
            children: [
              if (_showFindReplace) _buildFindReplaceBar(),
              Expanded(child: _buildEditor()),
            ],
          ),
          floatingActionButton: _buildSaveButton(),
          bottomNavigationBar: _buildStatusBar(),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text('行 $_cursorLine, 列 $_cursorColumn', style: AppTextStyles.caption),
          const VerticalDivider(width: 20),
          Text('字数 $_wordCount', style: AppTextStyles.caption),
          const VerticalDivider(width: 20),
          Text('行数 $_lineCount', style: AppTextStyles.caption),
          const VerticalDivider(width: 20),
          Text('字符 $_charCount', style: AppTextStyles.caption),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_fileType, style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
          ),
          if (_hasChanges) ...[
            const SizedBox(width: AppSpacing.md),
            Text('未保存', style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
          ],
        ],
      ),
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
          icon: const Icon(Icons.open_in_new, size: 20),
          tooltip: '用系统默认程序打开',
          onPressed: () => openFileWithDefaultApp(widget.file.filePath),
        ),
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
