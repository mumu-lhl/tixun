# 开发进度

## M0 工程基础

- [x] Flutter Android 10+ / Linux、Material 3、响应式导航、深浅主题与随包中文字体。
- [x] Drift SQLite、外键、事务、索引、全文检索、数据库升级测试。
- [x] GitHub Actions 检查、Android Debug APK、Linux 正式构建与 GUI Artifact。
- [x] Xvfb 真实 GUI 启动、鼠标键盘操作、截图、Widget / Golden / 集成验证。
- [x] GitHub 写权限已恢复，已有代码和 CI 修复已推送。
- [x] 基线双平台 CI 通过：[41673120845](https://github.com/mumu-lhl/tixun/actions/runs/41673120845)。Android 旧版 tools 包已退役，工作流改为只安装 platform-tools。
- [ ] Android 实机安装、拍照/照片选择、安全存储、输入法及进程恢复验收。

## M1 AI Chat

- [x] DeepSeek / 兼容服务、能力校验、系统安全存储、连接测试。
- [x] SSE、多轮、取消、分支编辑与重新生成、超时、有限重试、上下文限制和错误处理。
- [x] 持久化会话、消息、草稿、图片；搜索、重命名、回收区。
- [x] Markdown / LaTeX、教学模式、基础阶段状态和独立 Mock。
- [ ] 使用真实 API Key 验证 DeepSeek 文本与图片问答。

## M2 知识库与错题本

- [x] 知识 CRUD、类型、自由正文、科目/章节/标签、FTS 与短中文检索。
- [x] 文本历史、恢复成新版本、版本冲突检测、资料及图片删除恢复。
- [x] 错题原题/原答案/个人分析/AI 解析/原因，AI 建议与用户判断分离。
- [x] 原图持久化、多图快速录入、裁剪/旋转/缩小副本、手动框选分题，原图与副本均保留。
- [x] 知识关联、错题知识关联、来源追溯、Chat 双向跳转、资料填入可检查的对话草稿。
- [x] Chat 消息保存资料、AI 解析回写；会话授权的 AI 检索和资料写工具、逐项确认、去重、原子执行与审计。
- [x] schema v1 → v2 保留聊天/草稿/图片/配置的迁移测试。
- [x] Mock GUI 验证：AI 工具确认保存知识、资料打开；多题图片手动拆分并保留原图。
- [ ] AI 自动题目边界建议和可编辑分题结果（当前只能手动框选，不宣称已实现）。
- [ ] 真实 DeepSeek + Android 真机的完整错题学习流程验收。
- [x] M2 双平台 CI、APK、Linux Release、GUI 交互和最终截图审查：[41680879458](https://github.com/mumu-lhl/tixun/actions/runs/41680879458)。

## M3：训练

- [x] 五种结构化交互题、题目一致性校验、AI 答案待核对标识。
- [x] Chat 可操作题卡、作答草稿、确定性评分、提示标记、幂等提交与历史记录。
- [x] 独立训练页、手动录题、离线基础题、错题重做、知识回忆、自主判分及变式请求。
- [x] 数据驱动的练习/提示/反馈状态；考试模式先提交再揭示解析。
- [x] schema v1 → v3 迁移、判分/恢复/工具/Widget 测试；新增题卡 Golden 已读取检查。
- [x] 36 项自动化测试、Linux Release 构建、错题重做→Chat 变式→交互作答的真实 GUI 测试；桌面与手机截图已读取审查。
- [x] M3 双平台 CI：[41856452795](https://github.com/mumu-lhl/tixun/actions/runs/41856452795)，Android APK、Linux Release、全部测试与 GUI 验证通过。

## 后续阶段

## M4：复习与诊断

- [x] 确定性间隔复习、评分/调度原子提交、调度历史与幂等记录。
- [x] 到期列表、知识回忆与错题重做、应用内提醒、日期调整/暂停/重置。
- [x] 今日任务、真实训练表现、已确认错误原因和知识点证据；不同判分依据分离，样本不足不显示精确掌握度。
- [x] 学习阶段、考试与日期、学习范围、每日时间、默认教学方式。
- [x] schema v1/v3 → v4 迁移、42 项自动化测试、更新的题卡 Golden 已读取检查。
- [x] Linux 真实交互：错题重做→变式→到期复习→再次作答→诊断；手机首页、复习、深浅诊断与题卡截图已读取审查。
- [x] M4 Linux Release 构建，事务通知回归与复习工具权限测试通过。
- [ ] M4 双平台 GitHub Actions 验证。

M5：带版本和完整性校验的备份恢复（排除 Key）、搜索与批量优化、无障碍、性能、Android 实机与 Linux 稳定性。

## 本地验证记录（2026-11-03）

- 静态分析通过；31 项单元、数据库、工具、图片、恢复与 Widget 测试通过。
- 工具测试覆盖无授权/拒绝/取消不写入、参数错误、重复调用、过期版本、审计失败时数据一起回滚。
- 真实 Linux GUI 的普通聊天、工具确认保存、手动分题共 3 项集成测试通过；Ctrl+Enter 发送也已验证。正式版与 Mock Linux Release 均构建并运行。
- Golden 随导航、消息操作和行内公式排版有意更新；已读取数学、深色 Chat Golden 和桌面/手机知识、错题、聊天、设置截图，完成视觉检查。单图已扩大，公式与中文标点已合并为正常段落。
- 无真实 API Key、无 Android 实机/模拟器，不能把 Mock 或 Linux 测试当作这些验证通过。Android APK 构建通过仍不能替代相机、密钥环和输入法的设备验收。

早期本地 Android 构建因约 8 GiB 磁盘无法解压 NDK；现已通过磁盘充足的 GitHub Actions 成功构建基线 APK。本地 Linux debug/release 必须顺序构建，避免共享引擎临时目录被并发覆盖。

当前验证代码提交：`a9f5640`（M2 核心 `8f10b4c`）。本地 Flutter SDK 位于 `/workspace/flutter`，Linux 工具链安装在 `tixun-dev` 容器；后续可用 `docker exec -e PUB_CACHE=/home/agent/.pub-cache -w /workspace/tixun tixun-dev flutter test` 继续验证。
