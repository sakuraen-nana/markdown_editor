import 'package:flutter/foundation.dart';

import '../editor/document_codec.dart';
import '../editor/models/block.dart';
import 'document_store.dart';
import 'fixed_documents.dart';
import 'template_assets.dart';

/// 单个已打开文档的运行时状态。
class _DocState {
  _DocState({
    required this.blocks,
    required this.savedContent,
    required this.trailingNewline,
  });

  List<MdBlock> blocks;

  /// 上次保存（或载入时规范化）后的内容，脏检测基线。
  String savedContent;
  bool trailingNewline;
}

/// 多文档工作区：固定文档集的确保创建、当前文档、脏状态、保存与切换
/// （spec：document-files 全部 Requirement）。
///
/// UI 层经 [updateBlocks] 回写编辑器内容，经 [selectDocument] /
/// [save] / [discardUnsavedChanges] 驱动切换与保存；未保存确认对话框
/// 由 UI 实现，按 [isDirty] 决定是否弹出。
class DocumentWorkspaceController extends ChangeNotifier {
  DocumentWorkspaceController({required this.store});

  final DocumentStore store;
  final Map<String, _DocState> _opened = {};
  String _currentFileName = kDefaultDocument.fileName;
  var _initialized = false;

  /// 当前打开的文档文件名。
  String get currentFileName => _currentFileName;

  /// 当前文档定义。
  FixedDocument get currentDocument => documentOf(_currentFileName);

  /// 存储根路径（模板图片相对路径解析基准）；内存实现为 null。
  String? get basePath => store.basePath;

  FixedDocument documentOf(String fileName) => kFixedDocuments.firstWhere(
    (document) => document.fileName == fileName,
  );

  /// 当前文档的块列表（载入或最近一次 [updateBlocks] 的内容）。
  List<MdBlock> get currentBlocks =>
      List.unmodifiable(_stateOf(_currentFileName).blocks);

  /// 启动初始化：复制模板图片资源、确保固定文档存在（缺失创建并写入
  /// 模板）、打开主文档（spec：固定文档集与自动创建、启动默认打开主文档）。
  Future<void> loadInitial() async {
    await TemplateAssets.ensureDemoImage(store.basePath);
    for (final document in kFixedDocuments) {
      if (!await store.exists(document.fileName)) {
        await store.write(document.fileName, document.template);
      }
    }
    await _open(_currentFileName);
    _initialized = true;
    notifyListeners();
  }

  /// 打开（惰性载入）文档。
  Future<void> _open(String fileName) async {
    if (_opened.containsKey(fileName)) return;
    final content = await store.read(fileName);
    final decoded = const DocumentCodec().decode(content ?? '');
    _opened[fileName] = _DocState(
      blocks: decoded.blocks,
      // 脏基线用规范化内容：CRLF 等格式差异不误报脏。
      savedContent: const DocumentCodec().encode(
        decoded.blocks,
        trailingNewline: decoded.trailingNewline,
      ),
      trailingNewline: decoded.trailingNewline,
    );
  }

  _DocState _stateOf(String fileName) {
    final state = _opened[fileName];
    if (state == null) {
      throw StateError('文档尚未打开：$fileName（应先 selectDocument/loadInitial）');
    }
    return state;
  }

  /// 文档是否有未保存修改（spec：手动保存与脏状态）。
  bool isDirty([String? fileName]) {
    final name = fileName ?? _currentFileName;
    final state = _opened[name];
    if (state == null) return false;
    return const DocumentCodec().encode(
          state.blocks,
          trailingNewline: state.trailingNewline,
        ) !=
        state.savedContent;
  }

  /// 编辑器内容变更回调：同步块列表；仅脏状态翻转时通知，避免逐键重建。
  void updateBlocks(List<MdBlock> blocks) {
    if (!_initialized) return;
    final state = _stateOf(_currentFileName);
    final wasDirty = isDirty();
    state.blocks = List.of(blocks);
    if (wasDirty != isDirty()) notifyListeners();
  }

  /// 保存当前文档（spec：手动保存与脏状态）。
  Future<void> save() async {
    final state = _stateOf(_currentFileName);
    final content = const DocumentCodec().encode(
      state.blocks,
      trailingNewline: state.trailingNewline,
    );
    await store.write(_currentFileName, content);
    state.savedContent = content;
    notifyListeners();
  }

  /// 放弃当前文档未保存修改（spec：未保存修改的切换语义·放弃）。
  void discardUnsavedChanges() {
    final state = _stateOf(_currentFileName);
    final decoded = const DocumentCodec().decode(state.savedContent);
    state.blocks = decoded.blocks;
    state.trailingNewline = decoded.trailingNewline;
    notifyListeners();
  }

  /// 切换到目标文档（spec：抽屉文档切换）。未保存确认由 UI 层先行处理。
  Future<void> selectDocument(String fileName) async {
    if (fileName == _currentFileName) return;
    await _open(fileName);
    _currentFileName = fileName;
    notifyListeners();
  }
}
