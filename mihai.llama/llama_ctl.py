#!/usr/bin/env python3
"""Status and control for the local llama.cpp servers used by opencode.

Commands:
  status                 JSON snapshot: per-model state + GPU memory
  load <model-id>        boot the model's llama-server in the background (no wait)
  unload <model-id>      kill that model's llama-server, freeing RAM/VRAM
  stop                   stop every llama-server
"""
import json
import os
import signal
import subprocess
import sys
import time
import urllib.request

HOME = os.path.expanduser("~")
SERVE_DIR = os.path.join(HOME, "llama-serve")
LOGS_DIR = os.path.join(SERVE_DIR, "logs")

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
    {"id": "spark-2.5-1.7b", "name": "Spark-X2.5-1.7B", "tag": "Spark1.7",
     "size": "1.0 GB", "port": 8092, "script": "spark-x2.5-1.7b.sh",
     "opencode": "local-spark17b/spark-x2.5-1.7b"},
    {"id": "gemma4-e2b", "name": "Gemma 4 E2B it", "tag": "Gemma",
     "size": "3.1 GB", "port": 8083, "script": "gemma4-e2b.sh",
     "opencode": "local-gemma4/gemma-4-e2b"},
]


def find_model(mid):
    for m in MODELS:
        if m["id"] == mid:
            return m
    raise SystemExit(f"unknown model: {mid}")


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


def cmd_status():
    models = []
    for m in MODELS:
        pid = model_pid(m)
        models.append({
            "id": m["id"], "name": m["name"], "tag": m["tag"],
            "size": m["size"], "port": m["port"],
            "opencode": m["opencode"], "state": model_state(m), "pid": pid,
        })
    print(json.dumps({"models": models, "gpu": gpu_info(), "ready": True}))


def cmd_load(mid):
    m = find_model(mid)
    if model_pid(m) is not None:
        print(json.dumps({"ok": False, "error": "already running"}))
        return
    age = marker_age(m)
    if age is not None and age < 120:
        print(json.dumps({"ok": False, "error": "already starting"}))
        return
    os.makedirs(LOGS_DIR, exist_ok=True)
    os.makedirs(SERVE_DIR, exist_ok=True)
    with open(marker(m), "w") as f:
        f.write(str(int(time.time())))
    log = open(os.path.join(LOGS_DIR, m["id"] + ".log"), "ab")
    subprocess.Popen(
        ["bash", os.path.join(SERVE_DIR, m["script"])],
        start_new_session=True, stdout=log, stderr=log)
    print(json.dumps({"ok": True, "model": m["id"],
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


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        cmd_status()
    elif cmd == "load":
        cmd_load(sys.argv[2])
    elif cmd == "unload":
        cmd_unload(sys.argv[2])
    elif cmd == "stop":
        cmd_stop()
    else:
        raise SystemExit(f"unknown command: {cmd}")


if __name__ == "__main__":
    main()