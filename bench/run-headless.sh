#!/usr/bin/env bash
# 3090-Variante (ubnt2080rm) des headless-Wrappers: Ollama ist hier ein System-Service
# (/usr/local/bin/ollama, User "ollama"), Xorg/GDM + Sunshine + gnome-remote-desktop belegen
# im Leerlauf ~826 MiB VRAM. Fuer die Messung: Modelle entladen, multi-user.target,
# danach graphical.target (GDM-Autologin + Sunshine kommen von selbst zurueck).
set -uo pipefail
export LC_ALL=C
export PATH="/usr/local/cuda/bin:$HOME/.local/bin:$PATH"
OLLAMA_URL=http://127.0.0.1:11434
restore() { echo "== graphical.target zurueck"; sudo -n systemctl isolate graphical.target; sleep 8; echo "   seat0: $(loginctl list-sessions --no-legend | awk '$4=="seat0"{print $1}' | head -1), sunshine: $(systemctl --user is-active sunshine.service 2>&1)"; }
trap restore EXIT
echo "== Modelle entladen"; for m in $(curl -s "$OLLAMA_URL/api/ps" | jq -r '.models[].name'); do curl -s "$OLLAMA_URL/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null; echo "   $m"; done; sleep 2
echo "== multi-user.target"; sudo -n systemctl isolate multi-user.target; sleep 6
# ollama.service haengt an default.target (= graphical.target) und wird vom isolate mit gestoppt -> explizit starten
sudo -n systemctl start ollama
for i in $(seq 1 30); do curl -s "$OLLAMA_URL/api/version" >/dev/null && break; sleep 1; done
echo "   gdm: $(systemctl is-active gdm), ollama: $(systemctl is-active ollama) ($(curl -s "$OLLAMA_URL/api/version" | jq -r .version))"
echo "== VRAM-Basis: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
START=$(date +%s); "$HOME/hermes-bench/llm-bench.sh" "$@"; RC=$?
echo "== Dauer: $(( ($(date +%s)-START)/60 )) min, exit $RC"; exit $RC
