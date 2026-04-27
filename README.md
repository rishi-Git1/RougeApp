# RougeApp (Chaos Mode Prototype)

Ground-up Godot 4 starter for your roguelike concept:

- Full pokedex data is loaded (1025 species with base stats).
- Full move and ability datasets are loaded from PokeAPI CSV exports (main-series entries).
- The first ever unlocks are Pikachu and Eevee (starter species).
- Every new run starts with 2 species rolled from your permanent unlock pool.
- Player team starts at Lv.5; floor 1 wild encounters remain Lv.1.
- Floors 1-10 only spawn basic-stage species for wild encounters; floor 11+ returns to full random pool.
- Floor climbs from 1 to 50.
- Every floor spawns a randomized wild Pokemon encounter.
- Battle actions are `Fight`, `Switch`, and `Run`:
  - `Fight`: choose one of your active Pokemon's 4 moves each turn.
  - `Switch`: choose exactly which living team member to swap into battle.
  - `Run`: skip the encounter and move to next floor with **no team level-up**.
- Enemy turns are CPU-controlled.
- Battle log is color-coded by event type (appear, attack, switch, faint, run, penalty).
- Stat stage buffs/debuffs (including accuracy/evasion) are applied in battle and logged when they change.
- If you `Run` more than once within a 5-floor checkpoint stretch, you forfeit that checkpoint's unlock reward.
- Team building is now a full-screen pre-run sprite grid of unlocked Pokemon in pokedex order.
- Hover a sprite in that grid to inspect that run preview (types, moves, ability, nature, HP).
- Move/type text in battle UI uses Pokemon type color coding.
- Level-up evolution prompts now appear at actual level-up evolution levels (where applicable).
- Declining evolution (`Not Now`) re-prompts on the next level-up if still eligible.
- Every 5 floors, the game rolls a random new Pokemon unlock.
- Unlocks are permanent across runs (`user://permanent_unlocks.json`).
- You can choose to add the unlock to your active team immediately or keep it unlocked but benched.
- Current run state auto-saves and auto-loads (`user://run_state.json`) so you can close/reopen and continue.
- Team Builder lets you assign only permanently unlocked species into active team slots.
- Save Debug panel includes Force Save / Reload From Disk and timestamps.
- Save Debug panel includes a 2-click **Clear Save Data** reset for quick test cycles.
- Added a start screen with **Continue Run** / **Start New Run**.
- Team slots now fetch sprites from the PokeAPI sprite repository and cache files in `user://sprite_cache/`.
- If API fetch fails (offline or missing sprite), UI falls back to the local icon.
- Window is configured to be resizable with responsive UI stretch settings.

## Run It

1. Open the folder in Godot 4.2+.
2. Run the project (`F5`).
3. Click **Start New Run**.
4. Click **Simulate Battle Win** to advance floors.
5. Use the **Team Builder** panel to place unlocked species into team slots.

At floors 5, 10, 15, ... you will get an unlock popup with a full summary.

## Project Layout

- `scenes/Main.tscn`: main prototype scene and UI layout
- `scripts/ui/Main.gd`: UI event wiring
- `scripts/managers/RunManager.gd`: run state and progression rules
- `scripts/managers/PokemonFactory.gd`: randomization system and summary generation
- `data/*.json`: starter datasets (pokedex, moves, types, abilities, natures)

## Next Suggested Steps

- Replace starter data with full Pokedex + move list.
- Add real battle simulation and enemy generation.
- Add sprite loading by PokeAPI id.
- Add save/load for run snapshots.
