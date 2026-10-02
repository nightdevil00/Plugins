#!/usr/bin/env bash
# NVIDIA Nemotron-Nano-9B-v2 Q4_K_M (5.5 GB) - strong reasoning at 9B,
# tools work. 5.5 GB over 3.7 GB usable VRAM, so -ngl 16 and the rest
# lands in RAM.
# LOCAL FIX: enable_thinking:false is required on llama.cpp b11344. With
# thinking on, a tools-bearing request spends the whole max_tokens budget on
# reasoning_content and returns no tool call.
# Tool calling VERIFIED (with thinking off).
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/nvidia_NVIDIA-Nemotron-Nano-9B-v2-Q4_K_M.gguf" \
  -ngl 16 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --host 127.0.0.1 \
  --port 8087 \
  --alias nemotron-nano