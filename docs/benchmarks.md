# Benchmarks

Numbers observed while running Hermes Agent against a local Ollama endpoint.
The RTX 4090 column will be filled in once the second machine is migrated to Ubuntu.

| Metric | RTX 3090 (24 GB) | RTX 4090 (24 GB) |
|---|---|---|
| Host | Ubuntu 24.04.4, driver 570.207, NVMe | _tbd_ |
| Model | `qwen3.6:27b` (Q4, 18 GB on disk) | _tbd_ |
| Context window | 65,536 tokens | _tbd_ |
| VRAM with model loaded | 22.6 GB of 24 GB (~92 %) | _tbd_ |
| Power draw during inference | 380–400 W (of 430 W cap) | _tbd_ |
| GPU temperature during inference | 61–70 °C, fan ~84 % | _tbd_ |
| Model pull (`ollama pull`) | 16 GB, peaked at 774 MB/s, ~40 MB/s at the tail | _tbd_ |
| First response in a fresh Hermes session | slow — ~8k-token system prompt has to be processed first, plus Qwen's thinking phase | _tbd_ |
| Simple tool call (`nvidia-smi` + `df -h`) | tool execution 0.1–0.2 s; total turn dominated by model latency | _tbd_ |
| Home Assistant skill (curl + jq, 192 tokens back) | tool call 13.7 s incl. model reasoning; full answer well under a minute | _tbd_ |
| Session that had to *search* for a smart-home system (no skill/token) | 82.7 s of `find`/`systemctl` before giving up | n/a |

## How to reproduce a number

```bash
# tokens/s for pure generation, no agent overhead
ollama run qwen3.6-27b-64k --verbose "Explain PCIe lanes in three sentences." 2>&1 | grep -E "eval rate|prompt eval rate"
```

Add the two `eval rate` lines to the table for each card.
