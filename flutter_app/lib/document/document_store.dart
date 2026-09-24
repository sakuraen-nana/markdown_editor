import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 文档存储抽象：文件实现（移动/桌面）与内存实现（web 降级，design D1）。
abstract class DocumentStore {
  /// 存储根目录的路径；内存实现无文件系统返回 null。
  /// （模板图片相对路径的解析基准，见 design D7。）
  String? get basePath;

  /// 读文件内容；不存在返回 null。
  Future<String?> read(String fileName);

  /// 写入（覆盖）文件内容。
  Future<void> write(String fileName, String content);

  Future<bool> exists(String fileName);

  /// 按平台创建实现：web 无文件系统，用内存实现；其余走应用文档目录
  /// 下的 `MarkdownEditor/` 子目录。
  static Future<DocumentStore> create() async {
    if (kIsWeb) return MemoryDocumentStore();
    return FileDocumentStore.create();
  }
}

class FileDocumentStore implements DocumentStore {
  FileDocumentStore(this.baseDir);

  /// 文档目录（存储根）。
  final Directory baseDir;

  @override
  String? get basePath => baseDir.path;

  static Future<FileDocumentStore> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}MarkdownEditor');
    return FileDocumentStore(dir);
  }

  Future<Directory> _ensureBaseDir() async =>
      baseDir.create(recursive: true);

  File _fileOf(String fileName) =>
      File('${baseDir.path}${Platform.pathSeparator}$fileName');

  @override
  Future<String?> read(String fileName) async {
    final file = _fileOf(fileName);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String fileName, String content) async {
    await _ensureBaseDir();
    await _fileOf(fileName).writeAsString(content, flush: true);
  }

  @override
  Future<bool> exists(String fileName) => _fileOf(fileName).exists();
}

/// web 降级实现：进程内 Map 承载，重启即失（proposal 已声明为非目标场景）。
class MemoryDocumentStore implements DocumentStore {
  final Map<String, String> _files = {};

  @override
  String? get basePath => null;

  @override
  Future<String?> read(String fileName) async => _files[fileName];

  @override
  Future<void> write(String fileName, String content) async =>
      _files[fileName] = content;

  @override
  Future<bool> exists(String fileName) async => _files.containsKey(fileName);
}
