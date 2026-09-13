# LLM benchmark: ubnt2080rm / NVIDIA GeForce RTX 3090

- Date: 2026-09-12T12:19:35+02:00
- OS: Ubuntu 24.04.4 LTS; driver 570.207; Ollama 0.34.0
- CPU: ; RAM:  GB
- VRAM: 24576 MiB; power cap: 430.00 W
- Settings: num_predict=256 (short), temperature=0, seed=42; long prompt ≈16k tokens

| Model | Load (s) | Prompt eval (tok/s) | Generation (tok/s) | TTFT short (s) | Long-ctx prompt eval (tok/s) | Long-ctx TTFT (s) | VRAM (MiB) | Avg power (W) | tok/Wh |
|---|---|---|---|---|---|---|---|---|---|
| qwen3.6-27b-64k | 8.1 | 191.4 | 51.3 | 0.21 | 1165 | 10.83 | 22705 | 329 | 561.0 |
| qwen3.6:35b | 18.6 | 211.4 | 93 | 0.19 | 2484 | 5.08 | 23299 | 174 | 1924.0 |
| gemma4:31b | 15.3 | 171.1 | 16.6 | 0.27 | 897.5 | 14.07 | 23238 | 242 | 247.0 |

## Concurrency (qwen3.6-27b-64k, 4 parallel requests, 128 tokens each)

OLLAMA_NUM_PARALLEL in service: not set (=1, requests are queued)
- Aggregate: 512 tokens in 23.6 s = 21.7 tok/s

## Raw compute (PyTorch bf16 matmul 8192², best of 5)

- torch not available, skipped
