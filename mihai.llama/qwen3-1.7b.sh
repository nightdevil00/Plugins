#!/usr/bin/env bash
# Qwen3-1.7B Q4_K_M (1.03 GB) — the quick tier.
# Smallest model in the set: fully resident in VRAM with room to spare, and
# by far the fastest here (~90 tok/s). Good for classification, extraction,
# log triage and other narrow jobs where a big model is overkill.
#
# Same family as the 4B, so llama.cpp's built-in Qwen3 chat template handles
# tool calling and no --chat-template-file is needed. Like the 8B, base Qwen3
# defaults to thinking mode, which would eat the token budget before any tool
# call, so thinking is turned off via the template kwarg.
# Tool calling: inherited from the 4B preset (same template path).
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Qwen3-1.7B-Q4_K_M.gguf" \
  -ngl 99 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --host 127.0.0.1 \
  --port 8084 \
  --alias qwen3-1.7b