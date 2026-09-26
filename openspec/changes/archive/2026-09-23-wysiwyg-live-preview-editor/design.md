## Context

`flutter_app/` 为 flutter create 骨架，无业务代码。硬约束：gpt_markdown ≥ 1.3.0 且禁用其全部 `@Deprecated` API（AGENTS.md「依赖约束」）。选型背景见 proposal Impact：实时样式发生在可编辑文本内部，文档渲染库（含 gpt_markdown）不在正确的抽象层，编辑态管线必须自建。

## Goals / Non-Goals

**Goals:**

- 块级双态编辑器（形态 B）的最小可用 demo：段落 + 标题两类块
- 编辑态实时样式、幽灵预填充、Tab 补全——specs 全部场景可被 widget 测试覆盖
- 渲染态以 gpt_markdown 现行 API 渲染，含高亮与行内公式的扩展支持

**Non-Goals:**

- 列表 / 表格 / 代码块 / 块级公式 / 引用等更多块型（后续变更）
- 文档持久化、撤销/重做策略、移动端 IME 深度适配
- 编辑态↔渲染态切换的动画过渡

## Decisions

### D1 编辑态：定制 `TextEditingController.buildTextSpan`，不引入渲染库

每次文本变更由 Flutter 回调 `buildTextSpan` 重建样式 span——这是「实时渲染」在编辑控件内的唯一发生地，光标/选区/输入法连接全部免费获得。

- 备选 A（gpt_markdown）：纯文档渲染，无编辑面；其 AST 渲染器未导出，放弃。
- 备选 B（flutter_code_editor 等代码编辑包）：面向关键字高亮，无「未闭合标记进行中样式 + 幽灵配对」语义，仅作机制参考。

### D2 幽灵提示：在 `buildTextSpan` 末尾追加浅色 span（非真实文本）

幽灵闭合符追加在 span 树末尾，不进入 `value.text`。光标停在 `value.text` 长度处，恰好位于真实文本与幽灵 span 之间，呈现 `今天的**天气是|**` 的期望形态。

- 备选（Stack 覆盖层 + `getLocalRectForCaret` 定位）：定位更精确但需 RenderEditable 句柄与手动布局同步，demo 不采用；若 D2 遇到 selection/IME 断言冲突则回退此方案（见 Risks）。

### D3 块模型：稳定 id + 纯文本；焦点驱动双态

`MdBlock {id, text}` 组成文档列表；每块持有 `FocusNode`，聚焦 → 编辑态（`EditableText`），失焦 → 渲染态（`GptMarkdown`）。点击渲染块 `requestFocus` 换回编辑态。块类型由文本推导（`#` 前缀 → 标题），不单独建模。

### D4 渲染态：gpt_markdown 现行 API + `inlinePatterns` 注入高亮

`GptMarkdown(text, inlinePatterns: [...])`：`==…==` 高亮经 `InlinePattern`（公开、非 deprecated，且优先于内置组件解析）注入；行内公式 `\(…\)` 为其原生支持。全部使用现行 API 面，满足依赖约束；样式 token（加粗/高亮底色等）集中定义，供编辑态与渲染态共用，降低两套管线的视觉偏差。

### D5 键盘语义：`Focus.onKeyEvent` 拦截

Tab → 有幽灵则补全（无则放行焦点遍历）；Enter → 拆块；行首 Backspace → 合块。桌面与测试环境有效；移动端 IME 无硬件键序，不在 demo 范围（见 Risks）。

## Risks / Trade-offs

- [幽灵 span 与 selection/IME 组合的边界行为] → widget 测试覆盖「出现 / Tab 补全 / 手动闭合消失」三场景；若断言冲突，回退 D2 备选方案
- [编辑态自建分词与渲染态 gpt_markdown 双管线样式不一致] → D4 的集中样式 token；demo 接受细微差异，记录为已知限制
- [未闭合标记的样式延伸到块尾]（如 `**abc` 后再输入普通文字也被加粗）→ demo 接受，后续以更精确的行内作用域规则迭代
- [移动端 IME 无按键事件，Enter/Backspace 拦截失效] → demo 以桌面 + widget 测试为准；后续变更加 `TextInputFormatter` / `TextEditIntent` 路径
- [`buildTextSpan` 覆写需自行处理 `withComposing`，否则中文输入法组合文本丢失下划线] → 实现时复刻默认控制器对 composing 区间的处理，测试覆盖中文输入文本渲染

## Migration Plan

不适用——全新模块，无存量迁移。

## Open Questions

（无）
