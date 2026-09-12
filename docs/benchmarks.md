# Benchmarks

Measured with [`bench/llm-bench.sh`](../bench/llm-bench.sh) against a local Ollama endpoint (num_predict=256, temperature=0, long prompt ≈16k tokens). Raw output per machine lives in [`bench/results/`](../bench/results/): [3090](../bench/results/ubnt2080rm-RTX-3090-2026-09-12.md), [4090](../bench/results/4090rtx-RTX-4090-2026-09-13.md).

## Host

| | RTX 3090 (24 GB) | RTX 4090 (24 GB) |
|---|---|---|
| OS / driver / Ollama | Ubuntu 24.04.4, 570.207, Ollama 0.34.0 | Ubuntu 26.04.1, 595.91.07, Ollama 0.34.0 |
| CPU / RAM | i9-9900K, 31 GB | i9-13900K, 62 GB |
| Power cap | 430 W | 450 W |
| Model pull (`ollama pull`, 16 GB) | peaked at 774 MB/s, ~40 MB/s at the tail | ~200 MB/s sustained, all three models (58 GB) in ~7 min |
| Display | headless (Xorg virtual display) | 4K monitor, Wayland — desktop + Sunshine cost ~0.4–1 GB VRAM, so the run was done with the remote-desktop services stopped (see [rtx4090-dl-workstation](https://github.com/rmesterheide/rtx4090-dl-workstation)) |

## Inference (3090: 2026-09-12, 4090: 2026-09-13)

Same script, same Ollama version, same models and context sizes, `OLLAMA_NUM_PARALLEL=1` on both.
Cells read `3090 → 4090 (factor)`.

| Model | Generation (tok/s) | Prompt eval, 16k ctx (tok/s) | Time to first token, 16k ctx (s) | Avg power (W) | tok/Wh |
|---|---|---|---|---|---|
| qwen3.6-27b-64k (dense, 64k ctx) | 51.3 → **93.3** (1.8×) | 1165 → **2623** (2.3×) | 10.8 → **4.8** | 329 → 329 | 561 → **1021** (1.8×) |
| qwen3.6:35b (MoE, 3B active) | 93.0 → **164.4** (1.8×) | 2484 → **5960** (2.4×) | 5.1 → **2.1** | 174 → 130 | 1924 → **4552** (2.4×) |
| gemma4:31b ¹ | 16.6 → 31.8 (1.9×) | 898 → 2046 (2.3×) | 14.1 → 6.2 | 242 → 209 | 247 → 548 (2.2×) |

¹ Not a fair number on either card: at the VRAM limit with Ollama's 256k default context for this model, and the 4090 run additionally shows an odd 12 tok/s short-prompt eval / 3.7 s TTFT. Re-run both sides with a smaller `num_ctx` before drawing conclusions.

Cold load (3090 → 4090): 8.1 → 3.3 s / 18.6 → 17.1 s / 15.3 → 16.9 s (the 27B-64k model loads 2.5× faster, the others are disk-bound). Short-prompt TTFT: 0.2–0.3 s → 0.1 s.

Concurrency (4 parallel requests, queued on both because `OLLAMA_NUM_PARALLEL=1`): 21.7 → 35.8 tok/s aggregate. Raw bf16 matmul: 3090 n/a (no torch) → **171.7 TFLOPS** on the 4090 (torch 2.14+cu132). `OLLAMA_NUM_PARALLEL=4` was tried on the 4090 first and rejected: it multiplies the KV cache and pushed the 64k model to 93 % GPU / 37 tok/s.

### What the numbers say

- **Generation: a flat 1.8× across all three models.** Token generation is memory-bandwidth-bound; the 4090's ~1008 GB/s vs. the 3090's 936 GB/s explains only ~8 % of that, the rest is the Ada architecture (larger L2, faster clocks) and Ollama's CUDA 13 build for `sm_89`.
- **Prompt processing: 2.3–2.4×.** This is compute-bound, so the 4090's tensor cores show up here. Pasting a 16k-token document now costs 2–5 s before the first token instead of 5–14 s — this is where the agent feels the difference most.
- **Efficiency: same or lower power for ~2× the work.** The MoE model runs at 130 W on the 4090 and delivers 4552 tok/Wh, 2.4× the 3090 and 4.5× the dense 27B on the same card.
- **The MoE model remains the agent's best choice on both cards:** fastest, cheapest, and the only one with real VRAM headroom (~1.2 GB) on 24 GB.
- Both cards fill to within ~1.3 GB with any of these models. On the 4090 even the desktop's ~1 GB VRAM pushed the 64k model partially into RAM, so on a 24 GB card *nothing else* may share the GPU while the agent runs.

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
