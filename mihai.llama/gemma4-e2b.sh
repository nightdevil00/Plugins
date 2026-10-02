#!/usr/bin/env bash
# Gemma 4 E2B it QAT q4_0 (3.1 GB) - Google's function-natively-trained MoE.
# 5.1B total / ~2B active per token; fits VRAM on a 4 GB card with q8_0 KV.
# Thinking is on by default. LOCAL FIX: on llama.cpp b11344 this is not merely
# "occupies tokens" - with a tools block present the model spent its entire
# max_tokens budget on reasoning_content and returned an empty content with no
# tool call at all, which opencode surfaces as "Unexpected server error".
# enable_thinking:false is what makes it emit a real tool call.
# Tool calling VERIFIED (with thinking off).
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/gemma-4-E2B_q4_0-it.gguf" \
  -ngl 99 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --host 127.0.0.1 \
  --port 8083 \
  --alias gemma-4-e2b