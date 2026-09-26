# markdown_editor

Flutter 实现的块级双态 Markdown 编辑器（Typora 式实时预览）：
聚焦块为编辑态（标记可见并实时样式化），失焦块为渲染态；文档以真实文件持久化于应用数据目录，
固定维护 `welcome.md` / `notes.md` / `todo.md` 三个文档，支持抽屉切换、手动保存与未保存确认。

- 行为规格（唯一权威）：`../openspec/specs/`
- 已归档提案（设计取舍与实现证据）：`../openspec/changes/archive/`
- Agent 工作规则：`../AGENTS.md`

## 源码结构

```
lib/main.dart                          应用壳：AppBar + 抽屉切换 + 未保存确认对话框
lib/document/document_store.dart       存储抽象：FileDocumentStore / MemoryDocumentStore(web)
lib/document/document_workspace.dart   多文档工作区状态：载入、脏检测、保存、切换
lib/document/fixed_documents.dart      3 个固定文档的文件名/显示名/初始模板
lib/document/template_assets.dart      内置图片资产复制到数据目录
lib/editor/models/block.dart           块模型 MdBlock（含块间间隔元数据）
lib/editor/document_codec.dart         文件 ↔ 块列表的双向映射（载入分块、保存回写）
lib/editor/controllers/markdown_block_controller.dart  编辑态实时样式化与幽灵补全
lib/editor/widgets/markdown_editor.dart  块级双态编辑器与键盘行为
lib/editor/widgets/rendered_block.dart   渲染态块（gpt_markdown，含图片分流）
lib/editor/widgets/chart_block_view.dart chart 围栏块的图表渲染
```

## 环境前提

Flutter 与 Android SDK 路径写入 `android/local.properties`（该文件机器相关、不入库），
换机器时需自行填写 `flutter.sdk` 与 `sdk.dir`。仓库既定开发机 `hermes-machine` 上：

- Flutter 3.44.1 / Dart 3.12.1（`flutter --version` 核实）
- Android SDK：platforms 34 与 36、build-tools 36.0.0、NDK 28.2.13676358

## 常用命令

**全部在 `flutter_app/` 目录下执行**（应用不在仓库根）：

```bash
flutter pub get --offline   # 依赖解析走本地 pub 缓存
flutter analyze
flutter test --no-pub       # 当前 66 个测试通过
```

## 构建 Android APK（网络受限环境）

`hermes-machine` 上代理参数不代表外网可达，Google/Maven 等境外源不可依赖，因此构建走**本地缓存**路径：

```bash
cd flutter_app
flutter pub get --offline          # 缺此步会尝试联网解析依赖
flutter build apk --release --no-pub
```

- 产物：`build/app/outputs/flutter-apk/app-release.apk`（约 59.7 MB，已被 `.gitignore` 忽略、不入库）
- 核实产物完整：`unzip -t build/app/outputs/flutter-apk/app-release.apk`
- 核实签名：`$ANDROID_HOME/build-tools/<版本>/apksigner verify --verbose <apk>`
- 构建日志末尾可能出现 `Caught exception: Already watching path: …/flutter_tools/gradle`：
  这是 Flutter 工具链的重复监听告警，不影响产物（退出码 0、APK 正常生成），无需排查。

> 签名说明：`android/app/build.gradle.kts` 的 release 构建沿用模板默认的 **debug 签名**，
> 仅适用于安装到测试设备，**不可用于分发**。正式发布需另行配置 release keystore。

## 部署到模拟器 / 真机

模拟器与真机均通过 ADB 接入。**Android 模拟器不运行在 `hermes-machine` 上**，而在同一局域网
的另一台主机上，需先建立连接再安装：

```bash
adb connect <模拟器宿主机IP>:5555     # 地址随环境变化，须现场确认
adb devices -l                        # 确认设备已列出
adb -s <设备序列号> install -r build/app/outputs/flutter-apk/app-release.apk
adb -s <设备序列号> shell am start -n com.example.markdown_editor/.MainActivity
```

排查要点：

- **共享资源**：该模拟器可能同时被其他项目使用（2026-09-26 观察到前台运行着另一项目的
  应用 `com.example.fileforest.file_forest`）。执行 `input tap` / `screencap` 前先确认前台
  应用是本项目，避免误操作他人应用。
- **签名冲突**：若模拟器中已有用其他 keystore 安装的同包名应用，覆盖安装会报
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE`。需先 `adb uninstall com.example.markdown_editor`
  （会清除该应用在模拟器中的本地数据），再安装。
- **观察运行与报错**：`adb -s <序列号> logcat -v threadtime`，过滤 `E/flutter`、`FATAL EXCEPTION`。
- **界面走查**：`adb -s <序列号> exec-out screencap -p > shot.png` 截图；
  `adb shell uiautomator dump` 可导出可点击元素边界用于定位坐标。
- **首次连接新模拟器报 `unauthorized`**：ADB 密钥需在设备上逐台授权，该实例尚未信任发起
  连接的机器。在模拟器屏幕上确认授权弹窗，或重启 ADB 服务后重连即可（已验证有效）：
  `adb kill-server && adb start-server`。
- **软键盘不弹出导致 `adb shell input text` 无效**：模拟器自带内置硬件键盘
  （`dumpsys input` 中的 `qwerty2`），系统据此抑制软键盘，此时文本注入无接收方。
  临时打开软键盘即可实测输入：`adb shell settings put secure show_ime_with_hard_keyboard 1`
  （用完还原为 0）。

> 记录时间 2026-09-24 / 2026-09-26：模拟器实例为 `sdk_gphone16k_x86_64`（Android 17，1080x2400，
> density 420），宿主机局域网地址为 `192.168.31.182`，已见端口 `5555` 与 `5557`（后者为独占实例）。
> 宿主机重启后端口可能漂移，此为点态值，使用前须重新确认。

## 桌面端（无显示环境）

CI / 容器内运行 Linux 桌面版必须带 D-Bus 会话，否则应用卡在 GTK 初始化、Dart 代码不执行且无输出：

```bash
xvfb-run -a dbus-run-session -- ./build/linux/x64/debug/bundle/markdown_editor
```

该环境下应用 stdout 不可靠，验证以文件系统副作用（`<docs>/MarkdownEditor/` 下的文件）为准。

## 已知行为（未列入规格，未修复）

- **内容短于视口时正文垂直居中**：`lib/main.dart` 的正文区是 `Center` + `ConstrainedBox(maxWidth: 720)`，
  `maxWidth` 表明原意只限制阅读宽度，但 `Center` 在纵向同样居中。因此 `notes.md` / `todo.md`
  这类短文档会浮在屏幕中部、上方留大片空白；`welcome.md` 内容长、填满视口，看起来是顶部对齐，
  掩盖了该现象。实测（2026-09-26，`192.168.31.182` 的 `5555` 与 `5557` 两台模拟器均复现）：
  视口 y 区间 210–2400（高 2190），内容容器 y 区间 658–1952（高 1294），上下留白各 448，完全对称。
  两份主规格均未规定纵向对齐方式，故此为「未规定」而非「违反规格」；如需固化对齐要求，
  应先走提案写入 `document-files` 规格。
