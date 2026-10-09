#!/usr/bin/env bash
# Underdog Saluki 27B 1.0 - IQ2-mix (7.89 GB) - ConwayResearch's Qwen3.8-27B
# squeezed under 8 GB with tool calling deliberately kept intact. Arch qwen35,
# 64 layers, hybrid Gated DeltaNet + full attention, 262k native context.
#
# SOLD AS A TOOL CALLER, BUT READ THE PERFORMANCE SECTION BEFORE USE. Tool
# calling is verified twice over: a raw curl tool call, and a real
# `opencode run` that answered correctly. Capability is not the problem -
# speed is. This is a 27B with only 20 of 64 layers in VRAM, so 44 layers run
# on CPU. Measured:
#   raw curl, 282-token prompt      8.5 tok/s prompt,  0.92 tok/s generation
#   real opencode run, 5,632-token    ~21 tok/s prompt, 1.29 tok/s generation,
#   system prompt                    4m23s wall for a one-word reply
# Sustained prompt processing is better than the small curl number suggests -
# that one is dominated by first-request warm-up - but the wall clock is what
# matters: expect ~4-5 minutes per opencode request, and an agent loop with
# several tool calls is a multi-minute-per-step affair. Viable for a long
# single question via llama-cli; not something you drive opencode with at
# speed. Wire it in if you want to try it.
#
# --reasoning off, not --chat-template-kwargs: this model's own docs say
# "thinking off with chat_template_kwargs {enable_thinking: false}, temperature
# 0" for fast direct tool calls. Same trap as every other preset here - with
# thinking on the model spends its whole max_tokens on reasoning_content and
# returns an empty content with no tool call. The build logs the kwargs route as
# deprecated, so --reasoning off is used. NOTE this template is fussier than the
# others: it injects a "reasoning effort: xhigh" system message by default and
# raise_exception()s if there is no user message at all.
#
# -fa on is worth 2x on prompt processing (4.6 -> 8.5 tok/s) and is what the
# model's own quickstart passes. Not optional here.
#
# --device Vulkan1 EXPLICITLY, unlike the other presets. The default device
# auto-pick left the Intel iGPU idle, which sounds like a free win - it is not.
# Tested --device Vulkan0,Vulkan1 -ngl 44 (split across both GPUs): 1.4 tok/s
# prompt and 0.45 tok/s generation, 3x SLOWER than NVIDIA alone, because every
# layer boundary pays a cross-device transfer and a UHD iGPU is slower than the
# 12 CPU threads it displaces. Do not "fix" this preset by adding the iGPU.
#
# -ngl 20 of 64: ~3.2 GB of VRAM, ~460 MiB headroom. The remaining 44 layers
# run on CPU, which is why generation is what it is. -ngl 24 needs ~3.8 GB and
# OOMs the KV cache; -c is already at the floor for opencode (8192 cannot hold
# its system prompt), so there is no VRAM to trade for more layers.
# --parallel 1 for the same reason as every other preset: the default 4 slots
# multiplies the KV cache by 4.
set -euo pipefail

exec "$HOME/llama.cpp/build/bin/llama-server" \
  -m "$HOME/models/Underdog-Saluki-27B-1.0-IQ2-mix.gguf" \
  -ngl 20 \
  -c 16384 \
  -ctk q8_0 \
  -ctv q4_0 \
  --jinja \
  -fa on \
  --parallel 1 \
  --reasoning off \
  --device Vulkan1 \
  --host 127.0.0.1 \
  --port 8095 \
  --alias saluki-27b
