#!/usr/bin/env bash
# OxCoder-9B Q4_K_M (5.63 GB) - OrionLLM's agentic coding model, distilled from
# Claude Code / OpenCode / Codex traces. Qwen3.5-9B derivative: hybrid attention
# (3 Gated DeltaNet + 1 full-attention layer, full_attention_interval=4), 262k
# native context.
#
# Unusually, NO template flag is needed here. The GGUF embeds its own
# tokenizer.chat_template and llama.cpp's autoparser reads the tool format
# straight out of it, so --chat-template-file would be wrong, not helpful.
# That template obfuscates its tags with a zero-width space
# ("<\u200btool_call>") to defeat prompt scrapers; the autoparser handles it.
# opencode never passes images, so the separate 0.62 GB mmproj is not loaded.
#
# -ngl 18 is the ceiling on a 3.7 GB card: it puts ~3.5 GB of the 5.63 GB in
# VRAM and measures ~22% faster generation than -ngl 16 at a 12k context
# (4.4 vs 3.6 tok/s), which is where an agentic loop actually lives. -ngl 20
# dies at load with cudaMalloc OOM, so do not raise it.
#
# -ctv q8_0 rather than the q4_0 the other presets use: this build only ships
# FlashAttention kernels for q4_0-q4_0, q8_0-q8_0, f16-f16 and bf16-bf16, so
# -ctk q8_0 -ctv q4_0 silently falls back to converting K and V to f16 anyway.
# q8_0/q8_0 hits a real kernel instead of warning about a missing one.
#
# --reasoning off (not the deprecated --chat-template-kwargs) because in an
# agentic loop every tool call would otherwise spend reasoning tokens first.
# Thinking genuinely works here - flip to "--reasoning on" and opencode shows
# reasoning_content, and the model is benchmarked in thinking mode.
# Tool calling VERIFIED (llama.cpp b11344): single calls, parallel calls, and
# the assistant-tool_calls/tool-result round trip all return clean JSON.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/OxCoder-9B-Q4_K_M.gguf" \
  -ngl 18 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q8_0 \
  --jinja \
  --reasoning off \
  --host 127.0.0.1 \
  --port 8093 \
  --alias oxcoder-9b