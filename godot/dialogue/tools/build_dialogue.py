#!/usr/bin/env python3
"""Compile the dialogue sources in godot/dialogue/src/*.txt into JSON.

Source format (one file per personality, named <personality_id>.txt):

    == base                      # tier: base | dating | marriage
    # greet stage=stranger       # context, then optional conditions
    Hi there, {player}.          # one line of dialogue per text line
    // comment                   # ignored

Conditions (space separated key=value, values comma separated):
    stage=stranger,acquaintance  friendship tier; "friend+" = friend or higher,
                                 "dislike-" = dislike or lower
    romance=none,crush           romance tier
    time=morning,evening         morning 05-12, afternoon 12-17, evening 17-22, night 22-05
    weekend=true|false
    place=cafe,bar               any of Life.place tags/category/type

Tier implies romance: dating lines need dating/partner/engaged/married,
marriage lines need married.

Output:
    data/lines/<id>.json   {"id", "lines": [{"id","tier","context","text","cond"}]}
    data/index.json        line counts per personality and tier

Run: python3 godot/dialogue/tools/build_dialogue.py   (exits 1 on validation errors)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "data" / "lines"
PERSONALITIES = ROOT / "data" / "personalities.json"

FRIEND_ORDER = ["enemy", "dislike", "stranger", "acquaintance", "friend", "close_friend", "best_friend"]
ROMANCE = ["none", "crush", "dating", "partner", "engaged", "married"]
TIMES = ["morning", "afternoon", "evening", "night"]
TIERS = {"base": (100, 200), "dating": (50, None), "marriage": (200, None)}
TIER_ROMANCE = {"dating": ["dating", "partner", "engaged", "married"], "marriage": ["married"]}
TOKENS = {"player", "npc", "place", "weekday", "timeofday"}

# Every personality must cover these (tier, context) pairs with at least N lines.
REQUIRED = {
    ("base", "greet"): 20, ("base", "farewell"): 6, ("base", "smalltalk"): 15,
    ("base", "about_self"): 5, ("base", "opinion_place"): 4, ("base", "compliment_reply"): 4,
    ("base", "insult_reply"): 4, ("base", "gift_reply"): 4, ("base", "joke"): 3,
    ("base", "ask_favor"): 2, ("base", "favor_reply"): 2, ("base", "work_talk"): 3,
    ("base", "school_talk"): 2, ("base", "hostile"): 5, ("base", "flirt_reply"): 6,
    ("base", "ask_out_yes"): 2, ("base", "ask_out_no"): 2,
    ("dating", "date_greet"): 5, ("dating", "flirt"): 6, ("dating", "date_talk"): 10,
    ("dating", "compliment"): 4, ("dating", "kiss_reply"): 3, ("dating", "miss_you"): 3,
    ("dating", "jealous"): 3, ("dating", "date_end"): 4, ("dating", "lovers_quarrel"): 3,
    ("dating", "proposal_yes"): 2,
    ("marriage", "home_greet"): 28, ("marriage", "affection"): 15, ("marriage", "home_talk"): 20,
    ("marriage", "chores"): 10, ("marriage", "money"): 8, ("marriage", "meal"): 8,
    ("marriage", "argue"): 10, ("marriage", "makeup"): 6, ("marriage", "support"): 8,
    ("marriage", "plans"): 8, ("marriage", "memories"): 8, ("marriage", "anniversary"): 5,
    ("marriage", "tease"): 8, ("marriage", "work_return"): 6, ("marriage", "bedtime"): 8,
    ("marriage", "goodbye_work"): 6,
}


def expand_stage(values, errs, where):
    out = []
    for v in values:
        if v.endswith("+") and v[:-1] in FRIEND_ORDER:
            out += FRIEND_ORDER[FRIEND_ORDER.index(v[:-1]):]
        elif v.endswith("-") and v[:-1] in FRIEND_ORDER:
            out += FRIEND_ORDER[: FRIEND_ORDER.index(v[:-1]) + 1]
        elif v in FRIEND_ORDER:
            out.append(v)
        else:
            errs.append(f"{where}: unknown stage '{v}'")
    return sorted(set(out), key=FRIEND_ORDER.index)


def parse_header(text, errs, where):
    parts = text.split()
    ctx, cond = parts[0], {}
    for p in parts[1:]:
        if "=" not in p:
            errs.append(f"{where}: bad condition '{p}'")
            continue
        k, v = p.split("=", 1)
        vals = [x for x in v.split(",") if x]
        if k == "stage":
            cond["stage"] = expand_stage(vals, errs, where)
        elif k == "romance":
            bad = [x for x in vals if x not in ROMANCE]
            if bad:
                errs.append(f"{where}: unknown romance {bad}")
            cond["romance"] = vals
        elif k == "time":
            bad = [x for x in vals if x not in TIMES]
            if bad:
                errs.append(f"{where}: unknown time {bad}")
            cond["time"] = vals
        elif k == "weekend":
            cond["weekend"] = vals[0] == "true"
        elif k == "place":
            cond["place"] = vals
        else:
            errs.append(f"{where}: unknown condition key '{k}'")
    return ctx, cond


def parse_file(path, errs):
    pid = path.stem
    tier, ctx, cond = None, None, {}
    lines, seen = [], set()
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        s = raw.strip()
        where = f"{path.name}:{n}"
        if not s or s.startswith("//"):
            continue
        if s.startswith("=="):
            tier = s[2:].strip()
            if tier not in TIERS:
                errs.append(f"{where}: unknown tier '{tier}'")
            ctx = None
            continue
        if s.startswith("#"):
            ctx, cond = parse_header(s[1:].strip(), errs, where)
            if tier in TIER_ROMANCE and "romance" not in cond:
                cond = dict(cond, romance=TIER_ROMANCE[tier])
            continue
        if tier is None or ctx is None:
            errs.append(f"{where}: line outside a section")
            continue
        for tok in re.findall(r"\{(\w+)\}", s):
            if tok not in TOKENS:
                errs.append(f"{where}: unknown token {{{tok}}}")
        if s.lower() in seen:
            errs.append(f"{where}: duplicate line in {pid}: {s}")
        seen.add(s.lower())
        lines.append({"tier": tier, "context": ctx, "text": s, "cond": cond})
    counters = {}
    for ln in lines:
        k = ln["tier"]
        counters[k] = counters.get(k, 0) + 1
        ln["id"] = f"{pid}.{k}.{counters[k]:03d}"
    return pid, lines


def main():
    errs = []
    personalities = json.loads(PERSONALITIES.read_text(encoding="utf-8"))["personalities"]
    ids = [p["id"] for p in personalities]
    if len(ids) != 30 or len(set(ids)) != 30:
        errs.append(f"expected 30 unique personalities, found {len(set(ids))}")
    OUT.mkdir(parents=True, exist_ok=True)
    index = {"personalities": {}, "total_lines": 0}
    all_text = {}
    for pid in ids:
        path = SRC / f"{pid}.txt"
        if not path.exists():
            errs.append(f"missing source {path.name}")
            continue
        pid, lines = parse_file(path, errs)
        counts = {t: sum(1 for l in lines if l["tier"] == t) for t in TIERS}
        for t, (lo, hi) in TIERS.items():
            if counts[t] < lo or (hi and counts[t] > hi):
                errs.append(f"{pid}: {t} has {counts[t]} lines, needs {lo}{'-' + str(hi) if hi else '+'}")
        for (t, c), need in REQUIRED.items():
            have = sum(1 for l in lines if l["tier"] == t and l["context"] == c)
            if have < need:
                errs.append(f"{pid}: {t}/{c} has {have} lines, needs {need}")
        for l in lines:
            all_text.setdefault(l["text"].lower(), []).append(pid)
        (OUT / f"{pid}.json").write_text(
            json.dumps({"id": pid, "lines": lines}, ensure_ascii=False, indent=1), encoding="utf-8")
        index["personalities"][pid] = counts
        index["total_lines"] += len(lines)
    shared = {t: p for t, p in all_text.items() if len(set(p)) > 1}
    for t, p in list(shared.items())[:20]:
        errs.append(f"line shared by {sorted(set(p))}: {t}")
    (ROOT / "data" / "index.json").write_text(json.dumps(index, indent=1), encoding="utf-8")
    if errs:
        print("\n".join(errs))
        print(f"{len(errs)} error(s)")
        return 1
    print(f"OK: {len(index['personalities'])} personalities, {index['total_lines']} lines")
    for pid, c in index["personalities"].items():
        print(f"  {pid:24s} base {c['base']:3d}  dating {c['dating']:3d}  marriage {c['marriage']:3d}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
