#!/usr/bin/env bash
# MiniCPM5-2B Q8_0 (2.68 GB) - openbmb's on-device LLM.
# Fully resident in VRAM (-ngl 99). Tool calling VERIFIED (curl + opencode run).
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/MiniCPM5-2B-Q8_0.gguf" \
  -ngl 99 \
  -c 32768 \
  -np 1 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --host 127.0.0.1 \
  --port 8097 \
  --alias minicpm5-2b
