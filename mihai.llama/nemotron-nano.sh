#!/usr/bin/env bash
# NVIDIA Nemotron-Nano-9B-v2 Q4_K_M (5.5 GB) - strong reasoning at 9B,
# tools work. 5.5 GB over 3.7 GB usable VRAM, so -ngl 16 and the rest
# lands in RAM. Tool calling VERIFIED.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/nvidia_NVIDIA-Nemotron-Nano-9B-v2-Q4_K_M.gguf" \
  -ngl 16 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --host 127.0.0.1 \
  --port 8087 \
  --alias nemotron-nano