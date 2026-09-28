#!/usr/bin/env bash
# Qwen3-Coder-30B-A3B Q2_K (11.26 GB) — the strongest tool caller of the set.
#
# MoE: 30B total but only 3.3B active per token, so it stays responsive on CPU.
# -ngl must stay low (8). At -ngl 20 llama.cpp tries to place a single 4.3 GB
# MoE expert tensor on the GPU and OOMs your 3.7 GB of VRAM.
# Also leaves ~7.5 GB resident in RAM, so close memory-heavy apps first.
# Tool calling VERIFIED. ~7.1s round trip.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/qwen3-coder-30b-a3b-Q2_K.gguf" \
  -ngl 8 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --host 127.0.0.1 \
  --port 8082 \
  --alias qwen3-coder-30b
