#!/usr/bin/env bash
# Gemma 3 12B it Q4_K_M (7.3 GB) - Google's dense 12B.
# 7.3 GB over 3.7 GB of usable VRAM, so -ngl 16 with the rest in RAM.
# Broad general-purpose quality; strong at grounded, long-form answers.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/gemma-3-12b-it-Q4_K_M.gguf" \
  -ngl 16 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --reasoning-budget 0 \
  --host 127.0.0.1 \
  --port 8089 \
  --alias gemma3-12b
