import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'document/document_store.dart';
import 'document/document_workspace.dart';
import 'document/fixed_documents.dart';
import 'editor/widgets/markdown_editor.dart';
import 'editor/widgets/rendered_block.dart';

void main() {
  runApp(const MarkdownEditorDemoApp());
}

/// Markdown 编辑器 demo 入口：文件化多文档工作区。
class MarkdownEditorDemoApp extends StatelessWidget {
  const MarkdownEditorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown 编辑器 Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const WorkspacePage(),
    );
  }
}

enum _SwitchChoice { save, discard, cancel }

class _SaveIntent extends Intent {
  const _SaveIntent();
}

/// 工作区页面：抽屉文档切换 + 编辑器 + 保存（spec：document-files）。
///
/// [store] 供测试注入内存实现；生产代码走 [DocumentStore.create]。
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key, this.store});

  final DocumentStore? store;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  DocumentWorkspaceController? _workspace;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final workspace = DocumentWorkspaceController(
        store: widget.store ?? await DocumentStore.create(),
      );
      await workspace.loadInitial();
      MarkdownImage.basePath = workspace.basePath;
      if (mounted) setState(() => _workspace = workspace);
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) => _save(context),
          ),
        },
        child: Builder(
          builder: (context) {
            final workspace = _workspace;
            if (workspace == null) {
              return _loadingOrError();
            }
            return ListenableBuilder(
              listenable: workspace,
              builder: (context, _) => _buildScaffold(context, workspace),
            );
          },
        ),
      ),
    );
  }

  Widget _loadingOrError() {
    return Scaffold(
      body: Center(
        child:
            _loadError == null
                ? const CircularProgressIndicator()
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(height: 8),
                    Text('文档载入失败：$_loadError'),
                  ],
                ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    DocumentWorkspaceController workspace,
  ) {
    final dirty = workspace.isDirty();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${workspace.currentDocument.displayName}${dirty ? ' •' : ''}',
        ),
        actions: [
          IconButton(
            tooltip: '保存 (Ctrl+S)',
            icon: const Icon(Icons.save_outlined),
            onPressed: dirty ? () => _save(context) : null,
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('文档', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              for (final document in kFixedDocuments)
                ListTile(
                  key: ValueKey('doc-item-${document.fileName}'),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(document.displayName),
                  trailing:
                      workspace.isDirty(document.fileName)
                          ? Icon(
                            Icons.fiber_manual_record,
                            size: 10,
                            color: Theme.of(context).colorScheme.primary,
                          )
                          : null,
                  selected: document.fileName == workspace.currentFileName,
                  onTap: () => _onTapDocument(context, document),
                ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MarkdownEditor(
              // 切换文档即重挂载：载入目标文档内容，光标/焦点重置。
              key: ValueKey(workspace.currentFileName),
              initialBlocks: workspace.currentBlocks,
              onChanged: workspace.updateBlocks,
            ),
          ),
        ),
      ),
    );
  }

  /// 抽屉点击：脏文档先确认（保存/放弃/取消），随后切换（spec：未保存
  /// 修改的切换语义）。取消时抽屉保持打开、不发生切换。
  Future<void> _onTapDocument(
    BuildContext context,
    FixedDocument document,
  ) async {
    final workspace = _workspace!;
    if (document.fileName == workspace.currentFileName) {
      Navigator.of(context).pop();
      return;
    }
    if (workspace.isDirty()) {
      final choice = await showDialog<_SwitchChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('当前文档有未保存修改'),
          content: Text(
            '「${workspace.currentDocument.displayName}」尚未保存，要如何处理？',
          ),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.of(dialogContext).pop(_SwitchChoice.cancel),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed:
                  () =>
                      Navigator.of(dialogContext).pop(_SwitchChoice.discard),
              child: const Text('放弃修改并切换'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(dialogContext).pop(_SwitchChoice.save),
              child: const Text('保存并切换'),
            ),
          ],
        ),
      );
      switch (choice) {
        case null:
        case _SwitchChoice.cancel:
          return;
        case _SwitchChoice.save:
          await workspace.save();
        case _SwitchChoice.discard:
          workspace.discardUnsavedChanges();
      }
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    await workspace.selectDocument(document.fileName);
  }

  Future<void> _save(BuildContext context) async {
    final workspace = _workspace;
    if (workspace == null) return;
    await workspace.save();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存'), duration: Duration(seconds: 2)),
    );
  }
}
