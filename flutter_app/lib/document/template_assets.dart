import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 模板内置资源：应用打包的占位图，首次启动复制到数据目录
/// `assets/demo-image.png`（design D8），模板按相对路径引用。
class TemplateAssets {
  TemplateAssets._();

  /// 内置资产在应用包内的路径。
  static const String bundledImage = 'assets/images/demo_image.png';

  /// 数据目录中的相对路径（即模板中 `![…](…)` 引用的路径）。
  static const String demoImageRelativePath = 'assets/demo-image.png';

  /// 确保 `[baseDirPath]/assets/demo-image.png` 存在；已存在则跳过。
  /// [baseDirPath] 为 null（内存存储 / web）时整体跳过。
  static Future<void> ensureDemoImage(String? baseDirPath) async {
    if (kIsWeb || baseDirPath == null) return;
    final target = File(
      '$baseDirPath${Platform.pathSeparator}$demoImageRelativePath',
    );
    if (await target.exists()) return;
    final bytes = await rootBundle.load(bundledImage);
    await target.create(recursive: true);
    await target.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }
}
