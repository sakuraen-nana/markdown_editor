import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/editor/widgets/chart_block_view.dart';
import 'package:markdown_editor/editor/widgets/rendered_block.dart';

void main() {
  tearDown(() => MarkdownImage.basePath = null);

  testWidgets('合法定义渲染折线图，非法内容回退代码样式不崩溃', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: const [
                ChartBlockView(body: 'type: line\ntitle: 周数据\nx: 一, 二, 三\ny: 3, 5, 8'),
                ChartBlockView(body: 'type: pie\nlabels: a, b'),
                ChartBlockView(body: 'type: line\nx: 一, 二\ny: 1, abc'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(LineChart), findsOneWidget, reason: '仅合法折线图被渲染');
    expect(find.text('周数据'), findsOneWidget);
    expect(find.text('type: pie\nlabels: a, b'), findsOneWidget, reason: '未知类型回退源码');
    expect(find.text('type: line\nx: 一, 二\ny: 1, abc'), findsOneWidget, reason: '数值非法回退源码');
  });

  testWidgets('渲染态 chart 围栏经 blockComponents 呈现图表', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RenderedBlock(text: '```chart\ntype: line\nx: 一, 二\ny: 1, 2\n```'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(LineChart), findsOneWidget);
    expect(
      tester.widgetList<LineChart>(find.byType(LineChart)).first.data.lineBarsData.first.spots.map((s) => s.y),
      [1, 2],
    );
  });

  group('MarkdownImage 路径解析（design D7）', () {
    test('file:// 与绝对路径按字面解析', () {
      expect(
        MarkdownImage.resolvePath('file:///tmp/x/a.png'),
        '/tmp/x/a.png',
      );
      expect(MarkdownImage.resolvePath('/tmp/x/a.png'), '/tmp/x/a.png');
      expect(MarkdownImage.resolvePath(r'C:\x\a.png'), r'C:\x\a.png');
    });

    test('相对路径拼接数据目录；未设置基准时无法解析', () {
      MarkdownImage.basePath = '/base/dir';
      expect(MarkdownImage.resolvePath('assets/a.png'), '/base/dir/assets/a.png');
      MarkdownImage.basePath = null;
      expect(MarkdownImage.resolvePath('assets/a.png'), isNull);
    });
  });

  testWidgets('本地相对路径命中数据目录文件时构造本地图片', (tester) async {
    // 真实文件 IO 必须包在 runAsync 里：testWidgets 的假异步区不会
    // 回调真实 IO 的完成事件（本环境实测会挂起）。
    late Directory temp;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('md_img_test');
      // 1x1 PNG。
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      final assetDir = Directory('${temp.path}/assets');
      await assetDir.create(recursive: true);
      await File('${assetDir.path}/demo-image.png').writeAsBytes(png);
    });
    MarkdownImage.basePath = temp.path;

    // 只取 context，不挂载 Image 本身：挂载会触发真实图片解码，
    // 挂载级验证交给桌面端手动场景（tasks 7.2）。
    BuildContext? context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (innerContext) {
            context = innerContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final widget = MarkdownImage.build(context!, 'assets/demo-image.png', null, null);
    expect(widget, isA<Image>());
    expect((widget as Image).image, isA<FileImage>());

    await tester.runAsync(() => temp.delete(recursive: true));
  });

  testWidgets('本地图片缺失显示错误占位不崩溃', (tester) async {
    MarkdownImage.basePath = '/nonexistent-base-for-test';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RenderedBlock(text: '![缺失图](assets/no-such-image.png)'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('图片缺失'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
