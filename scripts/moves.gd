extends Node
## ============================================================================
##  Moves  (autoload singleton — available everywhere as "Moves")
## ----------------------------------------------------------------------------
##  Every battle move in the game lives in the ALL_MOVES dictionary below.
##  This is DATA-DRIVEN design: to invent a new move you just add one entry
##  here (and put its id in REWARD_POOL if players should be able to find it).
##  No other code needs to change.
##
##  A move entry looks like:
##      "move_id": {
##          "name": "Shown to the player",
##          "type": "slime" / "sword" / "water" / "support",
##          "effect": what it does (see the match statements in battle.gd),
##          "power": how strong the effect is,
##          "description": funny text shown on move cards,
##      }
##
##  Effects the battle system understands:
##      "damage"        — hit the other slime
##      "multi_hit"     — hit several times (needs a "hits" number)
##      "damage_recoil" — big hit, but you take "recoil" damage yourself
##      "heal"          — restore "power" HP
##      "shield"        — the NEXT hit you take does half damage
##      "buff_attack"   — your attacks get +"power" for this battle
##      "debuff_attack" — enemy attacks get -"power" for this battle
## ============================================================================

## THE RULE OF SLIMANIA: everyone is a slime, and slimes are weak to swords
## (and soggy against water). So sword moves hit harder... on everyone.
const TYPE_MULTIPLIER: Dictionary = {
	"slime": 1.0,
	"sword": 1.5,   # slimes HATE swords
	"water": 1.25,  # slimes get soggy
	"support": 1.0,
}

## Colors used for move buttons and cards, one per move type.
const TYPE_COLORS: Dictionary = {
	"slime": Color(0.18, 0.65, 0.35),
	"sword": Color(0.62, 0.44, 0.22),
	"water": Color(0.2, 0.5, 0.78),
	"support": Color(0.55, 0.36, 0.72),
}

const ALL_MOVES: Dictionary = {
	# ------------------- Goopzz's starting four -------------------
	"bonk": {
		"name": "Bonk", "type": "slime", "effect": "damage", "power": 6,
		"description": "A friendly headbutt. Reliable, like a good sandwich.",
	},
	"sword_slash": {
		"name": "Sword Slash", "type": "sword", "effect": "damage", "power": 7,
		"description": "Goopzz's trusty wooden sword. Slimes HATE swords.",
	},
	"goo_shield": {
		"name": "Goo Shield", "type": "support", "effect": "shield", "power": 0,
		"description": "Puff up into a wall of goo. The next hit does half damage.",
	},
	"slime_snack": {
		"name": "Slime Snack", "type": "support", "effect": "heal", "power": 14,
		"description": "Munch an emergency snack. Restores 14 HP.",
	},

	# ------------------- Findable / reward moves -------------------
	"double_bounce": {
		"name": "Double Bounce", "type": "slime", "effect": "multi_hit", "power": 4, "hits": 2,
		"description": "Boing! Boing! Hits twice.",
	},
	"splash": {
		"name": "Splash", "type": "water", "effect": "damage", "power": 8,
		"description": "Slimes are weak to water. Yes, even you. Use responsibly.",
	},
	"battle_cry": {
		"name": "Battle Cry", "type": "support", "effect": "buff_attack", "power": 3,
		"description": "BLORP! Raises your attack for the rest of this battle.",
	},
	"sand_throw": {
		"name": "Sand Throw", "type": "support", "effect": "debuff_attack", "power": 3,
		"description": "Kick beach sand at the enemy. Lowers their attack.",
	},
	"mega_bonk": {
		"name": "Mega Bonk", "type": "slime", "effect": "damage", "power": 13,
		"description": "Like Bonk, but MEGA.",
	},
	"sword_spin": {
		"name": "Sword Spin", "type": "sword", "effect": "damage_recoil", "power": 12, "recoil": 4,
		"description": "Spin with the sword! Huge damage, but you get dizzy (4 recoil damage).",
	},
	"royal_jelly": {
		"name": "Royal Jelly", "type": "support", "effect": "heal", "power": 30,
		"description": "Fancy healing jelly fit for a king. Restores 30 HP.",
	},

	# ------------------- Enemy-only moves -------------------
	"tackle": {
		"name": "Tackle", "type": "slime", "effect": "damage", "power": 5,
		"description": "A wobbly body slam.",
	},
	"chomp": {
		"name": "Chomp", "type": "slime", "effect": "damage", "power": 8,
		"description": "Angry slime teeth.",
	},
	"war_cry": {
		"name": "War Cry", "type": "support", "effect": "buff_attack", "power": 2,
		"description": "GRRRB! The enemy powers up.",
	},
	"big_slam": {
		"name": "Big Slam", "type": "slime", "effect": "damage", "power": 12,
		"description": "A boss-sized belly flop.",
	},
}

## The four moves Goopzz starts every run with.
const STARTING_LOADOUT: Array = ["bonk", "sword_slash", "goo_shield", "slime_snack"]

## Moves that can show up as battle rewards or inside Move Disc pickups.
const REWARD_POOL: Array = [
	"double_bounce", "splash", "battle_cry", "sand_throw",
	"mega_bonk", "sword_spin", "royal_jelly",
]

## How many moves Goopzz can carry at once (Pokemon-style four slots).
const MAX_LOADOUT_SIZE: int = 4


## Safe lookup — a typo'd id returns a dummy move instead of crashing.
func get_move(move_id: String) -> Dictionary:
	if ALL_MOVES.has(move_id):
		return ALL_MOVES[move_id]
	push_warning("Moves: unknown move id '%s'." % move_id)
	return {"name": move_id, "type": "slime", "effect": "damage", "power": 1, "description": "???"}


func type_color(type_name: String) -> Color:
	return TYPE_COLORS.get(type_name, Color.WHITE)


## Pick up to `count` random moves from the reward pool, skipping ones the
## player already has (that's what `exclude` is for).
func random_reward_choices(count: int, exclude: Array) -> Array:
	var options: Array = []
	for id in REWARD_POOL:
		if not exclude.has(id):
			options.append(id)
	options.shuffle()
	return options.slice(0, count)
