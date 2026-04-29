#!/usr/bin/env python3
"""
Builds data/species_profiles.json from PokeAPI Pokemon endpoint.

Output includes:
- Canonical typing by slot order
- Canonical abilities (including hidden flag)
- Canonical level-up learnset (latest mainline version group priority)
"""

from __future__ import annotations

import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests


ROOT = Path(__file__).resolve().parents[1]
POKEDEX_PATH = ROOT / "data" / "pokedex.json"
OUTPUT_PATH = ROOT / "data" / "species_profiles.json"
POKEAPI_POKEMON_URL = "https://pokeapi.co/api/v2/pokemon/{pokemon_id}"
POKEAPI_SPECIES_URL = "https://pokeapi.co/api/v2/pokemon-species/{species_id}"

VERSION_GROUP_PRIORITY = [
    "scarlet-violet",
    "sword-shield",
    "ultra-sun-ultra-moon",
    "sun-moon",
    "omega-ruby-alpha-sapphire",
    "x-y",
    "black-2-white-2",
    "black-white",
]


def title_from_api_name(raw_name: str) -> str:
    return raw_name.replace("-", " ").strip().title()


def read_pokedex_ids() -> list[int]:
    rows = json.loads(POKEDEX_PATH.read_text(encoding="utf-8"))
    out: list[int] = []
    for row in rows:
        dex_id = int(row.get("id", 0))
        if dex_id <= 0:
            continue
        out.append(dex_id)
    return sorted(set(out))


def fetch_pokemon_payload(session: requests.Session, pokemon_id: int) -> dict[str, Any]:
    response = session.get(POKEAPI_POKEMON_URL.format(pokemon_id=pokemon_id), timeout=30)
    response.raise_for_status()
    return response.json()


def fetch_species_payload(session: requests.Session, species_id: int) -> dict[str, Any]:
    response = session.get(POKEAPI_SPECIES_URL.format(species_id=species_id), timeout=30)
    response.raise_for_status()
    return response.json()


def extract_types(payload: dict[str, Any]) -> list[str]:
    type_rows = payload.get("types", []) or []
    ordered = sorted(type_rows, key=lambda row: int(row.get("slot", 99)))
    return [title_from_api_name(str(row.get("type", {}).get("name", ""))) for row in ordered if row.get("type", {}).get("name")]


def extract_abilities(payload: dict[str, Any]) -> list[dict[str, Any]]:
    rows = payload.get("abilities", []) or []
    ordered = sorted(rows, key=lambda row: int(row.get("slot", 99)))
    out: list[dict[str, Any]] = []
    for row in ordered:
        ability_name = str(row.get("ability", {}).get("name", "")).strip()
        if not ability_name:
            continue
        out.append(
            {
                "name": title_from_api_name(ability_name),
                "is_hidden": bool(row.get("is_hidden", False)),
                "slot": int(row.get("slot", 0)),
            }
        )
    return out


def pick_levelup_detail(details: list[dict[str, Any]]) -> tuple[int, str] | None:
    for version_group in VERSION_GROUP_PRIORITY:
        for detail in details:
            method = str(detail.get("move_learn_method", {}).get("name", ""))
            detail_group = str(detail.get("version_group", {}).get("name", ""))
            if method != "level-up" or detail_group != version_group:
                continue
            level = int(detail.get("level_learned_at", 0))
            return level, version_group
    return None


def extract_level_up_moves(payload: dict[str, Any]) -> list[dict[str, Any]]:
    rows = payload.get("moves", []) or []
    picks: list[dict[str, Any]] = []
    for row in rows:
        move_name_raw = str(row.get("move", {}).get("name", "")).strip()
        if not move_name_raw:
            continue
        selected = pick_levelup_detail(row.get("version_group_details", []) or [])
        if selected is None:
            continue
        level, version_group = selected
        move_url = str(row.get("move", {}).get("url", ""))
        move_id = 0
        if "/move/" in move_url:
            try:
                move_id = int(move_url.rstrip("/").split("/")[-1])
            except ValueError:
                move_id = 0
        picks.append(
            {
                "id": move_id,
                "name": title_from_api_name(move_name_raw),
                "level": level,
                "version_group": version_group,
            }
        )
    picks.sort(key=lambda item: (int(item.get("level", 0)), str(item.get("name", ""))))
    return picks


def build_entry(pokemon_payload: dict[str, Any], species_payload: dict[str, Any]) -> dict[str, Any]:
    pokemon_id = int(pokemon_payload.get("id", 0))
    pokemon_name = title_from_api_name(str(pokemon_payload.get("name", "")))
    growth_rate = str(species_payload.get("growth_rate", {}).get("name", "medium")).strip().lower()
    return {
        "id": pokemon_id,
        "name": pokemon_name,
        "base_experience": int(pokemon_payload.get("base_experience", 64) or 64),
        "growth_rate": growth_rate if growth_rate else "medium",
        "types": extract_types(pokemon_payload),
        "abilities": extract_abilities(pokemon_payload),
        "level_up_moves": extract_level_up_moves(pokemon_payload),
    }


def main() -> None:
    pokemon_ids = read_pokedex_ids()
    if not pokemon_ids:
        raise SystemExit("No species ids found in data/pokedex.json")

    entries: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    with requests.Session() as session:
        for index, pokemon_id in enumerate(pokemon_ids, start=1):
            try:
                pokemon_payload = fetch_pokemon_payload(session, pokemon_id)
                species_payload = fetch_species_payload(session, pokemon_id)
                entries.append(build_entry(pokemon_payload, species_payload))
            except Exception as exc:  # noqa: BLE001
                errors.append({"id": pokemon_id, "error": str(exc)})
            if index % 25 == 0:
                print(f"Fetched {index}/{len(pokemon_ids)} species...")
            time.sleep(0.03)

    entries.sort(key=lambda row: int(row.get("id", 0)))
    output = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "https://pokeapi.co/api/v2/pokemon/{id}",
        "version_group_priority": VERSION_GROUP_PRIORITY,
        "species_count": len(entries),
        "error_count": len(errors),
        "errors": errors,
        "entries": entries,
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2), encoding="utf-8")

    print(f"Wrote {OUTPUT_PATH} with {len(entries)} species entries.")
    if errors:
        print(f"Completed with {len(errors)} fetch errors.")


if __name__ == "__main__":
    main()
