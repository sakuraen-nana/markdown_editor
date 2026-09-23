# CLAUDE.md

Flutter 实现的 Markdown 编辑器。项目刚完成框架初始化（Flutter + OpenSpec），业务代码尚未开始；
首个功能一律从 OpenSpec 提案开始。

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
flutter_app/   Flutter 应用本体（目前为 flutter create 骨架，业务代码待开发）
openspec/      规格与提案（changes/ 在途提案，specs/ 已归档主规格）
.claude/       agent 规则与技能（openspec-* 工作流、git-commit 提交规范、flutter-* 官方技能）
```

## Flutter 开发要点

- **所有 `flutter` / `dart` 命令在 `flutter_app/` 目录下执行**（应用不在仓库根）。
- Flutter 相关任务**优先匹配已安装的 flutter-* 官方 skills**（Flutter 团队维护，见 `.claude/skills/flutter-*`），
  覆盖：widget/集成测试、响应式布局、布局错误修复、go_router 路由、国际化、JSON 序列化、http 请求等。
