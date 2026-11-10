# ChatGPT 订阅接入

代码说明更新：2026-11-10。官方 OAuth 登录和 Responses 适配已包含在近期 Nightly，旧稳定版 v0.5.2 不包含。真实账号授权、实际模型权限和 Android 实机验收仍待完成；隔离测试不能代替这些验收。

## 使用方式

「设置 → 模型与连接 → ChatGPT 订阅 → Continue with ChatGPT」，在系统浏览器授权后返回应用，选择账号、模型和思考强度，点击「使用此账号和模型」。账号和工作区的可用模型取自实际模型列表，图片能力未声明时默认关闭，允许用户依据模型文档明确开启。连接测试使用当前选项，只有收到完整结束事件才显示成功。

可重新授权或退出账号。相同邮箱的不同注册记录按 client ID 和已验证 sub 隔离，选择器显示注册 ID 后缀。切换账号停止当前聊天。启用订阅前的 API 配置会保留，设置中可恢复；API Key 仍按原地址保存在系统安全存储中。

## 实现边界

- 系统浏览器、127.0.0.1 动态端口回调、S256 PKCE、state、nonce，三分钟登录超时和取消。host ID 按安装实例保存，首次使用动态注册，后续使用该账号的已发行 client ID。
- 官方 discovery/JWKS、仅 RS256，校验 issuer、audience、过期时间、issued-at、nonce、sub 和多 audience 的 azp。确认实际授予 `resource.invoke` 与 `chatgpt.tokens.use.direct`。不使用其他应用登录文件或私有 backend-api。
- 账号、注册元数据与令牌整体写入系统安全存储，不写入数据库、备份或日志。刷新按账号合并并原子替换轮换令牌；退出先清除本机令牌，再请求远程撤销。远程失败会明确提示；登录/退出并发有保护。
- 推理固定使用公共 `/v1/responses`，请求 `store:false`、`stream:true`、按上下文预算准备的历史与摘要。系统提示转换为 instructions，图片转换为 input_image，省略当前订阅路线不支持的字段。
- 应用工具置于命名空间中，继续经过现有参数校验、会话权限、逐项写入确认和调用上限。加密推理与相关输出只在当前请求的多轮工具过程中回传，不写入聊天记录。思考档位按模型目录或明确的能力回退选择，`xhigh` 与 `max` 原样区分；模型默认不发送强度参数，支持的 `none` 则明确请求不推理。
- 只有 `response.completed` 算成功；中途额度错误、未完成、断流和错误 JSON 都有失败反馈，不切换到 API 计费。页面提供官方用量/授权管理入口。

## JOSE 依赖与验证约束

锁定 `jose 0.3.5+2`。公开通告 [GHSA-vm9r-h74p-hg97](https://github.com/advisories/GHSA-vm9r-h74p-hg97) 的 Pub 修复版本为 `0.3.5+1`；GitHub 的版本查询仍把 `0.3.5+2` 匹配到该通告，与 Pub 的修复版本数据不一致。当前集成 Token 无权读取仓库单条 Dependabot 告警详情，因此未擅自关闭告警或宣称仓库已无告警。

应用独立落实该通告的保护策略：在签名验证前拒绝 token header 中的 `jwk`、`jku`、`x5u`，只接受 RS256，并只使用官方 discovery 指向的 JWKS。加入攻击者自行签名并内嵌公钥/密钥地址的回归测试；不会因依赖版本比较差异而信任 token 自带密钥。

## 已验证与待验证

已验证签名与身份拒绝、PKCE 回调、稳定注册复用、多账号隔离、轮换刷新、取消、退出并发、晚到额度错误、图片请求构造、加密推理回传、真实工具创建交互题、备份排除令牌，以及中英文、手机/桌面、深浅色 Linux GUI 流程。自动化使用保留域名与自签测试夹具，不读取生产凭据或消耗真实账号额度。

仍需在 Android 和 Linux 上用实际账号确认授权浏览器、系统安全存储、模型目录、图片能力与订阅推理。受账号、工作区和官方预览政策影响，不能保证所有 Plus/Pro 账号都有相同模型或额度。

## 官方依据

- [开源本地应用概览](https://developers.openai.com/siwc/token-sharing-open-source)
- [登录与授权校验](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [账号与刷新](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions)
- [模型与 Responses 接口](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [当前预览限制](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
