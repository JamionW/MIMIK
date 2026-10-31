"""Check every site/<code>/phrases.json for mistakes the app and audio generator would not catch.

Errors fail the run (exit 1); warnings are printed as GitHub annotations and do not.

Usage: python scripts/lint_phrases.py [code ...]
"""
import json
import re
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent / "site"
# Text the TTS would read badly: a slash between options, or an ellipsis standing for a name.
NEEDS_SAY = re.compile(r"/|\.\.\.|…")
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
WORD = re.compile(r"\w+")


class Report:
    def __init__(self, code):
        self.code, self.errors, self.warnings = code, [], []

    def error(self, where, msg):
        self.errors.append(f"{self.code}/{where}: {msg}")

    def warn(self, where, msg):
        self.warnings.append(f"{self.code}/{where}: {msg}")


def check_header(data, r):
    for key in ("name", "native", "color", "lang", "voices", "sections"):
        if key not in data:
            r.error("header", f"missing {key}")
    if "color" in data and not HEX.match(str(data["color"])):
        r.error("header", f"color {data['color']!r} is not #rrggbb")
    voices = data.get("voices", {})
    if not isinstance(voices, dict) or not voices.get("m") or not voices.get("f"):
        r.error("header", "voices needs both m and f")


def check_sections(data, r):
    hours_seen = {}
    for i, sec in enumerate(data.get("sections", [])):
        where = f"sections[{i}]"
        for key in ("id", "title", "phrases"):
            if key not in sec:
                r.error(where, f"missing {key}")
        if "hours" not in sec:
            continue
        h = sec["hours"]
        if not (isinstance(h, list) and len(h) == 2 and all(isinstance(x, int) and 0 <= x <= 23 for x in h) and h[0] != h[1]):
            r.error(sec.get("id", where), f"hours {h!r} must be [start, end], whole hours 0 to 23, start != end")
            continue
        a, b = h
        for hour in range(24):
            if (a <= hour < b) if a < b else (hour >= a or hour < b):
                hours_seen.setdefault(hour, []).append(sec["id"])
    if hours_seen or any("hours" in s for s in data.get("sections", [])):
        gaps = [h for h in range(24) if h not in hours_seen]
        overlaps = {h: ids for h, ids in hours_seen.items() if len(ids) > 1}
        if gaps:
            r.error("sections", f"no time section covers hours {gaps}")
        for h, ids in sorted(overlaps.items()):
            r.error("sections", f"hour {h} is in more than one section: {ids}")


def check_spoken(item, where, stressed, r, inherited_say=None):
    """Fields shared by phrases, alt rows and feminine forms."""
    text = item.get("text", "")
    say = item.get("say", inherited_say)
    if NEEDS_SAY.search(text) and not say:
        r.error(where, f"text {text!r} has a slash or ellipsis but no say")
    ph = item.get("ph")
    if ph is not None:
        if stressed and not re.search(r"[A-Z]", ph):
            r.error(where, f"ph {ph!r} has no stressed syllable in capitals")
        if not stressed and re.search(r"[A-Z]", ph):
            r.error(where, f"ph {ph!r} has capitals, but this language has no stress marking")


def check_phrases(data, r, japanese):
    ids = []
    stressed = not japanese
    for sec in data.get("sections", []):
        for p in sec.get("phrases", []):
            pid = p.get("id", "?")
            ids.append(pid)
            for key in ("id", "en", "text", "ph"):
                if not p.get(key):
                    r.error(pid, f"missing {key}")
            if japanese and not p.get("rom"):
                r.error(pid, "missing rom")
            check_spoken(p, pid, stressed, r)
            if "f" in p:
                f = p["f"]
                # The feminine clip merges f over the phrase, so a masculine say would leak into it.
                if "text" in f and p.get("say") and "say" not in f:
                    r.error(f"{pid}.f", "overrides text but not say; the feminine clip would speak the masculine say")
                check_spoken({**p, **f}, f"{pid}.f", stressed, r)
            for j, a in enumerate(p.get("alt", [])):
                aid = a.get("id", f"{pid}.alt[{j}]")
                ids.append(aid)
                if not a.get("tag"):
                    r.error(aid, "alt entry has no tag")
                for key in ("id", "text", "ph"):
                    if not a.get(key):
                        r.error(aid, f"missing {key}")
                if japanese and not a.get("rom"):
                    r.error(aid, "missing rom")
                check_spoken(a, aid, stressed, r)
            for j, rep in enumerate(p.get("replies", [])):
                rid = rep.get("id", f"{pid}.replies[{j}]")
                ids.append(rid)
                for key in ("id", "text", "en"):
                    if not rep.get(key):
                        r.error(rid, f"missing {key}")
                if rep.get("id") and rep["id"] != f"{pid}-r{j + 1}":
                    r.error(rid, f"reply id should be {pid}-r{j + 1}")
                if "ph" in rep:
                    r.error(rid, "replies are heard, not said, and carry no ph")
                if japanese and not rep.get("rom"):
                    r.error(rid, "missing rom")
                check_spoken(rep, rid, stressed, r)
    dupes = sorted({i for i in ids if ids.count(i) > 1})
    if dupes:
        r.error("ids", f"duplicate ids: {dupes}")
    return set(ids)


def check_gender(data, r):
    """Warn when a word that some phrase genders (obrigado -> obrigada) appears in a phrase with no f form."""
    phrases = [p for s in data.get("sections", []) for p in s.get("phrases", [])]
    gendered = set()
    for p in phrases:
        if "text" in p.get("f", {}):
            m, f = WORD.findall(p["text"].lower()), WORD.findall(p["f"]["text"].lower())
            if len(m) == len(f):
                gendered |= {a for a, b in zip(m, f) if a != b}
    for p in phrases:
        if "f" in p:
            continue
        hits = gendered & set(WORD.findall(p.get("text", "").lower()))
        if hits:
            r.warn(p.get("id", "?"), f"contains {sorted(hits)}, gendered elsewhere, but has no f form")


def check_human(folder, ids, r):
    for g, sub in (("m", folder / "audio-human"), ("f", folder / "audio-human" / "f")):
        if not sub.is_dir():
            continue
        for clip in sorted(sub.iterdir()):
            if clip.is_dir():
                continue
            if clip.suffix != ".m4a":
                r.error(f"audio-human/{clip.relative_to(folder / 'audio-human')}", "human recordings must be .m4a")
            elif clip.stem not in ids:
                r.warn(f"audio-human/{clip.relative_to(folder / 'audio-human')}", f"no phrase with id {clip.stem!r}")


def lint(path):
    code = path.parent.name
    r = Report(code)
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        r.error("phrases.json", f"invalid JSON: {e}")
        return r
    check_header(data, r)
    check_sections(data, r)
    ids = check_phrases(data, r, str(data.get("lang", "")).startswith("ja"))
    check_gender(data, r)
    check_human(path.parent, ids, r)
    return r


def main():
    codes = sys.argv[1:]
    paths = [p for p in sorted(SITE.glob("*/phrases.json")) if not codes or p.parent.name in codes]
    if not paths:
        sys.exit(f"no languages matched {codes}")
    errors = 0
    for path in paths:
        r = lint(path)
        for w in r.warnings:
            print(f"::warning::{w}")
        for e in r.errors:
            print(f"::error::{e}")
        errors += len(r.errors)
    print(f"{len(paths)} languages checked, {errors} errors")
    sys.exit(1 if errors else 0)


main()
