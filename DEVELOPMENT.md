# 开发与验证

面向使用者的介绍和安装说明见 [README](README.md)，架构见 [DESIGN](DESIGN.md)，验收状态见 [ROADMAP](ROADMAP.md)。

## 开发环境与运行

使用 Flutter **3.50.0**（Dart 3.14.0），依赖锁定于 `pubspec.lock`。 CI 与本地使用相同 SDK 版本。 Android 使用 Gradle 9.9.1、AGP 9.5.1、Kotlin 2.4.21（均为稳定版），CI 使用 Java 25 LTS。

UI 使用 Flutter 官方独立的 `material_ui` 包。微信图片选择器、Markdown 等依赖仍使用旧 Material 类型，应用通过官方 `MaterialUiCompatibilityBridge` 保留主题和中英文翻译；待这些依赖迁移后移除兼容代码。

直接 Dart 依赖已更新至当前最新稳定版；间接依赖遵循 Flutter SDK 和上游约束，不使用 `dependency_overrides` 强行越过兼容范围。可用 `flutter pub outdated` 检查后续更新。

```bash
flutter pub get --enforce-lockfile
flutter run -d linux
# 隔离 Mock：内存数据库 + 独立临时附件目录，不需要 API Key
flutter run -d linux --dart-define=TIXUN_DEMO=true
# Android 手机连接调试后
flutter run -d <设备ID>
```

Linux 系统依赖：`sudo bash scripts/install_linux_deps.sh`。保存 API Key 需要可用且已解锁的 Secret Service（例如 GNOME Keyring）；没有密钥环时不回退到明文存储，仍可浏览本地学习资料。

## 测试与构建

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build linux --release
# GUI 检查必须使用隔离 Mock 构建
flutter build linux --release --dart-define=TIXUN_DEMO=true
scripts/gui_smoke.sh
scripts/gui_tests.sh
```

Linux debug / release 共享临时引擎目录，**必须顺序构建**。启动冒烟截图保存在 `artifacts/gui/`，集成场景截图在 `artifacts/gui-*/`，各入口日志由 `TIXUN_GUI_LOG_DIR` 指定（默认当前目录）；脚本通过不代表视觉审查完成，仍需读取截图检查。

不使用 Golden 像素快照；保留真实字体下的 Widget 行为、窄屏布局、键盘与公式测试，以及 Linux GUI 截图和视觉检查。当前数据库为 schema v13，迁移测试使用 `test/fixtures/` 中的历史快照验证保留旧数据；新增字段和表时必须继续提供显式迁移。

```bash
dart run build_runner build
dart run drift_dev schema dump lib/core/database/database.dart test/fixtures
dart run drift_dev schema generate test/fixtures test/generated_migrations
```

## 持续集成

普通 push / PR 执行静态分析、自动测试、Android Debug APK、Linux 正式构建与 GUI 启动冒烟，并上传程序、截图与日志。完整 GUI 回归仅在版本发布或手动勾选 `full_gui` 时运行；Nightly 跳过单元测试与完整 GUI 回归。十二个 GUI 测试入口由 [scripts/gui_tests.sh](scripts/gui_tests.sh) 顺序执行，各有独立日志、240 秒超时，并在首个失败时停止。纯文档修改不触发完整构建。CI 还接受 `nightly_tag` 输入（字符串，默认空），仅 Nightly 传入，用于将标签写入构建。

## 按版本标签发布

推送 `v` 开头的版本标签会运行 [Publish release](.github/workflows/release.yml)：先校验版本，再复用完整 CI，最后将 Android Release APK（Universal 与三个 ABI）、Linux x86_64 压缩包和 `SHA256SUMS` 发布到 GitHub Releases。无需额外配置发布 Token。

例如，发布下一个版本（先更新并提交版本号）：

```bash
# 先将 pubspec.yaml 更新为 version: 0.6.1+9，并将代码提交到远程仓库
# 后续版本需要先更新 pubspec.yaml 的版本号及构建号
git tag -a v0.6.1 -m 'TiXun 0.6.1'
git push origin v0.6.1
```

标签必须与 `pubspec.yaml` 的版本名一致，不包含 `+` 后的构建号。预发布可使用 `v0.6.1-rc.1`，对应 `version: 0.6.1-rc.1+9`；此类标签会自动标记为 GitHub Prerelease。

更新说明由 git-cliff 2.14.2 和 [cliff.toml](cliff.toml) 生成，使用 GitHub 风格的 What's Changed、贡献者信息及 Full Changelog 比较链接。包含普通提交和 Conventional Commits；第一版列出完整历史；后续以当前标签可达、最近公开发布的版本为基线（包括公开的预发布版本）。草稿、失败构建和未发布标签不会截断记录，Full Changelog 链接也使用这个基线。生成的是 Release 正文，不自动提交 CHANGELOG 文件。

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

在 Actions 手动运行 Build and verify 时，可以勾选 `android_release` 验证四份签名 Release APK，勾选 `full_gui` 运行完整 GUI 回归；不勾选时只执行 GUI 启动冒烟。这不会创建新发布。已有 Release 和版本标签不会被修改。

## 界面语言与配色

界面使用同步 Flutter Localizations delegate，支持 `zh` 和 `en`。`context.tr` 只处理应用文案；不要把笔记正文、消息、用户标题或自定义提示词交给翻译。内置科目用稳定的中文标识保存，界面可显示英文名称，自定义科目原样保留。

新增文案时编辑 [assets/l10n/en.json](assets/l10n/en.json)，再生成 Dart 字典：

```bash
python3 scripts/generate_l10n.py
flutter test test/localization_test.dart
```

测试会核对源字典、生成结果及参数占位符，检查中英文切换、偏好重启保留和窄屏布局。默认提示词随界面语言切换，覆盖内容原样保存；安全规则由应用追加。

动态配色使用 [`dynamic_color` 1.9.0](https://pub.dev/packages/dynamic_color/versions/1.9.0)（兼容当前 Flutter ColorScheme；Android 和 Linux 原生插件），系统未提供颜色时回退到默认绿色。独立 Mock 默认关闭动态配色以固定截图；测试可以显式开启。`integration_test/ai_preferences_test.dart` 覆盖提示词编辑/预览/恢复、会话思考强度、中英文切换及动态配色，并保留手机/桌面和深浅色截图。


## ChatGPT 订阅适配的验证

`flutter test test/chatgpt_test.dart` 使用隔离的签名/JWKS、真实本机回调和 HTTP 适配器，验证授权、刷新、退出、流式失败、工具和备份边界；不需要真实账号。`integration_test/chatgpt_flow_test.dart` 通过同一业务代码驱动原生登录/模型/聊天/退出 UI，截图保存在 `artifacts/gui-chatgpt/`，CI 有独立日志。

真实账号验收必须单独进行。不要把 OAuth 令牌或其他应用的登录文件放入测试、仓库、环境日志或备份；通过应用的 Continue with ChatGPT 打开官方登录页。没有安全存储或浏览器时会报错，不提供明文凭据回退。


## AI 与偏好模块的维护

先阅读 [接口与约定](docs/ARCHITECTURE_REVIEW.md)。新增 Provider 实现 `ChatProvider.start`，返回单次 `AiConversation`；请求使用 `AiRequest`，事件只发布完整工具调用和明确完成状态。不要把厂商 JSON 或令牌带回控制器。

修改模型参数先调整 `AiOptions` 并补能力矩阵；修改进度、调用上限、取消或结束判定时运行 `flutter test test/architecture_test.dart`，再跑对应协议和控制器回归。偏好写入通过 AppPreferences，跨文件与数据库的学习资料写入通过 Store，确保关闭/备份屏障可追踪。

## 每日 Nightly

[Publish nightly](.github/workflows/nightly.yml) 每天 UTC 20:30（北京时间次日 04:30）从默认分支运行，也支持手动触发。GitHub 定时任务可能延迟；不承诺精确到分钟。

每次采用独立 UTC 时间标签 `nightly-YYYYMMDD-HHMMSS`，复用 CI 的构建流程（跳过单元测试与完整 GUI 回归），产出正式签名 Android Release APK、Linux Release 与校验文件。构建时把本次标签以 `--dart-define=TIXUN_NIGHTLY_TAG=<标签>` 写入应用内，供应用内更新比对；正式发布与普通构建不带标签。全部检查成功后创建草稿，附件完整上传后公开为 Prerelease，并明确不设为 Latest。失败不会替换已有 Nightly 或稳定版，可重跑失败任务继续草稿。公开成功后执行 `scripts/prune_nightlies.py`，只保留最新的公开 Nightly，并删除旧 Nightly Release、附件和 Tag；稳定版、其他预发布和草稿不参与清理。清理前将当前更新日志的旧 Tag 比较链接改用提交 SHA，避免删除 Tag 后失效。清理失败会使工作流失败，已公开的新版本保留，可重新执行清理脚本。

更新日志继续使用 git-cliff：优先比较上一条已公开且可达的 Nightly，首次回退到已公开的版本标签；无基线时包含完整历史。稳定版日志仍只比较版本标签，不会被 Nightly 截断。应用内版本名和构建号沿用 `pubspec.yaml`，下载文件名与 Release 标签区分各次 Nightly。首次从开发签名迁移仍需备份并卸载旧版。

Golden 像素比对及基线图片已移除；Widget 行为、窄屏/键盘布局、公式回退和原生 GUI 回归继续执行，不再因颜色、间距等像素变化更新快照。

## CI 缓存与 job 名称

Flutter SDK、Android/Linux 引擎和 Pub 依赖使用版本化缓存；SDK 缓存未命中时先在检查任务预下载双平台引擎，供后续构建复用。Pub 缓存按锁文件区分。Gradle 使用官方 `setup-gradle` 管理依赖与任务缓存，并开启 `org.gradle.caching`。PR 与非默认分支只读 Gradle 缓存，默认分支成功构建后写入；版本标签可复用默认分支缓存。签名密钥只在 Runner 临时目录中保存，打包/签名校验任务禁用输出缓存，不缓存最终签名 APK。不缓存测试通过结果或开启 Gradle configuration cache。

首次缓存是冷启动，后续收益以 Actions 的命中记录和 Gradle 任务统计为准，不能承诺固定提速比例。缓存丢失时仍能完整构建。普通 CI 不运行完整的原生 GUI 回归，这与缓存是两项独立优化。

job 内部 ID 保持不变，仅增加显示名：`Analyze and test`、动态的 `Android Debug APK` / `Android Release APK and signature`、`Linux Release and GUI tests`。两个发布入口分别显示标签准备、构建验证和对应发布阶段；若分支保护绑定了旧的检查显示名，需要同步规则。

## 思考面板与画板验证

`test/reasoning_display_test.dart` 覆盖流式思考、跨轮显示与协议隔离、错误后保留、Responses 公开摘要及作答前隐藏。`test/scratchpad_test.dart` 覆盖多页、局部擦除、串行保存、关联删除和完整备份；旧 schema v7 的思考可迁移到 v8。画板不含任何外部 AI 请求。

`integration_test/scratchpad_reasoning_test.dart` 覆盖流式展示、彩色短笔画起点、橡皮/撤销、多页保存、平移缩放/复位与重开，并生成手机、桌面英文截图。普通 CI 仍只做启动冒烟，完整 GUI 在版本发布或手动勾选 `full_gui` 时执行。

CI 的签名测试与 Android 构建统一使用 Temurin **Java 25 LTS**；Flutter 显式选择 CI 的 JAVA_HOME。Gradle 9.3.1 支持运行在 Java 25（[兼容性表](https://docs.gradle.org/9.3.1/userguide/compatibility.html)）。Android Java/Kotlin 字节码目标仍为 17，不因此提高 Android 最低版本。

## 考试记录

考试使用 schema v9 的四张独立表，按日期查询并关联科目、两级小分表与分类照片。小分表整表替换在事务中完成，以独立 revision 检测并发修改；裸分与明细合计独立。完整备份验证考试附件引用。`exam_flow_test.dart` 覆盖考试原生 GUI。真实模型识别准确率及 Android 实机拍照/活动恢复仍需设备验证。

## 科目目录

schema v10 新增两级科目目录、知识目录关联与错题目录关联三张表。根模块名用 SQLite 表达式唯一索引去重；分类与正文修订独立，改名不会重写每条笔记，旧章节保持原样。资料科目变更时移除不匹配关联；手动整组选取比较旧关联集合，防止覆盖并发分类。删除目录有 UI 确认，级联解除关联，资料和练习保留。完整备份包含目录与关联。

AI 工具 `list_subject_modules`、`create_subject_module` 和 `link_study_module` 复用原有授权、参数校验、确认与操作审计，不执行任意 SQL。新增关联为幂等追加，不覆盖其他模块。查询工具可按模块过滤。`modules_flow_test.dart` 覆盖创建目录、两类归类、筛选和准备专项训练请求。没有新增 Golden 比较。

## GPT 思考档位

`AiOptions` 统一设置、聊天和考试图片整理的档位策略。优先保留官方 `/models` 的 `supported_reasoning_levels` / `supported_reasoning_efforts`，并将选中模型的公开能力元数据保存到 Provider 配置；列表未声明时采用明确的模型文档回退，未知订阅模型只使用模型默认。兼容 API 的自定义模型由用户声明推理参数能力，具体支持范围以服务商为准。

`xhigh`、`max` 按原值发送，`none` 与省略参数独立。只有模型目录明确声明时才展示额外档位（例如 `ultra`）。schema v11 将旧 ChatGPT `max` 别名迁移为 `xhigh`，保留旧配置的实际请求行为；DeepSeek 和兼容 API 的 `max` 不变。

核对来源（2026-11-09）：[推理指南](https://developers.openai.com/api/docs/guides/reasoning)、[Responses API](https://developers.openai.com/api/reference/resources/responses/methods/create)、[GPT‑6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol)、[GPT‑5](https://developers.openai.com/api/docs/models/gpt-5)、[GPT‑5.2 Pro](https://developers.openai.com/api/docs/models/gpt-5.2-pro)、[GPT‑5.5 Pro](https://developers.openai.com/api/docs/models/gpt-5.5-pro)、[Codex 配置参考](https://developers.openai.com/codex/config-reference)。Codex 客户端参数不一概等同于公开 Responses API 支持的取值。

## 照片导入

Android 图库使用 `wechat_assets_picker`，支持预览多选。拍照保留 `wechat_camera_picker` 4.6，通过直接依赖 `camera_android` 选择官方 Camera2 实现，替代默认 CameraX 后端；实际注册文件确认使用 `AndroidCamera.registerWith()`。页面允许切换系统相机，先释放应用内控制器，再调用 `image_picker`。保留 CAMERA，移除录音及旧版外部写入权限。Linux 使用 `file_selector`。该调整针对 vivo Y35 / Android 13 预览黑屏，仍需设备复验。

所有入口先复制到应用附件目录，再复用 `StudyImageEditor`。普通编辑隐藏分题动作；退出编辑保留原导入。考试照片在 schema v12 增加可空原图引用，覆盖编辑使用当前路径并发校验；清理和备份同时检查两条引用。GUI 的文件选择器测试只替换系统返回的文件路径，导入、裁剪、保存和磁盘检查均真实执行。Android 相机、相册权限与设备恢复仍需实机验证。

消融：未引入第二套裁剪库、通用媒体工作流引擎或媒体 Repository；共用一个平台选择函数和已有编辑器，保留各业务现有的恢复目标。


## 长对话与应用内更新

`context_compactor.dart` / `token_estimator.dart` 按估算 Token 预算选择上下文；不再使用固定 30 条/32000 字符。默认预算 128000，设置范围 4096–1048576，保留回复与指令空间。旧对话分批摘要，schema v13 持久化摘要与覆盖位置；原始消息保留，摘要失败有降级反馈。普通聊天不设置固定输出上限，连接测试等窄用途可以显式限制。修改时运行 `test/context_compactor_test.dart` 及对应 Provider/控制器测试。

`features/update/` 按正式版、预发布、Nightly 选择 GitHub 发布，核对下载校验信息；Android 选择匹配 ABI 并交给系统安装器，Linux 暂存后在重启时切换。自动检查与手动检查共用节流记录，启动检查不阻塞页面。下载与程序更新不写入学习资料目录；不能把这类发布信息请求描述成学习数据遥测。

## 维护文档

README 面向使用者，中英文同步；DESIGN 说明当前边界，ROADMAP 区分代码实现、自动化结果与真实账号/设备验收。按代码和工作流更新入口、限制及运行命令，不把旧版本说明继续追加成当前结论。历史验证注明日期和代码，Nightly 下载链接使用稳定的筛选入口，避免引用会被保留策略删除的 Tag。

## 提示词与工具精简（2026-11-10）

默认引导提示词去除与应用规则重复的资料优先说明；出题参数、图片引用和未核验状态保留在工具描述中，不在每次请求另拼一份。无图不声明分题工具；显式资料整理不开放出题。考试分数提取的未知留空、两级结构、禁止反推分数等规则影响正确性，予以保留，且不注入无关的学习地区背景。

AI 资料整理按操作筛选工具，本地 `estimateTokens` 对同一套序列化 schema 的估算如下（不是实际账单或模型 tokenizer，也不代表真实模型教学质量的 A/B 评估）：

| 范围 | 估算 tokens |
| --- | ---: |
| 全部资料工具 | 2625 |
| 新建知识：检索、读取、新建 | 464 |
| 编辑指定知识：读取、更新 | 380 |
| 新建错题 | 361 |

消融：复用现有生成和审批链，只保留任务权限元数据与共享对话框；没有新建通用工作流、另一套 AI 客户端或地区身份模型。`test/study_writing_test.dart` 覆盖真实写入、拒绝、合并修订、来源关联、越界与截断保护、背景和工具预算；原生资料 GUI 测试覆盖手机操作及英文桌面。

## 嵌入 Python 的构建与验证

运行时固定 `serious_python` 6.1.3 / CPython 3.13（具体补丁版本由锁定插件决定）。依赖固定在 `python/requirements.txt`，包含 SymPy、mpmath 和 NumPy 2.4.6。安装脚本明确指定 CPython 3.13 ABI；Android NumPy 来自 [Flet wheel 索引](https://pypi.flet.dev/numpy/)，三个架构分别安装，Linux 使用 PyPI wheel。不能跨架构复制原生扩展。

Python 包保留最新兼容版本：Flet 目前为 CPython 3.13 提供的三个 Android ABI 的 NumPy wheel 均为 2.4.6，因此 Android 和 Linux 统一使用此版本；SymPy 1.14.0 要求 `mpmath < 1.4`，保留 mpmath 1.3.0。升级时须同时检查 Android wheel 可用性和包之间的版本约束。

```bash
bash scripts/prepare_python.sh Linux
bash scripts/flutter_python.sh build linux --release
# Android 改为 prepare_python.sh Android，再用同一个 wrapper 构建 APK。
python3 -m unittest discover -s python -p 'test_*.py'
bash scripts/flutter_python.sh test integration_test/python_flow_test.dart -d linux --dart-define=TIXUN_DEMO=true
```

需要 Python 3 与 pip。CI 的构建任务自动准备包并缓存上游运行时下载；Android 保留 arm64-v8a、armeabi-v7a、x86_64 与 Universal 产物。宿主 Python 版本可以不同，pip 按目标解释器版本选择 wheel，不在应用运行时安装依赖。普通 `flutter build` 也必须设置 wrapper 中的环境变量；Android 需 `SERIOUS_PYTHON_ANDROID_EXTRACT_PACKAGES='numpy*'`，让 NumPy 的 Python 文件和元数据可从实际目录访问，原生模块仍由插件按 ABI 打包。

消融：复用原工具循环、审批卡与审计表；没有预设数学函数白名单、独立服务器、Flask 服务或另一套 AI 客户端。传输长度和输出展示上限不限制 Python 语法或模块能力。`test/python_tool_test.dart` 验证拒绝/关闭/自动授权、参数及重复执行；Python 单测验证标准库、文件、异常、时限与输出；原生 GUI 测试真实运行打包 SymPy 和 NumPy（数组运算、线性方程求解）、审查/自动允许、查看结果及手机全屏导航。

发布检查还会逐个确认 APK 与 Linux 包内含实际 Python 运行时、工作脚本、NumPy、SymPy 和 mpmath，并校验 Android NumPy 核心原生模块的 ELF 架构，防止仅编译成功却漏打包依赖。
