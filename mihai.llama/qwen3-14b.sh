#!/usr/bin/env bash
# Qwen3-14B Q4_K_M (9.0 GB) - the quality step above the 8B.
# Dense 14B, ~3x the 8B's compute per token and 9 GB over 3.7 GB of usable
# VRAM, so -ngl 10 and the remainder runs in system RAM. Expect single-digit
# tok/s: this is the "think harder" tier, not the interactive one.
# Same Qwen3 family as the verified 4B/8B presets, so tool calling follows.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Qwen3-14B-Q4_K_M.gguf" \
  -ngl 10 \
  -c 8192 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --host 127.0.0.1 \
  --port 8086 \
  --alias qwen3-14b
