#!/usr/bin/env python3
import json
import re
from collections import Counter
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "SHIYUN" / "Resources" / "Poetry" / "poetry.json"
poems = json.loads(path.read_text(encoding="utf-8"))
errors = []

required = {"id", "text", "author", "title", "dynasty", "tags", "mood", "length"}
for index, poem in enumerate(poems):
    missing = required - poem.keys()
    if missing:
        errors.append(f"[{index}] missing {sorted(missing)}")
    for key in ("id", "author", "title", "dynasty", "mood", "length"):
        if not isinstance(poem.get(key), str) or not poem[key].strip():
            errors.append(f"[{index}] empty {key}")
    text = poem.get("text", [])
    if not isinstance(text, list) or not 1 <= len(text) <= 2 or not all(isinstance(line, str) and line.strip() for line in text):
        errors.append(f"[{index}] invalid text")
    if any(re.search(r"[A-Za-z0-9]", line) for line in text):
        errors.append(f"[{index}] unexpected latin/digit content")

ids = Counter(poem.get("id") for poem in poems)
texts = Counter("|".join(poem.get("text", [])) for poem in poems)
errors.extend(f"duplicate id: {value}" for value, count in ids.items() if count > 1)
errors.extend(f"duplicate text: {value}" for value, count in texts.items() if count > 1)

if len(poems) < 3000:
    errors.append(f"dataset too small: {len(poems)}")

if errors:
    print("\n".join(errors[:100]))
    raise SystemExit(1)
print(f"OK: {len(poems)} poems, {len(ids)} unique IDs, {len(texts)} unique fragments")
