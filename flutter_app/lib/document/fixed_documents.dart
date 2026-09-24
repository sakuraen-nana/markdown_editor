/// 固定文档集：文件名、显示名与初始模板（spec：固定文档集与自动创建、
/// 主文档模板特性完整）。
///
/// 模板按空行分段书写，与 [DocumentCodec] 的载入分块规则一致；图片引用
/// 数据目录相对路径（design D8），chart 围栏经 blockComponents 渲染
/// （design D6）。
library;

import '../editor/document_codec.dart';

class FixedDocument {
  const FixedDocument({
    required this.fileName,
    required this.displayName,
    required this.template,
  });

  /// 数据目录中的固定文件名。
  final String fileName;

  /// 抽屉与标题栏中的显示名。
  final String displayName;

  /// 文件缺失时自动写入的初始模板。
  final String template;
}

/// 主文档：启动默认打开，模板覆盖全部已支持特性。
const FixedDocument kWelcomeDocument = FixedDocument(
  fileName: 'welcome.md',
  displayName: '欢迎与功能总览',
  template: r'''
# Markdown 编辑器

欢迎使用实时预览编辑器：聚焦的块处于**编辑态**，点击其它块即可切换。本文档覆盖全部支持的特性，可作为速查手册。

## 目录

- [快速开始](#快速开始)
- [功能一览](#功能一览)
- [图表与图片](#图表与图片)

## 快速开始

试试这些行内语法：**加粗**、*斜体*、~~删除线~~、`行内代码`、==高亮==，以及行内公式 \(E=mc^2\)。

输入对称标记（如 `**`）后按 Tab，编辑器会自动补全闭合标记。

## 功能一览

### 列表

无序列表：

- 第一项
- 第二项
- 第三项

有序列表：

1. 打开文档
2. 编辑内容
3. 保存并退出

任务勾选：

- [x] 支持实时预览
- [x] 支持多文档切换
- [ ] 支持导出 PDF

### 表格

| 特性 | 语法示例 | 状态 |
| --- | --- | --- |
| 加粗 | `**文字**` | 已支持 |
| 高亮 | `==文字==` | 已支持 |
| 图表 | chart 块 | 已支持 |

### 引用

> 好的编辑器让内容创作者忘记工具的存在。
>
> —— 实时预览的设计初衷

### 代码块

```dart
void main() {
  print('Hello, Markdown!');
}
```

### 数学公式

行内公式：质能方程 \(E=mc^2\)。

块级公式：

$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$

## 图表与图片

chart 图表块（`type: line` 折线图）：

```chart
type: line
title: 每周编辑字数
x: 周一, 周二, 周三, 周四, 周五, 周六, 周日
y: 320, 480, 260, 540, 610, 720, 450
```

本地图片（首次启动时复制到数据目录）：

![编辑器示意图](assets/demo-image.png)

---

更多内容见左侧抽屉中的「笔记」与「待办」文档。链接示例：[Markdown 官方教程](https://markdown.com.cn)。
''',
);

/// 笔记文档：会议/日常笔记模板。
const FixedDocument kNotesDocument = FixedDocument(
  fileName: 'notes.md',
  displayName: '笔记',
  template: r'''
# 笔记

> 习惯：每次会议后把要点记录在这里，保留上下文比完整记录更重要。

## 本周要点

- 编辑器核心是**块级双态**：聚焦即编辑，离开即渲染
- 多行结构（表格、代码块、引用）在块内按 Enter 只换行、不拆块
- 保存用 `Ctrl+S`，未保存修改会有标记提醒

## 事项跟踪

| 事项 | 负责人 | 状态 |
| --- | --- | --- |
| 实时预览编辑器 | 我 | 进行中 |
| 文件持久化 | 我 | ==已就绪== |

> 提示：切换文档时若未保存，应用会询问如何处理。
''',
);

/// 待办文档：任务清单模板。
const FixedDocument kTodoDocument = FixedDocument(
  fileName: 'todo.md',
  displayName: '待办',
  template: r'''
# 待办

## 当前迭代

- [x] 块编辑操作（Enter 拆块 / Backspace 合块）
- [x] 实时样式化与幽灵补全
- [ ] 表格单元格编辑优化
- [ ] 文档导出

## 已完成

1. WYSIWYG 实时预览
2. ==高亮== 与公式支持
3. 固定文档集与抽屉切换

## 小贴士

代码内联样式 `Ctrl+B` 加粗选中文本的功能排在导出之后。
''',
);

const List<FixedDocument> kFixedDocuments = [
  kWelcomeDocument,
  kNotesDocument,
  kTodoDocument,
];

/// 主文档：启动默认打开（spec：启动默认打开主文档）。
FixedDocument get kDefaultDocument => kFixedDocuments.first;
