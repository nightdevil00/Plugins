#!/usr/bin/env bash
# gpt-oss-20b MXFP4 (12.1 GB) - OpenAI's MoE: 20B total, ~3.6B active/token.
# The active-parameter count is what makes it viable here - prompt processing
# and generation stay CPU-bound on a small fraction of the weights, so it
# responds far quicker than its size suggests.
# At -ngl 0 the full 12.1 GB sits in RAM and this box has ~10 GB free,
# so it WILL spill into swap. Close memory-heavy apps first.
# -ngl must stay 0: gpt-oss packs each MoE expert into a single ~8.8 GB
# tensor, so ANY offload attempts a cudaMalloc larger than the whole 3.7 GB
# card and dies at load. This one is CPU/RAM-only by construction.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/gpt-oss-20b-MXFP4.gguf" \
  -ngl 0 \
  -c 8192 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --host 127.0.0.1 \
  --port 8090 \
  --alias gpt-oss-20b
