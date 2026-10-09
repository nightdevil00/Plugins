# local llama

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/mihai.llama`](https://github.com/nightdevil00/Plugins/mihai.llama/)

A bar widget + panel that boots and stops **local [llama.cpp](https://github.com/ggml-org/llama.cpp) model servers** for [opencode](https://opencode.ai) on demand, and shows on the bar which model is currently resident.

Nothing occupies RAM or VRAM by itself — the widget reports **off** and every model is idle until you click **Load**. Pick a model in the panel, click Load, and once it reports **loaded** you can select it in opencode (`/models`). Unload frees the memory again.

It ships with **sixteen launchers tuned for a GTX 1650 Ti (4 GB class)** — twelve usable as opencode models, four chat-only because they don't survive tool calling. The same flow and control script work for any llama.cpp build: edit the launchers in `~/llama-serve` to point at your own GGUFs and ports.

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh mihai.llama
```

Or copy it straight from a clone:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/mihai.llama ~/.config/omarchy/plugins/mihai.llama
omarchy-shell shell rescanPlugins
omarchy plugin enable mihai.llama
```

## Requirements

- Omarchy (Quickshell shell), `python3`, `notify-send`
- A build of **[llama.cpp](https://github.com/ggml-org/llama.cpp)** with the `llama-server` executable
- The model GGUFs listed below, sitting in `~/models`
- (optional) `nvidia-smi` for the VRAM-free indicator on the bar

### 1. Build llama.cpp

The launchers call `~/llama.cpp/build/bin/llama-server`. Build with your GPU backend from the llama.cpp directory:

```sh
git clone https://github.com/ggml-org/llama.cpp    # or download a release
cd llama.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON     # NVIDIA CUDA
# -DGGML_VULKAN=ON, -DGGML_HIP=ON (AMD ROCm) or no backend flag for CPU-only
cmake --build build -j --target llama-server
```

CPU-only works too — the models are a bit slower, and the tool-calling tests above were done on the CUDA build. (On Arch Linux, `paru llama.cpp-cuda` installs a packaged build if you prefer.)

You do not have to build anything from source. If a working `llama-server`
already exists elsewhere on the machine, point `~/llama.cpp/build/bin` at it:

```sh
mkdir -p ~/llama.cpp/build/bin
ln -s /path/to/existing/llama-server ~/llama.cpp/build/bin/llama-server
```

`RUNPATH` is `$ORIGIN` in stock builds, so the symlink still finds its sibling
`.so` files — no `LD_LIBRARY_PATH` needed. (This box runs the Vulkan build that
`atomic-agent` installs under `~/.atomic-agent/models/backend`, which is enough
for every preset here; `atomic-agent models start` would fight you for VRAM if
it is holding a model resident, so stop it first with `atomic-agent models stop`.)

### 2. Download the models

Save the GGUFs into `~/models` with the exact filenames the launchers expect:

Split into two groups, because **whether a model can call tools decides whether opencode can use it at all.** Only the first group is wired into the panel; the second is chat-only.

**Tool calling verified — these are the panel presets:**

| Model (GGUF) | File | Size | Port | VRAM | Measured on a 1650 Ti |
| --- | --- | --- | --- | --- | --- |
| Qwen3-1.7B · Q4_K_M | `Qwen3-1.7B-Q4_K_M.gguf` | 1.0 GB | 8084 | fits, `-ngl 99` | ~90 tok/s, fastest |
| Qwen3-4B-Instruct-2507 · Q4_K_M | `Qwen3-4B-Instruct-2507-Q4_K_M.gguf` | 2.3 GB | 8080 | fits, `-ngl 99` | ~43 tok/s, good default |
| Gemma 4 E2B it · q4_0 | `gemma-4-E2B_q4_0-it.gguf` | 3.1 GB | 8083 | fits, `-ngl 99` | ~62 tok/s |
| Qwen3-8B · Q4_K_M | `Qwen3-8B-Q4_K_M.gguf` | 4.7 GB | 8081 | partial, `-ngl 16` | ~6 tok/s |
| OxCoder-9B · Q4_K_M | `OxCoder-9B-Q4_K_M.gguf` | 5.3 GB | 8093 | partial, `-ngl 18`, `-ctv q8_0` | ~4.4 tok/s at 12k ctx, best agentic tool caller |
| Qwen3-14B · Q4_K_M | `Qwen3-14B-Q4_K_M.gguf` | 8.4 GB | 8086 | partial, `-ngl 10`, `-c 8192` | ~2.7 tok/s |
| Spark-X2.5-1.7B · Q4_K_M | `Spark-X2.5-1.7B-Q4_K_M.gguf` | 1.0 GB | 8092 | fits, `-ngl 99` | ~75 tok/s, best tool caller at this size |
| Spark-X2.5-4B · Q4_K_M | `Spark-X2.5-4B-Q4_K_M.gguf` | 2.4 GB | 8091 | fits, `-ngl 99` | ~38 tok/s |
| Qwen3-Coder-30B-A3B · Q2_K | `qwen3-coder-30b-a3b-Q2_K.gguf` | 10.5 GB | 8082 | low, `-ngl 8` | ~11 tok/s, best tool caller |
| gpt-oss-20b · MXFP4 | `gpt-oss-20b-MXFP4.gguf` | 11.3 GB | 8090 | **CPU only**, `-ngl 0`, `-c 8192` | ~4.8 tok/s |
| Qwen3.5-9B Kimi-k3 Distilled · Q4_K_M | `Qwen3.5-9B-Kimi-k3-Distilled-Q4_K_M.gguf` | 5.8 GB | 8094 | partial, `-ngl 18`, `--parallel 1` | ~5.6 tok/s, no template coaxing needed |
| Underdog Saluki 27B 1.0 · IQ2-mix | `Underdog-Saluki-27B-1.0-IQ2-mix.gguf` | 7.9 GB | 8095 | partial, `-ngl 20`, `-fa on`, `--device Vulkan1` | ~1.3 tok/s, 4m23s per opencode request — see the box below |

> **Saluki 27B is wired in and does work, but it is slow enough to change how you use it.** Tool calling is verified twice — a raw curl tool call with clean JSON arguments, and a real `opencode run` that answered correctly. The cost is that it is a 27B with only 20 of 64 layers in VRAM; the other 44 run on CPU. Measured: ~21 tok/s prompt processing and 1.29 tok/s generation, which is **4m23s of wall clock to answer a one-word prompt**, because opencode's system prompt alone is 5,632 tokens. An agent loop with several tool calls is multi-minutes per step. Fine for a long single question through `llama-cli`; not a preset to drive opencode with at speed.
>
> Everything in its launcher that matters is about squeeze: `-fa on` (the model's own quickstart passes it; without it prompt processing was 4.6 tok/s on a small prompt), `--parallel 1` for the usual 4× KV reason, and `-ngl 20` because `-ngl 24` dies allocating the KV cache. `--device Vulkan1` is pinned deliberately: the unused Intel iGPU looks like free compute and is a trap — splitting across both GPUs measured **3× slower** (1.4 tok/s prompt, 0.45 tok/s generation), because every layer boundary pays a cross-device transfer and a UHD iGPU loses to the 12 CPU threads it displaces.

**No tool calling — chat-only, deliberately absent from the panel:**

| Model (GGUF) | File | Size | Port | Symptom |
| --- | --- | --- | --- | --- |
| Llama-3.2-3B-Instruct · Q4_K_M | `Llama-3.2-3B-Instruct-Q4_K_M.gguf` | 1.9 GB | 8085 | **Dangerous.** Calls tools but ignores the request — asked only to *read* a file it issued `edit` (with an empty `oldString`), `grep`, then `write` over it. |
| LFM2.5-8B-A1B · Q4_K_M | `LFM2.5-8B-A1B-Q4_K_M.gguf` | 4.8 GB | 8088 | Never emits a tool call; claims the file "does not exist". Ignores `enable_thinking:false` *and* `--reasoning off`. |
| Nemotron-Nano-9B-v2 · Q4_K_M | `nvidia_NVIDIA-Nemotron-Nano-9B-v2-Q4_K_M.gguf` | 6.1 GB | 8087 | Never emits a tool call; spends the budget on `reasoning_content`. |
| Gemma 3 12B it · Q4_K_M | `gemma-3-12b-it-Q4_K_M.gguf` | 6.8 GB | 8089 | Declines — "I am unable to access files on your local computer". |

Their launchers still ship, so you can run them by hand for a plain OpenAI-compatible endpoint:

```sh
bash ~/llama-serve/llama3.2-3b.sh    # or lfm2.5-8b.sh, nemotron-nano.sh, gemma3-12b.sh
```

From Hugging Face (rename to the filenames above if the repo names differ):

```sh
mkdir -p ~/models
cd ~/models
wget -O Qwen3-1.7B-Q4_K_M.gguf \
  https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf
wget -O Qwen3-4B-Instruct-2507-Q4_K_M.gguf \
  https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf
wget -O Qwen3-8B-Q4_K_M.gguf \
  https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/main/Qwen3-8B-Q4_K_M.gguf
wget -O OxCoder-9B-Q4_K_M.gguf \
  https://huggingface.co/mradermacher/OxCoder-9B-GGUF/resolve/main/OxCoder-9B.Q4_K_M.gguf
wget -O Qwen3-14B-Q4_K_M.gguf \
  https://huggingface.co/unsloth/Qwen3-14B-GGUF/resolve/main/Qwen3-14B-Q4_K_M.gguf
wget -O gemma-4-E2B_q4_0-it.gguf \
  https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/main/gemma-4-E2B_q4_0-it.gguf
wget -O qwen3-coder-30b-a3b-Q2_K.gguf \
  https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/resolve/main/Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf
wget -O gpt-oss-20b-MXFP4.gguf \
  https://huggingface.co/ggml-org/gpt-oss-20b-GGUF/resolve/main/gpt-oss-20b-MXFP4.gguf
wget -O Spark-X2.5-1.7B-Q4_K_M.gguf \
  https://huggingface.co/XHToken/Spark-X2.5-1.7B-GGUF/resolve/main/Spark-X2.5-1.7B-Q4_K_M.gguf
wget -O Spark-X2.5-4B-Q4_K_M.gguf \
  https://huggingface.co/XHToken/Spark-X2.5-4B-GGUF/resolve/main/Spark-X2.5-4B-Q4_K_M.gguf
wget -O Qwen3.5-9B-Kimi-k3-Distilled-Q4_K_M.gguf \
  https://huggingface.co/mradermacher/Qwen3.5-9B-Kimi-k3-Distilled-GGUF/resolve/main/Qwen3.5-9B-Kimi-k3-Distilled.Q4_K_M.gguf
wget -O Underdog-Saluki-27B-1.0-IQ2-mix.gguf \
  https://huggingface.co/ConwayResearch/Underdog-Saluki-27B-1.0/resolve/main/Underdog-Saluki-27B-1.0-IQ2-mix.gguf
# chat-only, optional
wget -O Llama-3.2-3B-Instruct-Q4_K_M.gguf \
  https://huggingface.co/unsloth/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf
wget -O LFM2.5-8B-A1B-Q4_K_M.gguf \
  https://huggingface.co/LiquidAI/LFM2.5-8B-A1B-GGUF/resolve/main/LFM2.5-8B-A1B-Q4_K_M.gguf
wget -O nvidia_NVIDIA-Nemotron-Nano-9B-v2-Q4_K_M.gguf \
  https://huggingface.co/bartowski/nvidia_NVIDIA-Nemotron-Nano-9B-v2-GGUF/resolve/main/nvidia_NVIDIA-Nemotron-Nano-9B-v2-Q4_K_M.gguf
wget -O gemma-3-12b-it-Q4_K_M.gguf \
  https://huggingface.co/ggml-org/gemma-3-12b-it-GGUF/resolve/main/gemma-3-12b-it-Q4_K_M.gguf
```

> The 30B URL is `Qwen3-Coder-30B-A3B-**Instruct**-GGUF`, not `Qwen3-Coder-30B-A3B-GGUF`. The ungated-looking name is a 401.

**Thinking must be off, per model, or tool calling silently fails.** This is the single most common failure and it does not look like a tool-calling failure: with a `tools` block present the model spends its *entire* `max_tokens` budget on `reasoning_content`, returns an empty `content`, and opencode surfaces it as a generic `Unexpected server error`. Four different mechanisms are needed:

- **Qwen3 family** (`qwen3-8b`, `qwen3-14b`, `qwen3-1.7b`): `--chat-template-kwargs '{"enable_thinking": false}'`. The 8B additionally ships *no* chat template at all, so its launcher also points at `~/models/qwen3-tool.jinja` (a copy is in this plugin folder).
- **Gemma** (`gemma4-e2b`): `--chat-template-kwargs '{"enable_thinking": false}'`.
- **OxCoder-9B** (`oxcoder-9b`): this build takes the non-deprecated `--reasoning off` for the same job — `--chat-template-kwargs '{"enable_thinking": false}'` still works but logs a deprecation warning. Unlike the others, its thinking mode is genuinely good (it returns clean `reasoning_content` *and* still calls tools), so `--reasoning on` is a real option if you want the reasoning trace.
- **Qwen3.5-9B Kimi-k3** (`qwen3.5-9b-kimi-k3`): also `--reasoning off`. Its embedded template honours `enable_thinking:false` too, but routing it through `--chat-template-kwargs` logs a deprecation warning on every start, so the modern flag is the better default. Unlike every other preset here this model needs *no* template coaxing at all for tools — the autoparser reads the `<tool_call>` format straight out of the GGUF's own chat template.
- **Spark-X2.5** (`spark-x2.5-4b`, `spark-x2.5-1.7b`): same `enable_thinking:false`. Note this model emits a correct tool call *either way* — thinking-on is not a bug here, it's just slower in a tool loop. Their published agentic numbers are measured in thinking mode, so flip the flag if you want that trade.
- **Anything else**: `--reasoning off` / `--reasoning-budget 0` do *not* reliably work — the template ignores them. Don't assume a model is fixable this way; test it (see below).

> **Which other models did *not* make the list, and why:** `microsoft_Phi-4-mini-instruct-Q4_K_M.gguf`, `Mistral-7B-Instruct-v0.3-Q4_K_M.gguf`, and `Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf` all fit the machine but fail tool calling through `llama-server` (this build silently drops the OpenAI `tools` block for them — prompts come out a few tokens long — and the Coder model answers in an unparseable `<function-call>` dialect). A custom `--chat-template-file` doesn't help: llama.cpp decides tool support per model and won't hand the tools to these templates. They're fine as plain chat models if you want the extra downloads.

> **Tool-calling results are build-specific.** The table above was verified against llama.cpp **b11344**. llama.cpp decides per model whether the OpenAI `tools` block reaches the template, so a different build can flip a model either way. Test any new preset before trusting it — see "Testing tool calling" below.

### 3. Runtime directory (`~/llama-serve`)

The control script (`llama_ctl.py`) lives inside the plugin folder — but its *runtime* files live outside it, in `~/llama-serve`:

```
~/llama-serve/
  qwen3-1.7b.sh             launchers: copy the matching .sh from this plugin folder
  qwen3-4b.sh
  qwen3-8b.sh
  oxcoder-9b.sh
  qwen3-14b.sh
  qwen3-coder-30b.sh
  gemma4-e2b.sh
  gpt-oss-20b.sh
  spark-x2.5-4b.sh
  spark-x2.5-1.7b.sh
  qwen3.5-9b-kimi-k3.sh
  saluki-27b.sh
  llama3.2-3b.sh            chat-only, not in the panel
  lfm2.5-8b.sh              chat-only, not in the panel
  nemotron-nano.sh          chat-only, not in the panel
  gemma3-12b.sh             chat-only, not in the panel
  stop.sh                   stop every llama-server
  logs/<model-id>.log       server stdout/stderr
  load.<model-id>.mark      "starting" marker, written on load, removed on unload
```

`install.sh` copies the launchers into `~/.config/omarchy/plugins/mihai.llama/`; copy them to `~/llama-serve` once:

```sh
mkdir -p ~/llama-serve
cp ~/.config/omarchy/plugins/mihai.llama/*.sh ~/llama-serve
chmod +x ~/llama-serve/*.sh
```

This separation is deliberate: the control script and its files must **never** be written by the plugin's own folder, because the shell's plugin file-watcher hot-reloads the whole plugin on any change there and each reload leaks a stale duplicate widget.

## Wiring opencode

The servers expose standard llama.cpp OpenAI-compatible endpoints (`http://127.0.0.1:8080` etc.). Add one provider per model in `~/.config/opencode/opencode.json`. OpenCode **v2** uses `providers` / `package` / `settings` — the older `provider` / `npm` / `options` spelling is v1 and is ignored:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "providers": {
    "local-4b": {
      "name": "Local llama 4B (8080)",
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": { "baseURL": "http://127.0.0.1:8080/v1" },
      "models": {
        "qwen3-4b": {
          "name": "Qwen3-4B-Instruct-2507",
          "modelID": "qwen3-4b",
          "capabilities": { "tools": true, "input": ["text"], "output": ["text"] },
          "limit": { "context": 16384, "output": 8192 }
        }
      }
    }
    // local-17b → 8084, local-14b → 8086, local-oss → 8090,
    // local-spark4b → 8091, local-spark17b → 8092,
    // local-8b → 8081, local-coder → 8082, local-gemma4 → 8083,
    // local-kimi → 8094, local-saluki → 8095
  }
}
```

`modelID` must match the launcher's `--alias` (that is the name the server answers
to), while the `models` key is what you type in `/models`. Set `capabilities` and
`limit` explicitly: OpenCode cannot probe a custom endpoint and otherwise assumes
a 200,000-token context and 32,000-token output, which quietly overruns every
preset here — `limit.context` is what makes it compact in time. Skip `apiKey`
entirely; llama.cpp servers run without authentication.

Model ids match the panel's `opencode` field, so `llama_ctl.py status` always tells you the exact `provider/model` string to select.

Models stay unloaded by default — opencode will show a connection error until you Load one in the panel. That is the point: nothing runs until you ask for it.

## Testing tool calling

A model that loads, answers `/health`, and chats can still be useless to opencode. Assert the tool call directly — this is much faster than a full `opencode run` and catches the thinking-budget trap:

```sh
python3 ~/.config/omarchy/plugins/mihai.llama/llama_ctl.py load qwen3-4b
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "messages":[{"role":"user","content":"What is in /tmp/x.txt?"}],
  "tools":[{"type":"function","function":{"name":"read","description":"Read a file",
    "parameters":{"type":"object","properties":{"filePath":{"type":"string"}},"required":["filePath"]}}}],
  "max_tokens":200}' | python3 -m json.tool | grep -A5 tool_calls
```

Then confirm end-to-end through opencode itself, which also exercises the real ~7k-token system prompt and every tool schema:

```sh
opencode run -m local-4b/qwen3-4b "Read /tmp/x.txt with the read tool and reply with only its contents."
```

Read the failure modes carefully:

- `content: ""` with a long `reasoning_content` → thinking ate the budget. Fix the launcher's thinking flag.
- A well-formed answer like "the file does not exist" or "I cannot access files" → the model never got the tools at all. Not fixable with template flags; drop it from the panel.
- Tool calls that don't match the request (e.g. `write` when asked to `read`) → treat as dangerous and drop it.

## Usage

- **Left click** the bar button opens the panel; **right click** refreshes status.
- The button reads `off` (nothing resident), a tag like `4B` (loaded), or `4B…` while one is starting.
- In the panel, **Load** starts the server (no waiting; the widget tracks the transition), **Unload** shuts it down and frees RAM/VRAM.
- A desktop notification fires the moment a model flips to **loaded**.
- Status refreshes every `refreshIntervalSec` (default 3, minimum 3) and the panel reflects live states.

States come from `llama_ctl.py status`: `loaded` (HTTP `/health` OK on the model's port), `starting` (a `llama-server` pid owns the port, or the load marker is under 120 s old — covers boot and crash-on-start), or `idle`. Port ownership is checked against `/proc/<pid>/cmdline` by name + exact `--port` argument, never by a fuzzy command-line substring, so a status poller can never mistake itself for a real server.

## CLI control

The control script is yours outside the widget too:

```sh
python3 ~/.config/omarchy/plugins/mihai.llama/llama_ctl.py status   # JSON snapshot
python3 ~/.config/omarchy/plugins/mihai.llama/llama_ctl.py load qwen3-4b
python3 ~/.config/omarchy/plugins/mihai.llama/llama_ctl.py unload qwen3-8b
python3 ~/.config/omarchy/plugins/mihai.llama/llama_ctl.py stop     # all servers
```

Model ids (panel presets only): `qwen3-1.7b`, `qwen3-4b`, `qwen3-8b`, `oxcoder-9b`, `qwen3-14b`, `qwen3-coder-30b`, `gemma4-e2b`, `gpt-oss-20b`, `spark-2.5-4b`, `spark-2.5-1.7b`, `qwen3.5-9b-kimi-k3`, `saluki-27b`. The chat-only models (`llama3.2-3b`, `lfm2.5-8b`, `nemotron-nano`, `gemma3-12b`) are intentionally absent — run their launchers by hand.

## Editing for your own hardware

Everything model-specific lives in the launcher scripts under `~/llama-serve`: `-m` model path, `-ngl` VRAM layers, `-c` / KV quantization, and `--port`. Useful llama.cpp knobs used here: `--jinja` (Jinja templating), `--chat-template-file` (models that ship without a template), `--chat-template-kwargs '{"enable_thinking": false}'` (Qwen3/Gemma thinking off for fast tool calls), `-ctk q8_0 -ctv q4_0` (quantized KV cache so a long context fits in small VRAM). The control script reads the launch scripts + ports per model id — keep the ids and ports in sync with `llama_ctl.py` if you add models.

Two sizing rules that cost time to rediscover on a 4 GB card:

- **Set `-ngl` low enough for the KV cache to fit too, not just the weights.** A model at `-ngl 16` may place weights fine and then die allocating the context (`failed to allocate buffer for kv cache`). If that happens, drop `-ngl` *and* `-c` together.
- **MoE models can be impossible to offload entirely.** gpt-oss packs each expert into one ~8.8 GB tensor, so *any* nonzero `-ngl` requests a `cudaMalloc` larger than the whole card and the server exits at load. It must run `-ngl 0` on a 4 GB card. Qwen3-Coder-30B has the same shape but smaller experts, so `-ngl 8` works.

If you add a model, add it to `MODELS` in `llama_ctl.py` (id, port and script must match the launcher), add a provider in `opencode.json`, and verify tool calling before you trust it.