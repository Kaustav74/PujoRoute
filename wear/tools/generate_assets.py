#!/usr/bin/env python3
"""Regenerate the Wear OS app's bundled JSON assets from the phone app's Dart data.

Sources (relative to the repo root):
  Android App/lib/data/puja_calendar_data.dart   -> calendar.json
  Android App/lib/data/pujas_data.dart           -> pandals.json
  Android App/lib/services/emergency_service.dart -> emergency.json
  Android App/lib/services/metro_graph_service.dart -> metro.json (+ station/line/gate per pandal)

Usage:  python3 wear/tools/generate_assets.py [pandals] [metro] [emergency] [calendar]
With no arguments every asset is regenerated. NOTE: calendar.json has been
maintained by hand since the phone calendar data was restructured (PR #5);
build_calendar() no longer matches it, so regenerate only the assets you need,
e.g.  python3 wear/tools/generate_assets.py pandals metro
Only the Python 3 standard library is needed.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "Android App" / "lib"
OUT = ROOT / "wear" / "app" / "src" / "main" / "assets"


# --------------------------------------------------------------------------
# Tiny Dart literal parser (enough for the const constructor calls we read)
# --------------------------------------------------------------------------
class Parser:
    def __init__(self, text, pos):
        self.s = text
        self.i = pos

    def ws(self):
        s = self.s
        while self.i < len(s):
            if s[self.i].isspace():
                self.i += 1
            elif s.startswith("//", self.i):
                nl = s.find("\n", self.i)
                self.i = len(s) if nl < 0 else nl + 1
            elif s.startswith("/*", self.i):
                self.i = s.index("*/", self.i) + 2
            else:
                break

    def peek(self):
        self.ws()
        return self.s[self.i] if self.i < len(self.s) else ""

    def expect(self, ch):
        self.ws()
        if not self.s.startswith(ch, self.i):
            raise ValueError(f"expected {ch!r} at {self.i}: {self.s[self.i:self.i + 60]!r}")
        self.i += len(ch)

    def string_literal(self):
        s = self.s
        q = s[self.i]
        self.i += 1
        out = []
        while s[self.i] != q:
            c = s[self.i]
            if c == "\\":
                n = s[self.i + 1]
                out.append({"n": "\n", "t": "\t", "'": "'", '"': '"', "\\": "\\", "$": "$"}.get(n, n))
                self.i += 2
            else:
                out.append(c)
                self.i += 1
        self.i += 1
        return "".join(out)

    def value(self):
        c = self.peek()
        if c in "'\"":
            parts = [self.string_literal()]
            while self.peek() in ("'", '"'):  # adjacent literal concatenation
                parts.append(self.string_literal())
            return "".join(parts)
        if c == "[":
            self.i += 1
            items = []
            while self.peek() != "]":
                items.append(self.value())
                if self.peek() == ",":
                    self.i += 1
            self.i += 1
            return items
        m = re.compile(r"[A-Za-z_][\w.]*").match(self.s, self.i)
        if m:
            name = m.group(0)
            self.i = m.end()
            if self.peek() == "(":
                return {"__ctor__": name, **self.call_args()}
            return {"true": True, "false": False, "null": None}.get(name, name)
        m = re.compile(r"-?\d+(\.\d+)?").match(self.s, self.i)
        if m:
            self.i = m.end()
            return float(m.group(0)) if m.group(1) else int(m.group(0))
        raise ValueError(f"cannot parse value at {self.i}: {self.s[self.i:self.i + 60]!r}")

    def call_args(self):
        self.expect("(")
        args = {}
        pos = 0
        while self.peek() != ")":
            m = re.compile(r"(\w+)\s*:(?!:)").match(self.s, self.i)
            if m:
                self.i = m.end()
                args[m.group(1)] = self.value()
            else:
                args[f"_{pos}"] = self.value()
                pos += 1
            if self.peek() == ",":
                self.i += 1
        self.i += 1
        return args


def parse_list(text, header_regex):
    m = re.search(header_regex, text)
    if not m:
        raise SystemExit(f"Could not find list matching {header_regex!r}")
    p = Parser(text, text.index("[", m.end() - 1))
    return p.value()


def dt(d):
    """DateTime(y, m, d[, h, min]) ctor dict -> ISO local string (IST, no offset)."""
    vals = [d.get(f"_{i}", 0) for i in range(6)]
    y, mo, da, h, mi, se = vals
    return f"{y:04d}-{mo:02d}-{da:02d}T{h:02d}:{mi:02d}:{se:02d}"


# --------------------------------------------------------------------------
def build_calendar():
    text = (LIB / "data" / "puja_calendar_data.dart").read_text(encoding="utf-8")
    tithi_days = parse_list(text, r"final List<PujaTithiDay> pujaCalendar2026\s*=\s*\[")
    details = {d["id"]: d for d in parse_list(text, r"const List<PujaDayTithi> kDurgaPujaCalendar2026\s*=\s*\[")}
    days = []
    for t in tithi_days:
        d = details.get(t["id"], {})
        days.append({
            "id": t["id"],
            "titleEn": t["titleEn"],
            "titleBn": t["titleBn"],
            "subTitle": t["subTitle"],
            "date": dt(t["targetDate"])[:10],
            "dateFormatted": d.get("dateFormatted", ""),
            "tithiStart": dt(t["tithiStart"]),
            "tithiEnd": dt(t["tithiEnd"]),
            "tithiName": d.get("tithiName", ""),
            "tithiTimings": d.get("tithiTimings", ""),
            "muhuratTitle": t["muhuratTitle"],
            "muhuratWindow": t["muhuratWindow"],
            "auspiciousMoments": [s.strip() for s in d.get("auspiciousMoments", "").split("|") if s.strip()],
            # Beni Madhab / traditional para mode (falls back to Belur Math values in the app when empty)
            "tithiTimingsTrad": d.get("tithiTimingsTraditional") or "",
            "auspiciousMomentsTrad": [s.strip() for s in (d.get("auspiciousMomentsTraditional") or "").split("|") if s.strip()],
            "crowdForecast": d.get("crowdForecast", ""),
            "crowdLevel": d.get("crowdLevel", 0),
        })
    days.sort(key=lambda x: x["date"])
    return {"timezone": "Asia/Kolkata", "days": days}


def short_history(text, limit=240):
    text = re.sub(r"\s+", " ", text.replace("*", "")).strip()
    if len(text) <= limit:
        return text
    cut = text[:limit]
    dot = cut.rfind(". ")
    return (cut[:dot + 1] if dot > 80 else cut.rsplit(" ", 1)[0] + "…")


def gate_rules(text):
    """Port of Pandal.detailedMetroGate: ordered (needles, result) rules."""
    body = text[text.index("String get detailedMetroGate"):]
    body = body[:body.index("\n  }")]
    rules = []
    for cond, result in re.findall(r"if \((mLower\.contains\([^)]*\)(?:\s*\|\|\s*mLower\.contains\([^)]*\))*)\) return '((?:[^'\\]|\\.)*)';", body):
        rules.append((re.findall(r"contains\('([^']*)'\)", cond), result.replace("\\'", "'")))
    return rules


def gate_for(metro, rules):
    m = metro.lower()
    for needles, result in rules:
        if any(n in m for n in needles):
            return result
    if "Gate" in metro:
        return metro
    return f"{metro} - Gate 1 (Main Street Concourse)"


def build_pandals(metro):
    text = (LIB / "data" / "pujas_data.dart").read_text(encoding="utf-8")
    rules = gate_rules(text)
    items = parse_list(text, r"const List<Pandal> kAllKolkataPujas\s*=\s*\[")
    out, seen = [], set()
    for p in items:
        if p["id"] in seen:
            continue
        seen.add(p["id"])
        raw_metro = p.get("metroStation", "")
        station = canonical_station(raw_metro, metro) or raw_metro.strip()
        landmark = p.get("landmark", "")
        rec = {
            "id": p["id"],
            "name": p["name"],
            "cat": "h" if p.get("category") == "heritage" else "m",
            "zone": p["zone"],
            "area": p.get("subsection", ""),
            "lat": round(float(p.get("lat", 0.0)), 4),
            "lon": round(float(p.get("lon", p.get("lng", 0.0))), 4),
            # Most landmarks are just "<name>, Kolkata"; drop those to save space.
            "landmark": "" if landmark.startswith(p["name"]) else landmark,
            "metro": station,
            "line": line_for(station, metro) or "",
            "gate": gate_for(raw_metro, rules) if raw_metro else "",
            "about": short_history(p.get("history", "")),
            "rank": p.get("popularityRank", 999),
        }
        if rec["rank"] == 999:
            del rec["rank"]
        out.append({k: v for k, v in rec.items() if v != ""})
    return out


# --------------------------------------------------------------------------
LINE_LISTS = [("Blue", "kBlueLineStations"), ("Green", "kGreenLineStations"),
              ("Purple", "kPurpleLineStations"), ("Orange", "kOrangeLineStations"),
              ("Yellow", "kYellowLineStations")]


def build_metro():
    text = (LIB / "services" / "metro_graph_service.dart").read_text(encoding="utf-8")
    coords = parse_map(text, "kStationCoordinates")
    aliases = parse_map(text, "kCanonicalAliases")
    lines = []
    for name, const in LINE_LISTS:
        stations = parse_list(text, rf"static const List<String> {const}\s*=\s*\[")
        lines.append({"name": f"{name} Line", "stations": [
            {"name": st, "lat": coords.get(st, [0, 0])[0], "lon": coords.get(st, [0, 0])[1]} for st in stations]})
    return {"lines": lines, "aliases": aliases}


def parse_map(text, const):
    m = re.search(rf"static const Map<[^>]*>>? {const}\s*=\s*\{{", text)
    body = text[m.end():text.index("};", m.end())]
    out = {}
    for k, v in re.findall(r"'([^']+)'\s*:\s*('[^']*'|\[[^\]]*\])", body):
        out[k] = v.strip("'") if v.startswith("'") else [float(x) for x in v.strip("[]").split(",")]
    return out


def canonical_station(name, metro):
    n = name.strip().lower()
    if not n:
        return None
    if n in metro["aliases"]:
        return metro["aliases"][n]
    all_st = [st["name"] for ln in metro["lines"] for st in ln["stations"]]
    for st in all_st:
        if st.lower() == n:
            return st
    best = None
    for st in all_st:  # longest substring match wins (port of getCanonicalStation)
        sl = st.lower()
        if (sl in n or n in sl) and (best is None or len(st) > len(best)):
            best = st
    return best


def line_for(station, metro):
    names = [ln["name"] for ln in metro["lines"] if any(st["name"] == station for st in ln["stations"])]
    return " / ".join(names)


def build_emergency():
    text = (LIB / "services" / "emergency_service.dart").read_text(encoding="utf-8")
    hospitals = parse_list(text, r"List<HospitalCasualty> kKolkataCasualtyHospitals\s*=\s*\[")
    police = parse_list(text, r"List<PoliceAssistanceBooth> kPoliceBooths\s*=\s*\[")
    # The phone app groups several numbers under one label ("Kolkata Police Emergency: 112 / 100").
    # On the watch every number gets its own chip, so give each a distinct, correct label.
    per_number = {
        "112": "National Emergency (ERSS)",
        "100": "Kolkata Police Control Room",  # label used in quick_reply_service.dart
        "102": "Medical Ambulance",
        "108": "Emergency Ambulance",
    }
    grouped = []
    for label, nums in re.findall(r'"• ([^:"]+?): ([0-9][0-9 /]*)(?:\\n)?"', text):
        grouped.append((label.strip(), [n.strip() for n in nums.split("/") if n.strip()]))
    qr = (LIB / "services" / "quick_reply_service.dart").read_text(encoding="utf-8")
    for label, nums in re.findall(r"'• \*\*([^*]+)\*\*: ([0-9][0-9 /-]*)(?:\\n)?'", qr):
        grouped.append((label.strip(), [n.strip() for n in nums.split("/") if n.strip()]))
    helplines, seen = [], set()
    for label, nums in grouped:
        for n in nums:
            if n in seen:
                continue
            seen.add(n)
            helplines.append({"label": per_number.get(n, label), "numbers": [n]})
    order = ["112", "100", "102", "108", "101", "1091", "1073", "139"]
    helplines.sort(key=lambda h: order.index(h["numbers"][0]) if h["numbers"][0] in order else len(order))
    return {
        "helplines": helplines,
        "hospitals": [{"name": h["name"], "zone": h["zone"], "phone": h["phone"], "address": h["address"]} for h in hospitals],
        "police": [{"name": b["division"], "landmark": b["landmark"],
                    "numbers": [n.strip() for n in b["contact"].split("/") if n.strip()]} for b in police],
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    wanted = set(sys.argv[1:]) or {"calendar", "pandals", "emergency", "metro"}
    metro = build_metro()
    builders = {"calendar": build_calendar, "pandals": lambda: build_pandals(metro),
                "emergency": build_emergency, "metro": lambda: {"lines": metro["lines"]}}
    for key in sorted(wanted):
        obj = builders[key]()
        (OUT / f"{key}.json").write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        if key == "calendar":
            print(f"calendar.json: {len(obj['days'])} days")
            ok = len(obj["days"]) >= 8
        elif key == "pandals":
            print(f"pandals.json: {len(obj)} pandals")
            ok = len(obj) >= 100
        elif key == "emergency":
            print(f"emergency.json: {len(obj['helplines'])} helplines, {len(obj['hospitals'])} hospitals, {len(obj['police'])} police")
            ok = len(obj["helplines"]) >= 5
        else:
            print(f"metro.json: {len(obj['lines'])} lines, {sum(len(l['stations']) for l in obj['lines'])} station entries")
            ok = len(obj["lines"]) >= 4
        if not ok:
            sys.exit(f"Sanity check failed: unexpectedly small {key}.json")


if __name__ == "__main__":
    main()
