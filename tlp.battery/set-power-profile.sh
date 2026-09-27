#!/bin/bash
# Sets the TLP power profile at runtime (backed by TLP instead of
# power-profiles-daemon, which has no profile interface on this firmware).
# Usage: set-power-profile.sh <performance|balanced|power-saver>
set -euo pipefail

p="${1:-}"
case "$p" in
  performance | balanced | power-saver) ;;
  *) echo "usage: set-power-profile.sh <performance|balanced|power-saver>" >&2; exit 2 ;;
esac

sudo tlp "$p"