# local llama

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/mihai.llama`](https://github.com/nightdevil00/Plugins/mihai.llama/)

A bar widget + panel that boots and stops **local [llama.cpp](https://github.com/ggml-org/llama.cpp) model servers** for [opencode](https://opencode.ai) on demand, and shows on the bar which model is currently resident.

Nothing occupies RAM or VRAM by itself — the widget reports **off** and every model is idle until you click **Load**. Pick a model in the panel, click Load, and once it reports **loaded** you can select it in opencode (`/models`). Unload frees the memory again.

It ships with a three-model preset tuned for a **GTX 1650 Ti (4 GB class)** but the same flow and control script work for any llama.cpp build — edit the launchers in `~/llama-serve` to point at your own GGUFs and ports.

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

CPU-only works too — the models are a bit slower, and the tool-calling tests below were done on the CUDA build. (On Arch Linux, `paru llama.cpp-cuda` installs a packaged build if you prefer.)

### 2. Download the models

Save the GGUFs into `~/models` with the exact filenames the launchers expect:

| Model (GGUF) | File | Size | Port | VRAM |
| --- | --- | --- | --- | --- |
| Qwen3-4B-Instruct-2507 · Q4_K_M | `Qwen3-4B-Instruct-2507-Q4_K_M.gguf` | 2.5 GB | 8080 | fits, `-ngl 99` |
| Qwen3-8B · Q4_K_M | `Qwen3-8B-Q4_K_M.gguf` | 5.0 GB | 8081 | partial, `-ngl 16` |
| Qwen3-Coder-30B-A3B · Q2_K | `qwen3-coder-30b-a3b-Q2_K.gguf` | 11 GB | 8082 | low, `-ngl 8` |

From Hugging Face (rename to the filenames above if the repo names differ):

```sh
mkdir -p ~/models
cd ~/models
wget -O Qwen3-4B-Instruct-2507-Q4_K_M.gguf \
  https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf
wget -O Qwen3-8B-Q4_K_M.gguf \
  https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/main/Qwen3-8B-Q4_K_M.gguf
wget -O qwen3-coder-30b-a3b-Q2_K.gguf \
  https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-GGUF/resolve/main/Qwen3-Coder-30B-A3B-Q2_K.gguf
```

The 4B GGUF needs nothing extra. The 8B ships without a chat template, so its launcher points at `~/models/qwen3-tool.jinja` (a copy is included in this plugin folder) and turns off thinking mode — without both, 8B rams its whole token budget into `thinking` instead of calling tools. Tool calling is **verified** on all three presets (~1.9s / ~4.9s / ~7.1s round trips on the 1650 Ti).

### 3. Runtime directory (`~/llama-serve`)

The control script (`llama_ctl.py`) lives inside the plugin folder — but its *runtime* files live outside it, in `~/llama-serve`:

```
~/llama-serve/
  qwen3-4b.sh              launchers: copy the matching .sh from this plugin folder
  qwen3-8b.sh
  qwen3-coder-30b.sh
  stop.sh                  stop every llama-server
  logs/<model-id>.log      server stdout/stderr
  load.<model-id>.mark     "starting" marker, written on load, removed on unload
```

`install.sh` copies the launchers into `~/.config/omarchy/plugins/mihai.llama/`; copy them to `~/llama-serve` once:

```sh
mkdir -p ~/llama-serve
cp ~/.config/omarchy/plugins/mihai.llama/{qwen3-4b.sh,qwen3-8b.sh,qwen3-coder-30b.sh,stop.sh} ~/llama-serve
```

This separation is deliberate: the control script and its files must **never** be written by the plugin's own folder, because the shell's plugin file-watcher hot-reloads the whole plugin on any change there and each reload leaks a stale duplicate widget.

## Wiring opencode

The servers expose standard llama.cpp OpenAI-compatible endpoints (`http://127.0.0.1:8080` etc.). Add one provider per model in `~/.config/opencode/opencode.json`:

```jsonc
{
  "provider": {
    "local-4b": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local llama 4B (8080)",
      "options": { "baseURL": "http://127.0.0.1:8080/v1" },
      "models": { "qwen3-4b": { "name": "Qwen3-4B-Instruct-2507" } }
    }
    // local-8b → 127.0.0.1:8081/v1, local-coder → 127.0.0.1:8082/v1
  }
}
```

Models stay unloaded by default — opencode will show a connection error until you Load one in the panel. That is the point: nothing runs until you ask for it.

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

Model ids: `qwen3-4b`, `qwen3-8b`, `qwen3-coder-30b`.

## Editing for your own hardware

Everything model-specific lives in the launcher scripts under `~/llama-serve`: `-m` model path, `-ngl` VRAM layers, `-c` / KV quantization, and `--port`. Useful llama.cpp knobs used here: `--jinja` (Jinja templating), `--chat-template-file` (models that ship without a template), `--chat-template-kwargs '{"enable_thinking": false}'` (Qwen3 thinking off for fast tool calls), `-ctk q8_0 -ctv q4_0` (quantized KV cache so a long context fits in small VRAM). The control script reads the launch scripts + ports per model id — keep the ids and ports in sync with `llama_ctl.py` if you add models.