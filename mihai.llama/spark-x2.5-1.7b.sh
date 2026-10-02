#!/usr/bin/env bash
# Spark-X2.5-1.7B Q4_K_M (1.03 GB) - the quick tier of the Spark-X2.5 pair.
# Same 1.03 GB footprint as the Qwen3-1.7B preset but better tool calling, so
# prefer this one for narrow agentic jobs. Fully resident in VRAM.
# Tool calling VERIFIED (llama.cpp b11344, ~75 tok/s).
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Spark-X2.5-1.7B-Q4_K_M.gguf" \
  -ngl 99 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --host 127.0.0.1 \
  --port 8092 \
  --alias spark-x2.5-1.7b
