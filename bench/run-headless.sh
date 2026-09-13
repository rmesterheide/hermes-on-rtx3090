#!/usr/bin/env bash
# Headless wrapper for llm-bench.sh on the RTX 3090 box (ubnt2080rm): Ollama runs there as a
# system service (/usr/local/bin/ollama, user "ollama"); Xorg/GDM + Sunshine + gnome-remote-desktop
# hold ~826 MiB of VRAM at idle. For the measurement: unload all models, switch to
# multi-user.target, run, then back to graphical.target (GDM autologin + Sunshine return on their own).
# The 4090 box has its own variant (rtx4090-dl-workstation, scripts-4090/10b-run-llm-bench.sh).
set -uo pipefail
export LC_ALL=C
export PATH="/usr/local/cuda/bin:$HOME/.local/bin:$PATH"
OLLAMA_URL=http://127.0.0.1:11434
restore() { echo "== back to graphical.target"; sudo -n systemctl isolate graphical.target; sleep 8; echo "   seat0: $(loginctl list-sessions --no-legend | awk '$4=="seat0"{print $1}' | head -1), sunshine: $(systemctl --user is-active sunshine.service 2>&1)"; }
trap restore EXIT
echo "== unloading models"; for m in $(curl -s "$OLLAMA_URL/api/ps" | jq -r '.models[].name'); do curl -s "$OLLAMA_URL/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null; echo "   $m"; done; sleep 2
echo "== multi-user.target"; sudo -n systemctl isolate multi-user.target; sleep 6
# ollama.service is wanted by default.target (= graphical.target) and gets stopped by the isolate -> start it explicitly
sudo -n systemctl start ollama
for i in $(seq 1 30); do curl -s "$OLLAMA_URL/api/version" >/dev/null && break; sleep 1; done
echo "   gdm: $(systemctl is-active gdm), ollama: $(systemctl is-active ollama) ($(curl -s "$OLLAMA_URL/api/version" | jq -r .version))"
echo "== VRAM baseline: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
START=$(date +%s); "$HOME/hermes-bench/llm-bench.sh" "$@"; RC=$?
echo "== duration: $(( ($(date +%s)-START)/60 )) min, exit $RC"; exit $RC
