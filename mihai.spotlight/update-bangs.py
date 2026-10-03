#!/usr/bin/env python3
"""Regenerate bangs.txt from DuckDuckGo's public bang list.

Usage:  ./update-bangs.py

Source: https://duckduckgo.com/bang.js  (the same data behind bang_lite.html)

Output: bangs.txt, one bang per line, sorted by trigger:

    trigger <TAB> url-template <TAB> domain <TAB> name <TAB> rank

`trigger` is the bang name without the leading `!`, `url-template` carries
DuckDuckGo's `{{{s}}}` placeholder for the search term, `rank` is
DuckDuckGo's popularity score.

Spotlight keeps the parsed lines in memory and binary searches them, so the
alphabetical order matters: exact lookups are a bisection and the "did you
mean" alternates for `!gh` are just the lines that follow it.
"""

import json
import re
import urllib.request

SOURCE = "https://duckduckgo.com/bang.js"
OUTPUT = "bangs.txt"

# Bang.js is noisy: a few hundred triggers are whole URLs or phrases with
# punctuation. Keep the ones a person can actually type.
TRIGGER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]{0,19}$")


def fetch():
    with urllib.request.urlopen(SOURCE, timeout=60) as response:
        return json.load(response)


def clean(value, limit=48):
    text = " ".join(str(value or "").split()).replace("\t", " ")
    return text if len(text) <= limit else text[: limit - 1] + "…"


def main():
    entries = fetch()
    seen = set()
    rows = []
    for entry in entries:
        trigger = clean(entry.get("t"), 20).lower()
        url = str(entry.get("u") or "").replace("\t", " ").strip()
        if not trigger or not url or not TRIGGER.match(trigger):
            continue
        if (trigger, url) in seen:
            continue
        seen.add((trigger, url))
        rows.append(
            (
                trigger,
                url,
                clean(entry.get("d")),
                clean(entry.get("s")),
                int(entry.get("r") or 0),
            )
        )

    rows.sort(key=lambda row: row[0])
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join("\t".join(str(field) for field in row) for row in rows) + "\n")

    print(f"{len(rows)} bangs -> {OUTPUT}")


if __name__ == "__main__":
    main()