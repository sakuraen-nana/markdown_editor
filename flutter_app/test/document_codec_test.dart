import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/editor/document_codec.dart';
import 'package:markdown_editor/editor/models/block.dart';

void main() {
  const codec = DocumentCodec();

  group('decode：载入分块', () {
    test('空行分隔的段落各自成块', () {
      final doc = codec.decode('第一段\n\n第二段');
      expect(doc.blocks.map((b) => b.text), ['第一段', '第二段']);
      expect(doc.trailingNewline, isFalse);
    });

    test('连续多行表格归为单个多行结构块', () {
      const table = '| a | b |\n| --- | --- |\n| 1 | 2 |';
      final doc = codec.decode('引言\n\n$table\n\n结尾');
      expect(doc.blocks.length, 3);
      expect(doc.blocks[1].text, table);
    });

    test('代码围栏内部空行不作为分块边界', () {
      const fenced = '```dart\nint a = 1;\n\nint b = 2;\n```';
      final doc = codec.decode(fenced);
      expect(doc.blocks.length, 1);
      expect(doc.blocks.single.text, fenced);
    });

    test('空文件得到单个空块', () {
      final doc = codec.decode('');
      expect(doc.blocks.length, 1);
      expect(doc.blocks.single.text, '');
      expect(doc.trailingNewline, isFalse);
    });

    test('载入块记录原始间隔为空行', () {
      final doc = codec.decode('A\n\nB');
      expect(doc.blocks[0].recordedSeparatorAfter, '\n\n');
      expect(doc.blocks[1].recordedSeparatorAfter, '\n\n');
    });
  });

  group('encode：保存回写', () {
    test('往返稳定：空行分段 + 围栏内空行 + 结尾换行', () {
      const source = '# 标题\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n\n'
          '```text\nx\n\ny\n```\n\n- 甲\n- 乙\n\n正文。\n';
      expect(codec.encode(codec.decode(source).blocks), source);
    });

    test('往返稳定：无结尾换行', () {
      const source = 'A\n\nB';
      final doc = codec.decode(source);
      expect(codec.encode(doc.blocks, trailingNewline: false), source);
    });

    test('往返稳定：松散列表的空行间隔不被改写', () {
      const source = '- 甲\n\n- 乙';
      expect(codec.encode(codec.decode(source).blocks, trailingNewline: false), source);
    });

    test('新建相邻表格行以单换行连接', () {
      final blocks = [
        const MdBlock(text: '| a | b |'),
        const MdBlock(text: '| --- | --- |'),
        const MdBlock(text: '| 1 | 2 |'),
      ];
      expect(codec.encode(blocks, trailingNewline: false), '| a | b |\n| --- | --- |\n| 1 | 2 |');
    });

    test('新建相邻列表项以单换行连接', () {
      final unordered = [
        const MdBlock(text: '- 甲'),
        const MdBlock(text: '- 乙'),
      ];
      expect(codec.encode(unordered, trailingNewline: false), '- 甲\n- 乙');

      final ordered = [
        const MdBlock(text: '1. 一'),
        const MdBlock(text: '2. 二'),
      ];
      expect(codec.encode(ordered, trailingNewline: false), '1. 一\n2. 二');
    });

    test('不同 bullet 字符不合并、普通段落以空行连接', () {
      final mixed = [const MdBlock(text: '- 甲'), const MdBlock(text: '* 乙')];
      expect(codec.encode(mixed, trailingNewline: false), '- 甲\n\n* 乙');

      final paragraphs = [const MdBlock(text: 'A'), const MdBlock(text: 'B')];
      expect(codec.encode(paragraphs, trailingNewline: false), 'A\n\nB');
    });

    test('recorded 间隔优先于结构连续规则', () {
      final blocks = [
        const MdBlock(text: '| a |', recordedSeparatorAfter: '\n\n'),
        const MdBlock(text: '| b |'),
      ];
      expect(codec.encode(blocks, trailingNewline: false), '| a |\n\n| b |');
    });

    test('引用行相邻合并', () {
      final quotes = [const MdBlock(text: '> 一'), const MdBlock(text: '> 二')];
      expect(codec.encode(quotes, trailingNewline: false), '> 一\n> 二');
    });
  });

  group('startsWithStructure：Enter 判定', () {
    test('结构前缀命中', () {
      expect(DocumentCodec.startsWithStructure('| a |'), isTrue);
      expect(DocumentCodec.startsWithStructure('> 引用'), isTrue);
      expect(DocumentCodec.startsWithStructure('```dart'), isTrue);
      expect(DocumentCodec.startsWithStructure('~~~'), isTrue);
      expect(DocumentCodec.startsWithStructure('- 甲'), isTrue);
      expect(DocumentCodec.startsWithStructure('* 乙'), isTrue);
      expect(DocumentCodec.startsWithStructure('1. 一'), isTrue);
    });

    test('标题与普通段落不命中', () {
      expect(DocumentCodec.startsWithStructure('# 标题'), isFalse);
      expect(DocumentCodec.startsWithStructure('正文'), isFalse);
      expect(DocumentCodec.startsWithStructure('-无空格'), isFalse);
    });
  });
}
