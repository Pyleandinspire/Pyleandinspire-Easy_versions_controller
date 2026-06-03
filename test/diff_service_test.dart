import 'package:flutter_test/flutter_test.dart';
import 'package:easy_versions_controller/services/diff_service.dart';

/// 阶段四测试: DiffService LCS 差异对比算法
void main() {
  group('DiffService - LCS算法差异对比', () {
    late DiffService diffService;

    setUp(() {
      diffService = DiffService();
    });

    test('diff_01: 完全相同的文本返回全部 same 行', () {
      const text = 'line1\nline2\nline3';
      final diffs = diffService.getDiffBetweenTexts(
        fromText: text,
        toText: text,
      );

      expect(diffs.length, 3);
      for (final d in diffs) {
        expect(d.type, DiffLineType.same);
      }
    });

    test('diff_02: 新增行检测', () {
      const from = 'line1\nline2';
      const to = 'line1\nline2\nline3';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      final addedLines = diffs.where((d) => d.type == DiffLineType.added);
      expect(addedLines.length, 1);
      expect(addedLines.first.content, 'line3');
    });

    test('diff_03: 删除行检测', () {
      const from = 'line1\nline2\nline3';
      const to = 'line1';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      final removedLines = diffs.where((d) => d.type == DiffLineType.removed);
      expect(removedLines.length, 2);
      expect(removedLines.first.content, 'line2');
      expect(removedLines.last.content, 'line3');
    });

    test('diff_04: 修改行检测（删除+新增）', () {
      const from = 'old line';
      const to = 'new line';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      final removed = diffs.where((d) => d.type == DiffLineType.removed);
      final added = diffs.where((d) => d.type == DiffLineType.added);

      expect(removed.length, 1);
      expect(removed.first.content, 'old line');
      expect(added.length, 1);
      expect(added.first.content, 'new line');
    });

    test('diff_05: 空文本 -> 新文本（全部新增）', () {
      const from = '';
      const to = 'new\nfile\ncontent';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      final addedLines = diffs.where((d) => d.type == DiffLineType.added);
      expect(addedLines.length, 3);
    });

    test('diff_06: 有文本 -> 空文本（全部删除）', () {
      const from = 'delete\nme\nall';
      const to = '';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      final removedLines = diffs.where((d) => d.type == DiffLineType.removed);
      expect(removedLines.length, 3);
    });

    test('diff_07: 多行混合变更（新增+删除+相同）', () {
      const from = 'keep1\nremove_me\nkeep2\nold_line';
      const to = 'keep1\nkeep2\nnew_line';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      final same = diffs.where((d) => d.type == DiffLineType.same);
      final removed = diffs.where((d) => d.type == DiffLineType.removed);
      final added = diffs.where((d) => d.type == DiffLineType.added);

      expect(same.length, 2); // keep1, keep2
      expect(removed.length, 2); // remove_me, old_line
      expect(added.length, 1); // new_line
    });

    test('diff_08: 行号正确分配', () {
      const from = 'line1\nline2\nline3';
      const to = 'line1\nline3';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      // 应该保持 line1(same), line2(removed), line3(same)
      expect(diffs[0].type, DiffLineType.same);
      expect(diffs[0].oldLineNumber, 1);
      expect(diffs[0].newLineNumber, 1);

      expect(diffs[1].type, DiffLineType.removed);
      expect(diffs[1].oldLineNumber, 2);
      expect(diffs[1].newLineNumber, -1);

      expect(diffs[2].type, DiffLineType.same);
      expect(diffs[2].oldLineNumber, 3);
      expect(diffs[2].newLineNumber, 2);
    });

    test('diff_09: 中等大小文本（100行）响应时间', () {
      final fromLines = List.generate(100, (i) => 'line_$i');
      final toLines = List.generate(100, (i) {
        // 每10行修改一行
        return i % 10 == 0 ? 'modified_$i' : 'line_$i';
      });

      final from = fromLines.join('\n');
      final to = toLines.join('\n');

      final stopwatch = Stopwatch()..start();
      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);
      stopwatch.stop();

      // 应有10行修改（20个diff条目：10删除+10新增）
      final changed = diffs.where((d) => d.type != DiffLineType.same);
      expect(changed.length, 20);

      // 响应时间应在合理范围
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('diff_10: 跨平台行分隔符兼容（\\r\\n）', () {
      // Windows 风格换行符
      const from = 'line1\r\nline2\r\nline3';
      const to = 'line1\r\nline2_modified\r\nline3';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      final changed = diffs.where((d) => d.type != DiffLineType.same);
      expect(changed.length, 2); // 1删除 + 1新增
    });

    test('diff_11: 空行为空字符串时正确处理', () {
      const from = 'line1\n\nline3';
      const to = 'line1\nline2\nline3';

      final diffs = diffService.getDiffBetweenTexts(fromText: from, toText: to);

      final removed = diffs.where((d) => d.type == DiffLineType.removed);
      final added = diffs.where((d) => d.type == DiffLineType.added);

      expect(removed.length, 1);
      expect(removed.first.content, '');
      expect(added.length, 1);
      expect(added.first.content, 'line2');
    });
  });
}
