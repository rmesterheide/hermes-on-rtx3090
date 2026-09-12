# Benchmarks

Everything here is meant to be run unchanged on both machines (RTX 3090 today, RTX 4090 next), so the numbers are comparable line by line.

## 1. LLM inference (`llm-bench.sh`)

```bash
ollama pull qwen3.6:35b && ollama pull gemma4:31b     # once; qwen3.6-27b-64k already exists
bench/llm-bench.sh                                     # ~10 min, writes bench/results/<host>-<gpu>-<date>.md
```

Per model it measures cold load time, prompt processing (tok/s), generation (tok/s), time to first token, the same for a ~16k-token prompt, VRAM, average power draw and tokens per watt-hour. Then 4 parallel requests (set `OLLAMA_NUM_PARALLEL=4` in the Ollama service first, otherwise they queue) and a raw bf16 matmul TFLOPS number via PyTorch.

Readers care about three of those: generation tok/s (how fast it "types"), long-context prompt eval (how long it thinks before answering when you paste a document), and tok/Wh (what it costs).

## 2. Agent turn, end to end (stopwatch)

Same Hermes question on both machines, fresh session each time, three runs, median:

> Run nvidia-smi and df -h / and tell me how much VRAM is in use and how much space is free on the root partition.

> How many and which lights are on?

Time from Enter to the last character of the answer. This is the number that shows what the hardware means for the *agent*, not just for the model.

## 3. Optional, for the screenshots

- `nvtop` side by side with Hermes during test 2.
- Whisper: `pip install faster-whisper`, transcribe the same 10-minute audio file, report seconds per minute of audio.
- Image generation: same SDXL prompt, 1024x1024, 30 steps, report seconds per image.

## Results

| Machine | File |
|---|---|
| RTX 3090 | [`results/ubnt2080rm-RTX-3090-2026-09-12.md`](results/ubnt2080rm-RTX-3090-2026-09-12.md) |
| RTX 4090 | `results/` (pending) |
