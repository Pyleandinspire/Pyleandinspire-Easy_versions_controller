import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

class XlsxSheet {
  final String name;
  final List<List<String>> rows;

  const XlsxSheet({required this.name, required this.rows});
}

class XlsxParserService {
  /// 解析 XLSX 文件，返回所有工作表
  static List<XlsxSheet> parse(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    return parseBytes(bytes);
  }

  /// 从字节数据解析 XLSX
  static List<XlsxSheet> parseBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. 解析共享字符串表
    final sharedStrings = _parseSharedStrings(archive);

    // 2. 解析工作表名称和顺序
    final sheetNames = _parseSheetNames(archive);

    // 3. 解析每个工作表的数据
    final sheets = <XlsxSheet>[];
    for (int i = 0; i < sheetNames.length; i++) {
      final sheetPath = 'xl/worksheets/sheet${i + 1}.xml';
      final rows = _parseSheetData(archive, sheetPath, sharedStrings);
      sheets.add(XlsxSheet(name: sheetNames[i], rows: rows));
    }

    return sheets;
  }

  /// 解析共享字符串表
  static List<String> _parseSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return [];

    final content = utf8.decode(file.content as List<int>);
    final document = XmlDocument.parse(content);
    final strings = <String>[];

    for (final si in document.findAllElements('si')) {
      // 简单文本
      final t = si.findAllElements('t');
      if (t.isNotEmpty) {
        strings.add(t.map((e) => e.innerText).join());
      } else {
        strings.add('');
      }
    }

    return strings;
  }

  /// 解析工作表名称
  static List<String> _parseSheetNames(Archive archive) {
    final file = archive.findFile('xl/workbook.xml');
    if (file == null) return ['Sheet1'];

    final content = utf8.decode(file.content as List<int>);
    final document = XmlDocument.parse(content);
    final names = <String>[];

    for (final sheet in document.findAllElements('sheet')) {
      final name = sheet.getAttribute('name') ?? 'Sheet${names.length + 1}';
      names.add(name);
    }

    return names.isEmpty ? ['Sheet1'] : names;
  }

  /// 解析工作表数据
  static List<List<String>> _parseSheetData(
    Archive archive,
    String sheetPath,
    List<String> sharedStrings,
  ) {
    final file = archive.findFile(sheetPath);
    if (file == null) return [];

    final content = utf8.decode(file.content as List<int>);
    final document = XmlDocument.parse(content);

    final rows = <List<String>>[];
    final maxRows = 100; // 限制最大行数
    final maxCols = 50; // 限制最大列数

    for (final rowElement in document.findAllElements('row')) {
      if (rows.length >= maxRows) break;

      final rowNum = int.tryParse(rowElement.getAttribute('r') ?? '0') ?? 0;
      // 确保行按顺序排列
      while (rows.length < rowNum - 1) {
        rows.add([]);
      }

      final cells = <String>[];
      for (final cell in rowElement.findAllElements('c')) {
        if (cells.length >= maxCols) break;

        final cellRef = cell.getAttribute('r') ?? '';
        final cellType = cell.getAttribute('t') ?? '';
        final valueElement = cell.findAllElements('v').firstOrNull;
        final value = valueElement?.innerText ?? '';

        String cellValue;
        if (cellType == 's') {
          // 共享字符串
          final idx = int.tryParse(value) ?? 0;
          cellValue = idx < sharedStrings.length ? sharedStrings[idx] : '';
        } else if (cellType == 'b') {
          // 布尔值
          cellValue = value == '1' ? 'TRUE' : 'FALSE';
        } else {
          cellValue = value;
        }

        // 填充列到正确位置
        final colIndex = _columnIndex(cellRef);
        while (cells.length < colIndex) {
          cells.add('');
        }
        cells.add(cellValue);
      }

      rows.add(cells);
    }

    return rows;
  }

  /// 从单元格引用（如 "A1", "AB3"）提取列索引（0-based）
  static int _columnIndex(String cellRef) {
    final letters = cellRef.replaceAll(RegExp(r'\d'), '');
    int index = 0;
    for (int i = 0; i < letters.length; i++) {
      index = index * 26 + (letters.codeUnitAt(i) - 'A'.codeUnitAt(0) + 1);
    }
    return index - 1;
  }
}
