#!/usr/bin/env bash
# Qwen3.5-9B Kimi-k3 Distilled Q4_K_M (5.78 GB) - agentic coding model distilled
# from Kimi K3 coding/debugging traces. Arch "qwen35": hybrid attention (3 Gated
# DeltaNet + 1 full-attention layer per group) plus an MTP head, which is why the
# load log warns about unused blk.32.nextn tensors. 262k native context.
#
# NOTHING here needed coaxing to make tools work. The GGUF embeds its own
# chat_template with the <tool_call> format and llama.cpp's autoparser reads
# the tool format straight out of it - no --chat-template-file, and none of the
# "template ships empty" trap that the Qwen3-8B preset needs a jinja file for.
# Tool calling VERIFIED (llama.cpp turboquant-9ca222f, GTX 1650 Ti): single calls
# return a clean function name + JSON arguments with finish_reason tool_calls.
#
# --reasoning off, NOT --chat-template-kwargs '{"enable_thinking": false}': both
# silence thinking (this template honours enable_thinking), but the kwargs route
# logs "Setting 'enable_thinking' via --chat-template-kwargs is deprecated. Use
# --reasoning on / --reasoning off instead." on every start. With thinking on the
# model spends its whole max_tokens on reasoning_content and returns an empty
# content with no tool call - the same trap as the Qwen3/Gemma presets, quieter
# escape hatch. Flip to "--reasoning on" if you want the trace.
#
# --parallel 1 is load-bearing, not a micro-optimisation. The default is 4 slots,
# which multiplies the KV cache by 4 and pinned VRAM at 3.5 GB with ~200 MiB
# free. opencode is single-request anyway; only the title/summary call overlaps.
#
# -ngl 18 of 32 layers. Measured on this card, in order:
#   -ngl 24, -c 24576  -> dies at load, "failed to allocate buffer for kv cache"
#                        (the README's sizing rule: drop -ngl and -c together)
#   -ngl 20, -c 16384  -> 6.1 tok/s but only 322 MiB VRAM free
#   -ngl 18, -c 16384  -> 5.6 tok/s and 600 MiB free - chosen, a model that dies
#                        mid-agent-loop costs far more than 0.5 tok/s
#   auto (no -ngl)     -> 4.4 tok/s, the build's fitter is too conservative here
# Stress-tested with a 12288-token prompt: 74 tok/s prompt processing, VRAM
# peaked at 3.2 GB, no OOM. Expect ~95 s just to swallow opencode's ~7k system
# prompt before the first token.
#
# No --device flag: the default device auto-pick already lands on the NVIDIA
# card (verified - the Intel iGPU stays untouched), which keeps this launcher
# portable if you swap ~/llama.cpp for a CUDA build.
#
# Two caveats specific to this build, both expected, neither a bug:
#   - "fused Gated Delta Net (chunked) not supported, set to disabled" - there is
#     no Vulkan kernel for it, so DeltaNet attention runs on CPU regardless of
#     -ngl. That is most of why this 9B is not faster than the 8B preset.
#   - the load log's unused-tensor warnings are the MTP head, ignored by design.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Qwen3.5-9B-Kimi-k3-Distilled-Q4_K_M.gguf" \
  -ngl 18 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  --parallel 1 \
  --reasoning off \
  --host 127.0.0.1 \
  --port 8094 \
  --alias qwen3.5-9b-kimi-k3
