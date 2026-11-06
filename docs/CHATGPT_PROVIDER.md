# ChatGPT 订阅接入

核对日期：2026-11-06。当前题训尚未实现 ChatGPT 登录；现有 OpenAI-compatible 服务使用 API Key，不代表已接入 Plus/Pro 订阅额度。

## 是否可行

可行。OpenAI 已为开源、本地运行的应用提供 [Sign in with ChatGPT](https://developers.openai.com/siwc/token-sharing-open-source)。用户在官方浏览器页面授权应用使用账号允许共享的 ChatGPT plan usage。额度、模型及权限由账号实际授权决定，不保证任意 Plus/Pro 账号都具有相同范围，也不代表无限使用。

此路径使用 OAuth 令牌调用公共 `https://api.openai.com/v1/responses`。不应抓取其他应用的 `auth.json`、复用 Codex 的客户端身份或调用 ChatGPT 私有 backend-api。API Key 与订阅授权应作为两个独立的 Provider 登录方式。

## 接入前必须完成

1. Android、Linux 的系统浏览器登录与本机回调，PKCE、state、nonce；按安装实例保留 host ID，使用官方动态注册并保存返回的 client ID。
2. 通过官方 JWKS 验证 ID token 的签名、issuer、audience、有效期、nonce 及账号身份；确认实际授予的推理权限。
3. 按 client ID 与已验证身份隔离账号，在系统安全存储中原子保存和串行刷新令牌。令牌不进入数据库、备份或日志；退出登录支持撤销授权。
4. 从当前账号的模型列表取实际可选模型。Responses 请求使用 `store:false`、`stream:true`；把现有 Chat Completions 的消息、图片、思考参数和受控工具转换为对应协议，正确处理工具多轮与中断。
5. 遇到额度耗尽或订阅权限不足时明确反馈，不静默转用 API 计费。完成 OAuth/流式/账号隔离测试后，再分别做 Android、Linux 的真实账号验收。

## 官方依据

- [开源本地应用概览](https://developers.openai.com/siwc/token-sharing-open-source)
- [登录与授权校验](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [账号与刷新](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions)
- [模型与 Responses 接口](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [当前预览限制](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
