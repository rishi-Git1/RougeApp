# RougeApp (Chaos Mode)

RougeApp is a Pokemon roguelike prototype made in Godot.

Each run is about adapting to random teams, random enemies, and weird combinations of types, moves, and abilities.

## What This Game Has Right Now

- Start with a small team and climb floors from 1 to 50.
- Every floor has a battle.
- Your options in battle are `Fight`, `Switch`, `Run`, `Status`, and `Quit`.
- Moves now use real PP. You cannot spam moves forever.
- Team gets fully healed every 10 floors (including PP restore).
- Boss fights happen every 10 floors with boosted HP.
- Every 5 floors you get a random new Pokemon unlock.
- Unlocks are permanent, so future runs can use them.
- Runs are saved automatically, so you can close the game and continue later.
- Sprites are pulled from PokeAPI and cached locally.

## How Team Randomization Works

Each Pokemon gets:

- 2 random types
- 4 random moves using this structure:
  1. Type 1 damaging move
  2. Type 2 damaging move
  3. Random status move
  4. Random damaging move
- Random ability (from supported ability list)
- Random nature

## How To Play

1. Open this project in Godot 4.6.
2. Press `F5` to run.
3. Start a new run from the start screen.
4. Pick your starting team from unlocked Pokemon.
5. Climb floors and build your team.

## Save Files

The game writes save data in Godot's `user://` folder:

- `run_state.json` for current run
- `permanent_unlocks.json` for long-term unlocks
- `sprite_cache/` for downloaded sprites

## Notes

- This is still a prototype, but core run flow and battle flow are playable.
- If something feels off, it is usually easiest to test from a fresh run after major updates.
