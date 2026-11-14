# Repository guidance

本项目是题训 TiXun（Flutter / Dart），面向 Android 与 Linux，界面支持中文和英文。

## 开始工作

- 先确认任务涉及的模块与测试；只读相关代码和文档，避免重复抄写项目文档。
- 修改 AI、偏好或数据流边界前，先看 [`docs/ARCHITECTURE_REVIEW.md`](docs/ARCHITECTURE_REVIEW.md)；涉及整体架构时再看 [`DESIGN.md`](DESIGN.md)。
- 环境、常用命令、构建和测试约定见 [`DEVELOPMENT.md`](DEVELOPMENT.md)。按变更范围运行针对性测试；UI、数据库或协议改动优先补回归测试。

## 项目约定

- 保持本地优先与离线可用：学习数据留在本机；API Key 只能经系统安全存储，不写入数据库、日志或备份。
- 持久化学习数据通过对应 Store；偏好写入通过 `AppPreferences`。新增或修改数据库结构时，提供显式迁移并更新迁移测试与 schema 快照。
- 新增界面文案时，同时更新 `assets/l10n/app_zh.arb` 和 `assets/l10n/app_en.arb`，使用一致的消息 ID；运行 `flutter gen-l10n` 和本地化测试。生成文件不提交。
- 尊重现有错误类型、本地化错误映射和 provider 能力声明；不要把厂商协议细节泄漏到 UI 或控制器。
- 新增测试优先验证行为，不依赖像素 Golden；GUI 截图脚本通过不等于视觉检查完成。

## 完成检查

- 格式化修改过的 Dart 文件，运行 `flutter analyze` 与受影响的测试。
- 汇报改动及实际运行的检查；未运行的验证明确说明。
