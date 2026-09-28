#!/usr/bin/env bash
# Gemma 4 E2B it QAT q4_0 (3.1 GB) - Google's function-natively-trained MoE.
# 5.1B total / ~2B active per token; fits VRAM on a 4 GB card with q8_0 KV.
# Thinking is on by default (occupies tokens before the tool call).
# Tool calling VERIFIED.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/gemma-4-E2B_q4_0-it.gguf" \
  -ngl 99 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --host 127.0.0.1 \
  --port 8083 \
  --alias gemma-4-e2b