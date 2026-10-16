#!/usr/bin/env python3
"""Status, control and downloads for the local llama.cpp servers used by opencode.

Commands:
  status                    JSON snapshot: per-model state, disk presence, fit + GPU/RAM
  load <model-id> [secs]    boot the model's llama-server in the background (no wait);
                            `secs` (optional) asks llama-server to sleep after that
                            many idle seconds, freeing VRAM until the next request
  unload <model-id>         kill that model's llama-server, freeing RAM/VRAM
  stop                      stop every llama-server
  download <model-id>       fetch the model's GGUF into ~/models (resumable, background)
  cancel <model-id>         stop an in-flight download and drop its partial file
"""
import json
import os
import re
import signal
import subprocess
import sys
import time
import urllib.request

HOME = os.path.expanduser("~")
SERVE_DIR = os.path.join(HOME, "llama-serve")
LOGS_DIR = os.path.join(SERVE_DIR, "logs")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Only models verified to emit real OpenAI tool calls are listed here. opencode
# is an agent, so a model that cannot call tools is not usable as a provider -
# keeping one in this list would only produce a confusing failure after a load.
# Three presets that shipped with this plugin were removed for that reason, and
# Llama-3.2-3B was removed because it issues destructive writes when asked only
# to read. Their launchers still ship for plain `llama-cli` chat; see the
# "No tool calling" table in README.md for the per-model symptoms.
MODELS = [
    {"id": "qwen3-1.7b", "name": "Qwen3-1.7B", "tag": "1.7B",
     "size": "1.0 GB", "port": 8084, "script": "qwen3-1.7b.sh",
     "opencode": "local-17b/qwen3-1.7b"},
    {"id": "qwen3-4b", "name": "Qwen3-4B-Instruct-2507", "tag": "4B",
     "size": "2.3 GB", "port": 8080, "script": "qwen3-4b.sh",
     "opencode": "local-4b/qwen3-4b"},
    {"id": "qwen3-8b", "name": "Qwen3-8B", "tag": "8B",
     "size": "4.7 GB", "port": 8081, "script": "qwen3-8b.sh",
     "opencode": "local-8b/qwen3-8b"},
    {"id": "oxcoder-9b", "name": "OxCoder-9B", "tag": "Oxc9B",
     "size": "5.3 GB", "port": 8093, "script": "oxcoder-9b.sh",
     "opencode": "local-oxcoder/oxcoder-9b"},
    {"id": "qwen3-14b", "name": "Qwen3-14B", "tag": "14B",
     "size": "8.4 GB", "port": 8086, "script": "qwen3-14b.sh",
     "opencode": "local-14b/qwen3-14b"},
    {"id": "gpt-oss-20b", "name": "gpt-oss-20b", "tag": "OSS20",
     "size": "11.3 GB", "port": 8090, "script": "gpt-oss-20b.sh",
     "opencode": "local-oss/gpt-oss-20b"},
    {"id": "qwen3-coder-30b", "name": "Qwen3-Coder-30B-A3B", "tag": "30B",
     "size": "10.5 GB", "port": 8082, "script": "qwen3-coder-30b.sh",
     "opencode": "local-coder/qwen3-coder-30b"},
    {"id": "spark-2.5-4b", "name": "Spark-X2.5-4B", "tag": "Spark4B",
     "size": "2.4 GB", "port": 8091, "script": "spark-x2.5-4b.sh",
     "opencode": "local-spark4b/spark-x2.5-4b"},
    # Qwen3.5-9B distilled from Kimi K3 coding traces. Needs no template coaxing
    # at all - the GGUF embeds one that the autoparser reads the tool format out
    # of - but --reasoning off, or it burns max_tokens on thinking before the
    # first tool call. Port 8094, one past the highest existing preset.
    {"id": "qwen3.5-9b-kimi-k3", "name": "Qwen3.5-9B Kimi-k3 Distilled",
     "tag": "9B",
     "size": "5.8 GB", "port": 8094, "script": "qwen3.5-9b-kimi-k3.sh",
     "opencode": "local-kimi/qwen3.5-9b-kimi-k3"},
    # Underdog Saluki 27B, a Qwen3.8-27B quantised to IQ2-mix. Tool calling is
    # real (verified by curl AND by a real opencode run), but it is a 27B with
    # 44 of 64 layers on CPU: 1.29 tok/s generation and 4m23s of wall clock to
    # answer opencode's 5,632-token system prompt. Listed because it does emit
    # correct tool calls; read the launcher before driving it.
    {"id": "saluki-27b", "name": "Underdog Saluki 27B 1.0", "tag": "S27B",
     "size": "7.9 GB", "port": 8095, "script": "saluki-27b.sh",
     "opencode": "local-saluki/saluki-27b"},
    {"id": "spark-2.5-1.7b", "name": "Spark-X2.5-1.7B", "tag": "Spark1.7",
     "size": "1.0 GB", "port": 8092, "script": "spark-x2.5-1.7b.sh",
     "opencode": "local-spark17b/spark-x2.5-1.7b"},
    {"id": "gemma4-e2b", "name": "Gemma 4 E2B it", "tag": "Gemma",
     "size": "3.1 GB", "port": 8083, "script": "gemma4-e2b.sh",
     "opencode": "local-gemma4/gemma-4-e2b"},
    {"id": "lfm2.5-2.6b", "name": "LFM2.5-2.6B", "tag": "2.6B",
     "size": "1.6 GB", "port": 8096, "script": "lfm2.5-2.6b.sh",
     "opencode": "local-lfm/lfm2.5-2.6b"},
    {"id": "minicpm5-2b", "name": "MiniCPM5-2B", "tag": "MC5",
     "size": "2.7 GB", "port": 8097, "script": "minicpm5-2b.sh",
     "opencode": "local-minicpm/minicpm5-2b"},
]


def load_sources():
    """id -> Hugging Face URL for the model's GGUF. Ships as sources.json next
    to this script; keep it out of llama_ctl.py so a wrong URL is a one-line
    fix rather than a code edit. Missing file simply means no Download button."""
    try:
        with open(os.path.join(SCRIPT_DIR, "sources.json")) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


SOURCES = load_sources()


def find_model(mid):
    for m in MODELS:
        if m["id"] == mid:
            return m
    raise SystemExit(f"unknown model: {mid}")


# --------------------------------------------------------------------------- #
# llama-server process / health probes
# --------------------------------------------------------------------------- #

def llama_pids():
    """All running llama-server processes, matched by name (not -f, so a
    pgrep process can never match itself or a sibling poller)."""
    try:
        out = subprocess.run(
            ["pgrep", "-x", "llama-server"],
            capture_output=True, text=True).stdout.strip()
        return [int(x) for x in out.split() if x.isdigit()]
    except Exception:
        return []


def pid_has_port(pid, port):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            args = f.read().split(b"\0")
        return b"--port" in args and str(port).encode() in args
    except OSError:
        return False


def model_pid(m):
    for pid in llama_pids():
        if pid_has_port(pid, m["port"]):
            return pid
    return None


def marker(m):
    return os.path.join(SERVE_DIR, "load." + m["id"] + ".mark")


def marker_age(m):
    try:
        return time.time() - os.path.getmtime(marker(m))
    except OSError:
        return None


def healthy(m):
    try:
        with urllib.request.urlopen(
                f"http://127.0.0.1:{m['port']}/health", timeout=1.0) as r:
            return r.status == 200
    except Exception:
        return False


def model_state(m):
    if healthy(m):
        return "loaded"
    if model_pid(m) is not None:
        return "starting"
    age = marker_age(m)
    if age is not None and age < 120:
        return "starting"
    return "idle"


# --------------------------------------------------------------------------- #
# Launcher introspection: where the GGUF lives, and how much goes on the GPU
# --------------------------------------------------------------------------- #

def launcher_path(m):
    return os.path.join(SERVE_DIR, m["script"])


def parse_launcher(m):
    """Read the launcher on disk for its `-m` model path, its `-ngl` layer count
    and whether it forwards extra args ("$@"). Deriving these from the script
    the server actually runs keeps the panel honest when you retune a preset."""
    info = {"model": None, "ngl": None, "forwardsArgs": False}
    try:
        with open(launcher_path(m)) as f:
            text = f.read()
    except OSError:
        return info

    mm = re.search(r'(?:^|\s)-m\s+"?([^"\s]+\.gguf)"?', text)
    if mm:
        p = mm.group(1).replace("$HOME", HOME)
        if p.startswith("~"):
            p = os.path.join(HOME, p[2:])
        info["model"] = p

    ng = re.search(r'(?:^|\s)(?:-ngl|--n-gpu-layers)\s+(-?\d+)', text)
    if ng:
        info["ngl"] = int(ng.group(1))

    info["forwardsArgs"] = '"$@"' in text
    return info


def gpu_class(ngl):
    """How the preset places the model: fully in VRAM, split onto the CPU, or
    entirely on the CPU. Read off -ngl, so it matches the README's own wording."""
    if ngl is None:
        return "unknown"
    if ngl <= 0:
        return "cpu"
    if ngl >= 99:
        return "vram"
    return "partial"


# --------------------------------------------------------------------------- #
# Disk presence + download bookkeeping
# --------------------------------------------------------------------------- #

def dl_marker(m):
    return os.path.join(SERVE_DIR, "download." + m["id"] + ".mark")


def part_path(target):
    return target + ".part" if target else None


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def remote_size(url):
    """Content-Length of the resolved download, or None if the HEAD fails."""
    try:
        req = urllib.request.Request(url, method="HEAD",
                                     headers={"User-Agent": "mihai.llama"})
        with urllib.request.urlopen(req, timeout=8) as r:
            cl = r.headers.get("Content-Length")
            return int(cl) if cl and cl.isdigit() else None
    except Exception:
        return None


def disk_info(m):
    """Presence, on-disk bytes and download progress for one model."""
    target = parse_launcher(m)["model"]
    part = part_path(target)
    present = bool(target) and os.path.isfile(target) and os.path.getsize(target) > 0
    downloading = os.path.exists(dl_marker(m))
    out = {
        "present": present, "path": target, "bytes": None,
        "downloading": downloading, "downloadedBytes": None, "totalBytes": None,
        "hasSource": m["id"] in SOURCES,
    }
    if present:
        out["bytes"] = os.path.getsize(target)
    elif downloading:
        dlm = read_json(dl_marker(m)) or {}
        out["totalBytes"] = dlm.get("total")
        if part and os.path.exists(part):
            out["downloadedBytes"] = os.path.getsize(part)
    return out


# --------------------------------------------------------------------------- #
# Host memory + GPU
# --------------------------------------------------------------------------- #

def gpu_info():
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.used,memory.total",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True).stdout.strip()
        used, total = out.split(",")
        return {"used_mb": int(used), "total_mb": int(total)}
    except Exception:
        return {"used_mb": 0, "total_mb": 0}


def ram_info():
    try:
        vals = {}
        with open("/proc/meminfo") as f:
            for line in f:
                key, _, rest = line.partition(":")
                vals[key.strip()] = int(rest.split()[0])  # kB
        return {"total_mb": vals.get("MemTotal", 0) // 1024,
                "available_mb": vals.get("MemAvailable", 0) // 1024}
    except Exception:
        return {"total_mb": 0, "available_mb": 0}


# --------------------------------------------------------------------------- #
# Commands
# --------------------------------------------------------------------------- #

def cmd_status():
    models = []
    for m in MODELS:
        pid = model_pid(m)
        entry = {
            "id": m["id"], "name": m["name"], "tag": m["tag"],
            "size": m["size"], "port": m["port"],
            "opencode": m["opencode"], "state": model_state(m), "pid": pid,
        }
        info = parse_launcher(m)
        entry["ngl"] = info["ngl"]
        entry["gpu"] = gpu_class(info["ngl"])
        entry["forwardsArgs"] = info["forwardsArgs"]
        entry.update(disk_info(m))
        models.append(entry)
    print(json.dumps({"models": models, "gpu": gpu_info(),
                      "ram": ram_info(), "ready": True}))


def resolve_idle_seconds(arg):
    """Idle-sleep seconds from the argv value or MIHAI_LLAMA_IDLE_SLEEP. 0 or
    negative disables it; anything unparseable is treated as disabled."""
    for cand in (arg, os.environ.get("MIHAI_LLAMA_IDLE_SLEEP")):
        if cand is None:
            continue
        try:
            v = int(cand)
        except (TypeError, ValueError):
            continue
        if v > 0:
            return v
    return 0


def cmd_load(mid, idle_arg=None):
    m = find_model(mid)
    if model_pid(m) is not None:
        print(json.dumps({"ok": False, "error": "already running"}))
        return
    age = marker_age(m)
    if age is not None and age < 120:
        print(json.dumps({"ok": False, "error": "already starting"}))
        return

    info = parse_launcher(m)
    target = info["model"]
    if target and not os.path.isfile(target):
        print(json.dumps({"ok": False, "error": "model not downloaded",
                          "file": os.path.basename(target)}))
        return

    extra = []
    secs = resolve_idle_seconds(idle_arg)
    if secs > 0:
        # Honoured only if the launcher ends with "$@"; harmless otherwise.
        extra = ["--sleep-idle-seconds", str(secs)]

    os.makedirs(LOGS_DIR, exist_ok=True)
    os.makedirs(SERVE_DIR, exist_ok=True)
    with open(marker(m), "w") as f:
        f.write(str(int(time.time())))
    log = open(os.path.join(LOGS_DIR, m["id"] + ".log"), "ab")
    subprocess.Popen(
        ["bash", launcher_path(m)] + extra,
        start_new_session=True, stdout=log, stderr=log)
    print(json.dumps({"ok": True, "model": m["id"], "idleSleepSec": secs,
                      "log": os.path.join(LOGS_DIR, m["id"] + ".log")}))


def cmd_unload(mid):
    m = find_model(mid)
    pid = model_pid(m)
    if pid is None:
        print(json.dumps({"ok": False, "error": "not running"}))
        return
    os.kill(pid, signal.SIGTERM)
    try:
        os.remove(marker(m))
    except OSError:
        pass
    time.sleep(0.5)
    print(json.dumps({"ok": True, "model": m["id"]}))


def cmd_stop():
    subprocess.run(["bash", os.path.join(SERVE_DIR, "stop.sh")],
                   capture_output=True)
    print(json.dumps({"ok": True}))


def cmd_download(mid):
    m = find_model(mid)
    src = SOURCES.get(mid)
    if not src:
        print(json.dumps({"ok": False, "error": "no download source"}))
        return
    target = parse_launcher(m)["model"]
    if not target:
        print(json.dumps({"ok": False,
                          "error": "launcher has no -m model path"}))
        return
    if os.path.isfile(target) and os.path.getsize(target) > 0:
        print(json.dumps({"ok": False, "error": "already downloaded"}))
        return
    if os.path.exists(dl_marker(m)):
        print(json.dumps({"ok": False, "error": "already downloading"}))
        return

    os.makedirs(os.path.dirname(target), exist_ok=True)
    os.makedirs(LOGS_DIR, exist_ok=True)
    part = part_path(target)
    total = remote_size(src)
    log = os.path.join(LOGS_DIR, m["id"] + ".download.log")

    # Marker first, so a poll during the curl sees the download; the shell
    # removes it when it is done (moved into place or failed).
    with open(dl_marker(m), "w") as f:
        json.dump({"url": src, "file": target, "part": part, "total": total,
                   "started": int(time.time())}, f)

    # curl into a .part file and move it into place only on success, so a
    # half-written GGUF is never mistaken for a downloaded one; -C - resumes.
    shell = (
        'curl -L --fail --retry 3 --retry-delay 2 --connect-timeout 20 -C - '
        '-o "$2" -- "$1" >> "$3" 2>&1 && mv -f -- "$2" "$4"; rm -f -- "$5"'
    )
    subprocess.Popen(
        ["bash", "-c", shell, "dl", src, part, log, target, dl_marker(m)],
        start_new_session=True,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(json.dumps({"ok": True, "model": m["id"], "file": target,
                      "totalBytes": total, "log": log}))


def curl_pids(part):
    """The curl/bash processes downloading into `part`, matched by the unique
    .part path so cancel never has to trust a pid recorded earlier."""
    if not part:
        return []
    try:
        out = subprocess.run(["pgrep", "-f", "--", part],
                             capture_output=True, text=True).stdout
        return [int(x) for x in out.split() if x.isdigit()]
    except Exception:
        return []


def cmd_cancel(mid):
    m = find_model(mid)
    if not os.path.exists(dl_marker(m)):
        print(json.dumps({"ok": False, "error": "not downloading"}))
        return
    target = parse_launcher(m)["model"]
    part = part_path(target)
    for pid in curl_pids(part):
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
    for path in filter(None, [part]):
        try:
            os.remove(path)
        except OSError:
            pass
    try:
        os.remove(dl_marker(m))
    except OSError:
        pass
    print(json.dumps({"ok": True, "model": m["id"]}))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        cmd_status()
    elif cmd == "load":
        cmd_load(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif cmd == "unload":
        cmd_unload(sys.argv[2])
    elif cmd == "stop":
        cmd_stop()
    elif cmd == "download":
        cmd_download(sys.argv[2])
    elif cmd == "cancel":
        cmd_cancel(sys.argv[2])
    else:
        raise SystemExit(f"unknown command: {cmd}")


if __name__ == "__main__":
    main()
