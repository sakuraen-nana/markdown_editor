## 1. 依赖与模块骨架

- [x] 1.1 在 `flutter_app/` 添加 gpt_markdown 依赖（验证：`flutter pub get` 成功，pubspec.lock 出现 gpt_markdown 1.3.x）
- [x] 1.2 建立 `lib/editor/{models,controllers,widgets}` 模块结构，`main.dart` 替换为 demo 页骨架（验证：`flutter analyze` 无错误）

## 2. 编辑态核心

- [x] 2.1 实现 `MarkdownBlockController`：行内分词（加粗/斜体/删除线/行内代码/高亮/行内公式，含未闭合进行中状态）+ `buildTextSpan` 样式输出，正确处理 `withComposing`（验证：widget 测试覆盖已闭合加粗、进行中加粗、高亮、公式四场景）
- [x] 2.2 实现幽灵预填充与 Tab 补全：输入起始符→光标后浅色闭合符提示；Tab 写入真实文本；手动输入闭合符后提示消失（验证：widget 测试覆盖三个场景）

## 3. 块级双态与文档操作

- [x] 3.1 实现块列表与焦点驱动双态切换：聚焦块 `EditableText`，失焦块 `GptMarkdown`（含 `inlinePatterns` 高亮注入），点击渲染块回编辑态（验证：widget 测试覆盖「离开转渲染态」「点击回编辑态」两场景）
- [x] 3.2 实现 Enter 拆块与行首 Backspace 合块（验证：widget 测试覆盖两场景）
- [x] 3.3 标题块处理：编辑态 `#` 标记样式化，渲染态标题排版（验证：widget 测试覆盖两场景）

## 4. 集成验证

- [x] 4.1 demo 页组装（滚动容器 + 文档状态管理 + 样式 token 共用），基准场景 `今天的**天气是晴天**，还不错` 全流程走通（验证：`flutter test` 全绿）
- [x] 4.2 收尾检查（验证：`flutter analyze` 无告警；`openspec validate wysiwyg-live-preview-editor --type change` 通过）
