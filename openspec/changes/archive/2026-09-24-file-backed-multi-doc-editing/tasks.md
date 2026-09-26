# 任务：file-backed-multi-doc-editing

> 所有 `flutter` / `dart` 命令在 `flutter_app/` 目录下执行。实施遵循 AGENTS.md：gpt_markdown 只用现行 API。

## 1. 依赖与资产准备

- [x] 1.1 在 `pubspec.yaml` 声明 `path_provider` 与 `fl_chart`，`flutter pub get` 成功且 `flutter analyze` 无新增告警
- [x] 1.2 创建 `flutter_app/assets/images/` 并放入一张小尺寸占位图（实现时生成 PNG），在 `pubspec.yaml` 注册 assets，验证构建能打包该资产

## 2. 块模型与文件映射（design D2/D3/D4/D5/D10）

- [x] 2.1 `MdBlock` 增加 `recordedSeparatorAfter` 可空字段，`MarkdownEditor` 构造参数改为 `initialBlocks: List<MdBlock>`，`main.dart` 调用同步修改；验证 `flutter analyze` 通过
- [x] 2.2 实现围栏感知载入分块（空行边界、围栏内空行忽略、`trailingNewline` 记录），单元测试覆盖：表格归单块、围栏内空行不拆分、空行分段、空文件
- [x] 2.3 实现保存序列化（recordedSeparator 优先、新建边界按结构连续规则、结尾换行还原），单元测试覆盖：往返稳定（含围栏内空行与松散列表）、新建相邻表格行/列表项以 `\n` 连接、普通段落以空行连接
- [x] 2.4 `MarkdownEditor` Enter 分支增加结构块判定（含 `\n` 或表格行/引用/围栏/列表前缀开头 → 插入 `\n` 不拆块，清 composing），widget 测试覆盖：普通段落拆块、表格行块续行、列表行块续行
- [x] 2.5 Backspace 合并块在多行块场景下回归验证（既有 widget 测试通过）

## 3. 存储层（design D1）

- [x] 3.1 定义 `DocumentStore` 接口并实现 `FileDocumentStore`（`getApplicationDocumentsDirectory()/MarkdownEditor/`，按需建目录）；单元测试（临时目录注入）覆盖读写、exists、缺失返回 null
- [x] 3.2 实现 `MemoryDocumentStore` 并以 `kIsWeb` 分流创建；单元测试覆盖内存读写在 `FileDocumentStore` 相同契约下表现一致

## 4. 固定文档与模板（design D8）

- [x] 4.1 `lib/document/fixed_documents.dart` 定义 3 个固定文档（`welcome.md`/`notes.md`/`todo.md`：fileName、displayName、template）；`welcome.md` 模板覆盖规格所列全部特性样例，其余两文档为有效 Markdown 模板；测试断言模板中含每类特性标记
- [x] 4.2 实现内置图片资产复制到数据目录（`assets/demo-image.png`，存在则跳过，web 跳过）；单元测试：缺失时复制成功、已存在不覆盖

## 5. 渲染扩展：chart 块与本地图片（design D6/D7）

- [x] 5.1 实现 `ChartBlockView`（行式 key:value 解析 + fl_chart 折线图；解析失败回退代码块样式容器），widget 测试：合法定义渲染出图表、非法内容显示源码不抛异常
- [x] 5.2 `RenderedBlock` 以 State 字段持有稳定的 `blockComponents` 列表并挂载 chart 组件；widget 测试：渲染态 ```` ```chart ```` 围栏呈现图表
- [x] 5.3 `RenderedBlock` 增加 `imageBuilder` 分流（http 走网络、file:// 与绝对路径按字面、相对路径拼接存储目录、缺失显示错误占位）；widget 测试覆盖相对路径命中与缺失占位

## 6. 工作区与应用壳（design D9）

- [x] 6.1 实现 `DocumentWorkspaceController`（loadInitial 确保固定文档存在并载入主文档、updateBlocks、脏检测=序列化比对、save 写盘、switchTo 含未保存确认回调）；单元测试覆盖：首次启动建三文件、重启不覆盖、脏判定、切换语义
- [x] 6.2 改造 `main.dart`：Scaffold + AppBar（显示名 + 脏标记 + 保存按钮）+ Drawer 文档列表（当前高亮、脏标记、点击切换）+ 编辑器以 `ValueKey(文档名)` 重挂载；widget 测试：启动即显示主文档内容、抽屉切换载入对应文档、无修改切换不弹窗
- [x] 6.3 未保存确认对话框三选（保存并切换/放弃并切换/取消）接入 `switchTo`；widget 测试覆盖三种选择的最终状态
- [x] 6.4 `Shortcuts`/`Actions` 注册 Ctrl+S 与 Cmd+S 触发保存，保存成功 SnackBar 反馈；widget 测试：快捷键触发写盘且脏标记消除

## 7. 收尾验证

- [x] 7.1 `flutter analyze` 与全量 `flutter test` 通过
- [x] 7.2 在桌面平台手动过一遍规格场景：首启建文件 → 编辑出现脏标记 → Ctrl+S 落盘（重启后内容保留）→ 删除 `notes.md` 重启自动重建 → 抽屉切换与未保存确认；对照 specs 逐条勾核
- [x] 7.3 `openspec validate --strict` 通过，按 `/opsx:archive` 归档并沉淀主规格
