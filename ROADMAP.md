# 开发进度

当前版本 **0.5.2+7**。M0–M5 核心功能已实现；真实 API 和 Android 设备验收尚未完成，不能以 Mock 或 Linux 结果代替。默认正式构建没有测试资料。

## M0 工程与双平台

- [x] Android 10+ / Linux、Material 3、Riverpod、go_router、Drift SQLite、随包中文字体、深浅主题及响应式导航。
- [x] GitHub Actions 静态分析、自动测试、Android Debug APK、Linux Release、GUI 截图和日志 Artifact。
- [x] Xvfb、软件渲染、真实窗口交互、超时及后台进程清理。Linux debug/release 顺序构建。

## M1 AI Chat

- [x] DeepSeek / 通用兼容接口、能力校验、系统安全存储、连接测试。
- [x] SSE、多轮、流式持久化、取消、分支编辑/重新生成、有限重试、超时及有界上下文。
- [x] 会话管理、全文搜索、消息与草稿、原图/编辑图、发送前裁剪/旋转/预览、Markdown / LaTeX 和独立 Mock。
- [x] 普通、引导和考试模式；手机输入区适配键盘、长草稿、图片与大字体。

## M2 知识与错题

- [x] CRUD、类型、科目/章节/标签、全文与短中文检索、分页、文本修订与恢复、并发版本保护。
- [x] 错题原图、答案、个人/AI 解析、已确认/建议错误原因、知识关联、Chat 双向追溯。
- [x] 多图录入、手动分题、AI 结构化边界建议后人工改框、旋转、逐题保存及原图保留。
- [x] 受控资料工具、按会话授权、写入逐项确认、参数校验、幂等与原子审计。内容不能自行授予权限。

## M3 教学与训练

- [x] Chat 内真实单选/多选/判断/填空/数值组件；简答及错题重做先提交再自主判分。
- [x] 确定性评分、草稿、提示、历史与幂等提交；AI 答案待核对，不作已验证的掌握证据。
- [x] 离线题库、手动录题、基础模板、随机小测与续做、专项/综合知识训练、错题重做、Chat 变式及来源关联。
- [x] 教学状态持久化；分支复用原题与作答；题目修订保留旧版本及原评分依据。

## M4 复习与诊断

- [x] 确定性简化 SM-2、评分与复习原子保存、到期列表、应用内提醒、历史、日期调整、暂停及重置。
- [x] 今日任务、训练表现、已确认错误原因和独立检测证据；少于 3 道不同题目显示数据不足，不预测考试分数。
- [x] 阶段、目标考试、日期、范围、每日时间和默认教学方式配置。

## M5 可靠性与产品完善

- [x] 完整版本化备份、SHA-256、路径/大小/数据库/外键检查、旧版本迁移、流式读写；排除密钥。
- [x] 恢复前等待在途写入和草稿，独立暂存验证、原子目录切换、中断恢复、一份撤销副本及单独删除副本。
- [x] Android 系统文档导出、Linux 文件选择；不申请广泛存储权限。
- [x] 批量资料操作及撤销、历史分页、回收区恢复和确认永久删除、共享图片引用保护。
- [x] 56 项自动化测试；schema v1/v3/v4 → v5 保留资料与作答的迁移测试。
- [x] 7 项真实 Linux GUI 集成测试：聊天/流式/图片编辑、工具保存、人工和 AI 分题、错题→变式→交互题→复习→诊断、备份恢复/撤销、小测/修订/批量操作。
- [x] 已读取手机与桌面、深浅主题、公式、图片和训练截图；已按维护需求移除 Golden 像素基线，保留行为测试与 GUI 视觉检查。
- [x] 0.5.1 Linux 正式/Mock Release 构建、真实生产数据库启动、创建会话后重启保留、最终 GUI 启动与截图审查。
- [x] 已下载并检查 CI APK：`org.tixun.tixun`、版本 `0.5.1`/6、minSdk 29、targetSdk 36、arm64-v8a/armeabi-v7a/x86_64，APK v2 签名校验通过。Manifest 无相机或广泛存储权限；硬件行为另行验收。
- [x] 最终 0.5.1 双平台 CI：[41879876725](https://github.com/mumu-lhl/tixun/actions/runs/41879876725)。56 项测试、Android Debug APK、Linux Release 和 7 项真实 GUI 集成测试全部通过，构建与截图日志 Artifact 已上传。

## 0.5.2 发布

- [x] [GitHub Release v0.5.2](https://github.com/mumu-lhl/tixun/releases/tag/v0.5.2) 已公开发布，附 Android Release APK、Linux Release 压缩包和 SHA256SUMS；更新日志由 git-cliff 生成。
- [x] [标签发布工作流 42061568956](https://github.com/mumu-lhl/tixun/actions/runs/42061568956) 全部通过，代码提交 `8f4ca35`。APK 已确认包含 AOT 代码、不含 Debug kernel，且未启用 debuggable；发布文件摘要与核验产物一致。
- Android 当前仍采用开发签名；Release 构建模式与正式发布签名分别验收。`v0.5.1` 的旧发布流程已取消，未公开 Release。

## 工作流优化

- [x] 并发组隔离普通 CI、发布验证和手动 Release 验证；产物命名统一生成并通过可复用工作流输出传递。
- [x] Android APK 自动核验实际构建模式；Linux 正式程序与 GUI 截图日志分别上传，发布不再依赖测试目录结构。
- [x] GUI 测试统一脚本顺序执行，独立日志、超时和首错停止；更新日志按最近公开且可达的 Release 生成，忽略未发布标签及草稿。
- [x] 提交 `6834838` 的 [Release 验证 CI 42065457302](https://github.com/mumu-lhl/tixun/actions/runs/42065457302) 通过：16 项脚本回归、56 项 Flutter 测试、7 项真实 GUI 测试、双平台 Release 构建及 APK 模式核验。已下载核对正式程序与测试 Artifact 的分离和五份 GUI 日志；此验证没有创建或覆盖发布版本。

## 主分支新增（尚未发布）

- [x] 思考强度：Provider 全局默认、会话独立覆盖、分支继承。工具任务明确提示并只关闭当前会话思考，不改全局默认。
- [x] 独立提示词管理：九类场景、搜索、编辑、预览、恢复默认；版本化持久化、长度校验及备份恢复；应用权限和提交规则保留。
- [x] 中文 / English / 跟随系统，662 条英文界面文案；Material 控件与日期本地化，中文学习资料和自定义内容保持原样。增加英文用户 README。
- [x] 动态配色：Android 12+ 壁纸色与 Linux 桌面强调色，支持关闭及无系统色时回退；保持深浅主题和独立 Mock 的确定性。
- [x] 本地静态分析、62 项 Flutter 测试、16 项脚本测试；另跑备份与语言 7 项回归。新增真实 Linux GUI 流程通过，已读取审查中英文、手机、桌面和深浅色截图。上述功能的 Android 实机验证仍待完成。
- [x] 本地 Linux Release 构建和隔离数据目录的正式 GUI 启动通过（`demo=false`）；已读取桌面截图，无演示资料。
- [x] 提交 `3a27f55` 的[完整双平台 CI 42260109254](https://github.com/mumu-lhl/tixun/actions/runs/42260109254) 全部通过：62 项 Flutter 测试、16 项脚本测试、Android Debug APK、Linux Release、Mock GUI 启动及六组原生 GUI 回归。正式程序与截图/日志分别上传；本次没有创建新 Release。
- [x] ChatGPT 订阅 Provider：官方浏览器 OAuth、PKCE/JWT 校验、账号隔离、轮换刷新、退出撤销、模型列表、Responses 流式文字/图片、命名空间工具和思考上下文回传；恢复原 API 配置，令牌不进入数据库或备份。协议测试及隔离 Linux GUI 流程通过，见[接入说明](docs/CHATGPT_PROVIDER.md)。
- [x] 本地新增 19 项 ChatGPT 协议/数据测试通过（另含语言回归）；Linux Release 构建与原生 GUI 验证通过，已读取中英文、手机/桌面及深浅主题截图。[最终双平台 CI 42370065545](https://github.com/mumu-lhl/tixun/actions/runs/42370065545) 全部通过：81 项 Flutter 测试、16 项脚本测试、Android Debug APK、Linux Release、Mock 启动和七组原生 GUI 回归，构建与测试 Artifact 分开上传。
- [ ] 实际 ChatGPT Plus/Pro 账号的浏览器授权、系统安全存储、模型/图片能力和订阅推理，以及 Android 实机验证。自动化结果不代表实际账号已验收。

## 必须单独完成的外部验收

- [ ] 用实际 DeepSeek API Key 验证文本、Flash 图片理解、非思考工具调用与教学质量。当前已验证请求格式、能力限制、本地 HTTP/SSE、错误与 Mock；未发送付费真实模型请求。
- [ ] Android 实机安装、相机/照片选择、系统文档导出、安全存储、软键盘、滚动和进程恢复。CI 编译成功不等于设备行为已验证。

当前没有可用的真实 API Key、Android 设备或模拟器。不要把密钥发到对话或提交到仓库，正式使用时在应用设置中填写。后台系统通知和 Linux 拖放导入暂未提供；已有应用内到期提醒及系统文件选择入口。

## 可重复验证

Flutter 3.47.9 / Dart 3.13.7；`flutter analyze`、`flutter test`。Linux GUI 参照 [开发指南](DEVELOPMENT.md)与 CI 的七个测试入口，截图/日志保存在 `artifacts/`，生成截图与完成视觉审查分别记录。约 8 GiB 的当前云盘无法解压 Android NDK，APK 由磁盘充足的 GitHub Actions 构建。

已验证代码提交：`341542d`（0.5.1）。最终双平台 CI：[41879876725](https://github.com/mumu-lhl/tixun/actions/runs/41879876725)。[最新工作流与产物](https://github.com/mumu-lhl/tixun/actions/workflows/ci.yml)。

## 架构调整

- [x] 类型化 AI 请求、消息、工具与完成事件；三种 Adapter 共用 Interface，凭据解析与协议片段处理留在对应实现中。
- [x] LearningRun 负责学习上下文、超时、轮次和工具执行；AppController 保留 UI 状态与消息持久化。
- [x] AppPreferences 独立写入跟踪，关闭及备份等待偏好保存；模型选项集中校验与解析。
- [x] ChatGPT 只读账号摘要与一致快照；令牌记录私有；Responses 推理状态限于当前 Conversation。
- [x] 分题接收及题目修订移入 Store，根部/导航缩小 Riverpod 订阅。
- [x] [架构调整 CI 42376246976](https://github.com/mumu-lhl/tixun/actions/runs/42376246976) 全部通过：90 项 Flutter 测试、16 项脚本测试、Android Debug APK、Linux Release、Mock 启动与七组原生 GUI 回归。本地额外验证生产版 GUI，并读取桌面/手机、深浅主题、提示词和备份恢复截图。

详见[当前接口与约定](docs/ARCHITECTURE_REVIEW.md)。数据与备份格式未变，简单只读查询保留，未做全面重写。
