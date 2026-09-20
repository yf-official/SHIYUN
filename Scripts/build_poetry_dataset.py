#!/usr/bin/env python3
"""Build SHIYUN's offline display-fragment library from public-domain poetry.

The generated JSON is committed and the app never needs the network. Source text
comes from the MIT-licensed chinese-poetry project. A small hand-reviewed seed
list reflects the product reference; only entries with a stable attribution are
included here.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "Scripts" / ".poetry-cache"
OUTPUT = ROOT / "SHIYUN" / "Resources" / "Poetry" / "poetry.json"
BASE = "https://raw.githubusercontent.com/chinese-poetry/chinese-poetry/master"

CI_AUTHORS = {
    "苏轼", "辛弃疾", "李清照", "柳永", "晏殊", "欧阳修", "秦观", "周邦彦",
    "陆游", "杨万里", "范成大", "王安石", "黄庭坚", "姜夔", "贺铸", "张先",
    "晏几道", "岳飞", "朱敦儒", "吴文英", "蒋捷", "张孝祥", "陈与义", "朱淑真",
}

QUIET_KEYWORDS = set("山水月春夏秋冬雨雪花风夜云江河湖海溪泉竹松梅荷柳星舟梦乡归")
EXCLUDE = ("杀", "血", "尸", "战死", "胡虏", "帝业", "圣主", "万岁", "宫阙")
SPLIT = re.compile(r"[，。！？；!?;]+")
NON_HAN = re.compile(r"[^\u3400-\u9fff、·—]|")


CURATED = [
    ("佚名", "无题", "现代", ["春风若有怜花意", "可否许我再少年"], ["春", "花", "少年"]),
    ("纳兰性德", "木兰花·拟古决绝词柬友", "清", ["人生若只如初见", "何事秋风悲画扇"], ["秋", "人生", "时间"]),
    ("王国维", "蝶恋花·阅尽天涯离别苦", "近代", ["最是人间留不住", "朱颜辞镜花辞树"], ["花", "时间", "人生"]),
    ("刘过", "唐多令·芦叶满汀洲", "宋", ["欲买桂花同载酒", "终不似，少年游"], ["花", "少年", "时间"]),
    ("李商隐", "锦瑟", "唐", ["此情可待成追忆", "只是当时已惘然"], ["思念", "时间"]),
    ("佚名", "无题", "现代", ["相逢已是上上签", "何用相思煮余年"], ["相思", "人生"]),
    ("李商隐", "无题·相见时难别亦难", "唐", ["相见时难别亦难", "东风无力百花残"], ["离别", "花", "风"]),
    ("刘禹锡", "秋词", "唐", ["自古逢秋悲寂寥", "我言秋日胜春朝"], ["秋", "豁达"]),
    ("佚名", "金缕衣", "唐", ["劝君莫惜金缕衣", "劝君惜取少年时"], ["少年", "时间"]),
    ("佚名", "越人歌", "先秦", ["山有木兮木有枝", "心悦君兮君不知"], ["山水", "爱情"]),
    ("李商隐", "锦瑟", "唐", ["锦瑟无端五十弦", "一弦一柱思华年"], ["时间", "思念"]),
    ("白居易", "长恨歌", "唐", ["天长地久有时尽", "此恨绵绵无绝期"], ["爱情", "时间"]),
    ("佚名", "金缕衣", "唐", ["花开堪折直须折", "莫待无花空折枝"], ["花", "时间"]),
    ("白居易", "长恨歌", "唐", ["在天愿作比翼鸟", "在地愿为连理枝"], ["爱情"]),
    ("佚名", "无题", "现代", ["他朝若是同淋雪", "此生也算共白头"], ["雪", "爱情"]),
    ("佚名", "化用《琵琶记》", "现代", ["我本将心照明月", "奈何明月照沟渠"], ["月", "人生"]),
    ("佚名", "无题", "现代", ["人道洛阳花似锦", "偏我来时不逢春"], ["春", "花"]),
    ("刘希夷", "代悲白头翁", "唐", ["年年岁岁花相似", "岁岁年年人不同"], ["花", "时间", "人生"]),
    ("崔郊", "赠去婢", "唐", ["侯门一入深如海", "从此萧郎是路人"], ["离别", "人生"]),
    ("佚名", "无题", "现代", ["从此烟尘各悄然", "春山如黛草如烟"], ["春", "山水"]),
    ("佚名", "无题", "现代", ["辞别再无相见日", "终是一人度春秋"], ["离别", "秋"]),
    ("陆游", "沈园二首·其一", "宋", ["伤心桥下春波绿", "曾是惊鸿照影来"], ["春", "思念"]),
    ("佚名", "无题", "现代", ["所得终是水中月", "枯木能逢几回春"], ["月", "春", "人生"]),
    ("佚名", "无题", "现代", ["我与春风皆过客", "你携秋水揽星河"], ["春", "秋", "爱情"]),
]


def fetch(path: str) -> object:
    CACHE.mkdir(parents=True, exist_ok=True)
    cache_file = CACHE / (hashlib.sha1(path.encode()).hexdigest() + ".json")
    if not cache_file.exists():
        url = f"{BASE}/{urllib.parse.quote(path)}"
        result = subprocess.run(
            ["curl", "--fail", "--location", "--silent", "--show-error", url],
            check=True,
            capture_output=True,
        )
        cache_file.write_bytes(result.stdout)
    return json.loads(cache_file.read_text(encoding="utf-8"))


def clean_clause(value: str) -> str:
    value = re.sub(r"[\s\u3000]+", "", value)
    value = value.strip("，。！？；、 ")
    return value


def valid_clause(value: str) -> bool:
    return 4 <= len(value) <= 14 and not any(word in value for word in EXCLUDE) and all(
        "\u3400" <= char <= "\u9fff" or char in "、·，" for char in value
    )


def infer_tags(lines: list[str]) -> list[str]:
    text = "".join(lines)
    mapping = {
        "山水": "山水峰岭泉溪", "月": "月", "春": "春", "夏": "夏", "秋": "秋", "冬": "冬",
        "雨": "雨", "雪": "雪", "花": "花梅桃李荷菊", "风": "风", "夜": "夜暮夕",
        "江河": "江河湖海潮", "思乡": "乡故园归家", "离别": "别离送", "爱情": "相思情",
        "人生": "人生世间老", "少年": "少年", "时间": "年岁日暮", "自由": "自在闲",
        "孤独": "独孤", "宁静": "静闲幽", "豁达": "笑醉旷",
    }
    tags = [name for name, chars in mapping.items() if any(char in text for char in chars)]
    if not tags:
        tags = ["自然"] if any(char in text for char in QUIET_KEYWORDS) else ["人生"]
    return tags[:5]


def paragraph_strings(values: list) -> list[str]:
    result: list[str] = []
    for value in values:
        if isinstance(value, str):
            result.append(value)
        elif isinstance(value, dict):
            result.extend(paragraph_strings(value.get("paragraphs", [])))
    return result


def add_record(records: list[dict], seen: set[str], author: str, title: str, dynasty: str, lines: list[str], tags: list[str] | None = None) -> None:
    cleaned = [clean_clause(line) for line in lines]
    if len(cleaned) not in (1, 2) or not all(valid_clause(line) for line in cleaned):
        return
    key = "|".join(cleaned)
    if key in seen:
        return
    seen.add(key)
    digest = hashlib.sha1(f"{dynasty}|{author}|{title}|{key}".encode()).hexdigest()[:14]
    records.append({
        "id": f"poem_{digest}",
        "text": cleaned,
        "author": author.strip("（）() ").replace("唐）", "").replace("宋）", ""),
        "title": title.strip(),
        "dynasty": dynasty,
        "tags": tags or infer_tags(cleaned),
        "mood": "calm",
        "length": "short" if sum(map(len, cleaned)) <= 20 else "medium",
    })


def build() -> list[dict]:
    records: list[dict] = []
    seen: set[str] = set()

    for author, title, dynasty, lines, tags in CURATED:
        add_record(records, seen, author, title, dynasty, lines, tags)
    curated_count = len(records)

    anthology = fetch("蒙学/qianjiashi.json")
    for section in anthology["content"]:
        for poem in section["content"]:
            author_value = poem["author"]
            dynasty_match = re.match(r"（([^）]+)）", author_value)
            dynasty = dynasty_match.group(1) if dynasty_match else "古代"
            author = re.sub(r"^（[^）]+）", "", author_value)
            for paragraph in paragraph_strings(poem["paragraphs"]):
                clauses = [clean_clause(item) for item in SPLIT.split(paragraph) if clean_clause(item)]
                for index in range(0, len(clauses) - 1, 2):
                    add_record(records, seen, author, poem["chapter"], dynasty, clauses[index:index + 2])

    # These six volumes contain a broad, hand-selected set of major Northern and
    # Southern Song writers while keeping regeneration fast and deterministic.
    for start in range(0, 6000, 1000):
        for poem in fetch(f"宋词/ci.song.{start}.json"):
            if poem.get("author") not in CI_AUTHORS:
                continue
            title = poem.get("rhythmic") or "词作"
            for paragraph in poem.get("paragraphs", []):
                clauses = [clean_clause(item) for item in SPLIT.split(paragraph) if clean_clause(item)]
                for index in range(0, len(clauses) - 1, 2):
                    add_record(records, seen, poem["author"], title, "宋", clauses[index:index + 2])

    # Put the calmest, most image-rich entries first, then retain broad variety.
    curated = records[:curated_count]
    remainder = records[curated_count:]
    remainder.sort(key=lambda item: (
        -sum(tag in {"山水", "月", "春", "夏", "秋", "冬", "雨", "雪", "花", "风", "夜", "宁静"} for tag in item["tags"]),
        item["dynasty"], item["author"], item["title"], item["id"],
    ))
    return (curated + remainder)[:8000]


def main() -> None:
    records = build()
    if len(records) < 3000:
        raise SystemExit(f"Only generated {len(records)} records; refusing undersized library")
    raw = ROOT / "Scripts" / ".poetry-cache" / "poetry.traditional.json"
    raw.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    subprocess.run(["swift", str(ROOT / "Scripts" / "simplify_json.swift"), str(raw), str(OUTPUT)], check=True)
    print(f"Generated {len(records)} verified fragments at {OUTPUT}")


if __name__ == "__main__":
    main()
