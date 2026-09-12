# Benchmarks

Measured with [`bench/llm-bench.sh`](../bench/llm-bench.sh) against a local Ollama endpoint (num_predict=256, temperature=0, long prompt ≈16k tokens). Raw output per machine lives in [`bench/results/`](../bench/results/). The RTX 4090 column will be filled in once the second machine is migrated to Ubuntu.

## Host

| | RTX 3090 (24 GB) | RTX 4090 (24 GB) |
|---|---|---|
| OS / driver / Ollama | Ubuntu 24.04.4, 570.207, Ollama 0.34.0 | _tbd_ |
| Power cap | 430 W | _tbd_ |
| Model pull (`ollama pull`, 16 GB) | peaked at 774 MB/s, ~40 MB/s at the tail | _tbd_ |

## Inference (2026-09-12)

| Model | Generation (tok/s) | Prompt eval, 16k ctx (tok/s) | Time to first token, 16k ctx (s) | VRAM (MiB) | Avg power (W) | tok/Wh |
|---|---|---|---|---|---|---|
| qwen3.6-27b-64k (dense, 64k ctx) | 51.3 | 1165 | 10.8 | 22705 | 329 | 561 |
| qwen3.6:35b (MoE, 3B active) | **93.0** | **2484** | **5.1** | 23299 | 174 | **1924** |
| gemma4:31b | 16.6 ¹ | 898 | 14.1 | 23238 | 242 | 247 |

¹ Suspiciously slow and at the VRAM limit; most likely partially offloaded to system RAM (Ollama's 256k default context for this model). Not a fair number for the card. Re-run with a smaller `num_ctx` before comparing.

Cold load: 8.1 s / 18.6 s / 15.3 s. Short-prompt TTFT: 0.2–0.3 s for all three.

Concurrency test ran with `OLLAMA_NUM_PARALLEL=1` (requests queued), so its 21.7 tok/s aggregate is not meaningful yet. PyTorch was not available in the system Python, so the raw TFLOPS line is empty; both to be repeated.

### What the 3090 numbers say

- The MoE model is the surprise: almost 2x the generation speed of the dense 27B at half the power draw, which makes it 3.4x more efficient per watt-hour. It is also the model that makes the agent feel snappy.
- Pasting a document is where you wait: 5–14 s before the first token for 16k tokens of context. This is the metric where the 4090 should pull furthest ahead.
- All three models fill the card to within ~1.5 GB. Nothing else can share the GPU.

## Agent turn, end to end

Stopwatch from Enter to the end of the answer, fresh Hermes session, median of three (see [`bench/README.md`](../bench/README.md)).

| Question | RTX 3090 | RTX 4090 |
|---|---|---|
| nvidia-smi + df -h summary | _tbd_ | _tbd_ |
| "How many and which lights are on?" (Home Assistant skill) | _tbd_ | _tbd_ |

## Quick check

```bash
# tokens/s for pure generation, no agent overhead
ollama run qwen3.6-27b-64k --verbose "Explain PCIe lanes in three sentences." 2>&1 | grep -E "eval rate|prompt eval rate"
```
