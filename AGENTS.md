# AGENTS.md

Flutter 实现的 Markdown 编辑器。已交付两个特性并归档沉淀至 `openspec/specs/`：
块级双态实时预览编辑（`live-preview-editing`）、文件化多文档工作区（`document-files`）；
Android release APK 已可离线构建。后续功能一律从 OpenSpec 提案开始。

规格以 `openspec/` 为唯一事实来源；本文件只存「怎么做」的规则。

## 元规则：规则的存放

1. **一切长期生效的规则写入本文件**；需求与规格一律走 OpenSpec，不写进这里。
2. 对用户提出的每条要求，先判断是否长期生效、现有体系是否已覆盖：
   长期且未覆盖 → 持久化（规则类进本文件，需求类走 OpenSpec 流程）；长期且已覆盖 → 指出已有条目，不重复写；临时性 → 直接执行。
3. **每次持久化后，明确告知用户写入了哪些文件。**

## 开发流程：全程遵循 OpenSpec

工作流细则以 openspec 官方指令为权威（`.claude/skills/openspec-*/SKILL.md`、`.claude/commands/opsx/`、
`openspec instructions` 的输出）。本文件只列强制点：

1. 任何功能或规格变更，**先走提案流程**（`/opsx:propose`，产出 proposal / specs 增量 / design / tasks）。
2. **规划阶段不得改动项目代码**；实施必须由用户显式发起（`/opsx:apply`），不得在提案阶段顺带实现。
3. 实施以 `tasks.md` 为清单逐项推进；完成后 `openspec validate` 校验并归档（`/opsx:archive`），规格沉淀至主 specs。
4. 未完成的任务不得勾选；实施中若发现规格需要变更，先改规划产物再改代码。

## 提交约定

- 格式遵循 `.claude/skills/git-commit/SKILL.md`（git-commit-plugin / Angular 规范）：
  首行 `emoji + type(scope): 中文描述`，如 `✨ feat(editor): 支持实时预览`；
  12 种类型与 emoji 对照、body/footer 规则以该 skill 为准，本文件不重复维护。
- **提交信息不得包含任何协作者署名** —— 不加 `Co-Authored-By:` 行，不署工具名或 AI 名。只描述变更本身。
- **推送通道（环境点态，换机需现场核实）**：`origin` 使用 SSH 主机别名 `git@github-se77:…`，
  该别名在 `hermes-machine` 的 `~/.ssh/config` 中定义（映射 `github.com`，指定专用密钥，
  `IdentitiesOnly yes`），**仓库内不含其配置**。换机器推送前需自行配置等价别名或改写远端地址。
  核实方式：`ssh -T git@github-se77` 应返回 GitHub 的认证成功提示；`git remote -v` 查看当前地址。
  推送前先 `git ls-remote origin` 探测连通性——该环境下 GitHub 可达性是间歇的，失败时做有限重试，
  不要改动远端或绕过认证。

## 依赖约束

- **gpt_markdown**：禁止使用其 1.3.0 中被标记为 `@Deprecated` 的任何特性与 API。
  deprecated 面基本等于整个 legacy 正则解析管线（`MarkdownComponent` / `InlineMd` /
  `MdWidget` 等）与旧版参数（`components` / `inlineComponents` / `incremental` /
  `sourceTagBuilder` / `highlightBuilder` / `linkBuilder`），计划在 2.0 移除；
  只允许使用现行 API（plusparse 解析、`blockComponents` / `inlinePatterns` /
  `inlineDirectives`、styleSheet 与现行 builders）。升级依赖版本后新增的
  deprecated 项同理禁用。

## 项目结构

```
flutter_app/   Flutter 应用本体（构建与运行方式见 flutter_app/README.md）
  lib/main.dart      应用壳：AppBar + 抽屉文档切换 + 未保存确认
  lib/document/      存储层与多文档工作区（store / workspace / 固定文档 / 模板资产）
  lib/editor/        块模型、编解码、块编辑与渲染（controllers / models / widgets）
openspec/      规格与提案（specs/ 主规格，changes/archive/ 已归档提案）
.claude/       agent 规则与技能（openspec-* 工作流、git-commit 提交规范、
               session-checkpoint 会话落盘、flutter-* 官方技能）
```

## Flutter 开发要点

- **所有 `flutter` / `dart` 命令在 `flutter_app/` 目录下执行**（应用不在仓库根）。
- Flutter 相关任务**优先匹配已安装的 flutter-* 官方 skills**（Flutter 团队维护，见 `.claude/skills/flutter-*`），
  覆盖：widget/集成测试、响应式布局、布局错误修复、go_router 路由、国际化、JSON 序列化、http 请求等。
- **网络受限环境（环境点态，换机需现场核实）**：`hermes-machine`（本仓库既定开发机）上即使运行
  代理程序并配置代理参数，也无法访问 Google 等境外网站，GitHub 访问亦不稳定；不得把代理配置
  视为外网可达。此后的开发、构建与调试应优先检查并复用本地 SDK、依赖和构建缓存，避免无必要的
  公网下载；遇到网络依赖时优先尝试缓存/离线方案，区分网络故障与代码故障，并如实说明因缺少
  本地资源而无法继续的阻塞，不要反复依赖不稳定的外网访问。可用的离线构建命令与核实方式见
  `flutter_app/README.md`。
- **无显示环境（CI/容器）运行桌面应用**：必须带 D-Bus 会话，否则应用卡在 GTK 初始化、
  Dart 代码完全不执行且无任何输出：
  `xvfb-run -a dbus-run-session -- ./build/linux/x64/debug/bundle/markdown_editor`（可加 `NO_AT_BRIDGE=1`）。
  应用 stdout 在此环境不可靠，验证以文件系统副作用为准。
- **widget 测试（`testWidgets`）内禁止裸真实副作用**：假异步区里直接 `await` 真实文件 IO，
  或挂载会触发图片解码的组件（`Image.file`/`Image.network`），会静默挂起；真实 IO 用
  `tester.runAsync` 包裹，图片类断言在构造层（不真正挂载解码）完成。
