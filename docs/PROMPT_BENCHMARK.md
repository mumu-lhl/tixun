# 提示词 A/B benchmark

入口：`scripts/prompt_benchmark.py`（Python 标准库）。与具体功能、提交和案例数量解耦。ChatGPT 订阅通过 `scripts/eval_chatgpt_prompts_test.dart` 复用题训的正式 Adapter；另支持 OpenAI-compatible Chat Completions API（不支持 Anthropic 原生 Messages 协议）。不自动评判教学质量。

## 数据集

保存 UTF-8 JSON。每个 case 必须具有相同的全部 variants；配对的 input 与 expectJson 必须一致。instructions 是完整请求提示词，input 是原样发送的字符串，可包含序列化 JSON。任务不同可使用不同 instructions。标签不要求叫 old/new。

```json
{"requests":[
  {"case":"paraphrase","variant":"A","instructions":"Paraphrase in plain English.","input":"It slipped my mind.","expectJson":false},
  {"case":"paraphrase","variant":"B","instructions":"Give one plain English paraphrase preserving the meaning, without explanation.","input":"It slipped my mind.","expectJson":false}
]}
```

仅使用合成或已脱敏数据。计划和结果保存完整提示词、输入和公开回答，不能视作隐私脱敏工具。

已有历史评测可离线导入（不复制响应）：

```bash
python3 scripts/prompt_benchmark.py import-snapshots docs/evals/language-prompts-83b73ba /tmp/language-suite.json
# 或直接从历史 Git 提取相同的 13 对请求：
python3 scripts/eval_language_prompts.py /tmp/language-suite-from-git.json
```

后续版本应从实际请求导出/准备新的请求快照，不要用历史源码提取器代表 main 的自适应请求。历史快照没有 learnerProfile。

## 先生成计划，再显式联网

```bash
python3 scripts/prompt_benchmark.py prepare /tmp/language-suite.json /tmp/prompt-run \
  --provider chatgpt --model gpt-6.1-terra --repeats 3 --seed 42 --effort high
# 检查 /tmp/prompt-run/plan.json；此时不读凭据、不发请求
python3 scripts/prompt_benchmark.py run /tmp/prompt-run --allow-live --max-calls 78
python3 scripts/prompt_benchmark.py report /tmp/prompt-run
```

需将 `flutter` 加入 PATH。订阅路线仅显式读取题训 Linux Secret Service 中的 ChatGPT 账号；不会读取 Pi 凭据。标准 OAuth 刷新可能更新题训令牌，保留其他存储项；请勿同时修改账号设置。CA 和代理沿用环境的 `NODE_EXTRA_CA_CERTS` / `HTTPS_PROXY`，不关闭 TLS 校验。

API 路线：

```bash
python3 scripts/prompt_benchmark.py prepare suite.json /tmp/api-run --provider api --model YOUR_MODEL
# 在安全环境中设置 BENCHMARK_API_KEY，不把密钥写入命令、数据集或配置文件
python3 scripts/prompt_benchmark.py run /tmp/api-run --allow-live --max-calls 2 \
  --endpoint https://api.openai.com/v1/chat/completions --key-env BENCHMARK_API_KEY
```

API Key **只发送到你明确指定的 HTTPS endpoint**，不要使用不信任的地址；不跟随重定向。不自动读取任何应用 Key。API 路线仅发送 model/messages，使用服务商默认采样，不发送订阅专用 effort。不要跨路线直接比较用量或模型质量。

## 可复现与失败处理

- 计划包含精确请求、模型、订阅 effort、重复次数、种子和 SHA-256 指纹。按种子打乱顺序，顺序执行，每个请求独立 Conversation。
- `--max-calls` 是本次待执行请求的上限；超限时在任何模型请求前停止。默认不重试，没有付费回退。
- 每个请求发送前保留结果占位；中断或失败也不自动再次收费。再次运行只执行没有结果文件的案例。确需重测时建立新的运行目录，保留失败证据。
- 运行目录不可换提示词/模型；API endpoint 和凭据变量名也锁定。只记录允许的输出字段，不保存原始 HTTP 错误、Header、认证或推理状态。
- 不保证跨进程锁和并发 OAuth 安全；同一个运行目录仅启动一个进程。
- API 的 stop、订阅的 completed 才计为完成；JSON 可解析不等于符合业务 schema，也不等于内容正确。

## 报告与盲评

`summary.json` 按 variant 汇总完成次数、JSON 检查、耗时总和、可用 token 用量。缺少用量不冒充零消耗，参看 usageAvailable。不同案例长度不可直接当作质量分数。

`blind.json` 隐藏 variant、提示词和模型，按种子打乱，包含输入与公开输出；`blind-key.json` 单独保存映射。让不知道映射的评审先按 case 的固定标准打分，再揭盲按同 case、同 repeat 比较。题目正确性、唯一答案、忠于原意、语言/难度遵循分别检查；允许双方都失败。输出本身可能暴露版本风格，因此不声称绝对盲法。不要把映射交给评审，不要只挑有利重跑；预留 holdout，报告样本数、模型请求名和局限。

自动离线测试：

```bash
python3 -m unittest discover -s scripts/tests -p test_prompt_benchmark.py
```

## 本次凭据检查

2026-11-25：检查本地所有 Git 引用的 blob、scripts、评测产物和 `/tmp/tixun*` 文件，共 3,812 项；在进程内匹配当前已知凭据及常见 Key/JWT 模式，未发现命中，没有输出凭据。范围不包含远端服务日志、已删除文件、未知旧凭据或所有终端历史，不能证明绝无泄露。此前误用 Pi DeepSeek 凭据属于未经许可选择凭据来源，已单独记录在历史评测报告，不等于发现密钥被公开。
