#!/usr/bin/env python3
"""Collect opencode usage into one display-ready JSON record.

The bar widget calls this on a timer; every field the panel draws comes from
the JSON printed here. Nothing is ever written: opencode may be writing right
now, so the sqlite connection is read-only (mode=ro + query_only).

Aggregation happens over the session table, where opencode records per-session
token and cost columns, plus a straight count of today's user messages from
the message table for the prompt figure. Overriding the database location is
possible with a --db argument or the OPENCODE_DB environment variable.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sqlite3
import sys
from pathlib import Path


def default_db_path() -> str:
  base = os.environ.get("OPENCODE_DATA_DIR") or os.path.join(
      os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share"),
      "opencode")
  return os.path.join(base, "opencode.db")


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(description="Collect opencode usage as JSON")
  parser.add_argument("--db", default=os.environ.get("OPENCODE_DB") or default_db_path())
  return parser.parse_args()


def local_day_from_epoch_ms(value: int) -> dt.date:
  try:
    seconds = float(value) / 1000.0
    return dt.datetime.fromtimestamp(seconds).date()
  except Exception:
    return dt.date.today()


def day_string(day: dt.date) -> str:
  return day.strftime("%Y-%m-%d")


def number(value) -> int:
  try:
    return round(float(value or 0))
  except Exception:
    return 0


def parse_model(raw) -> tuple[str, str]:
  try:
    obj = json.loads(raw) if raw else {}
    model = str(obj.get("id") or "unknown")
    provider = str(obj.get("providerID") or "opencode")
    return model, provider
  except Exception:
    return str(raw or "unknown"), "opencode"


def collect(db_path: str) -> dict:
  if not os.path.isfile(db_path):
    return {"ready": False, "error": "opencode database not found"}

  today = dt.date.today()
  recent_dates = [today - dt.timedelta(days=offset) for offset in range(6, -1, -1)]
  today_start_ms = int(dt.datetime.combine(today, dt.time.min).timestamp() * 1000)

  today_input = today_output = today_reasoning = today_cache_read = today_cache_write = 0
  today_tokens = 0
  today_cost = 0.0
  today_by_model: dict[str, int] = {}
  recent_tokens = {day: 0 for day in recent_dates}
  models: dict[tuple[str, str], dict] = {}
  agents: dict[str, dict] = {}
  active_dates: set[str] = set()
  total_prompts = total_sessions = 0
  total_tokens = 0
  total_cost = 0.0

  try:
    conn = sqlite3.connect("file:" + db_path + "?mode=ro", uri=True, timeout=2)
  except sqlite3.Error:
    return {"ready": False, "error": "could not open opencode database"}
  try:
    conn.execute("PRAGMA query_only = ON")
    tables = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
    if "session_v2" in tables:
      session_table, message_table = "session_v2", "session_message"
      user_filter = "type = 'user'"
    else:
      session_table, message_table = "session", "message"
      user_filter = "data LIKE '%\"role\":\"user\"%'"

    for agent, raw_model, in_t, out_t, rea_t, cache_r, cache_w, cost, created in conn.execute(
        "SELECT agent, model, tokens_input, tokens_output, tokens_reasoning,"
        " tokens_cache_read, tokens_cache_write, cost, time_created FROM " + session_table):
      total = number(in_t) + number(out_t) + number(rea_t) + number(cache_r) + number(cache_w)
      if total <= 0:
        continue

      day = local_day_from_epoch_ms(created)
      day_key = day_string(day)
      active_dates.add(day_key)
      recent_tokens[day] = recent_tokens.get(day, 0) + total
      total_tokens += total
      total_sessions += 1
      total_cost += float(cost or 0)

      model, provider = parse_model(raw_model)
      bucket = models.setdefault((model, provider), {
        "name": model, "provider": provider, "input": 0, "output": 0,
        "reasoning": 0, "cacheRead": 0, "cacheWrite": 0, "total": 0, "sessions": 0,
      })
      bucket["input"] += number(in_t)
      bucket["output"] += number(out_t)
      bucket["reasoning"] += number(rea_t)
      bucket["cacheRead"] += number(cache_r)
      bucket["cacheWrite"] += number(cache_w)
      bucket["total"] += total
      bucket["sessions"] += 1

      if day == today:
        today_input += number(in_t)
        today_output += number(out_t)
        today_reasoning += number(rea_t)
        today_cache_read += number(cache_r)
        today_cache_write += number(cache_w)
        today_tokens += total
        today_cost += float(cost or 0)
        today_by_model[model] = today_by_model.get(model, 0) + total

      agent_name = str(agent or "build")
      agent_bucket = agents.setdefault(agent_name, {"name": agent_name, "total": 0, "sessions": 0})
      agent_bucket["total"] += total
      agent_bucket["sessions"] += 1

    # Prompts: one user message, whole database for the total, only since
    # local midnight for today's figure.
    total_prompts = conn.execute(
        f"SELECT COUNT(*) FROM {message_table} WHERE {user_filter}").fetchone()[0]
    today_prompts = conn.execute(
        f"SELECT COUNT(*) FROM {message_table} WHERE time_created >= ?"
        f" AND {user_filter}", (today_start_ms,)).fetchone()[0]
    today_sessions = conn.execute(
        f"SELECT COUNT(DISTINCT session_id) FROM {message_table} WHERE time_created >= ?",
        (today_start_ms,)).fetchone()[0]
  except sqlite3.Error as exc:
    conn.close()
    return {"ready": False, "error": str(exc)}
  finally:
    conn.close()

  model_rows = [models[key] for key in sorted(
      models, key=lambda key: models[key]["total"], reverse=True)]
  agent_rows = [agents[key] for key in sorted(
      agents, key=lambda key: agents[key]["total"], reverse=True)]

  return {
    "ready": True,
    "db": db_path,
    "updatedAt": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
    "today": {
      "prompts": today_prompts,
      "sessions": today_sessions,
      "input": today_input,
      "output": today_output,
      "reasoning": today_reasoning,
      "cacheRead": today_cache_read,
      "cacheWrite": today_cache_write,
      "total": today_tokens,
      "cost": round(today_cost, 4),
      "byModel": today_by_model,
    },
    "days": [
      {"date": day_string(day), "tokens": recent_tokens.get(day, 0)}
      for day in recent_dates
    ],
    "models": model_rows,
    "agents": agent_rows,
    "totals": {
      "prompts": total_prompts,
      "sessions": total_sessions,
      "tokens": total_tokens,
      "cost": round(total_cost, 4),
      "activeDays": len(active_dates),
    },
  }


def main() -> int:
  payload = collect(parse_args().db)
  sys.stdout.write(json.dumps(payload, separators=(",", ":"), sort_keys=True) + "\n")
  return 0


if __name__ == "__main__":
  sys.exit(main())