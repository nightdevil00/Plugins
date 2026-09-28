#!/usr/bin/env bash
# Liquid LFM2.5-8B-A1B Q4_K_M (5.2 GB) - 8B, 1.5B active MoE; key-value
# heads + QK at higher precision, aims for strong instruction following.
# 5.2 GB over 3.7 GB usable VRAM, so -ngl 16 and the rest lands in RAM.
# Tool calling VERIFIED.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/LFM2.5-8B-A1B-Q4_K_M.gguf" \
  -ngl 16 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --host 127.0.0.1 \
  --port 8088 \
  --alias lfm2.5-8b