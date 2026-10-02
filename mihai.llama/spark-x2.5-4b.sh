#!/usr/bin/env bash
# Spark-X2.5-4B Q4_K_M (2.42 GB) - SparkLLM, purpose-built for agentic use.
# Hybrid attention (1 full-attention + 3 sliding-window layers) and a native
# 1M-token context, but it ships its own chat template so there's no
# --chat-template-file needed. Fully resident in VRAM alongside a 16k context.
#
# Unusually for a new architecture, llama.cpp routes the OpenAI tools block to
# it correctly out of the box - no per-model coaxing required. Thinking is on by
# default and works, but enable_thinking:false is the default here for the same
# reason as every other preset: in an agentic loop each tool call would
# otherwise spend reasoning tokens first. Flip it if you want thinking for
# hard reasoning; the model is benchmarked in thinking mode and stays capable.
# Tool calling VERIFIED (llama.cpp b11344, ~38 tok/s).
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Spark-X2.5-4B-Q4_K_M.gguf" \
  -ngl 99 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --chat-template-kwargs '{"enable_thinking": false}' \
  --host 127.0.0.1 \
  --port 8091 \
  --alias spark-x2.5-4b
