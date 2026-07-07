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
##          "cost": how many GELS it costs to use (0-4),
##          "effect": what it does (see the match statements in battle.gd),
##          "power": how strong the effect is,
##          "description": funny text shown on move cards,
##      }
##
##  GELS are Goopzz's battle energy: he gets 4 every turn, each equipped move
##  can be used once per turn, and leftover gels do NOT carry over. Spend
##  them well, then End Turn.
##
##  A move with "once_per_battle": true can only be used ONE time in each
##  battle — emergency buttons, not every-turn habits.
##
##  Effects the battle system understands:
##      "damage"           — hit one slime (WATER-type damage hits ALL enemies!)
##      "multi_hit"        — hit one slime several times (needs a "hits" number)
##      "damage_recoil"    — big hit, but you take "recoil" damage yourself
##      "damage_lifesteal" — hit one slime, then heal back half the damage dealt
##      "heal"             — restore "power" HP
##      "block"            — gain "power" BLOCK: it soaks damage until your
##                           next turn starts, then melts away
##      "heal_block"       — restore "power" HP AND gain "power" block
##      "buff_attack"      — your attacks get +"power" for this battle
##      "debuff_attack"    — ALL enemies' attacks get -"power" for this battle
## ============================================================================

## THE RULE OF SLIMANIA: everyone is a slime, and slimes are weak to swords.
## Water moves have a different superpower now — they splash EVERY enemy in
## the fight (see battle.gd) — so they no longer get a damage bonus here.
const TYPE_MULTIPLIER: Dictionary = {
	"slime": 1.0,
	"sword": 1.5,   # slimes HATE swords
	"water": 1.0,   # water's perk is hitting the whole enemy team at once
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
		"name": "Bonk", "type": "slime", "cost": 1, "effect": "damage", "power": 5,
		"description": "A friendly headbutt. Reliable, like a good sandwich.",
	},
	"sword_slash": {
		"name": "Sword Slash", "type": "sword", "cost": 2, "effect": "damage", "power": 7,
		"description": "Goopzz's trusty wooden sword. Slimes HATE swords.",
	},
	"goo_shield": {
		"name": "Goo Shield", "type": "support", "cost": 1, "effect": "block", "power": 8,
		"description": "Puff up into a wall of goo. Blocks 8 damage until your next turn.",
	},
	"slime_snack": {
		"name": "Slime Snack", "type": "support", "cost": 1, "effect": "heal", "power": 12,
		"once_per_battle": true,
		"description": "Munch THE emergency snack. Restores 12 HP. You only packed one!",
	},

	# ------------------- Findable / reward moves -------------------
	"double_bounce": {
		"name": "Double Bounce", "type": "slime", "cost": 2, "effect": "multi_hit",
		"power": 4, "hits": 2,
		"description": "Boing! Boing! Hits twice.",
	},
	"splash": {
		"name": "Splash", "type": "water", "cost": 2, "effect": "damage", "power": 7,
		"description": "Soaks EVERY enemy — slimes are weak to water. Yes, even you.",
	},
	"battle_cry": {
		"name": "Battle Cry", "type": "support", "cost": 1, "effect": "buff_attack", "power": 2,
		"description": "BLORP! Raises your attack for the rest of this battle.",
	},
	"sand_throw": {
		"name": "Sand Throw", "type": "support", "cost": 1, "effect": "debuff_attack", "power": 2,
		"description": "Kick sand at EVERY enemy. Lowers their attack.",
	},
	"mega_bonk": {
		"name": "Mega Bonk", "type": "slime", "cost": 3, "effect": "damage", "power": 14,
		"description": "Like Bonk, but MEGA.",
	},
	"sword_spin": {
		"name": "Sword Spin", "type": "sword", "cost": 3, "effect": "damage_recoil",
		"power": 11, "recoil": 4,
		"description": "Spin with the sword! Huge damage, but you get dizzy (4 recoil damage).",
	},
	"royal_jelly": {
		"name": "Royal Jelly", "type": "support", "cost": 2, "effect": "heal", "power": 20,
		"once_per_battle": true,
		"description": "Fancy healing jelly fit for a king. Restores 20 HP — once per battle.",
	},
	"tsunami": {
		"name": "Tsunami", "type": "water", "cost": 4, "effect": "damage", "power": 12,
		"description": "THE BIG WAVE. Crashes into every enemy at once. Costs your whole turn.",
	},
	"rebel_yell": {
		"name": "Rebel Yell", "type": "support", "cost": 2, "effect": "buff_attack", "power": 5,
		"description": "A Battle Cry so loud the trees flinch. Attack way up!",
	},
	"sandstorm": {
		"name": "Sandstorm", "type": "support", "cost": 2, "effect": "debuff_attack", "power": 4,
		"description": "A whole BEACH of sand, airborne. Every enemy hits much softer.",
	},
	"goo_armor": {
		"name": "Goo Armor", "type": "support", "cost": 2, "effect": "block", "power": 20,
		"once_per_battle": true,
		"description": "Goo Shield's big sibling. Blocks 20 damage — save it for the REALLY big hit.",
	},
	"slurp_slash": {
		"name": "Slurp Slash", "type": "sword", "cost": 2, "effect": "damage_lifesteal", "power": 6,
		"description": "Slice a slime and slurp up the splatter. Heals half the damage dealt!",
	},
	"jelly_roll": {
		"name": "Jelly Roll", "type": "support", "cost": 1, "effect": "heal_block", "power": 6,
		"description": "Tuck and roll! A little heal AND a little block. Flexible.",
	},
	"pointy_stick": {
		"name": "Pointy Stick", "type": "sword", "cost": 1, "effect": "damage", "power": 4,
		"description": "Technically a sword! Cheap, cheerful, surprisingly pointy.",
	},
	"belly_flop": {
		"name": "Belly Flop", "type": "slime", "cost": 4, "effect": "damage", "power": 18,
		"description": "Leap. Flop. Flatten ONE unlucky slime. Worth the whole turn.",
	},

	# --------- Enemy-only moves (enemies don't use gels, so no cost) ---------
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
	"tsunami", "rebel_yell", "sandstorm", "goo_armor",
	"pointy_stick", "belly_flop", "slurp_slash", "jelly_roll",
]

## Moves that help you SURVIVE. The first Move Disc of every run guarantees
## at least one of these among its choices, so no run is doomed by bad luck.
const DEFENSIVE_MOVES: Array = ["royal_jelly", "goo_armor", "jelly_roll", "sandstorm"]

## How many moves Goopzz can carry at once (Pokemon-style four slots).
const MAX_LOADOUT_SIZE: int = 4

## How many gels Goopzz gets at the start of each battle turn.
const GELS_PER_TURN: int = 4


## Safe lookup — a typo'd id returns a dummy move instead of crashing.
func get_move(move_id: String) -> Dictionary:
	if ALL_MOVES.has(move_id):
		return ALL_MOVES[move_id]
	push_warning("Moves: unknown move id '%s'." % move_id)
	return {
		"name": move_id, "type": "slime", "cost": 1,
		"effect": "damage", "power": 1, "description": "???",
	}


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


## Like random_reward_choices, but guarantees at least one DEFENSIVE move is
## among the options (used for the first Move Disc of a run).
func reward_choices_with_defense(count: int, exclude: Array) -> Array:
	var choices := random_reward_choices(count, exclude)
	for id in choices:
		if DEFENSIVE_MOVES.has(id):
			return choices  # luck already provided one
	var defensive_options: Array = []
	for id in DEFENSIVE_MOVES:
		if not exclude.has(id):
			defensive_options.append(id)
	if defensive_options.is_empty() or choices.is_empty():
		return choices
	# Swap one random choice out for a random defensive move.
	choices[randi() % choices.size()] = defensive_options.pick_random()
	return choices
