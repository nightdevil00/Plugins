#!/usr/bin/env bash
# Qwen3-4B-Instruct-2507 Q4_K_M (2.50 GB) — the fast default.
# Fully resident in VRAM (-ngl 99). Tool calling VERIFIED. ~1.9s round trip.
# This GGUF needs no --chat-template-file: llama.cpp's built-in Qwen3 template
# already emits the <tool_call> format correctly.
#
# Context: opencode's system prompt plus every tool schema is ~6-7k tokens, so
# 8192 OOMs on the first real request. 16384 needs the quantized KV cache
# (-ctk q8_0 / -ctv q4_0) to fit alongside 2.5 GB of weights in 3.7 GB of VRAM.
# f16 KV at 16384 does NOT fit here.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Qwen3-4B-Instruct-2507-Q4_K_M.gguf" \
  -ngl 99 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --host 127.0.0.1 \
  --port 8080 \
  --alias qwen3-4b
