# 设计：file-backed-multi-doc-editing

## Context

现有编辑器为块级双态架构（见 `lib/editor/`）：文档 = `MdBlock(id, text)` 列表，聚焦块 `EditableText` 编辑态，失焦块 `GptMarkdown` 渲染态；`MarkdownEditor` 对外暴露 `initialBlockTexts`（仅 initState 读一次）与 `onChanged(List<MdBlock>)`。文档目前硬编码在 `main.dart`，无持久化。

gpt_markdown 1.3.0 现行扩展点已确认：`blockComponents: [MarkdownBlockComponent(syntax: FencedBlockSyntax(type:, opening:), builder:)]` 注册自定义围栏块；`imageBuilder(context, url, width, height)` 重定向图片渲染（默认实现为 `NetworkImage`）。两处均为现行 API，不触碰 deprecated 面。

真实文件引入的核心结构性问题：表格/围栏/引用/列表是多行结构，而现有「块 = 单段文本、Enter 一律拆块」模型会将其拆散。本设计给出块模型的扩展方案。

## Goals / Non-Goals

**Goals:**

- 文件 ↔ 块列表的双向映射：载入分块（围栏感知）、保存回写（往返稳定 + 新建结构块紧凑连接）。
- 多行结构块内的编辑行为（Enter 插入换行）。
- 最小可用的多文档工作区：固定文档集、自动创建、默认打开、手动保存、抽屉切换、未保存确认。
- chart 围栏块与本地图片两个渲染扩展，补齐模板所需的「图」与图片。

**Non-Goals:**

- 另存为、新建/删除/重命名文档、目录树、文件选择器。
- web 平台真实文件 IO。
- 智能续写（Enter 后自动补 `- `/`> `/`| ` 前缀）、行号、搜索替换、撤销栈增强。
- 复杂图表类型（首版仅折线图）。

## Decisions

### D1 存储层：`DocumentStore` 接口 + 文件/内存双实现

```dart
abstract class DocumentStore {
  Future<String?> read(String fileName);
  Future<void> write(String fileName, String content);
  Future<bool> exists(String fileName);
}
```

- `FileDocumentStore`：基于 `path_provider` 的 `getApplicationDocumentsDirectory()`，文件位于 `<docs>/MarkdownEditor/` 子目录（桌面端文档目录是用户可见目录，子目录避免污染；移动端该目录本身即应用私有）。
- `MemoryDocumentStore`：`kIsWeb` 时使用，进程内 Map 承载，重启即失（等同现状，web 降级已被 proposal 声明为非目标）。
- 目录不存在由首次写入/检查时按需创建（`Directory.create(recursive: true)`）。

备选：直接散落调用 `File` API——放弃，可测性与 web 降级都要求接口隔离。

### D2 块模型：`MdBlock` 增加边界元数据

`MdBlock` 增加可空字段 `recordedSeparatorAfter`（`'\n'` | `'\n\n'` | null）：

- **载入时**：相邻块之间原本以单个换行相接（只发生在围栏内，不会出现——围栏整体一块）——实际上文件级分块边界都是空行，故载入产生的块该字段恒为 `'\n\n'`；字段为未来更细的分块预留，当前仅用于保存。
- **新建块**（Enter 拆分、初始构造无记录时）：null。
- **保存时**：`recordedSeparatorAfter != null` → 原样使用（保证往返稳定，即使原文件有 `| a |` 空行 `| b |` 这种罕见写法也不被改写）；为 null → 按结构连续规则计算（见 D5）。

`MarkdownEditor` 构造参数从 `initialBlockTexts: List<String>` 改为 `initialBlocks: List<MdBlock>`（内部 API，调用方仅 `main.dart`）；`onChanged(List<MdBlock>)` 不变。

备选：保存时统一智能连接、不存元数据——放弃，会把既有文件中的松散列表/独立表格改写为紧凑形式，违反往返稳定。

### D3 载入分块：围栏感知的空行切分

逐行扫描：

1. 围栏状态机：行 trim 后以 ```` ``` ```` 或 `~~~` 开头即翻转围栏开闭状态（开围栏时记录标记类型，闭围栏须匹配同标记）。
2. 围栏外的空行（trim 后为空）为分块边界；围栏内空行忽略。
3. 非空行持续累积为当前块，块内行以 `\n` 连接。
4. 首尾空白行忽略；文件末尾是否以换行结束记录为 `trailingNewline` 布尔值（D4 使用）；空文件 → 单个空块。

### D4 保存序列化

- 块间连接符按 D2 计算，块内容原样写出（块内 `\n` 保留）。
- 文件末尾：`trailingNewline`（载入时记录；新建文档默认 true）→ 写出单个结尾换行。
- 脏检测：保存用内容 = 当前块列表序列化结果；与「上次已保存内容」字符串比对，不同即脏。`onChanged` 时比较而非仅置位，避免空改动误标脏。

### D5 结构判定与连接规则

- **Enter 不拆块的判定**：块文本含 `\n`（已是多行结构块），或块首行（trim 后）匹配结构前缀——表格行 `|`、引用 `>`、围栏 ```` ``` ````/`~~~`、无序列表 `- `/`* `/`+ `、有序列表 `N. `。标题 `#`、普通段落不在集合内（Enter 仍拆块）。
- **新建块边界的紧凑连接判定**（两侧块首行）：
  - 表格连续：两侧均以 `|` 开头；
  - 引用连续：两侧均以 `>` 开头；
  - 列表连续：两侧为同种列表——无序要求同一 bullet 字符（CommonMark 中 `-` 与 `*` 相邻是两个列表），有序只要求均为 `N. ` 形式；
  - 其余 → 空行连接。

### D6 chart 围栏块：现行 `blockComponents` 扩展

```dart
MarkdownBlockComponent(
  syntax: const FencedBlockSyntax(type: 'chart', opening: '```chart'),
  builder: (context, node, config) => ChartBlockView(body: node.body),
)
```

- 内容格式为行式 `key: value`（简单可手写，无需引入 YAML 依赖）：

  ~~~
  ```chart
  type: line
  title: 周浏览量
  x: 周一, 周二, 周三, 周四, 周五
  y: 12, 19, 8, 15, 22
  ```
  ~~~

- `ChartBlockView` 解析后用 fl_chart `LineChart` 渲染；`type` 或数值列解析失败 → 回退为代码块样式容器展示原始文本（满足规格的降级要求），不抛异常。
- `RenderedBlock` 挂载该 `blockComponents`；实例保持在 State 字段以保持稳定引用（官方文档要求，避免反复失效解析缓存）。

备选：mermaid（WebView 重、平台参差）、本地图片充当图（与「图片」重复）——用户已选 chart 块路线。

### D7 本地图片：`imageBuilder` 分流

`imageBuilder(context, url, w, h)`：

- `http`/`https` 开头 → 复刻默认行为（`Image.network` + loading/error builder）。
- `file://` 前缀剥离后按绝对路径；其余按相对路径 → 拼接存储目录（`<docs>/MarkdownEditor/`）。
- `Image.file` 渲染，`errorBuilder` 显示自带占位（图标 + 「图片缺失」文案），不崩溃。

### D8 模板与内置图片资产

- `flutter_app/assets/images/` 打包一张小尺寸占位图（实现时生成，如纯色 + 文字示意图 PNG）。
- 应用启动确保数据目录存在 `assets/demo-image.png`：不存在则从内置资产复制（`rootBundle.load` → `File.writeAsBytes`）；web 上跳过（内存存储，图片显示错误占位，可接受降级）。
- 模板引用相对路径：`![示例图片](assets/demo-image.png)`。
- 三个固定文档模板集中在 `lib/document/fixed_documents.dart`：`fileName` / `displayName` / `template` 三元组，`welcome.md` 模板按规格覆盖全部特性，`notes.md`（会议笔记示例：标题/列表/引用/表格）、`todo.md`（待办清单示例：任务勾选/有序列表/高亮）。

### D9 应用结构与状态

- 新增 `lib/document/document_workspace.dart`：`DocumentWorkspaceController extends ChangeNotifier`——持有 store、固定文档定义、各文档最新块列表与已保存内容、当前文档名、脏集合；提供 `loadInitial()`（确保文件存在 + 读主文档）、`switchTo(name)`、`save()`、`updateBlocks(blocks)`。
- `main.dart` 改为 `Scaffold`：AppBar（标题 = 当前文档显示名 + 脏标记「•」，actions = 保存 IconButton）；`Drawer` = 文档列表（`ListTile`：显示名 + 脏标记圆点，当前项高亮）；body = `MarkdownEditor`。
- **切换 = 以 `ValueKey(文档名)` 重挂载 `MarkdownEditor`**，`initialBlocks` 传目标文档块列表。光标/焦点重置是切换文档的合理语义，且避免为编辑器增加双向数据流。当前文档的块列表在每次 `onChanged` 时已同步进 controller，切换不丢数据。
- 保存快捷键：外层 `Shortcuts` + `Actions` 注册 `Ctrl+S`（Apple 平台 `Meta+S`，用 `DefaultSelectionStyle`… 不，直接两个 `SingleActivator` 变体并存注册），触发 `controller.save()`；保存成功用 `SnackBar` 反馈。
- 不引入状态管理库（provider/riverpod）：单个页面级状态，`ChangeNotifier` + `ListenableBuilder` 足够，避免为 demo 引入架构依赖。

### D10 编辑器键盘行为改造

`MarkdownEditor._handleKey` 的 Enter 分支增加 D5 的结构块判定：判定命中 → `controller.value` 在选区处替换插入 `\n`（`copyWith` 同时清 composing，避免与输入法组合态冲突），不拆块；未命中 → 现有拆块逻辑。Backspace 合并逻辑不变。

## Risks / Trade-offs

- [块列表整体序列化在每次 `onChanged` 做字符串比对，长文档下 O(n)] → demo 规模（KB 级）可忽略；规格不做性能承诺，后续可增量比对。
- [CRLF 文件载入后统一按 LF 处理，保存回写换行符改变（行内容不变）] → 往返稳定按行内容定义；风险已被规格场景范围覆盖（模板与测试文件均为 LF）。
- [多行结构块在编辑态是单个 `EditableText`，无渲染负担，但失焦后整块 `GptMarkdown` 全量渲染，超大表格块可能卡顿] → demo 规模可接受；渲染态本就整块刷新，非本提案引入。
- [fl_chart 在各平台的渲染差异（字体/尺寸）] → 图表尺寸用固定容器高度 + `AspectRatio`，模板数据简单，降低差异面。
- [web 上相对路径图片必然缺失 → 错误占位] → 已接受的降级，template 与文档字符串仍正确。
- [切换文档用重挂载而非编辑器复用，`MarkdownEditor` 失去「外部换内容」能力] → 换取零双向绑定复杂度；未来需要原地换内容时再增加显式 `loadDocument` API（记为后续，不在本提案）。

## Open Questions

无——资产图片的具体内容由实施时生成，不影响规格与任务拆分。
