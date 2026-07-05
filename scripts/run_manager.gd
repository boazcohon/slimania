extends Node
## ============================================================================
##  RunManager  (autoload singleton — available everywhere as "RunManager")
## ----------------------------------------------------------------------------
##  Remembers everything about the CURRENT RUN: Goopzz's HP, level, XP, his
##  four equipped moves, and which room he has reached. A "run" is one attempt
##  at fighting through all the rooms. When Goopzz faints, the run is over and
##  the next run starts fresh from Room 1 — that's the roguelike loop.
##
##  This is also where the ROOMS list lives — the easiest place to make the
##  game bigger: copy a room entry, tweak it, done.
##
##  PHASE 2 NOTE (story mode): keep this class as the "combat run" brain and
##  add a separate StoryManager for quests/areas — rooms here already support
##  water + climbing walls, so forest/rocks/mountain rooms can reuse them.
## ============================================================================

# ------------------------- easy tuning knobs -------------------------
const PLAYER_BASE_MAX_HP: int = 40    # Goopzz's HP at the start of a run
const PLAYER_BASE_ATTACK: int = 3     # added to every damaging move's power
const XP_PER_LEVEL: int = 25          # XP needed = 25 x your current level
const LEVEL_UP_HP_BONUS: int = 6      # max HP gained per level
const LEVEL_UP_ATTACK_BONUS: int = 1  # attack gained per level
const ROOM_CLEAR_HEAL: int = 8        # free HP for reaching the next room

# ------------------------- current run state -------------------------
var player_level: int = 1
var player_xp: int = 0
var player_max_hp: int = PLAYER_BASE_MAX_HP
var player_hp: int = PLAYER_BASE_MAX_HP
var player_attack: int = PLAYER_BASE_ATTACK
var loadout: Array = []        # the four equipped move ids
var current_room: int = 1      # 1-based: Room 1 is the first room
var battles_won: int = 0
var run_won: bool = false      # true when the player beats the last room


## ============================================================================
##  THE ROOMS — one dictionary per room, in order. Positions are in "room
##  pixels": each room is 1920 wide and 1024 tall (the size of Isaac's sand
##  art). The playable sand starts below y=260 (above that is the black top
##  wall). Things you can put in a room:
##    "title"       — shown at the top of the screen
##    "hint"        — helper text at the bottom of the screen ("" for none)
##    "enemies"     — list of {"pos", "level"} (+ "boss": true for big ones)
##    "pickups"     — list of {"pos", "kind"} where kind is "move" or "heal"
##    "water"       — list of Rect2 water pools (JUMP over them — they hurt!)
##    "climb_walls" — list of Rect2 rock walls (hold SHIFT to climb over)
## ============================================================================
const ROOMS: Array = [
	{
		"title": "Sandy Landing",
		"hint": "WASD / arrows to move  ·  SPACE to hop  ·  walk into a slime to battle it!",
		"enemies": [{"pos": Vector2(1400, 640), "level": 1}],
		"pickups": [],
		"water": [],
		"climb_walls": [],
	},
	{
		"title": "Tide Pools",
		"hint": "Hop over the water with SPACE — slimes and water do NOT mix!",
		"enemies": [
			{"pos": Vector2(1250, 450), "level": 1},
			{"pos": Vector2(1500, 750), "level": 2},
		],
		"pickups": [{"pos": Vector2(1700, 380), "kind": "move"}],
		"water": [Rect2(860, 260, 120, 764)],
		"climb_walls": [],
	},
	{
		"title": "The Rocks",
		"hint": "Hold SHIFT on the rocks to climb — but hurry, slimes slip!",
		"enemies": [
			{"pos": Vector2(1300, 400), "level": 2},
			{"pos": Vector2(1450, 800), "level": 3},
		],
		"pickups": [{"pos": Vector2(300, 850), "kind": "heal"}],
		"water": [],
		"climb_walls": [Rect2(900, 260, 110, 764)],
	},
	{
		"title": "Slime Patrol",
		"hint": "",
		"enemies": [
			{"pos": Vector2(1150, 350), "level": 3},
			{"pos": Vector2(1350, 650), "level": 3},
			{"pos": Vector2(1600, 880), "level": 4},
		],
		"pickups": [{"pos": Vector2(1750, 320), "kind": "move"}],
		"water": [Rect2(600, 260, 120, 764)],
		"climb_walls": [Rect2(1000, 260, 110, 400)],
	},
	{
		"title": "Invader's Camp",
		"hint": "The invasion leader is here. Show him what a REAL hero slime can do!",
		"enemies": [
			{"pos": Vector2(1100, 850), "level": 2},
			{"pos": Vector2(1500, 620), "level": 5, "boss": true},
		],
		"pickups": [{"pos": Vector2(350, 400), "kind": "heal"}],
		"water": [],
		"climb_walls": [],
	},
]


func _ready() -> void:
	# Make sure the run state is always valid, even if someone runs a scene
	# directly from the editor with F6 instead of starting at the title screen.
	start_new_run()


## Reset everything — called when a new run begins at the title screen.
func start_new_run() -> void:
	player_level = 1
	player_xp = 0
	player_max_hp = PLAYER_BASE_MAX_HP
	player_hp = PLAYER_BASE_MAX_HP
	player_attack = PLAYER_BASE_ATTACK
	loadout = Moves.STARTING_LOADOUT.duplicate()
	current_room = 1
	battles_won = 0
	run_won = false


func room_config() -> Dictionary:
	return ROOMS[clampi(current_room - 1, 0, ROOMS.size() - 1)]


func total_rooms() -> int:
	return ROOMS.size()


func is_last_room() -> bool:
	return current_room >= ROOMS.size()


## Move on to the next room (called when Goopzz walks through the exit).
func advance_room() -> void:
	current_room += 1
	# A little breather heal as a reward for clearing the room.
	player_hp = mini(player_hp + ROOM_CLEAR_HEAL, player_max_hp)


## How much XP is needed to go from the current level to the next one.
func xp_to_next_level() -> int:
	return XP_PER_LEVEL * player_level


## Give Goopzz XP. Returns how many levels he gained (usually 0 or 1).
## Leveling up raises max HP and attack, and heals a little — it feels good!
func add_xp(amount: int) -> int:
	player_xp += amount
	var levels_gained := 0
	while player_xp >= xp_to_next_level():
		player_xp -= xp_to_next_level()
		player_level += 1
		levels_gained += 1
		player_max_hp += LEVEL_UP_HP_BONUS
		player_attack += LEVEL_UP_ATTACK_BONUS
		player_hp = mini(player_hp + LEVEL_UP_HP_BONUS * 2, player_max_hp)
	return levels_gained


## Build the stat sheet for one enemy slime of a given level.
## Rooms only store a level number — all the math lives here, so making
## enemies stronger/weaker for the whole game is a one-line change.
func make_enemy_stats(level: int, is_boss: bool = false) -> Dictionary:
	var names: Dictionary = {
		1: "Baby Red", 2: "Red Slime", 3: "Angry Red", 4: "Slime Bruiser", 5: "Slime Bully",
	}
	var enemy_moves: Array = ["tackle"]
	if level >= 2:
		enemy_moves.append("chomp")
	if level >= 4:
		enemy_moves.append("war_cry")

	var stats: Dictionary = {
		"name": names.get(level, "Red Slime"),
		"level": level,
		"is_boss": is_boss,
		"max_hp": 14 + level * 7,
		"attack": 1 + level * 2,
		"moves": enemy_moves,
		"xp": 10 + level * 5,
		"sprite_scale": 1.0 + (level - 1) * 0.06,  # higher level = slightly bigger
	}
	if is_boss:
		# The leader of the BEACH invasion. (The true final boss arrives in
		# Phase 2 — Isaac wants to code that reveal himself!)
		stats.name = "General Wobble"
		stats.max_hp = int(stats.max_hp * 1.7)
		stats.moves = ["chomp", "big_slam", "war_cry"]
		stats.xp = int(stats.xp * 2)
		stats.sprite_scale = 1.5
	stats["hp"] = stats.max_hp
	return stats
