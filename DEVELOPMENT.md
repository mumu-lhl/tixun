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
