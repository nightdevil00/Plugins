#!/usr/bin/env bash
# Qwen3-8B Q4_K_M (5.03 GB) — middle tier.
#
# TWO flags are load-bearing, both found by testing rather than guessing:
#   --chat-template-file  the GGUF ships no template, so llama.cpp guessed wrong
#                         and the model rambled instead of calling tools
#   --chat-template-kwargs  Qwen3-8B defaults to thinking mode, which burned the
#                         whole token budget on <think> before any tool call
# Model is 5.03 GB vs 3.7 GB usable VRAM, so -ngl 16 and the rest lands in RAM.
# Tool calling VERIFIED. ~4.9s round trip.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Qwen3-8B-Q4_K_M.gguf" \
  -ngl 16 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --chat-template-file "$HOME/models/qwen3-tool.jinja" \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --host 127.0.0.1 \
  --port 8081 \
  --alias qwen3-8b
