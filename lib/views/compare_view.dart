import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/services/diff_service.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';
import 'package:easy_versions_controller/models/snapshot.dart';

/// 基于快照的文件差异对比 Provider
final snapshotDiffProvider =
    FutureProvider.family<
      List<DiffLine>,
      ({TrackedFile file, Snapshot? snapshot})
    >((ref, args) async {
      final diffService = ref.read(diffServiceProvider);

      if (args.snapshot == null) {
        return <DiffLine>[];
      }

      return diffService.getDiffBetweenFiles(
        fromFilePath: args.snapshot!.snapshotPath,
        toFilePath: args.file.filePath,
      );
    });

class CompareView extends ConsumerStatefulWidget {
  final TrackedFile file;
  final Snapshot? snapshot;

  const CompareView({super.key, required this.file, this.snapshot});

  @override
  ConsumerState<CompareView> createState() => _CompareViewState();
}

class _CompareViewState extends ConsumerState<CompareView> {
  bool _sideBySide = true;
  int _currentDiffIndex = -1;
  List<DiffLine> _currentDiffs = [];
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  bool _isLeftScrolling = false;

  @override
  void initState() {
    super.initState();

    // 加载差异数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDiff();
    });

    _leftScrollController.addListener(_syncScroll);
    _rightScrollController.addListener(_syncScroll);
  }

  Future<void> _loadDiff() async {
    final diffService = ref.read(diffServiceProvider);

    if (widget.snapshot != null) {
      final diffs = await diffService.getDiffBetweenFiles(
        fromFilePath: widget.snapshot!.snapshotPath,
        toFilePath: widget.file.filePath,
      );
      setState(() {
        _currentDiffs = diffs;
      });
    }
  }

  @override
  void dispose() {
    _leftScrollController.removeListener(_syncScroll);
    _rightScrollController.removeListener(_syncScroll);
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  void _syncScroll() {
    final left = _leftScrollController;
    final right = _rightScrollController;

    if (_isLeftScrolling) {
      if (right.position.pixels != left.position.pixels) {
        right.jumpTo(left.position.pixels);
      }
    } else {
      if (left.position.pixels != right.position.pixels) {
        left.jumpTo(right.position.pixels);
      }
    }
  }

  void _navigateToDiff(int index) {
    final diffs = _currentDiffs;
    final diffLines = diffs.where((d) => d.type != DiffLineType.same).toList();
    if (diffLines.isEmpty || index < 0 || index >= diffLines.length) return;

    setState(() {
      _currentDiffIndex = index;
    });

    // 找到目标差异行在原始 diffs 列表中的索引
    final targetLine = diffLines[index];
    final targetIndex = diffs.indexOf(targetLine);

    // 每行高度约 20px，滚动到目标位置
    const double itemHeight = 20.0;
    final scrollOffset = targetIndex * itemHeight;

    // 确保滚动位置不超过最大范围
    if (_leftScrollController.hasClients) {
      final maxScroll = _leftScrollController.position.maxScrollExtent;
      final target = scrollOffset.clamp(0.0, maxScroll);
      _leftScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    if (_rightScrollController.hasClients) {
      final maxScroll = _rightScrollController.position.maxScrollExtent;
      final target = scrollOffset.clamp(0.0, maxScroll);
      _rightScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildVersionDropdown(bool isLeft) {
    final label = widget.snapshot != null
        ? DateFormat('MM-dd HH:mm').format(widget.snapshot!.timestamp)
        : 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isLeft ? Icons.history : Icons.file_present,
            size: 14,
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isLeft ? '快照: $label' : '当前: ${widget.file.fileName}',
              style: AppTextStyles.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffLine(DiffLine line, bool showLeft) {
    Widget child;
    Color? bgColor;

    if (showLeft) {
      if (line.type == DiffLineType.removed || line.type == DiffLineType.same) {
        child = Text(line.content, style: AppTextStyles.body);
        bgColor = line.type == DiffLineType.removed
            ? AppColors.diffRemoved
            : null;
      } else {
        child = const SizedBox();
        bgColor = null;
      }
    } else {
      if (line.type == DiffLineType.added || line.type == DiffLineType.same) {
        child = Text(line.content, style: AppTextStyles.body);
        bgColor = line.type == DiffLineType.added ? AppColors.diffAdded : null;
      } else {
        child = const SizedBox();
        bgColor = null;
      }
    }

    return Container(
      color: bgColor,
      child: Row(
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerRight,
            child: Text(
              showLeft
                  ? (line.oldLineNumber > 0 ? '${line.oldLineNumber}' : '')
                  : (line.newLineNumber > 0 ? '${line.newLineNumber}' : ''),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSideBySideView(List<DiffLine> diffs) {
    _currentDiffs = diffs;
    final diffLines = diffs.where((d) => d.type != DiffLineType.same).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _buildVersionDropdown(true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('VS', style: AppTextStyles.heading3),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _buildVersionDropdown(false),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: AppColors.background,
                  child: ListView.builder(
                    controller: _leftScrollController,
                    itemCount: diffs.length,
                    itemBuilder: (context, index) {
                      return _buildDiffLine(diffs[index], true);
                    },
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Container(
                  color: AppColors.background,
                  child: ListView.builder(
                    controller: _rightScrollController,
                    itemCount: diffs.length,
                    itemBuilder: (context, index) {
                      return _buildDiffLine(diffs[index], false);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildNavigationBar(diffLines.length),
      ],
    );
  }

  Widget _buildUnifiedView(List<DiffLine> diffs) {
    _currentDiffs = diffs;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _buildVersionDropdown(true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('VS', style: AppTextStyles.heading3),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _buildVersionDropdown(false),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: diffs.length,
            itemBuilder: (context, index) {
              final line = diffs[index];
              Color? bgColor;
              String prefix = '';

              switch (line.type) {
                case DiffLineType.added:
                  bgColor = AppColors.diffAdded;
                  prefix = '+';
                  break;
                case DiffLineType.removed:
                  bgColor = AppColors.diffRemoved;
                  prefix = '-';
                  break;
                case DiffLineType.same:
                  bgColor = null;
                  prefix = ' ';
                  break;
              }

              return Container(
                color: bgColor,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        prefix,
                        style: AppTextStyles.caption.copyWith(
                          color: line.type == DiffLineType.added
                              ? AppColors.success
                              : line.type == DiffLineType.removed
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.centerRight,
                      child: Text(
                        line.oldLineNumber > 0 ? '${line.oldLineNumber}' : '',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.centerRight,
                      child: Text(
                        line.newLineNumber > 0 ? '${line.newLineNumber}' : '',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(line.content, style: AppTextStyles.body),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildNavigationBar(
          diffs.where((d) => d.type != DiffLineType.same).length,
        ),
      ],
    );
  }

  Widget _buildNavigationBar(int diffCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _currentDiffIndex > 0
                ? () => _navigateToDiff(_currentDiffIndex - 1)
                : null,
            disabledColor: AppColors.textSecondary,
          ),
          Text(
            _currentDiffIndex >= 0
                ? '差异 ${_currentDiffIndex + 1}/$diffCount'
                : '$diffCount 个差异',
            style: AppTextStyles.caption,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _currentDiffIndex < diffCount - 1
                ? () => _navigateToDiff(_currentDiffIndex + 1)
                : null,
            disabledColor: AppColors.textSecondary,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => setState(() => _sideBySide = !_sideBySide),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: Text(_sideBySide ? '上下对比' : '并排对比'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('对比 ${widget.file.fileName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.snapshot != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '快照: ${DateFormat('MM-dd HH:mm').format(widget.snapshot!.timestamp)}',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
          IconButton(
            icon: Icon(_sideBySide ? Icons.view_agenda : Icons.view_column),
            tooltip: _sideBySide ? '统一视图' : '并排视图',
            onPressed: () => setState(() => _sideBySide = !_sideBySide),
          ),
        ],
      ),
      body: _currentDiffs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.compare_arrows,
                    size: 48,
                    color: Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.snapshot == null ? '请从时间轴选择快照进行对比' : '未检测到差异',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            )
          : _sideBySide
          ? _buildSideBySideView(_currentDiffs)
          : _buildUnifiedView(_currentDiffs),
    );
  }
}
