#!/usr/bin/env bash
# Stop any running local llama-server and free its RAM/VRAM.
set -u

PIDS=$(pgrep -f 'llama.cpp/build/bin/llama-server')
if [ -z "$PIDS" ]; then
  echo "no llama-server running — nothing to free"
  exit 0
fi

echo "stopping llama-server: $PIDS"
kill $PIDS
sleep 3
if grep -q . <(pgrep -f 'llama.cpp/build/bin/llama-server'); then
  kill -9 $(pgrep -f 'llama.cpp/build/bin/llama-server')
fi
echo "done — memory freed"