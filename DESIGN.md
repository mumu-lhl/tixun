# 关键设计

- **阶段范围**：先交付 M0 / M1 的真实聊天链路。未实现的学习模块不伪造统计，不宣称掌握程度。
- **界面**：Material 3，中文字体随包提供；同一 Widget 树适配底部导航和桌面侧栏。长公式横向滚动，非法 LaTeX 回退为原文。
- **状态**：Riverpod 管理 AppController 生命周期；go_router 页面导航。Controller 统一串行发送、取消与落库，流式更新限制至约 80ms。复杂度到来前不引入重复的 UseCase/Mapper 层。
- **数据**：Drift 类型化 SQLite 表：会话、消息、附件、Provider 配置、偏好。外键、事务、索引、FTS5 trigram；短中文查询回退子串搜索。schema v1，保留迁移入口；后续变更必须显式迁移并测试旧数据升级，禁止直接重建库。
- **可靠性**：用户消息及附件关联原子写入后才请求模型。流式内容周期性落库，重启把生成中消息标记为中断。重新生成替换当前末条 AI 回复；编辑用户消息创建分支，原会话保留。软删除提供撤销和恢复能力。未发送图片也在数据库中引用。
- **附件**：稳定相对路径，应用目录保存原始字节，拒绝目录穿越和超大输入；缩略显示限制解码宽度。裁剪、压缩和分题留待 M2，不冒充已支持。
- **Provider 边界**：业务依赖 ChatProvider。DeepSeek 与兼容接口共用 OpenAI Chat Completions 传输；模型能力在构造请求时验证。API Key 由平台 KeyStore 读取，与 SQLite 隔离。只有一个活动 Provider 配置，地址对应密钥分别保存。
- **运行边界**：SSE 按 UTF-8、行和事件解帧，不假设 HTTP chunk 边界。超时、限流、异常 JSON、未完成输出、无正文和取消独立处理；未收到响应前最多重试一次，生成后不自动重发。上下文最多 30 条/32000 字符，明确展示限制；未来再按需求增加摘要。
- **教学**：guided/direct/exam 三种提示策略，持久化基础阶段（diagnosing/explaining），当前尚无练习驱动的状态转移。M3 引入结构化题目和确定性评分后再扩展。模型无数据管理工具，不能声称执行了保存/删除。
- **隔离**：编译期开启 TIXUN_DEMO 后使用内存数据库、独立临时附件目录和固定 Mock Provider。默认生产构建没有演示记录。现阶段不提供运行时混入真实数据库的 Mock 开关。
- **验证**：纯逻辑/数据库测试、真实本地 HTTP SSE 测试、Widget/Golden、Linux integration_test 和 Xvfb GUI 截图分别覆盖不同层面。截图生成与视觉检查分别记录。

## 已核对的官方依据（2026-11-03）

- [Flutter Linux 设置](https://docs.flutter.dev/platform-integration/linux/setup)：clang、CMake、Ninja、pkg-config、GTK3、C++ 标准库。实测 SDK 3.47.9 / Dart 3.13.7，Debian 13 工具链。
- [DeepSeek 模型能力](https://api-docs.deepseek.com/quick_start/pricing)：Flash 支持视觉；V4 Pro 不支持。
- [DeepSeek 图片输入](https://api-docs.deepseek.com/guides/vision)：用户消息 content 数组中的 image_url，支持内联 base64；JPEG/PNG/GIF/WebP。
- [DeepSeek 推理模式](https://api-docs.deepseek.com/guides/thinking_mode)：thinking.type enabled/disabled；reasoning_effort low/high/max。本版本默认关闭思考以控制延迟与消耗，不发送不适用的采样参数。
- [Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion)：SSE、finish_reason、usage；工具调用和结构化题目计划在 M2/M3 实现。
- 所用依赖的 pub.dev 版本及 SDK 约束已核对：Drift 2.35.3 / sqlite3 3.8.0、Riverpod 3.4.3、go_router 18.1.2、Dio 5.11.1、secure_storage 11.2.0、file_selector 1.1.0、image_picker 1.2.4、markdown_plus 1.0.12。均覆盖 Android/Linux 所需能力；Linux 相机仅通过文件选择代替。flutter_math_fork 0.7.4 最近发布较早，以实际分式、矩阵、多行公式和错误回退测试约束使用范围。
