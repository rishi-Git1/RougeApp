#!/usr/bin/env python3
"""
Builds data/move_effects.json from PokeAPI move metadata.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests


ROOT = Path(__file__).resolve().parents[1]
MOVES_PATH = ROOT / "data" / "moves.json"
OUTPUT_PATH = ROOT / "data" / "move_effects.json"
POKEAPI_MOVE_URL = "https://pokeapi.co/api/v2/move/{move_id}"


STATUS_MAP = {
    "paralysis": "paralysis",
    "burn": "burn",
    "poison": "poison",
    "freeze": "freeze",
    "sleep": "sleep",
    "bad-poison": "bad_poison",
}

PROTECT_MOVE_NAMES = {"protect", "detect", "max guard"}
WEATHER_FROM_NAME = {
    "rain dance": "rain",
    "sunny day": "sun",
    "sandstorm": "sandstorm",
    "hail": "hail",
    "snowscape": "hail",
}
TERRAIN_FROM_NAME = {
    "electric terrain": "electric",
    "grassy terrain": "grassy",
    "psychic terrain": "psychic",
    "misty terrain": "misty",
}
BARRIER_FROM_NAME = {
    "reflect": "reflect",
    "light screen": "light_screen",
    "aurora veil": "aurora_veil",
}
HAZARD_FROM_NAME = {
    "stealth rock": "stealth_rock",
    "spikes": "spikes",
    "toxic spikes": "toxic_spikes",
    "sticky web": "sticky_web",
}


@dataclass
class MoveSeed:
    move_id: int
    move_name: str


def normalize_move_name(value: str) -> str:
    return value.strip().lower()


def read_moves_seed() -> list[MoveSeed]:
    rows = json.loads(MOVES_PATH.read_text(encoding="utf-8"))
    out: list[MoveSeed] = []
    for row in rows:
        move_id = int(row.get("id", 0))
        move_name = str(row.get("name", "")).strip()
        if move_id <= 0 or not move_name:
            continue
        out.append(MoveSeed(move_id=move_id, move_name=move_name))
    return out


def fetch_move_payload(session: requests.Session, move_id: int) -> dict[str, Any]:
    response = session.get(POKEAPI_MOVE_URL.format(move_id=move_id), timeout=30)
    response.raise_for_status()
    return response.json()


def english_short_effect(payload: dict[str, Any]) -> str:
    entries = payload.get("effect_entries", [])
    for entry in entries:
        lang_name = str(entry.get("language", {}).get("name", ""))
        if lang_name == "en":
            return str(entry.get("short_effect", ""))
    return ""


def derive_status(meta: dict[str, Any], move_name: str) -> str:
    ailment_name = str(meta.get("ailment", {}).get("name", ""))
    mapped = STATUS_MAP.get(ailment_name, "")
    if mapped:
        return mapped
    lower = normalize_move_name(move_name)
    if "toxic" in lower:
        return "bad_poison"
    if "poison" in lower:
        return "poison"
    if "burn" in lower:
        return "burn"
    if "sleep" in lower:
        return "sleep"
    if "freeze" in lower:
        return "freeze"
    if lower == "thunder wave":
        return "paralysis"
    return ""


def derive_charge_recharge(effect_text: str, move_name: str) -> tuple[bool, bool]:
    lower_effect = effect_text.lower()
    lower_name = normalize_move_name(move_name)
    requires_charge = "charges on the first turn" in lower_effect or "turn 1" in lower_effect and "turn 2" in lower_effect
    requires_recharge = "must recharge" in lower_effect

    # Safety fallback for inconsistent effect text.
    if lower_name in {"solar beam", "solarblade", "solar blade", "sky attack", "skull bash", "razor wind", "bounce", "fly", "dig", "dive", "phantom force", "shadow force", "meteor beam", "electro shot"}:
        requires_charge = True
    if lower_name in {"hyper beam", "giga impact", "blast burn", "hydro cannon", "frenzy plant", "rock wrecker", "roar of time", "prismatic laser", "eternabeam", "meteor assault"}:
        requires_recharge = True
    return requires_charge, requires_recharge


def build_effect_entry(seed: MoveSeed, payload: dict[str, Any]) -> dict[str, Any]:
    meta = payload.get("meta", {}) or {}
    short_effect = english_short_effect(payload)
    lower_name = normalize_move_name(seed.move_name)

    drain_raw = int(meta.get("drain", 0) or 0)
    healing_raw = int(meta.get("healing", 0) or 0)
    # PokeAPI uses +/- percentages.
    drain_fraction = abs(drain_raw) / 100.0 if drain_raw != 0 else 0.0
    recoil_fraction = abs(drain_raw) / 100.0 if drain_raw < 0 else 0.0
    heal_fraction = healing_raw / 100.0 if healing_raw > 0 else 0.0

    min_hits = int(meta.get("min_hits", 0) or 0)
    max_hits = int(meta.get("max_hits", 0) or 0)
    min_turns = int(meta.get("min_turns", 0) or 0)
    max_turns = int(meta.get("max_turns", 0) or 0)

    ailment_chance = int(meta.get("ailment_chance", 0) or 0)
    flinch_chance = int(meta.get("flinch_chance", 0) or 0)
    stat_chance = int(meta.get("stat_chance", 0) or 0)
    effect_chance = int(payload.get("effect_chance", 0) or 0)

    # Relations mostly captured by authoritative fields + explicit move family maps.
    status = derive_status(meta, seed.move_name)
    weather = WEATHER_FROM_NAME.get(lower_name, "")
    terrain = TERRAIN_FROM_NAME.get(lower_name, "")
    barrier = BARRIER_FROM_NAME.get(lower_name, "")
    hazard = HAZARD_FROM_NAME.get(lower_name, "")
    protect = lower_name in PROTECT_MOVE_NAMES
    trap = str(meta.get("ailment", {}).get("name", "")) == "trap" or (min_turns >= 2 and max_turns >= min_turns and lower_name not in PROTECT_MOVE_NAMES)
    requires_charge, requires_recharge = derive_charge_recharge(short_effect, seed.move_name)

    return {
        "id": seed.move_id,
        "name": seed.move_name,
        "status": status,
        "status_chance": ailment_chance,
        "weather": weather,
        "terrain": terrain,
        "barrier": barrier,
        "hazard": hazard,
        "protect": protect,
        "trap": trap,
        "trap_min_turns": min_turns,
        "trap_max_turns": max_turns,
        "flinch": flinch_chance > 0,
        "flinch_chance": flinch_chance,
        "drain_fraction": drain_fraction,
        "recoil_fraction": recoil_fraction,
        "self_heal_fraction": heal_fraction,
        "requires_charge": requires_charge,
        "requires_recharge": requires_recharge,
        "min_hits": min_hits,
        "max_hits": max_hits,
        "stat_chance": stat_chance,
        "effect_chance": effect_chance,
        "ailment": str(meta.get("ailment", {}).get("name", "")),
        "category": str(meta.get("category", {}).get("name", "")),
        "target": str(payload.get("target", {}).get("name", "")),
        "crit_rate": int(meta.get("crit_rate", 0) or 0),
        "short_effect": short_effect,
    }


def main() -> None:
    seeds = read_moves_seed()
    if not seeds:
        raise SystemExit("No moves found in data/moves.json")

    entries: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    with requests.Session() as session:
        for index, seed in enumerate(seeds, start=1):
            try:
                payload = fetch_move_payload(session, seed.move_id)
                entries.append(build_effect_entry(seed, payload))
            except Exception as exc:  # noqa: BLE001
                errors.append({"id": seed.move_id, "name": seed.move_name, "error": str(exc)})
            if index % 25 == 0:
                print(f"Fetched {index}/{len(seeds)} moves...")
            time.sleep(0.03)

    entries.sort(key=lambda item: int(item.get("id", 0)))

    out = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "https://pokeapi.co/api/v2/move/{id}",
        "move_count": len(entries),
        "error_count": len(errors),
        "errors": errors,
        "entries": entries,
    }
    OUTPUT_PATH.write_text(json.dumps(out, indent=2), encoding="utf-8")

    print(f"Wrote {OUTPUT_PATH} with {len(entries)} moves.")
    if errors:
        print(f"Completed with {len(errors)} fetch errors.")


if __name__ == "__main__":
    main()
