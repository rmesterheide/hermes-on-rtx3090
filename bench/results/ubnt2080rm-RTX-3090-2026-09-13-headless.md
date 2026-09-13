# LLM benchmark: ubnt2080rm / NVIDIA GeForce RTX 3090

- Date: 2026-09-13T08:18:12+02:00
- OS: Ubuntu 24.04.4 LTS; driver 570.207; Ollama 0.34.0
- CPU: Intel(R) Core(TM) i9-9900K CPU @ 3.60GHz; RAM: 31 GB
- VRAM: 24576 MiB; power cap: 430.00 W
- Settings: num_predict=256 (short), temperature=0, seed=42; long prompt ≈16k tokens

| Model | Load (s) | Prompt eval (tok/s) | Generation (tok/s) | TTFT short (s) | Long-ctx prompt eval (tok/s) | Long-ctx TTFT (s) | VRAM (MiB) | Avg power (W) | tok/Wh |
|---|---|---|---|---|---|---|---|---|---|
| qwen3.6-27b-64k | 5.5 | 260.6 | 67.1 | 0.15 | 1317.5 | 9.58 | 22114 | 347 | 696.0 |
| qwen3.6:35b | 13.9 | 319 | 135.1 | 0.13 | 3445.6 | 3.66 | 23002 | 224 | 2171.0 |
| gemma4:31b | 14.2 | 285.7 | 27.4 | 0.16 | 1087.3 | 11.61 | 23048 | 346 | 285.0 |

## Concurrency (qwen3.6-27b-64k, 4 parallel requests, 128 tokens each)

OLLAMA_NUM_PARALLEL in service: not set (=1, requests are queued)
- Aggregate: 512 tokens in 19.6 s = 26.2 tok/s

## Raw compute (PyTorch bf16 matmul 8192², best of 5)

- torch not available, skipped
