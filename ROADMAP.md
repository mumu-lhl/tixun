# 开发进度

## M0 工程基础

- [x] Flutter Android / Linux 工程、Material 3、响应式导航、主题、中文字体。
- [x] Drift SQLite、外键、事务、FTS、初始 schema 和重启恢复。
- [x] GitHub Actions 检查、APK / Linux 构建、GUI Artifact 工作流。
- [x] Linux 开发依赖与 Xvfb 自动化脚本。
- [ ] Android CI 构建结果确认、实机安装和平台交互验证。

## M1 AI Chat

- [x] DeepSeek / 自定义兼容接口、能力校验、系统安全存储、连接测试。
- [x] SSE、多轮、上下文限制、取消、重新生成、超时、一次有限重试和明确错误提示。
- [x] 持久化会话 / 消息 / 草稿，搜索、重命名、软删除、编辑并分支重问。
- [x] 文件/Android 照片和相机导入、持久化原图、预览和多图输入。
- [x] Markdown、数学、复制、选择、代码块、教学模式与基础状态。
- [x] 隔离 Mock、AI/数据库/Controller 自动化测试。
- [ ] 使用用户自己的 Key 完成真实 DeepSeek 文本与视觉问答验证。
- [ ] Android 真机：安全存储、照片选择、拍照、进程恢复、软键盘与长列表。

## 下一阶段

M2：知识 CRUD 与修订/撤销、错题图片与解析、裁剪/压缩/分题、可恢复的受控 AI 工具、双向关联。

M3：结构化题目校验与可信度、Chat 可操作题卡、确定性判分、幂等作答记录、错题与变式训练、教学状态流转。优先验收「上传错题→引导→检测→反馈→变式→保存」。

M4：确定性间隔复习、真实数据的薄弱点分析与今日任务。没有足够数据时不显示虚假精确分数。

M5：带版本与完整性校验的备份恢复（不含 Key）、搜索和批量体验、无障碍与性能、Android 实机和 Linux 桌面稳定性。

所有未勾选项均未达到完整验收；已接入的真实 API 不代表已通过真实凭据测试。

## 本次验证（2026-11-03）

- `flutter analyze` 无问题；18 项逻辑、数据库与 Widget 测试通过，包含固定字体的数学 Golden。
- 真实 Linux GUI 集成测试通过：输入问题 → Mock 流式回复 → 数据库保存 → 切换页面 → 草稿恢复。
- Linux 正式版与隔离 Mock Release 均成功构建；Xvfb + llvmpipe 实际完成鼠标键盘操作和桌面/手机尺寸截图，截图已读取并完成视觉检查。
- 深色手机 Chat Golden 已生成并查看；公式错误回退、矩阵、多行公式均有渲染验证。
- Git 推送及 GitHub 连接器写入均收到 403 `Resource not accessible by integration`。代码保存在本地 Git 提交；远程仓库尚未更新，Actions 尚未运行。
- 无真实 API Key，真实 DeepSeek 文本/视觉问答未验证；无 Android 实机或模拟器，平台专属交互未验证。

构建并发约束：Linux debug / release 共享 `linux/flutter/ephemeral`，必须顺序构建，防止调试引擎和 AOT 资源被混装。CI 已按顺序执行。

Android 本地构建尝试：已安装 Java、Android 36 平台及 Build Tools 36；Gradle 配置推进至 NDK 安装。NDK 28.2 解压需要约 2.14 GiB，连同工具链和缓存超出当前约 8 GiB 工作区容量，两次清理重试仍返回 `No space left on device`。未生成 APK，不标记 Android 构建通过。已降低 Gradle 至 3 GiB 堆、2 个 worker；后续在磁盘充足的环境或具备写权限的 GitHub Actions 中继续验证。
