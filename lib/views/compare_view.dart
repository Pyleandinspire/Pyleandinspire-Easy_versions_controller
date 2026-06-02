import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:easy_versions_controller/utils/app_theme.dart';
import 'package:easy_versions_controller/services/diff_service.dart';
import 'package:easy_versions_controller/models/tracked_file.dart';

final diffProvider = FutureProvider.family<List<DiffLine>, ({TrackedFile file, String? fromOid, String? toOid})>(
  (ref, args) async {
    if (args.fromOid == null) {
      final diffService = ref.read(diffServiceProvider);
      return await diffService.getDiffFromCommit(
        repoPath: args.file.repoPath ?? '',
        commitOid: args.toOid ?? '',
        fileName: args.file.fileName,
      );
    }
    final diffService = ref.read(diffServiceProvider);
    return await diffService.getDiffBetweenVersions(
      repoPath: args.file.repoPath ?? '',
      fromOid: args.fromOid ?? '',
      toOid: args.toOid ?? '',
      fileName: args.file.fileName,
    );
  },
);

class CompareView extends ConsumerStatefulWidget {
  final TrackedFile file;
  final List<Map<String, dynamic>> commits;

  const CompareView({
    super.key,
    required this.file,
    required this.commits,
  });

  @override
  ConsumerState<CompareView> createState() => _CompareViewState();
}

class _CompareViewState extends ConsumerState<CompareView> {
  String? _fromOid;
  String? _toOid;
  bool _sideBySide = true;
  int _currentDiffIndex = -1;
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  bool _isLeftScrolling = false;

  @override
  void initState() {
    super.initState();
    if (widget.commits.length >= 2) {
      _fromOid = widget.commits[1]['oid'] as String;
      _toOid = widget.commits[0]['oid'] as String;
    } else if (widget.commits.length == 1) {
      _toOid = widget.commits[0]['oid'] as String;
    }

    _leftScrollController.addListener(_syncScroll);
    _rightScrollController.addListener(_syncScroll);
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

  void _navigateToDiff(int index, List<DiffLine> diffs) {
    final diffLines = diffs.where((d) => d.type != DiffLineType.same).toList();
    if (diffLines.isNotEmpty && index >= 0 && index < diffLines.length) {
      setState(() {
        _currentDiffIndex = index;
      });
    }
  }

  Widget _buildVersionDropdown(bool isLeft) {
    final currentOid = isLeft ? _fromOid : _toOid;
    
    return DropdownButton<String?>(
      value: currentOid,
      hint: Text(isLeft ? '选择基准版本' : '选择对比版本'),
      items: [
        if (isLeft)
          const DropdownMenuItem(
            value: null,
            child: Text('初始状态'),
          ),
        ...widget.commits.map((commit) {
          final oid = commit['oid'] as String;
          final time = commit['time'] as int;
          final message = commit['message'] as String;
          final dateStr = DateFormat('MM-dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(time * 1000),
          );
          
          return DropdownMenuItem(
            value: oid,
            child: Text(
              '$dateStr - ${message.trim().split('\n').first}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          if (isLeft) {
            _fromOid = value;
          } else {
            _toOid = value;
          }
          _currentDiffIndex = -1;
        });
      },
      isExpanded: true,
    );
  }

  Widget _buildDiffLine(DiffLine line, bool showLeft) {
    Widget child;
    Color? bgColor;

    if (showLeft) {
      if (line.type == DiffLineType.removed || line.type == DiffLineType.same) {
        child = Text(line.content, style: AppTextStyles.body);
        bgColor = line.type == DiffLineType.removed ? AppColors.diffRemoved : null;
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
              showLeft ? (line.oldLineNumber > 0 ? '${line.oldLineNumber}' : '') : (line.newLineNumber > 0 ? '${line.newLineNumber}' : ''),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSideBySideView(List<DiffLine> diffs) {
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
                case DiffLineType.context:
                  bgColor = AppColors.diffContext;
                  prefix = '~';
                  break;
              }

              return Container(
                color: bgColor,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(prefix, style: AppTextStyles.caption.copyWith(
                        color: line.type == DiffLineType.added ? AppColors.success : 
                               line.type == DiffLineType.removed ? AppColors.error : AppColors.textSecondary,
                      )),
                    ),
                    Container(
                      width: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.centerRight,
                      child: Text(
                        line.oldLineNumber > 0 ? '${line.oldLineNumber}' : '',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.centerRight,
                      child: Text(
                        line.newLineNumber > 0 ? '${line.newLineNumber}' : '',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
        _buildNavigationBar(diffs.where((d) => d.type != DiffLineType.same).length),
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
            onPressed: _currentDiffIndex > 0 ? () => _navigateToDiff(_currentDiffIndex - 1, []) : null,
            disabledColor: AppColors.textSecondary,
          ),
          Text(
            _currentDiffIndex >= 0 ? '差异 ${_currentDiffIndex + 1}/$diffCount' : '$diffCount 个差异',
            style: AppTextStyles.caption,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _currentDiffIndex < diffCount - 1 ? () => _navigateToDiff(_currentDiffIndex + 1, []) : null,
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
    final diffsAsync = ref.watch(
      diffProvider((
        file: widget.file,
        fromOid: _fromOid,
        toOid: _toOid,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('对比 ${widget.file.fileName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: diffsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e', style: AppTextStyles.bodySecondary)),
        data: (diffs) => _sideBySide ? _buildSideBySideView(diffs) : _buildUnifiedView(diffs),
      ),
    );
  }
}
