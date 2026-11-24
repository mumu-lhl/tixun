# ChatGPT 订阅：提示词 A/B 小样本

## 方法与网络修复

使用题训 Linux 安全存储中的 ChatGPT 登录，经现有 `ChatGptAuth` 和 `ChatGptResponses` 调用官方订阅路线；没有读取 Pi 凭据，也没有转入 API Key 计费。模型请求值为题训保存的 `gpt-6.1-terra`，思考强度 high；Adapter 不暴露响应模型名，因此此处不声称验证了底层模型版本。无联网工具。

此前网络错误可复现为 Dart `HandshakeException: CERTIFICATE_VERIFY_FAILED: self signed certificate in certificate chain`。当前环境设置 HTTPS_PROXY，但 Dart 的信任根未包含 NODE_EXTRA_CA_CERTS 指向的本机代理 CA。评测客户端显式加载该 CA 并使用环境代理后，无凭据探针由 TLS 错误变为正常 HTTP 401；随后订阅请求全部成功。未关闭证书校验、未安装系统级 CA、未修改生产网络适配器。

复用第一轮保存的 26 份固定请求快照（基线 `83b73ba^`、新版 `83b73ba`），13 个合成案例各一次，输入与指令不变，包括两边相同的 JSON 格式指令。固定种子 20261125 打乱顺序、逐次独立请求；未设 temperature 或输出 cap（遵循订阅适配器），无自动重试。仅使用合成学习资料。请求文本、完成标志、输出、UTC 时间与服务商用量保存在同目录 JSON；不保存令牌、HTTP 认证头或内部推理内容。

开发助手看过版本标签后进行定性评审，**不是独立盲评**。每个案例每版只有一次；JSON 可解析也不代表生产 Dart 校验或教学质量通过。词汇修订、试卷复核、追问与指令注入案例未覆盖，不把本轮称为全功能验收。

## 完成情况与用量

| 指标 | 旧版 | 新版 |
| --- | ---: | ---: |
| 完成请求 | 13/13 | 13/13 |
| JSON 语法通过（解释是纯文本，不计） | 12/12 | 12/12 |
| 服务商输入 token | 52,146 | 53,288 |
| 服务商输出 token | 4,043 | 3,704 |
| 平均耗时（秒） | 8.166 | 7.516 |

新版输入约 +2.2%，输出约 -8.4%，耗时约 -8.0%。这只是本次样本描述，不证明总体节省或加速。订阅路线报告的输入用量含其自身开销，不可直接与 DeepSeek 轮次比较；本地没有价格或额度扣减明细，不估算金额。

## 逐案例观察

| 案例 | 观察 |
| --- | --- |
| vocabulary | 两版都将 translation 写成例句英文改述，词义/例句不再混淆；未复现 DeepSeek 新版退化。词形与单一词义合理。 |
| sentence_en | 两版均为合法等级枚举且均含四个检测。新版 advanced 的 deceptively short 比旧版 waived 例句略有难度，但等级校准仍需独立量表；干扰项普遍偏容易。新版将 left paraphrase 为 forgot 加入了非必然的遗忘含义。 |
| dialogue_zh | 新版题干、选项和解释均为中文，旧版题干与选项仍是英文。这是本轮最明确的遵循改善。新版保留“很可能”的语气。两版均未所有条目都按 focus=inference 出题，但生产规则只要求至少一半，不能误记为解析失败。 |
| context | 两版都使用 to run into / don't run into 等自然语法，未复现 DeepSeek 时态问题。新版提示较少直接说出“偶遇”，但部分选项仍明显错误。 |
| check | 两版都正确检测 special exhibitions 例外，新版更紧凑；未见实质准确率差异。 |
| explain | 两版均用两句准确解释 slipped my mind，输出 token 相同。 |
| reading | 两版均有可追溯证据。新版图书馆借物数据不能证明减废的推断有明确依据；仍有较易排除的干扰项，不能单靠这一题证明推理质量普遍提升。 |
| cloze | 新版 without her help、agreed to attend 搭配明确，叙事因果连贯。旧版 notice/recognise 有可讨论的近义干扰，notice 更自然；不把“另一个词语法上能放进去”直接等同于必然双答案。新版本次更稳妥，仍需更多题目验证。 |
| writing_task | 两版都有完整情境、动机和未解决的转折；新版加入接受陌生人搭车的犹豫，旧版加入店主认出主人公，均可用于续写。 |
| writing_feedback | 两版均给三个维度满分、notes=[]，只把补充时间作为下一步建议，没有人为挑错；新版未体现明显优势。 |
| quick_express | 两版意思正确；新版更短并提供可保存句子，旧版给出 until later today 的强调变体。没有单一绝对优胜。 |
| quick_meaning | 两版都分开 see 的过去式与 saw 名词/动词。新版更短，旧版额外给 seen、sawed/sawn；详略取舍，不是准确性胜负。 |
| quick_usage | 新版 brief 保留两类核心结构与例子，191 输出 token，旧版 370 并扩展 get used to 和问句；新版更符合简短请求，但未测试详细模式。 |

## 结论与后续

这批 ChatGPT 样本支持新版的中文语言约束及简洁输出方向，也说明先前 DeepSeek 失败不是所有模型都会复现。不能将两轮合并成总体胜率，不能用一次采样证明修复了歧义或等级校准。

本轮没有为迎合样本继续修改生产提示词；保留原始失败与全部输出。下一阶段优先补齐未覆盖任务、真实生产解析验证、留出输入与独立盲评，而非堆叠通用禁令。若后续修改提示词，必须作为另一版本另存评测，不能覆盖本轮记录。

## Rebase 边界

评测完成后已按用户要求 rebase 到本地 main（`d74da0b`）。main 已包含原提示词提交 `83b73ba`，因此不存在重复应用。八类固定契约与速查共享指令未改变；main 新增的 `generationProfileInstructions` 与 learnerProfile 消息属于另一个请求边界，本轮固定快照未包含它们。不能将本轮结果宣称为带自适应学习历史的端到端评测；它们仍是 `83b73ba^` 对 `83b73ba` 的历史 A/B。

## 复现

仓库根目录手工运行：

```sh
TIXUN_LIVE_EVAL=1 EVAL_CHATGPT_MODEL=gpt-6.1-terra \
  flutter test --no-pub scripts/eval_chatgpt_prompts_test.dart --reporter expanded
```

这是 Linux 专用手工评测入口，依赖题训现有安全存储和 secret-tool；需要已登录账号。脚本可按 ChatGptAuth 的标准刷新流程更新安全存储，其他密钥保留。若设置了 HTTPS_PROXY/NODE_EXTRA_CA_CERTS，加载对应代理与 CA；不跳过 TLS 校验。已有同名结果跳过，避免重复消耗；更换模型或版本时必须使用新输出目录，不将不同模型混入当前目录。当前脚本固化本轮版本与 26 份快照，不是通用 benchmark 框架。
