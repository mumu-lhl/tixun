# 开发与验证

面向使用者的介绍和安装说明见 [README](README.md)，架构见 [DESIGN](DESIGN.md)，验收状态见 [ROADMAP](ROADMAP.md)。

## 开发环境与运行

UI 使用 Flutter 官方独立的 `material_ui` 包。微信图片选择器、Markdown 等依赖仍使用旧 Material 类型，应用通过官方 `MaterialUiCompatibilityBridge` 保留主题和中英文翻译；待这些依赖迁移后移除兼容代码。

界面中的单选下拉优先复用设置页的 AppSelectField。表单需要校验时使用 AppSelectFormField，两者共用菜单外观、动画和键盘交互。

直接 Dart 依赖已更新至当前最新稳定版；间接依赖遵循 Flutter SDK 和上游约束，不使用 `dependency_overrides` 强行越过兼容范围。可用 `flutter pub outdated` 检查后续更新。

仓库提供 `.githooks/pre-commit`，对暂存区代码文件增长给出非阻断式提示：普通代码文件超过 20 KiB 警告、达到 40 KiB 提高警告级别；测试文件分别为 40/80 KiB。已超限的文件仅在增长至少 2 KiB 或跨越更高阈值时再次提示；缩小文件不提示。lockfile、生成代码、构建产物及依赖目录不参与检查。不要仅为满足体积阈值拆分文件。Git 默认不会启用仓库内 hook，克隆后需执行一次：

```bash
git config core.hooksPath .githooks
```

```bash
flutter pub get --enforce-lockfile
flutter run -d linux
# 隔离 Mock：内存数据库 + 独立临时附件目录，不需要 API Key
flutter run -d linux --dart-define=TIXUN_DEMO=true
# Android 手机连接调试后
flutter run -d <设备ID>
```

Linux 系统依赖：`sudo bash scripts/install_linux_deps.sh`（包含 bubblewrap）。构建 Linux 沙盒 Python 还需要 Zig；将 `zig` 加入 PATH（ZVM 用户可 `export PATH="$HOME/.zvm/bin:$PATH"`）。保存 API Key 需要可用且已解锁的 Secret Service（例如 GNOME Keyring）；没有密钥环时不回退到明文存储，仍可浏览本地学习资料。

## 测试与构建

### 开发时优先最小充分验证

- 默认只运行能覆盖本次变更风险的最小测试集：先定位受影响模块、调用方和已有回归，指定相关测试文件，不把全量测试作为每次改动的固定步骤。
- 测试失败时，先缩小到失败文件或用 `--plain-name` 筛选用例复现；修复后运行受影响的回归，必要时再扩大范围。不要以跳过测试或削弱断言代替修复，也不要无变化地重复跑全量。
- 涉及跨模块公共边界、数据库迁移、全局配置或依赖等高风险改动且难以界定影响范围，或进行发布验收、用户明确要求时，再运行全量测试。普通 CI 的完整检查保持不变。
- 纯文档修改只检查差异、链接和命令示例；不因此运行 Flutter 测试或构建。构建及 GUI 验证也按变更需要选择，不要求每次全部执行。

新增或迁移测试时，优先镜像 `lib/` 的模块边界，按被验证的契约归档，不要求与源码逐文件对应。跨模块流程放在业务入口所属模块，全局架构测试保留在 `test/` 根目录，共用辅助代码仍放 `test/support/`。

日常开发命令（测试文件仅为示例，按实际影响范围替换）：

```bash
flutter analyze
flutter test -j 4 test/architecture_test.dart
# 需要聚焦单个用例时：flutter test -j 4 <测试文件> --plain-name '<用例名>'
```

需要全量验证时：

```bash
flutter test -j 4
```

按需构建及 GUI 检查：

```bash
flutter build apk --debug
flutter build linux --release
# GUI 检查必须使用隔离 Mock 构建
flutter build linux --release --dart-define=TIXUN_DEMO=true
scripts/gui_smoke.sh
scripts/gui_tests.sh
```

Flutter 单元和 Widget 测试统一使用 `flutter test -j 4`，按四个并发测试任务运行；指定测试文件时也保留 `-j 4`。这是测试套件之间的并发，不是把单个测试拆成四个线程。原生设备/GUI 集成测试仍按下述脚本隔离、顺序执行，不套用该并发参数。

Linux debug / release 共享临时引擎目录，**必须顺序构建**。启动冒烟截图保存在 `artifacts/gui/`，集成场景截图在 `artifacts/gui-*/`，各入口日志由 `TIXUN_GUI_LOG_DIR` 指定（默认当前目录）；脚本通过不代表视觉审查完成，仍需读取截图检查。

不使用 Golden 像素快照；保留真实字体下的 Widget 行为、窄屏布局、键盘与公式测试，以及 Linux GUI 截图和视觉检查。迁移测试使用 `test/fixtures/` 中的历史快照验证保留旧数据；新增字段和表时必须继续提供显式迁移。

```bash
dart run build_runner build
dart run drift_dev schema dump lib/core/database/database.dart test/fixtures
dart run drift_dev schema generate test/fixtures test/generated_migrations
```

## 持续集成

普通 push / PR 执行静态分析、完整 Flutter 测试、Android Debug APK、Linux 正式构建、GUI 启动冒烟和完整 Native GUI 回归，并上传程序、截图与日志。手动及复用工作流默认开启 `full_gui`；手动取消该选项可只跑冒烟，`run_tests=false` 则显式跳过单元测试及完整 GUI 回归；Nightly 还通过 `run_gui=false` 跳过 GUI 启动冒烟。依赖的静态分析/测试 job 失败时，构建与 GUI job 会被跳过，需先查看前置失败日志。二十二个 GUI 测试入口由 [scripts/gui_tests.sh](scripts/gui_tests.sh) 执行，CI 分成三个并行 job，各 job 内顺序执行；每个测试有独立日志、240 秒超时，单个 job 在首个失败时停止。脚本默认本地顺序运行全部测试，也可使用 `TIXUN_GUI_SHARD_COUNT` 和从 0 开始的 `TIXUN_GUI_SHARD_INDEX` 选择分片。其中 9 个是 Visual 集成测试（`visual_flow`、`visual_player_flow`、`visual_drag_flow`、`visual_quiz_flow`、`assessment_flow`、`visual_circuit_flow`、`visual_chem_geo_flow`、`visual_constraints_flow`、`visual_drag_answer_flow`）。纯文档修改不触发完整构建。CI 还接受 `nightly_tag` 输入（字符串，默认空），仅 Nightly 传入，用于将标签写入构建。

### 聊天 A2UI Express

组件白名单、工具及交互权限见 [聊天 A2UI](docs/CHAT_A2UI.md)。对 Catalog 或渲染进行改动时，运行：

```bash
flutter test -j 4 test/features/a2ui \
  test/features/chat/chat_a2ui_test.dart \
  test/features/chat/chat_a2ui_widget_test.dart \
  test/core/database/a2ui_migration_test.dart
```

原生 Mock 场景 `integration_test/a2ui_flow_test.dart` 由 GUI 回归脚本执行。

### AI 教学图形（Visual）

图形用声明式 DSL v1 描述：场景 JSON、元素、表达式、控件、时间线与几何约束都在 `lib/core/visual/`（模型、验证器、采样、渲染）与 `lib/features/visual/`（存储、卡片）里实现；三个 AI 工具（`create_visual` / `update_visual` / `get_visual`）在 `lib/core/ai/visual_tool.dart`。图形表在 schema v16 引入，题目图形的修订钉住在 v17；v18 增加题面/解析角色，显式迁移旧 pin 为题面图。

新增图形功能时，按所验证的契约补行为测试：场景模型、验证和渲染在 `test/core/visual/`，AI 工具在 `test/core/ai/`，图形存储和交互在 `test/features/visual/`，题图在 `test/features/practice/`。DSL 对模型公开的契约在 `lib/core/ai/visual_schema.dart`，示例须通过真实验证器。题图的可作答性规则在 `lib/features/practice/question_visual.dart`，由 `PracticeStore` 事务调用；不要在 AI 工具或 UI 另行补写 pin。首帧以 `resolveVisualFrame(scene, 0)` 为准，测评全屏不开放教学播放或参数控制；全屏复用题卡的 attempt、答案、提交和重做状态。考试通过 `create_quiz` 的 `question_scene` / `solution_scene` 原子保存独立图形，不链接消息、不开放探索图工具；解析图只在当前尝试提交后显示。新增 `integration_test/assessment_flow_test.dart` 覆盖手机尺寸全屏作答、提交后解析和桌面重做；可用 `GDK_BACKEND=x11 scripts/flutter_python.sh test integration_test/assessment_flow_test.dart -d linux --dart-define=TIXUN_DEMO=true` 在隔离 Xvfb 中验证。

审查回归覆盖在 `test/core/ai/visual_review_regression_test.dart`、`test/core/visual/visual_axis_safety_test.dart`、`test/features/practice/visual_question_invariants_test.dart` 和 `test/features/practice/visual_question_editor_test.dart`。修改刻度循环后，先用外部超时运行绘制安全测试：`timeout --kill-after=3s 30s flutter test -j 4 test/core/visual/visual_axis_safety_test.dart`，避免同步绘制回归阻塞整个测试进程。Widget 测试里数据库操作必须放在 `tester.runAsync` 内；`PracticeStore.detail()` 不能在提交事务进行中调用（参考 `test/features/practice/visual_question_card_test.dart` 的 `submitAndCheck` 模式：先点提交，再循环 `runAsync` + `pumpAndSettle` 等判分视图出现，之后才读 Store）。

## 按版本标签发布

推送 `v` 开头的版本标签会运行 [Publish release](.github/workflows/release.yml)：先校验版本，再复用 CI 运行静态分析、单元测试及正式构建（不运行 GUI 冒烟或 GUI 回归），最后将 Android Release APK（Universal 与三个 ABI）、Linux x86_64 压缩包和 `SHA256SUMS` 发布到 GitHub Releases。无需额外配置发布 Token。

例如，发布下一个版本（先更新并提交版本号）：

```bash
# 先将 pubspec.yaml 更新为 version: 0.6.1+9，并将代码提交到远程仓库
# 后续版本需要先更新 pubspec.yaml 的版本号及构建号
git tag -a v0.6.1 -m 'TiXun 0.6.1'
git push origin v0.6.1
```

标签必须与 `pubspec.yaml` 的版本名一致，不包含 `+` 后的构建号。预发布可使用 `v0.6.1-rc.1`，对应 `version: 0.6.1-rc.1+9`；此类标签会自动标记为 GitHub Prerelease。

更新说明由 git-cliff 和 [cliff.toml](cliff.toml) 生成，使用 GitHub 风格的 What's Changed、贡献者信息及 Full Changelog 比较链接。包含普通提交和 Conventional Commits；第一版列出完整历史；后续以当前标签可达、最近公开发布的版本为基线（包括公开的预发布版本）。草稿、失败构建和未发布标签不会截断记录，Full Changelog 链接也使用这个基线。生成的是 Release 正文，不自动提交 CHANGELOG 文件。

所有构建通过后才创建草稿；附件全部上传成功才公开。失败时可在 Actions 重跑同一次标签工作流，或从该标签手动运行 Publish release。未完成的草稿可继续上传；已经公开的版本不会被覆盖。

标签发布先构建 Universal Release，再使用 `--split-per-abi` 构建 `armeabi-v7a`、`arm64-v8a` 和 `x86_64` 三个 Release APK，立即保存各次输出，避免后一次构建覆盖通用包。四份文件共享包名、版本名、版本号与签名，可互相覆盖更新；设置 `force-version-code-ignoring-abi=true` 避免 Flutter 默认 ABI 版本号偏移。普通 CI 仍构建 Debug APK。Android Release APK 必须配置发布签名：三个必需 Secrets，别名默认 `tixun`（可选覆盖）。构建后校验实际签名与证书，缺少配置或验证失败会停止发布。首次从开发签名迁移需先备份、再卸载安装和恢复。Termux 配置与保管方法见[发布签名](docs/ANDROID_SIGNING.md)。Linux 使用 tar.gz 保留程序执行权限，下载包只包含正式构建，不含 Mock 数据和测试截图。

## 自动化脚本的维护

- `scripts/build_artifacts.py` 是产物约定的唯一来源：构建模式、原始文件名、Artifact 名及发布文件后缀统一生成。可复用 CI 将实际产物名作为输出交给发布流程，Linux 正式程序与 GUI 截图日志分开上传。
- 每次 Android 构建都会调用模式验证：实际读取 Manifest 信息和 ZIP 内容，Release 必须包含 AOT 代码、没有 Debug kernel 且未启用 debuggable，不能通过改文件名混入调试包。Release 逐份检查实际原生库架构、签名和相同应用版本；稳定版与 Nightly 共用同一打包约定。
- 并发组包含调用工作流名称、Git 引用、Android 构建模式与 GUI 验证范围，普通 CI、发布验证以及手动 Release 验证不会互相取消；同场景的新运行仍可取消旧运行。
- `scripts/release_notes.py` 查询公开 Release 并验证 Git 祖先关系。网络错误或已发布标签缺失会报错，不静默生成错误范围。不要删除已公开版本的标签。

脚本回归测试无需 Flutter 或 API Key：

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
```

在 Actions 手动运行 Build and verify 时，可以勾选 `android_release` 验证四份签名 Release APK；`full_gui` 默认勾选以运行完整 GUI 回归，手动取消时只执行 GUI 启动冒烟。这不会创建新发布。已有 Release 和版本标签不会被修改。

## 界面语言与配色

界面使用 Flutter `gen-l10n` 和同步 Localizations delegate，支持 `zh` 和 `en`。不要翻译笔记正文、消息、用户标题或自定义提示词。内置科目用稳定的中文标识保存，界面可显示英文名称，自定义科目原样保留。

中英文文案分别保存在 [assets/l10n/app_zh.arb](assets/l10n/app_zh.arb) 和 [assets/l10n/app_en.arb](assets/l10n/app_en.arb)，配置见 `l10n.yaml`。新增文案时在两个文件中使用相同的、具有描述性的 Dart 标识符作为 ID；在 `@消息ID` 的 `placeholders` 中声明命名参数及类型。界面通过 `context.l10n.消息ID` 调用生成的类型安全 API。

应用生成的错误使用 `AppErrorCode`、`AppFormatException` 或 `AiFailure.localized`，界面通过 `failureText` 在展示时翻译；未知异常、服务端文本和用户内容原样保留。带参数的错误将参数与代码一起保存，参数本身不作为翻译键；内置资料字段使用 `StudyErrorField` 稳定标识。包装错误时应保留 `LocalizedAppFailure` 的代码和参数，例如使用 `AiFailure.fromFormatException`。新增错误时，同时维护 `app_error.dart` 的枚举及 `app_error_localization.dart` 中的穷举映射。持久化的聊天错误使用稳定代码和参数，原始外部消息单独标记；`chat_failure.dart` 仅为已存储的旧版应用错误提供有限的历史数据读取，不是通用文案查找表。

ARB 可使用 Flutter `gen-l10n` 支持的 ICU plural/select。生成文件 `lib/core/l10n/generated/` 已忽略，不需提交。编辑 ARB 后执行：

```bash
flutter gen-l10n
flutter test -j 4 test/core/l10n/localization_test.dart
```

测试会核对源字典、生成结果及参数占位符，检查中英文切换、偏好重启保留和窄屏布局。默认提示词随界面语言切换，覆盖内容原样保存；安全规则由应用追加。

动态配色使用 [`dynamic_color`](https://pub.dev/packages/dynamic_color)，与 `material_ui` 共用 `ColorScheme`。Android 使用系统动态配色，Linux 可读取 XDG Desktop Portal 的强调色；系统未提供颜色时回退到默认绿色。独立 Mock 默认关闭动态配色以固定截图；测试可以显式开启。`integration_test/ai_preferences_test.dart` 覆盖提示词编辑/预览/恢复、会话思考强度、中英文切换及动态配色，并保留手机/桌面和深浅色截图。

## 每日 Nightly

[Publish nightly](.github/workflows/nightly.yml) 是发布每日 Nightly 的 CI

## GPT 思考档位

参考：[推理指南](https://developers.openai.com/api/docs/guides/reasoning)、[Responses API](https://developers.openai.com/api/reference/resources/responses/methods/create)、[GPT‑6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol)

## 嵌入 Python 的构建与验证

依赖固定在 `python/requirements.txt`，包含 SymPy、mpmath 和 NumPy。安装脚本明确指定 CPython 3.13 ABI；Android NumPy 来自 [Flet wheel 索引](https://pypi.flet.dev/numpy/)，三个架构分别安装，Linux 使用 PyPI wheel。不能跨架构复制原生扩展。

```bash
bash scripts/prepare_python.sh Linux
bash scripts/flutter_python.sh build linux --release
# 构建依赖 Zig、bubblewrap 和允许 unprivileged user namespaces 的 Linux 内核。
# Android 同样需要 Zig；改为 prepare_python.sh Android，再用 wrapper 构建 APK。
python3 -m pip install -r python/requirements.txt
python3 -m unittest discover -s python -p 'test_*.py'
bash scripts/flutter_python.sh test integration_test/python_flow_test.dart -d linux --dart-define=TIXUN_DEMO=true
```

普通 `flutter build` 也必须设置 wrapper 中的环境变量；Android 需 `SERIOUS_PYTHON_ANDROID_EXTRACT_PACKAGES='numpy*'`，将 NumPy 的 Python 文件和元数据放入 `extract.zip`；隔离服务直接从内存归档导入，原生模块仍由插件按 ABI 打包。

复用原工具循环、审批卡与审计表。`test/core/python/python_tool_test.dart` 验证审批、参数和重复执行；Python 单测确保旧的进程内入口 fail-closed；Linux GUI 集成验证隔离进程真实运行打包 SymPy/NumPy、工作区写入成功、工作区外写入被拒绝、硬超时和停止。Android 在 V2230A / Android 13 上已通过 CPython/SymPy/NumPy、工作区跨次同步、直接 libc 读取/写入应用私有文件被拒绝、网络被拒绝、硬超时、停止和进程异常退出后恢复测试。原生 UI 流程也已验证代码审批、真实执行结果、权限设置及自动允许。实机回归命令：

```bash
bash scripts/flutter_python.sh test integration_test/android/python_sandbox_test.dart -d <设备ID>
```

当前 Android Zig 构建脚本使用 Linux x86_64 NDK 主机工具链。

Android 不向隔离 UID 共享应用目录 FD（SELinux 会拒绝读取），而由服务从 APK 读取运行时并放入自身 memfd，CPython 通过 zipimport 使用这些只驻留内存的归档。宿主只传递有界输入/结果管道。CPython 的低层归档读取保持真实只读 IO，避免 ZIP 导入与 pyfakefs 回溯源代码读取互相递归；Python 单测包含完整 ZIP 运行时回归。工作区使用 pyfakefs 提供 Python 文件 API 兼容层；它**不是安全边界**，真正的边界是 Android 隔离 UID、无应用权限和 SELinux。返回文件必须经 `PythonWorkspaceStore` 的路径、类型、总大小及数量校验后才能写回当前会话目录；禁止符号链接、特殊文件及目录穿越。快照上限 8 MiB、1000 项；超时/取消/进程崩溃不写回未完成的快照。原生扩展需要使用 file-like 对象，直接使用虚拟路径的原生文件操作（如 mmap/SQLite 文件路径）不受支持，不宣称完整 POSIX 文件系统。虚拟工作区之外的虚拟临时文件不会被导出；不允许通过主进程代理任意真实路径或网络请求。隔离服务的网络权限也不继承主应用的 INTERNET 权限。
