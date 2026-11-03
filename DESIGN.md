# 关键设计

- **阶段范围**：当前交付 M2 核心：Chat、知识库、错题本、图片整理与受控资料工具。未实现的学习模块不伪造统计，不宣称掌握程度。
- **界面**：Material 3，中文字体随包提供；同一 Widget 树适配底部导航和桌面侧栏。长公式横向滚动，非法 LaTeX 回退为原文。
- **状态**：Riverpod 管理 AppController 生命周期；go_router 页面导航。Controller 统一串行发送、取消与落库，流式更新限制至约 80ms。复杂度到来前不引入重复的 UseCase/Mapper 层。
- **数据**：Drift 类型化 SQLite 表：会话、消息、附件、学习资料、版本、关系、工具操作、Provider 配置、偏好。外键、事务、索引、FTS5 trigram；短中文查询回退子串搜索。schema v2，已验证 v1 原数据升级；后续变更必须显式迁移并测试旧数据升级，禁止直接重建库。
- **可靠性**：用户消息及附件关联原子写入后才请求模型。流式内容周期性落库，重启把生成中消息标记为中断。编辑与重新生成均创建分支，原会话、来源引用及已执行工具的记录保留。软删除提供提示条撤销和独立回收区恢复能力。未发送图片也在数据库中引用。
- **附件**：稳定相对路径，应用目录保存原始字节，拒绝目录穿越和超大输入；缩略显示限制解码宽度。支持有界裁剪、旋转、缩小副本与手动分题；自动 OCR 和边界识别尚未提供。
- **Provider 边界**：业务依赖 ChatProvider。DeepSeek 与兼容接口共用 OpenAI Chat Completions 传输；模型能力在构造请求时验证。API Key 由平台 KeyStore 读取，与 SQLite 隔离。只有一个活动 Provider 配置，地址对应密钥分别保存。
- **运行边界**：SSE 按 UTF-8、行和事件解帧，不假设 HTTP chunk 边界。超时、限流、异常 JSON、未完成输出、无正文和取消独立处理；未收到响应前最多重试一次，生成后不自动重发。上下文最多 30 条/32000 字符，明确展示限制；未来再按需求增加摘要。
- **教学**：guided/direct/exam 三种提示策略，持久化基础阶段（diagnosing/explaining），当前尚无练习驱动的状态转移。M3 引入结构化题目和确定性评分后再扩展。资料工具必须由用户授权，写入逐项确认；未获成功工具结果时不能声称完成数据修改。
- **隔离**：编译期开启 TIXUN_DEMO 后使用内存数据库、独立临时附件目录和固定 Mock Provider。默认生产构建没有演示记录。现阶段不提供运行时混入真实数据库的 Mock 开关。
- **验证**：纯逻辑/数据库测试、真实本地 HTTP SSE 测试、Widget/Golden、Linux integration_test 和 Xvfb GUI 截图分别覆盖不同层面。截图生成与视觉检查分别记录。

## 已核对的官方依据（2026-11-03）

- [Flutter Linux 设置](https://docs.flutter.dev/platform-integration/linux/setup)：clang、CMake、Ninja、pkg-config、GTK3、C++ 标准库。实测 SDK 3.47.9 / Dart 3.13.7，Debian 13 工具链。
- [DeepSeek 模型能力](https://api-docs.deepseek.com/quick_start/pricing)：Flash 支持视觉；V4 Pro 不支持。
- [DeepSeek 图片输入](https://api-docs.deepseek.com/guides/vision)：用户消息 content 数组中的 image_url，支持内联 base64；JPEG/PNG/GIF/WebP。
- [DeepSeek 推理模式](https://api-docs.deepseek.com/guides/thinking_mode)：thinking.type enabled/disabled；reasoning_effort low/high/max。本版本默认关闭思考以控制延迟与消耗，不发送不适用的采样参数。
- [Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion)：SSE、finish_reason、usage；已接入非思考模式工具调用；结构化题目计划在 M3 实现。
- 所用依赖的 pub.dev 版本及 SDK 约束已核对：Drift 2.35.3 / sqlite3 3.8.0、Riverpod 3.4.3、go_router 18.1.2、Dio 5.11.1、secure_storage 11.2.0、file_selector 1.1.0、image_picker 1.2.4、markdown_plus 1.0.12。均覆盖 Android/Linux 所需能力；Linux 相机仅通过文件选择代替。flutter_math_fork 0.7.4 最近发布较早，以实际分式、矩阵、多行公式和错误回退测试约束使用范围。

Android 构建预算：Gradle 3 GiB 堆、1 GiB metaspace、最多 2 个 worker，Kotlin daemon 1 GiB，避免 Flutter 模板默认 8 GiB 堆挤占 CI 进程内存。Linux 各构建模式必须顺序执行，共享的引擎临时目录不支持并发打包。

## M2：学习资料与受控工具

- schema v2 添加类型化知识、错题、文本修订、标签关系、知识关系、错题知识关系、资料图片、对话资料关系及工具操作日志；v1 聊天、草稿、原图引用和配置原样保留。兼容服务迁移后默认不声明工具能力。数据库中只有历史标签快照、偏好和工具审计参数采用 JSON，不将学习实体整体塞入 JSON。
- StudyStore 是 UI 和 AI 共用的写边界：验证、事务、版本号、历史、软删除。恢复旧文本创建新版本；删除和撤销不覆盖历史。数据库写入失败不能返回工具成功。
- AI 必须获得用户从应用 UI 授予的会话权限；资料或消息中的指令不能改变权限。工具参数拒绝未知字段，写操作逐项确认，AI 不能修改用户原答案、个人分析和已确认错误原因。资料工具目前只在非深度思考模式提供，避免错误使用 DeepSeek 思考上下文协议。
- 工具请求最多 4 轮、8 次调用；读取返回摘要或有界正文。写入按当前请求、工具名和规范化参数去重，审计成功和数据修改在同一事务提交。中断的待确认操作在重启时取消，不能自动补执行。审计记录不包含密钥。题目图片仅由应用将已授权 Chat 上下文的图片稳定引用到错题，模型不能指定任意文件路径。
- Chat 编辑及重新生成建立分支，保留原消息、来源和已执行工具的审计，不删除已被学习资料引用的 AI 消息。新分支继承原教学模式、资料权限和关联关系；独立新会话的资料权限仍默认关闭。
- 图片编辑使用 Flutter 解码和 Canvas，无额外图像框架；先查像素数，最大 3200 万像素，按最长边 2048 解码后再旋转和裁剪。原始文件从不覆盖。分题仅支持用户框选，尚无自动边界识别；PNG 编辑副本超过 8 MB 时明确拒绝保存。
- Android 在启动系统照片选择或拍照前记录目标；恢复后导入原知识/错题。目标已删除时保留到新对话草稿并提示，不擅自恢复资料，不自动上传。实际平台行为仍需设备验证。
- Drift manager API 未被业务使用，关闭其代码生成；保留类型化查询和可重现的 schema 快照及迁移验证辅助代码。

GUI 自动化只在隔离 Mock 构建记录输入框和发送按钮的实际渲染坐标、草稿就绪标记，脚本等待控件完成布局再操作，避免平台字体或调度差异导致固定坐标误点。标记不包含学习正文或密钥。行内数学作为 WidgetSpan 合并回同一段落，SelectionArea 负责文字选择，避免标点被分成独立布局。
