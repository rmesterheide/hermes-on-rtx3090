# Benchmarks

Measured with [`bench/llm-bench.sh`](../bench/llm-bench.sh) against a local Ollama endpoint (num_predict=256, temperature=0, long prompt ≈16k tokens). Raw output per machine lives in [`bench/results/`](../bench/results/). The authoritative numbers are the **headless runs** ([3090](../bench/results/ubnt2080rm-RTX-3090-2026-09-13-headless.md), [4090](../bench/results/4090rtx-RTX-4090-2026-09-13-headless.md)): graphics stack shut down via `systemctl isolate multi-user.target` so nothing but Ollama touches the GPU (1 MiB / 36 MiB baseline). Wrapper: [`bench/run-headless.sh`](../bench/run-headless.sh). The earlier `*-desktop-run.md` files are kept as evidence of what a running desktop costs — see below.

## Host

| | RTX 3090 (24 GB) | RTX 4090 (24 GB) |
|---|---|---|
| OS / driver / Ollama | Ubuntu 24.04.4, 570.207, Ollama 0.34.0 | Ubuntu 26.04.1, 595.91.07, Ollama 0.34.0 |
| CPU / RAM | i9-9900K, 31 GB | i9-13900K, 62 GB |
| Power cap | 430 W | 450 W |
| Model pull (`ollama pull`, 16 GB) | peaked at 774 MB/s, ~40 MB/s at the tail | ~200 MB/s sustained, all three models (58 GB) in ~7 min |
| Idle VRAM with desktop up | 826 MiB (Xorg, gnome-remote-desktop 258, Sunshine 262) | ~400 MiB (GNOME/Wayland, Sunshine; RDP disabled) |
| Benchmark condition | headless, 1 MiB baseline | headless, 36 MiB baseline |

## Inference (headless, 2026-09-13)

Same script, same Ollama 0.34.0, same models and context sizes, `OLLAMA_NUM_PARALLEL=1`, graphics stack
down on both machines. Cells read `3090 → 4090 (factor)`.

| Model | Generation (tok/s) | Prompt eval, 16k ctx (tok/s) | Time to first token, 16k ctx (s) | Avg power (W) | tok/Wh |
|---|---|---|---|---|---|
| qwen3.6-27b-64k (dense, 64k ctx) | 67.1 → **93.3** (1.4×) | 1318 → **2623** (2.0×) | 9.6 → **4.8** | 347 → 328 | 696 → **1024** (1.5×) |
| qwen3.6:35b (MoE, 3B active) | 135.1 → **201.6** (1.5×) | 3446 → **6878** (2.0×) | 3.7 → **1.8** | 224 → 150 | 2171 → **4838** (2.2×) |
| gemma4:31b ¹ | 27.4 → 37.0 (1.4×) | 1087 → 2258 (2.1×) | 11.6 → 5.6 | 346 → 302 | 285 → 441 (1.5×) |

¹ Still at the VRAM limit on both cards with Ollama's 256k default context for this model; treat as indicative only until re-run with a smaller `num_ctx`.

Cold load (3090 → 4090): 5.5 → 3.0 s / 13.9 → 6.7 s / 14.2 → 5.7 s. Short-prompt TTFT ≤ 0.16 s on both.
Concurrency (4 requests, queued because `NUM_PARALLEL=1`): 26.2 → 52.7 tok/s aggregate. Raw bf16 matmul:
3090 n/a (no torch) → **171.8 TFLOPS** on the 4090 (torch 2.14+cu132).

### What the numbers say

- **Generation: 1.4–1.5×.** Token generation is memory-bandwidth-bound and the 4090 has only ~8 % more
  bandwidth than the 3090 (1008 vs 936 GB/s); the rest of the gain is Ada's larger L2 cache and higher clocks.
- **Prompt processing: a flat 2.0×.** Compute-bound, so the tensor cores show. A 16k-token document now
  costs 2–5 s before the first token instead of 4–12 s — the metric the agent feels most.
- **Efficiency:** the 4090 does the work at equal or lower power. The MoE model runs at 150 W and delivers
  4838 tok/Wh, 2.2× the 3090 and 4.7× the dense 27B on the same card.
- **The MoE model remains the agent's best choice on both cards:** fastest, cheapest, and the only one
  with real VRAM headroom.

### What a running desktop costs (the earlier runs)

The first runs were done with the desktop up (`*-desktop-run.md`). Compared with headless:

| Model | 3090 desktop → headless | 4090 desktop (Sunshine stopped) → headless |
|---|---|---|
| qwen3.6-27b-64k gen tok/s | 51.3 → 67.1 (**+31 %**) | 93.3 → 93.3 (was already fully on GPU) |
| qwen3.6:35b gen tok/s | 93.0 → 135.1 (**+45 %**) | 164.4 → 201.6 (+23 %) |
| gemma4:31b gen tok/s | 16.6 → 27.4 (**+65 %**) | 31.8 → 37.0 (+16 %) |

826 MiB of Xorg + remote-desktop daemons on the 3090 were enough to push every one of these ~23 GB models
partially into system RAM. The naive "4090 is 1.8× faster" from the first comparison was therefore mostly
the 3090 being handicapped; the real hardware gap is 1.4× generation, 2.0× prompt eval. On a 24 GB card,
**nothing else may share the GPU** — not even the login screen.

## Price context (September 2026)

What the two cards cost, to put the factors above on the other side of the scale.

| | RTX 3090 (24 GB) | RTX 4090 (24 GB) |
|---|---|---|
| Launch price | 1,499 € (Sept 2020, UVP) | 1,949 € (Oct 2022, UVP) |
| What I paid | not on file | 1,799 € (Gigabyte Aero OC, Mindfactory, Aug 2023) |
| Used market, Sept 2026 | ~750–950 € (eBay sold-price data via [borncity](https://borncity.com/news/nvidia-rtx-3090-der-ungekroente-ki-koenig-des-gebrauchtmarkts/)); asking prices on Kleinanzeigen up to ~1,400 € | ~2,000–2,200 € ([ComputerBase forum](https://www.computerbase.de/forum/threads/rtx-4090-gebrauchtpreis.2230231/)) |
| New, Sept 2026 | n/a | from ~3,390 € ([Geizhals](https://geizhals.de/nvidia-geforce-rtx-4090-founders-edition-a2815453.html)) — end of life, scarcity pricing |

Taking ~850 € vs ~2,100 € as the used-market midpoints, a used 4090 costs ~2.5× a used 3090 and
delivers (headless numbers above) 1.4–1.5× generation, 2.0× prompt eval, 2.2× tok/Wh:

| Per 100 € of used-card price | RTX 3090 | RTX 4090 |
|---|---|---|
| Generation, qwen3.6:35b (tok/s) | 15.9 | 9.6 |
| Prompt eval 16k, qwen3.6:35b (tok/s) | 405 | 328 |

Per euro the 3090 still wins on both — the 4090 buys latency (time to first token halves), power
efficiency and headroom, not throughput per euro. Two used 3090s cost less than one used 4090 and
give 48 GB of VRAM; that is the comparison to make before buying a 4090 for local LLM work in 2026.
Prices are snapshots and move; the sources are linked so the table can be redone.

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
