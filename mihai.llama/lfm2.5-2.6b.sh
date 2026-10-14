#!/usr/bin/env bash
# LFM2.5-2.6B Q4_K_M (1.6 GB) - Liquid's agentic general-purpose model.
# 2.69B params, 30 layers (22 conv + 8 GQA), 128k native context.
# Tool calling VERIFIED (llama.cpp b11592): emits clean OpenAI tool_calls
# through llama.cpp's autoparser. The model is a pure reasoning model that
# thinks before answering, so thinking is turned off for tool use - with it on
# the budget goes into reasoning_content and tool calls are empty or delayed.
# Fully resident in VRAM on a 4 GB card.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/LFM2.5-2.6B-Q4_K_M.gguf" \
  -ngl 99 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --reasoning off \
  --host 127.0.0.1 \
  --port 8096 \
  --alias lfm2.5-2.6b
