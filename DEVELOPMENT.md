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
xvfb-run -a dbus-run-session -- flutter test integration_test/chat_flow_test.dart -d linux --dart-define=TIXUN_DEMO=true
xvfb-run -a dbus-run-session -- flutter test integration_test/learning_materials_test.dart -d linux --dart-define=TIXUN_DEMO=true
# 另有 practice_flow_test.dart、practice_management_test.dart、backup_flow_test.dart，按 CI 顺序执行
```

Linux debug / release 共享临时引擎目录，**必须顺序构建**。截图和日志保存在 `artifacts/gui/`；脚本通过不代表视觉审查完成，仍需读取截图检查。

Golden 使用随包字体及固定环境；有意更新时运行 `flutter test --update-goldens test/ui_test.dart`，并检查图像。数据库 schema v1/v3/v4 → v5 迁移有保留历史数据的测试；新增字段和表时必须继续提供显式迁移。

```bash
dart run build_runner build
dart run drift_dev schema dump lib/core/database/database.dart test/fixtures
dart run drift_dev schema generate test/fixtures test/generated_migrations
```

## 持续集成

GitHub Actions 执行静态分析、自动测试、Android Debug APK 构建、Linux 正式构建和真实 GUI 测试，并上传程序、截图与日志。五个 GUI 测试入口及执行顺序见 [.github/workflows/ci.yml](.github/workflows/ci.yml)。纯文档修改不触发完整构建。

## 按版本标签发布

推送 `v` 开头的版本标签会运行 [Publish release](.github/workflows/release.yml)：先校验版本，再复用完整 CI，最后将 Android 开发 APK、Linux x86_64 压缩包和 `SHA256SUMS` 发布到 GitHub Releases。无需额外配置发布 Token。

例如，发布当前应用版本：

```bash
# 先确认 pubspec.yaml 为 version: 0.5.1+6，且代码已提交到远程仓库
# 后续版本需要先更新 pubspec.yaml 的版本号及构建号
git tag -a v0.5.1 -m 'TiXun 0.5.1'
git push origin v0.5.1
```

标签必须与 `pubspec.yaml` 的版本名一致，不包含 `+` 后的构建号。预发布可使用 `v0.6.0-rc.1`，对应 `version: 0.6.0-rc.1+7`；此类标签会自动标记为 GitHub Prerelease。

更新说明由 git-cliff 2.14.2 和 [cliff.toml](cliff.toml) 生成，使用 GitHub 风格的 What's Changed、贡献者信息及 Full Changelog 比较链接。包含普通提交和 Conventional Commits；第一版列出截至该标签的历史，后续只列出与上一版本之间的变更。生成的是 Release 正文，不自动提交 CHANGELOG 文件。

所有构建通过后才创建草稿；附件全部上传成功才公开。失败时可在 Actions 重跑同一次标签工作流，或从该标签手动运行 Publish release。未完成的草稿可继续上传；已经公开的版本不会被覆盖。

当前 Android 发布附件仍是开发签名的 Debug APK。不同构建的签名可能不同，覆盖安装失败时应先导出数据，再卸载安装和恢复；正式发布签名尚未配置。Linux 使用 tar.gz 保留程序执行权限，下载包只包含正式构建，不含 Mock 数据和测试截图。
