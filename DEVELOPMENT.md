# 开发与验证

面向使用者的介绍和安装说明见 [README](README.md)，架构见 [DESIGN](DESIGN.md)，验收状态见 [ROADMAP](ROADMAP.md)。

## 开发环境与运行

使用 Flutter **3.47.9**（Dart 3.13.7），依赖锁定于 `pubspec.lock`。

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

Linux debug / release 共享临时引擎目录，**必须顺序构建**。截图和日志保存在 `artifacts/gui/`；脚本通过不代表视觉审查完成，仍需读取截图检查。

不使用 Golden 像素快照；保留真实字体下的 Widget 行为、窄屏布局、键盘与公式测试，以及 Linux GUI 截图和视觉检查。数据库 schema v1/v3/v4 → v5 迁移有保留历史数据的测试；新增字段和表时必须继续提供显式迁移。

```bash
dart run build_runner build
dart run drift_dev schema dump lib/core/database/database.dart test/fixtures
dart run drift_dev schema generate test/fixtures test/generated_migrations
```

## 持续集成

普通 push / PR 执行静态分析、自动测试、Android Debug APK、Linux 正式构建与 GUI 启动冒烟，并上传程序、截图与日志。完整 GUI 回归仅在版本发布、Nightly 或手动勾选 `full_gui` 时运行。七个 GUI 测试入口由 [scripts/gui_tests.sh](scripts/gui_tests.sh) 顺序执行，各有独立日志、240 秒超时，并在首个失败时停止。纯文档修改不触发完整构建。

## 按版本标签发布

推送 `v` 开头的版本标签会运行 [Publish release](.github/workflows/release.yml)：先校验版本，再复用完整 CI，最后将 Android Release APK（Universal 与三个 ABI）、Linux x86_64 压缩包和 `SHA256SUMS` 发布到 GitHub Releases。无需额外配置发布 Token。

例如，发布下一个版本（先更新并提交版本号）：

```bash
# 先将 pubspec.yaml 更新为 version: 0.5.3+8，并将代码提交到远程仓库
# 后续版本需要先更新 pubspec.yaml 的版本号及构建号
git tag -a v0.5.3 -m 'TiXun 0.5.3'
git push origin v0.5.3
```

标签必须与 `pubspec.yaml` 的版本名一致，不包含 `+` 后的构建号。预发布可使用 `v0.6.0-rc.1`，对应 `version: 0.6.0-rc.1+7`；此类标签会自动标记为 GitHub Prerelease。

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

每次采用独立 UTC 时间标签 `nightly-YYYYMMDD-HHMMSS`，复用完整 CI，产出正式签名 Android Release APK、Linux Release 与校验文件。全部检查成功后创建草稿，附件完整上传后公开为 Prerelease，并明确不设为 Latest。失败不会替换已有 Nightly 或稳定版，可重跑失败任务继续草稿。

更新日志继续使用 git-cliff：优先比较上一条已公开且可达的 Nightly，首次回退到已公开的版本标签；无基线时包含完整历史。稳定版日志仍只比较版本标签，不会被 Nightly 截断。应用内版本名和构建号沿用 `pubspec.yaml`，下载文件名与 Release 标签区分各次 Nightly。首次从开发签名迁移仍需备份并卸载旧版。

Golden 像素比对及基线图片已移除；Widget 行为、窄屏/键盘布局、公式回退和原生 GUI 回归继续执行，不再因颜色、间距等像素变化更新快照。

## CI 缓存与 job 名称

Flutter SDK、Android/Linux 引擎和 Pub 依赖使用版本化缓存；SDK 缓存未命中时先在检查任务预下载双平台引擎，供后续构建复用。Pub 缓存按锁文件区分。Gradle 使用官方 `setup-gradle` 管理依赖与任务缓存，并开启 `org.gradle.caching`。PR 与非默认分支只读 Gradle 缓存，默认分支成功构建后写入；版本标签可复用默认分支缓存。签名密钥只在 Runner 临时目录中保存，打包/签名校验任务禁用输出缓存，不缓存最终签名 APK。不缓存测试通过结果或开启 Gradle configuration cache。

首次缓存是冷启动，后续收益以 Actions 的命中记录和 Gradle 任务统计为准，不能承诺固定提速比例。缓存丢失时仍能完整构建。普通 CI 不再运行七组原生 GUI 测试，这与缓存是两项独立优化。

job 内部 ID 保持不变，仅增加显示名：`Analyze and test`、动态的 `Android Debug APK` / `Android Release APK and signature`、`Linux Release and GUI tests`。两个发布入口分别显示标签准备、构建验证和对应发布阶段；若分支保护绑定了旧的检查显示名，需要同步规则。
