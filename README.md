# 题训 TiXun

理解知识，独立尝试，真正掌握。面向 Android 10+ 和 Linux 的开源 Flutter 学习应用，数据默认保存在本地，无需账号。

当前为 **M0 / M1 开发版**。已接入真实 DeepSeek / OpenAI-compatible Chat、SSE 流式响应、会话搜索和管理、消息与草稿持久化、图片导入和预览、Markdown / LaTeX、教学模式、停止和重新生成。编辑消息会创建分支，保留原会话。删除会话可撤销，也可从回收区恢复。

知识库、错题本、交互式评分、复习、学习诊断和完整备份**尚未实现**。当前考试模式仅为对话教学，不产生训练成绩。真实 API 和 Android 实机验证状态见 [ROADMAP.md](ROADMAP.md)。

## 运行

使用 Flutter **3.47.9**（Dart 3.13.7），依赖版本提交在 `pubspec.lock`。

```bash
flutter pub get --enforce-lockfile
flutter run -d linux
# 无 API Key 的隔离体验（内存数据库 + 独立临时附件目录）
flutter run -d linux --dart-define=TIXUN_DEMO=true
# Android 手机通过 USB / 无线调试连接后
flutter run -d <设备ID>
```

Linux 系统依赖可通过 `sudo bash scripts/install_linux_deps.sh` 安装。正常运行时需可用且已解锁的 Secret Service（例如 GNOME Keyring）。无密钥环时仍可查看本地资料，但不能安全保存 API Key；**没有明文回退**。

设置中输入服务地址、模型和 API Key，然后测试连接。DeepSeek 默认为 `https://api.deepseek.com` / `deepseek-flash`。Pro 不支持图片；含图片上下文会在请求前被拒绝。兼容接口需明确配置视觉和推理参数能力。测试连接会产生少量 API 用量。

单次上下文最多最近 30 条消息、32000 字符和 4 张图片；单张图片最多 8 MB。原图复制进应用目录。当前不提供图片裁剪、压缩、图像拆题或云同步。发送前可移除图片，历史图片点击可缩放预览。

## 验证与构建

```bash
flutter analyze
flutter test
flutter build linux --release
flutter build apk --debug
# 真实 GUI + 鼠标键盘操作 + 桌面/手机宽度截图
flutter build linux --release --dart-define=TIXUN_DEMO=true
scripts/gui_smoke.sh
xvfb-run -a dbus-run-session -- flutter test integration_test/chat_flow_test.dart -d linux --dart-define=TIXUN_DEMO=true
```

截图和应用日志保存在 `artifacts/gui/`。脚本成功代表启动/操作检查通过，**不代表视觉审查完成**。Golden 使用仓库内 OFL 字体和固定尺寸；有意更新时运行 `flutter test --update-goldens test/ui_test.dart`，并人工检查差异。勿用自动更新掩盖回归。

桌面快捷键：Ctrl+1/2/3 切换页面，Ctrl+N 新会话，Ctrl+Enter 发送，Esc 停止。手机使用底部导航和图片选择菜单。Android 使用系统照片选择器，无存储或相机权限的预先索取。

GitHub Actions 分别执行检查、Debug APK 构建、Linux 正式构建与隔离 Mock GUI 验证，上传 APK、Linux bundle、截图与日志；纯文档变更不触发完整构建。

## 数据与隐私

数据库及附件位于 `path_provider` 的应用支持目录下 `tixun/`。API Key 存放系统安全存储，按服务商与地址隔离，不进入数据库。无第三方分析和用户遥测。网络请求不记录密钥、对话正文或图片；Markdown 外部图片不自动联网加载。

当前尚无完整备份/恢复功能。卸载前自行保留整个应用数据目录；**不要只复制开启状态的 SQLite 主文件**，需关闭应用后连同附件完整复制。删除采用软删除，不自动清空回收数据。

架构与接口依据见 [DESIGN.md](DESIGN.md)，后续工作见 [ROADMAP.md](ROADMAP.md)。代码 MIT；字体采用随附 OFL 许可证。

## 界面

以下是隔离 Mock 构建的真实 Linux GUI 截图，回复内容为固定测试数据。

![桌面聊天与数学公式](docs/screenshots/chat-desktop.png)

<img src="docs/screenshots/chat-phone.png" width="390" alt="手机宽度的聊天界面" />
