# SLIMANIA — Phase 1: the roguelike prototype

You are **Goopzz**, a green slime with a wooden sword, bonking his way through
5 beach rooms of red invader slimes. Die and the run restarts — that's the
roguelike loop. All art is hand-drawn by Isaac.

## How to open and run it (Godot 4)

1. Install **Godot 4.3 or newer** (the free standard version, not .NET):
   <https://godotengine.org/download>
2. Open Godot → **Import** → browse to this folder and pick `project.godot`
   → **Import & Edit**.
3. The first open takes ~a minute while Godot imports the PNGs. Let it finish.
4. Press **F5** (or the ▶ Play button, top-right). That's it — you're on the
   title screen. Press ENTER to start a run.

Tip: press **F6** while looking at any scene (like `battle.tscn`) to run just
that scene by itself — every scene has safe defaults, so they all work solo.

## Controls

| Key | What it does |
| --- | --- |
| WASD / arrows | move (free top-down movement) |
| SPACE | short hop — carries you safely over water, then needs a moment to recharge |
| hold SHIFT | climb rock walls — slip back if your grip runs out! |
| mouse or 1–4 | pick a move in battle |
| ENTER | confirm on menus |

## How a run works

- Each room: defeat every red slime (walk into one to start a turn-based
  battle), then leave through the exit gate on the right.
- Winning a battle gives XP (level-ups = more HP and attack) **and** a
  pick-1-of-3 new move. You carry **4 moves** — learning a 5th means
  forgetting one, Pokémon-style.
- **Move Discs** and **healing jelly** sit on the sand in some rooms.
- Water hurts slimes (hop over it — enemies can't follow). Swords hurt slimes
  extra. *Everyone here is a slime.* Plan accordingly.
- 5 rooms, escalating. Room 5 holds **General Wobble**. Good luck.

## The easiest things to tweak first

All the numbers a game-designer cares about sit at the top of files as
constants or `@export` variables, with comments:

| Want to change... | Go to |
| --- | --- |
| Player speed, jump height/cooldown, climb grip time, water damage | top of `scripts/player.gd` |
| Enemy chase speed, how far they can see | top of `scripts/enemy.gd` |
| Move damage/effects, add a NEW move | `scripts/moves.gd` (one dictionary entry = one move) |
| Starting HP/attack, XP curve, level-up bonuses | top of `scripts/run_manager.gd` |
| **The rooms themselves** — enemy count/levels, pickups, water pools, climbing walls, add a room | the `ROOMS` list in `scripts/run_manager.gd` (copy a room entry and edit it!) |
| How much healing a jelly pickup gives | `HEAL_AMOUNT` in `scripts/pickup.gd` |
| Sword/water damage multipliers ("weakness rules") | `TYPE_MULTIPLIER` in `scripts/moves.gd` |

After editing, just press F5 again. If something breaks, the **Output** and
**Debugger** panels at the bottom of the editor say which line.

## Where the art lives

Every PNG path is listed in **one file**: `scripts/sprite_paths.gd`.
Scripts ask for art by nickname (`SpritePaths.tex("goopzz")`), so:

- **Replacing art**: overwrite the PNG file, keep the same name — done.
- **Adding art**: drop the PNG anywhere in `slimania assets/`, add one line to
  `sprite_paths.gd`, and use its nickname in code.
- Missing files never crash the game — you get a gray box and a warning.

Current placeholders waiting for real art (marked `TODO(Isaac)` in code):
water pools, rock walls, the healing-jelly pickup, and the game icon
(`icon.svg`).

## How the code is organized

```
project.godot            window size, input keys, autoload singletons
scenes/                  one tiny .tscn per screen/thing (logic lives in scripts)
scripts/
  sprite_paths.gd        nickname → PNG path (the ONLY place paths live)
  moves.gd               every battle move (data-driven — add moves here)
  run_manager.gd         the current run: HP, level, loadout, room list
  ui_helpers.gd          shared factories for labels/bars/buttons
  player.gd              Goopzz: walking, hopping, climbing, water
  enemy.gd               red slimes: wander → chase → touch = battle
  pickup.gd              Move Discs and healing jelly
  battle.gd              the Pokémon-style battle screen
  move_learn_panel.gd    the "pick / forget a move" pop-up
  overworld.gd           builds each room and glues everything together
  title_screen.gd        title + story + press enter
  game_over.gd           win/lose screen + run stats
tests/validate.gd        optional smoke test (see file header)
```

## Phase 2 hooks (already in place, not built yet)

- **Kath** and the **purple help slime** sprites are mapped in
  `sprite_paths.gd`, ready for story NPCs.
- Rooms are data — forest/rocks/mountain areas are new entries in `ROOMS`
  (or a second room list) with their own backdrop art.
- Climbing is deliberately weak: the **climbing gloves** quest reward can
  simply raise `climb_max_stamina`.
- `RunManager` is the "combat brain"; story/quests belong in a new
  `StoryManager` autoload beside it.
- The Phase 2 final boss reveal is Isaac's to code — General Wobble is only
  the *beach* invasion's leader.
