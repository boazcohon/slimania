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
const LEVEL_UP_HP_BONUS: int = 10     # max HP gained per level (fights are a
                                      # damage race — your HP pool must grow!)
const LEVEL_UP_ATTACK_BONUS: int = 1  # attack gained per level
const ROOM_CLEAR_HEAL_PERCENT: float = 0.35  # between rooms Goopzz recovers
                                      # 35% of his MISSING HP — hurt more,
                                      # heal more, but never a full reset

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
var first_disc_taken: bool = false  # the run's 1st Move Disc guarantees a
                                    # defensive option (see moves.gd)


## ============================================================================
##  THE ROOMS — one dictionary per room, in order. Positions are in "room
##  pixels": each room is 1920 wide and 1024 tall (the size of Isaac's sand
##  art). The playable ground starts below y=260 (above that is the top
##  wall). Things you can put in a room:
##    "title"       — shown at the top of the screen
##    "area"        — "beach", "forest_town" or "forest" (picks the ground
##                    art; the forest is the tougher second half of the run)
##    "hint"        — what Blurpo the guide slime says when you arrive
##    "full_heal"   — true = walking in restores Goopzz to full HP (rest stop)
##    "duo_chance"  — odds (0.0-1.0) that each normal slime brings a pal into
##                    battle with it (bosses never do)
##    "enemies"     — list of {"pos", "level"} (+ "boss": true for big ones)
##    "pickups"     — list of {"pos", "kind"} where kind is "move" or "heal"
##    "water"       — list of Rect2 water pools (JUMP over them — they hurt!)
##    "climb_walls" — list of Rect2 rock walls (hold SHIFT to climb over)
## ============================================================================
const ROOMS: Array = [
	# ------------------------------ THE BEACH ------------------------------
	{
		"title": "Sandy Landing",
		"area": "beach",
		"duo_chance": 0.1,
		"hint": "Welcome back, hero! WASD to move, SPACE to hop — and walk into that red slime to battle it!",
		"enemies": [{"pos": Vector2(1400, 640), "level": 1}],
		"pickups": [],
		"water": [],
		"climb_walls": [],
	},
	{
		"title": "Tide Pools",
		"area": "beach",
		"duo_chance": 0.2,
		"hint": "Hop over the water with SPACE — slimes and water do NOT mix! That rainbow thing is a Move Disc. Grab it!",
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
		"area": "beach",
		"duo_chance": 0.3,
		"hint": "Hold SHIFT on the rocks to climb — but hurry, slimes slip when their grip runs out!",
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
		"area": "beach",
		"duo_chance": 0.4,
		"hint": "Three on patrol! They're slower than you — lead them around and fight one at a time.",
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
		"area": "beach",
		"duo_chance": 0.5,
		"hint": "General Wobble runs the beach invasion. Show him what a REAL hero slime can do!",
		"enemies": [
			{"pos": Vector2(1100, 850), "level": 2},
			{"pos": Vector2(1500, 620), "level": 5, "boss": true},
		],
		"pickups": [{"pos": Vector2(350, 400), "kind": "heal"}],
		"water": [],
		"climb_walls": [],
	},
	# ----------------------------- FOREST TOWN ------------------------------
	# A safe rest stop between the beach and the forest. No enemies, exit
	# always open, and walking in patches Goopzz up to full HP. (The dev team
	# is still deciding what else lives here — a shop? a quest? Stay tuned.)
	{
		"title": "Forest Town",
		"area": "forest_town",
		"hint": "Welcome to Forest Town! You're safe here — rest up, you're back to full health. The forest ahead is MUCH meaner than the beach, so enjoy the quiet while it lasts.",
		"enemies": [],
		"pickups": [],
		"water": [],
		"climb_walls": [],
		"full_heal": true,
	},
	# ------------------------------ THE FOREST ------------------------------
	# The second-most slime-packed place in Slimania. Everything here is a
	# level or two meaner than the beach — heal up and pick moves wisely.
	{
		"title": "Forest Edge",
		"area": "forest",
		"duo_chance": 0.5,
		"hint": "The FOREST! Slimes grow bigger under the trees. Hop the stream if you need to shake off a chaser.",
		"enemies": [
			{"pos": Vector2(1250, 420), "level": 4},
			{"pos": Vector2(1500, 780), "level": 4},
		],
		"pickups": [{"pos": Vector2(350, 420), "kind": "heal"}],
		"water": [Rect2(760, 260, 120, 764)],
		"climb_walls": [],
	},
	{
		"title": "Mushroom Grove",
		"area": "forest",
		"duo_chance": 0.5,
		"hint": "Mind the pond — hop it or go around. And grab that Move Disc before the locals do!",
		"enemies": [
			{"pos": Vector2(1300, 400), "level": 4},
			{"pos": Vector2(1000, 880), "level": 4},
			{"pos": Vector2(1650, 700), "level": 5},
		],
		"pickups": [{"pos": Vector2(1500, 320), "kind": "move"}],
		"water": [Rect2(520, 560, 860, 110)],
		"climb_walls": [],
	},
	{
		"title": "Deep Woods",
		"area": "forest",
		"duo_chance": 0.5,
		"hint": "It's dark in here... these bullies hit HARD. Sand Throw makes them gentler, and Goo Shield never goes out of style.",
		"enemies": [
			{"pos": Vector2(1200, 380), "level": 5},
			{"pos": Vector2(1400, 860), "level": 4},
			{"pos": Vector2(1650, 560), "level": 5},
		],
		"pickups": [{"pos": Vector2(1780, 330), "kind": "move"}],
		"water": [],
		"climb_walls": [Rect2(950, 260, 110, 500)],
	},
	{
		"title": "Tangled Thicket",
		"area": "forest",
		"duo_chance": 0.5,
		"hint": "Almost there! Weave (or climb) through the tangle — Duke Mulch's lair is just past these rocks.",
		"enemies": [
			{"pos": Vector2(1250, 500), "level": 5},
			{"pos": Vector2(1550, 850), "level": 6},
		],
		"pickups": [{"pos": Vector2(320, 860), "kind": "heal"}],
		"water": [],
		"climb_walls": [Rect2(760, 260, 110, 500), Rect2(1050, 520, 110, 504)],
	},
	{
		"title": "Heart of the Forest",
		"area": "forest",
		"duo_chance": 0.5,
		"hint": "Duke Mulch, the forest boss! Shield before his big slams, and don't be shy about healing.",
		"enemies": [
			{"pos": Vector2(1050, 850), "level": 4},
			{"pos": Vector2(1500, 600), "level": 6, "boss": true},
		],
		"pickups": [{"pos": Vector2(330, 380), "kind": "heal"}],
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
	first_disc_taken = false


func room_config() -> Dictionary:
	return ROOMS[clampi(current_room - 1, 0, ROOMS.size() - 1)]


func total_rooms() -> int:
	return ROOMS.size()


func is_last_room() -> bool:
	return current_room >= ROOMS.size()


## Move on to the next room (called when Goopzz walks through the exit).
func advance_room() -> void:
	current_room += 1
	# Recover a slice of whatever HP is missing. A percentage scales with the
	# run (and with mistakes) — but it never quite erases a beating.
	var missing_hp := player_max_hp - player_hp
	player_hp = mini(player_hp + int(ceil(missing_hp * ROOM_CLEAR_HEAL_PERCENT)), player_max_hp)


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
		1: "Baby Red", 2: "Red Slime", 3: "Angry Red", 4: "Slime Bruiser",
		5: "Slime Bully", 6: "Camo Red", 7: "Elder Red",
	}
	# Each area's boss has a name. (The TRUE final boss arrives in Phase 2 —
	# Isaac wants to code that reveal himself!)
	var boss_names: Dictionary = {
		5: "General Wobble",  # runs the beach invasion
		6: "Duke Mulch",      # rules the forest for the invaders
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
		# HP is beefy because Goopzz can now play SEVERAL moves per turn
		# (the gel system) — fights should still last a few turns.
		"max_hp": 20 + level * 10,
		# Attack grows gently: battles are a damage RACE, and Goopzz's HP
		# pool (plus between-room recovery) is what he races with.
		"attack": 1 + level,
		"moves": enemy_moves,
		"xp": 10 + level * 5,
		"sprite_scale": 1.0 + (level - 1) * 0.06,  # higher level = slightly bigger
	}
	if is_boss:
		stats.name = boss_names.get(level, "General Wobble")
		stats.max_hp = int(stats.max_hp * 1.7)
		stats.moves = ["chomp", "big_slam", "war_cry"]
		stats.xp = int(stats.xp * 2)
		stats.sprite_scale = 1.5
	stats["hp"] = stats.max_hp
	return stats
