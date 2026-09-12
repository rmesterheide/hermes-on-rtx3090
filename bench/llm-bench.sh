#!/usr/bin/env bash
# LLM inference benchmark against a local Ollama endpoint.
# Produces bench/results/<hostname>-<gpu>-<date>.md so two machines can be compared line by line.
# Usage: bench/llm-bench.sh [model ...]      (default: qwen3.6-27b-64k qwen3.6:35b gemma4:31b)
set -euo pipefail

OLLAMA=${OLLAMA_HOST:-http://localhost:11434}
MODELS=("$@"); [ ${#MODELS[@]} -eq 0 ] && MODELS=(qwen3.6-27b-64k qwen3.6:35b gemma4:31b)
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | sed 's/NVIDIA GeForce //; s/ /-/g')
OUT="$(dirname "$0")/results/$(hostname)-${GPU}-$(date +%F).md"
mkdir -p "$(dirname "$OUT")"

need() { command -v "$1" >/dev/null || { echo "missing: $1"; exit 1; }; }
need curl; need jq; need nvidia-smi; need python3

# ---- helpers ---------------------------------------------------------------
gen() { # model prompt num_predict  -> JSON from /api/generate (non-streaming)
  curl -s "$OLLAMA/api/generate" -d "$(jq -cn --arg m "$1" --arg p "$2" --argjson n "$3" \
    '{model:$m,prompt:$p,stream:false,keep_alive:"10m",options:{num_predict:$n,temperature:0,seed:42}}')"
}
tps() { jq -r '(.eval_count / (.eval_duration/1e9)) | .*10|round/10'; }
pps() { jq -r '(.prompt_eval_count / (.prompt_eval_duration/1e9)) | .*10|round/10'; }
ttft() { jq -r '((.prompt_eval_duration + .load_duration)/1e9) | .*100|round/100'; }
power_start() { nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits -lms 500 > /tmp/power.$$ & echo $!; }
power_stop() { kill "$1" 2>/dev/null; sleep 0.6; awk '{s+=$1;n++} END{if(n) printf "%.0f", s/n; else print "n/a"}' /tmp/power.$$; rm -f /tmp/power.$$; }
unload() { curl -s "$OLLAMA/api/generate" -d "{\"model\":\"$1\",\"keep_alive\":0}" >/dev/null; sleep 2; }

SHORT_PROMPT="Explain in about 300 words how PCIe lanes, VRAM bandwidth and tensor cores each limit LLM inference speed on a consumer GPU."
LONG_PROMPT=$(python3 -c "print(('The quick brown fox jumps over the lazy dog while the platform engineer documents everything in git. ')*700)")  # ~16k tokens
LONG_PROMPT="$LONG_PROMPT
Summarise the text above in one sentence."

# ---- header ----------------------------------------------------------------
{
echo "# LLM benchmark: $(hostname) / $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
echo
echo "- Date: $(date -Is)"
echo "- OS: $(lsb_release -ds 2>/dev/null || uname -sr); driver $(nvidia-smi --query-gpu=driver_version --format=csv,noheader); Ollama $(ollama --version 2>/dev/null | awk '{print $NF}')"
echo "- CPU: $(lscpu | awk -F: '/Model name/{gsub(/^ +/,"",$2);print $2}'); RAM: $(free -g | awk '/Mem/{print $2}') GB"
echo "- VRAM: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader); power cap: $(nvidia-smi --query-gpu=power.limit --format=csv,noheader)"
echo "- Settings: num_predict=256 (short), temperature=0, seed=42; long prompt ≈16k tokens"
echo
echo "| Model | Load (s) | Prompt eval (tok/s) | Generation (tok/s) | TTFT short (s) | Long-ctx prompt eval (tok/s) | Long-ctx TTFT (s) | VRAM (MiB) | Avg power (W) | tok/Wh |"
echo "|---|---|---|---|---|---|---|---|---|---|"
} > "$OUT"

# ---- per model -------------------------------------------------------------
for M in "${MODELS[@]}"; do
  echo ">> $M"
  unload "$M"
  # cold load + warm-up
  C=$(gen "$M" "Say OK." 4); LOAD=$(echo "$C" | jq -r '.load_duration/1e9 | .*10|round/10')
  # short prompt, measured with power sampling
  PP=$(power_start); S=$(gen "$M" "$SHORT_PROMPT" 256); W=$(power_stop "$PP")
  TPS=$(echo "$S" | tps); PPS=$(echo "$S" | pps); TT=$(echo "$S" | ttft)
  EVAL=$(echo "$S" | jq -r .eval_count); EDUR=$(echo "$S" | jq -r '.eval_duration/1e9')
  TPWH=$(python3 -c "print(round($EVAL / ($W * $EDUR / 3600), 0)) if '$W' != 'n/a' else print('n/a')")
  VRAM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
  # long context
  L=$(gen "$M" "$LONG_PROMPT" 32); LPPS=$(echo "$L" | pps); LTT=$(echo "$L" | ttft)
  echo "| $M | $LOAD | $PPS | $TPS | $TT | $LPPS | $LTT | $VRAM | $W | $TPWH |" >> "$OUT"
done

# ---- concurrency (needs OLLAMA_NUM_PARALLEL>=4 in the ollama service, otherwise requests queue) ---
M=${MODELS[0]}
{
echo
echo "## Concurrency ($M, 4 parallel requests, 128 tokens each)"
echo
echo "OLLAMA_NUM_PARALLEL in service: $(systemctl show ollama -p Environment 2>/dev/null | grep -o 'OLLAMA_NUM_PARALLEL=[0-9]*' || echo 'not set (=1, requests are queued)')"
} >> "$OUT"
T0=$(date +%s.%N)
for i in 1 2 3 4; do gen "$M" "Write a limerick about GPU number $i." 128 > /tmp/par.$i.$$ & done; wait
T1=$(date +%s.%N)
TOT=$(cat /tmp/par.*.$$ | jq -s 'map(.eval_count)|add'); rm -f /tmp/par.*.$$
python3 -c "print(f'- Aggregate: {$TOT} tokens in {($T1-$T0):.1f} s = {$TOT/($T1-$T0):.1f} tok/s')" >> "$OUT"

# ---- raw GPU compute (PyTorch, optional) -------------------------------------
{
echo
echo "## Raw compute (PyTorch bf16 matmul 8192², best of 5)"
echo
python3 - << 'PY' 2>/dev/null || echo "- torch not available, skipped"
import torch, time
a=torch.randn(8192,8192,device='cuda',dtype=torch.bfloat16); b=torch.randn_like(a)
torch.matmul(a,b); torch.cuda.synchronize()
best=1e9
for _ in range(5):
    t=time.perf_counter(); torch.matmul(a,b); torch.cuda.synchronize(); best=min(best,time.perf_counter()-t)
print(f"- {2*8192**3/best/1e12:.1f} TFLOPS bf16 ({torch.cuda.get_device_name()}, torch {torch.__version__})")
PY
} >> "$OUT"

echo; echo "Results written to $OUT"; echo; cat "$OUT"
