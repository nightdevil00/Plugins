#!/usr/bin/env bash
# Llama-3.2-3B-Instruct Q4_K_M (1.9 GB) - Meta, small & fully in VRAM.
# Native tool calling, fast for light agentic work.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf" \
  -ngl 99 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --host 127.0.0.1 \
  --port 8085 \
  --alias llama3.2-3b