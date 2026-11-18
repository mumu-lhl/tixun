# Tokenizer data

These files are bundled for offline text tokenization. Provider-reported usage remains authoritative for billing; tokenizing visible text does not include protocol framing, images, or hidden reasoning.

- `deepseek_v4.json`: DeepSeek V4 tokenizer from https://cdn.deepseek.com/api-docs/deepseek_v4_tokenizer.zip, linked by https://api-docs.deepseek.com/quick_start/token_usage/. SHA-256: `89085f12ef79460ac5f66d1119325ddfc694b4ab209d80bbd81d35f081dc9614`.
- `cl100k_base.tiktoken`: https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken; SHA-256: `223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7`.
- `o200k_base.tiktoken`: https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken; SHA-256: `446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d`.

GPT model-to-encoding mapping and pre-tokenization patterns follow [tiktoken](https://github.com/openai/tiktoken); see [its MIT notice](LICENSE.tiktoken). Only recognized models are selected; other models have no local breakdown.

The checksums pin the exact API vocabularies. The tiktoken code license does not by itself verify the redistribution terms of its separately hosted rank files. The DeepSeek API ZIP does not include a license and its tokenizer differs from the one in the MIT-licensed DeepSeek-V4-Flash model repository. Confirm the redistribution terms of these exact assets before shipping them in a public release.
