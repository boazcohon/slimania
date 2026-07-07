class_name BattleScreen
extends CanvasLayer
## ============================================================================
##  Battle — the turn-based battle screen (now with GELS and DUOS!)
## ----------------------------------------------------------------------------
##  How a turn works (Slay-the-Spire style):
##    1. Your turn starts: you get 4 GELS and your old block melts away.
##    2. Spend gels on moves — each equipped move once per turn, and only if
##       you can afford its cost. Single-target moves ask you to click a
##       target when two enemies are up; WATER moves splash everyone at once.
##    3. Press End Turn (or run out of playable moves) — then EVERY living
##       enemy takes a swing at you. BLOCK soaks damage before HP does.
##    4. Repeat until one side is puddle goo.
##  Winning gives XP for every enemy beaten (maybe a LEVEL UP!) and a
##  pick-1-of-3 new move. Losing ends the run.
##
##  All the NUMBERS (damage, costs, multipliers) come from moves.gd and the
##  enemy stats dictionaries — this file is the referee, not the rulebook.
##
##  HOW THE OVERWORLD USES IT:
##      var battle := BattleScene.instantiate()
##      battle.setup([enemy.stats])            # a LIST — duos pass two!
##      add_child(battle)
##      battle.finished.connect(...)           # true = won, false = lost
## ============================================================================

signal finished(won: bool)

const MoveLearnPanelScene := preload("res://scenes/move_learn_panel.tscn")

# How hard a hit can randomly swing: every hit is multiplied by a random
# number between these two, so battles never feel like a spreadsheet.
const DAMAGE_WIGGLE_LOW := 0.85
const DAMAGE_WIGGLE_HIGH := 1.15

# Where fighters stand: one enemy gets center stage, a duo spreads out.
const GOOPZZ_HOME := Vector2(350, 400)
const ENEMY_SLOTS_SOLO: Array = [Vector2(930, 235)]
const ENEMY_SLOTS_DUO: Array = [Vector2(830, 205), Vector2(1080, 300)]

# ------------------------- battle state -------------------------
var enemies: Array = []            # one stats dictionary per enemy slime
var player_attack_bonus := 0       # from Battle Cry / Rebel Yell
var player_block := 0              # soaks damage until your next turn
var gels_left := 0
var moves_used_this_turn: Array = []
var moves_used_this_battle: Array = []  # for "once_per_battle" moves
var busy := true                   # true while animations play (input locked)
var awaiting_target := false       # true while we wait for a target click
var pending_move_id := ""

# ------------------------- UI pieces -------------------------
var goopzz_sprite: Sprite2D
var sword_sprite: Sprite2D
var message_label: Label
var player_name_label: Label
var player_block_label: Label
var player_hp_bar: ProgressBar
var player_hp_text: Label
var enemy_homes: Array = []
var enemy_sprites: Array = []
var enemy_name_labels: Array = []
var enemy_hp_bars: Array = []
var enemy_hp_texts: Array = []
var intent_labels: Array = []      # "Next: Chomp 11-15" floating over enemies
var target_buttons: Array = []
var move_buttons: Array = []
var gel_pips: Array = []
var end_turn_button: Button
var cancel_target_button: Button


## Called by overworld.gd BEFORE add_child. Takes a LIST of enemy stat
## dictionaries — one entry for a normal fight, two for a duo.
func setup(enemy_list: Array) -> void:
	enemies = []
	for stats in enemy_list:
		# duplicate(true) = our own copy; battle damage must not touch the
		# original until the fight is decided.
		var copy: Dictionary = stats.duplicate(true)
		copy["atk_bonus"] = 0  # War Cry raises it, Sand Throw lowers it
		enemies.append(copy)


func _ready() -> void:
	# The whole battle keeps running while the overworld underneath is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10  # draw on top of the overworld HUD

	# Safety net: pressing F6 on battle.tscn alone spawns a practice duo.
	if enemies.is_empty():
		setup([RunManager.make_enemy_stats(1), RunManager.make_enemy_stats(1)])

	_build_ui()
	_begin_battle()


# ============================ building the screen ============================

func _build_ui() -> void:
	# Dim the overworld behind us.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# The battle arena panel.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12)
	style.set_corner_radius_all(18)
	style.border_color = Color(0.18, 0.65, 0.35)
	style.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(70, 40)
	panel.size = Vector2(1140, 620)
	add_child(panel)

	# Isaac's beach scene (sand meeting green) as the arena backdrop.
	var backdrop := TextureRect.new()
	backdrop.texture = SpritePaths.tex("beach_scene")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.position = Vector2(80, 50)
	backdrop.size = Vector2(1120, 600)
	backdrop.modulate = Color(0.75, 0.75, 0.75)  # dimmed so the UI pops
	add_child(backdrop)

	# --- the enemies (one or two) ---
	var slots: Array = ENEMY_SLOTS_SOLO if enemies.size() == 1 else ENEMY_SLOTS_DUO
	var base_scale := 0.33 if enemies.size() == 1 else 0.30
	enemy_homes = []
	for i in enemies.size():
		var home: Vector2 = slots[mini(i, slots.size() - 1)]
		enemy_homes.append(home)

		var sprite := Sprite2D.new()
		sprite.texture = SpritePaths.tex("enemy_slime")
		sprite.scale = Vector2.ONE * base_scale * float(enemies[i].get("sprite_scale", 1.0))
		sprite.position = home
		add_child(sprite)
		enemy_sprites.append(sprite)

		# Info row (top-left, stacked when there are two enemies).
		var row_y := 75 + i * 58
		var name_label := UiHelpers.label("", 20)
		name_label.position = Vector2(110, row_y)
		add_child(name_label)
		enemy_name_labels.append(name_label)

		var hp_bar := UiHelpers.styled_bar(Color(0.85, 0.25, 0.25), Vector2(300, 18))
		hp_bar.position = Vector2(110, row_y + 30)
		add_child(hp_bar)
		enemy_hp_bars.append(hp_bar)

		var hp_text := UiHelpers.label("", 15)
		hp_text.position = Vector2(420, row_y + 26)
		add_child(hp_text)
		enemy_hp_texts.append(hp_text)

		# Invisible-ish button over the sprite, shown only while targeting.
		var target := Button.new()
		target.size = Vector2(200, 180)
		target.position = home - Vector2(100, 90)
		var target_style := StyleBoxFlat.new()
		target_style.bg_color = Color(1.0, 0.95, 0.4, 0.10)
		target_style.border_color = Color(1.0, 0.9, 0.3)
		target_style.set_border_width_all(3)
		target_style.set_corner_radius_all(16)
		target.add_theme_stylebox_override("normal", target_style)
		var target_hover := target_style.duplicate()
		target_hover.bg_color = Color(1.0, 0.95, 0.4, 0.25)
		target.add_theme_stylebox_override("hover", target_hover)
		target.add_theme_stylebox_override("pressed", target_hover.duplicate())
		target.add_theme_stylebox_override("focus", target_hover.duplicate())
		target.visible = false
		target.pressed.connect(_on_target_chosen.bind(i))
		add_child(target)
		target_buttons.append(target)

		# The INTENT label: this slime announces its next move up here, with
		# the same honest numbers the player's buttons get. No surprises.
		var intent_label := UiHelpers.label("", 15, Color(1.0, 0.95, 0.6))
		intent_label.custom_minimum_size = Vector2(240, 0)
		intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var half_height := 256.0 * base_scale * float(enemies[i].get("sprite_scale", 1.0))
		intent_label.position = home - Vector2(120, half_height + 46)
		add_child(intent_label)
		intent_labels.append(intent_label)

	# --- Goopzz ---
	goopzz_sprite = Sprite2D.new()
	goopzz_sprite.texture = SpritePaths.tex("goopzz")
	goopzz_sprite.scale = Vector2.ONE * 0.28  # v2 art is 1024px
	goopzz_sprite.position = GOOPZZ_HOME
	add_child(goopzz_sprite)

	# Goopzz's sword — hidden until a sword move flies it at an enemy.
	sword_sprite = Sprite2D.new()
	sword_sprite.texture = SpritePaths.tex("sword")
	sword_sprite.scale = Vector2.ONE * 0.28
	sword_sprite.position = GOOPZZ_HOME
	sword_sprite.visible = false
	add_child(sword_sprite)

	# --- player info (bottom-left) ---
	player_name_label = UiHelpers.label("", 22)
	player_name_label.position = Vector2(110, 462)
	add_child(player_name_label)

	player_block_label = UiHelpers.label("", 18, Color(0.5, 0.9, 1.0))
	player_block_label.position = Vector2(430, 464)
	add_child(player_block_label)

	player_hp_bar = UiHelpers.styled_bar(Color(0.2, 0.8, 0.4), Vector2(300, 20))
	player_hp_bar.position = Vector2(110, 497)
	add_child(player_hp_bar)

	player_hp_text = UiHelpers.label("", 16)
	player_hp_text.position = Vector2(420, 493)
	add_child(player_hp_text)

	# --- message line ("Goopzz used Bonk!") ---
	message_label = UiHelpers.label("", 19, Color(1.0, 1.0, 0.9))
	message_label.position = Vector2(110, 540)
	message_label.custom_minimum_size = Vector2(520, 100)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message_label)

	# Cancel button for when you change your mind mid-targeting.
	cancel_target_button = UiHelpers.styled_button("Cancel", Color(0.35, 0.35, 0.4), 15)
	cancel_target_button.position = Vector2(540, 462)
	cancel_target_button.visible = false
	cancel_target_button.pressed.connect(_on_cancel_target)
	add_child(cancel_target_button)

	# --- gel pips: your energy for this turn ---
	var gel_title := UiHelpers.label("GELS", 16, Color(0.6, 1.0, 0.8))
	gel_title.position = Vector2(660, 444)
	add_child(gel_title)
	for i in Moves.GELS_PER_TURN:
		var pip := Panel.new()
		var pip_style := StyleBoxFlat.new()
		pip_style.bg_color = Color(0.3, 0.9, 0.5)
		pip_style.set_corner_radius_all(13)  # a circle (the panel is 26x26)
		pip.add_theme_stylebox_override("panel", pip_style)
		pip.size = Vector2(26, 26)
		pip.position = Vector2(730 + i * 34, 442)
		add_child(pip)
		gel_pips.append(pip)

	# --- End Turn ---
	end_turn_button = UiHelpers.styled_button("End Turn", Color(0.7, 0.35, 0.25), 18)
	end_turn_button.position = Vector2(1000, 436)
	end_turn_button.custom_minimum_size = Vector2(170, 40)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)

	# --- the four move buttons (bottom-right) ---
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(660, 484)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)

	move_buttons.clear()
	for slot in RunManager.loadout.size():
		var move_id: String = RunManager.loadout[slot]
		var move := Moves.get_move(move_id)
		var button := UiHelpers.styled_button("", Moves.type_color(move.type), 15)
		button.custom_minimum_size = Vector2(250, 62)
		button.tooltip_text = str(move.get("description", ""))
		button.pressed.connect(_on_move_pressed.bind(move_id))
		grid.add_child(button)
		move_buttons.append(button)

	_update_move_buttons()
	_refresh_ui()


# ============================ live UI updates ============================

## What one damaging move would REALLY do, before the random wiggle:
## (power + attacker's attack) x type multiplier, as a (lowest, highest) pair.
## Used for the player's buttons AND the enemies' intent labels.
func _move_damage_range(move: Dictionary, attacker_attack: int) -> Vector2i:
	var base := float(int(move.get("power", 0)) + attacker_attack)
	base *= float(Moves.TYPE_MULTIPLIER.get(move.get("type", "slime"), 1.0))
	return Vector2i(
		maxi(1, int(round(base * DAMAGE_WIGGLE_LOW))),
		maxi(1, int(round(base * DAMAGE_WIGGLE_HIGH)))
	)


## The player's version — includes Goopzz's attack and any buffs.
func _damage_range(move: Dictionary) -> Vector2i:
	return _move_damage_range(move, RunManager.player_attack + player_attack_bonus)


## Two lines per button: "1. Sword Slash [2 gel]" then what it will actually
## do THIS turn. Re-run whenever gels/attack change, so buttons never lie.
## Also greys out anything used this turn or too expensive right now.
func _update_move_buttons() -> void:
	for slot in move_buttons.size():
		if slot >= RunManager.loadout.size():
			continue
		var move_id: String = RunManager.loadout[slot]
		var move := Moves.get_move(move_id)
		var cost := int(move.get("cost", 1))
		var detail := str(move.type)
		match move.get("effect", "damage"):
			"damage":
				var hit := _damage_range(move)
				detail += " · %d-%d dmg" % [hit.x, hit.y]
				if move.get("type", "") == "water":
					detail += " to ALL"
			"multi_hit":
				var hit := _damage_range(move)
				detail += " · %d-%d dmg x%d hits" % [hit.x, hit.y, int(move.get("hits", 2))]
			"damage_recoil":
				var hit := _damage_range(move)
				detail += " · %d-%d dmg, %d recoil" % [hit.x, hit.y, int(move.get("recoil", 0))]
			"damage_lifesteal":
				var hit := _damage_range(move)
				detail += " · %d-%d dmg, heal half back" % [hit.x, hit.y]
			"heal":
				detail += " · heal %d HP" % int(move.get("power", 0))
			"block":
				detail += " · block %d dmg" % int(move.get("power", 0))
			"heal_block":
				detail += " · heal %d + block %d" % [int(move.get("power", 0)), int(move.get("power", 0))]
			"buff_attack":
				detail += " · your attack +%d" % int(move.get("power", 0))
			"debuff_attack":
				detail += " · ALL enemies attack -%d" % int(move.get("power", 0))
		var cost_tag := "%d gel" % cost
		if move.get("once_per_battle", false):
			cost_tag += ", 1x"
			if moves_used_this_battle.has(move_id):
				detail = "already used this battle!"
		move_buttons[slot].text = "%d. %s  [%s]\n%s" % [slot + 1, move.name, cost_tag, detail]
		move_buttons[slot].disabled = busy or not _move_is_playable(move_id)


## Can this move be used right now? (not used up, and affordable)
func _move_is_playable(move_id: String) -> bool:
	var move := Moves.get_move(move_id)
	if moves_used_this_turn.has(move_id):
		return false
	if move.get("once_per_battle", false) and moves_used_this_battle.has(move_id):
		return false
	return int(move.get("cost", 1)) <= gels_left


func _any_move_playable() -> bool:
	for move_id in RunManager.loadout:
		if _move_is_playable(move_id):
			return true
	return false


func _refresh_ui() -> void:
	# Player side.
	player_hp_bar.max_value = RunManager.player_max_hp
	player_hp_bar.value = RunManager.player_hp
	player_hp_text.text = "%d / %d" % [RunManager.player_hp, RunManager.player_max_hp]
	player_name_label.text = "Goopzz  Lv %d  ·  ATK %d" % [
		RunManager.player_level, RunManager.player_attack + player_attack_bonus,
	]
	player_block_label.text = "BLOCK %d" % player_block if player_block > 0 else ""

	# Gel pips: bright = still yours to spend, dark = spent.
	for i in gel_pips.size():
		var pip_style: StyleBoxFlat = gel_pips[i].get_theme_stylebox("panel")
		pip_style.bg_color = Color(0.3, 0.9, 0.5) if i < gels_left else Color(0.15, 0.25, 0.18)

	# Enemy side — every enemy shows live HP and ATK; the fallen go dark.
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		enemy_hp_bars[i].max_value = enemy.get("max_hp", 1)
		enemy_hp_bars[i].value = enemy.get("hp", 0)
		enemy_hp_texts[i].text = "%d / %d" % [enemy.get("hp", 0), enemy.get("max_hp", 1)]
		enemy_name_labels[i].text = "%s  Lv %d  ·  ATK %d" % [
			enemy.get("name", "???"), enemy.get("level", 1),
			maxi(0, int(enemy.get("attack", 0)) + int(enemy.get("atk_bonus", 0))),
		]
		if int(enemy.get("hp", 0)) <= 0:
			enemy_name_labels[i].modulate = Color(1, 1, 1, 0.4)
			enemy_hp_texts[i].text = "puddle'd"
	_refresh_intent_labels()


## Redraw every enemy's "Next: ..." label from its declared intent. Rendered
## fresh each refresh so the numbers stay honest — if you Sandstorm them,
## the announced damage drops right away.
func _refresh_intent_labels() -> void:
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		var intent_id: String = str(enemy.get("intent_id", ""))
		if int(enemy.get("hp", 0)) <= 0 or intent_id == "":
			intent_labels[i].text = ""
			continue
		var move := Moves.get_move(intent_id)
		if move.get("effect", "damage") == "buff_attack":
			intent_labels[i].text = "Next: %s — powering up!" % move.name
		else:
			var attack: int = maxi(0, int(enemy.get("attack", 0)) + int(enemy.get("atk_bonus", 0)))
			var hit := _move_damage_range(move, attack)
			intent_labels[i].text = "Next: %s %d-%d" % [move.name, hit.x, hit.y]


## Every living enemy picks (and announces) its next move. Called at the
## start of the player's turn — that's what makes block a smart choice
## instead of a guess.
func _declare_intents() -> void:
	for i in _alive_indexes():
		enemies[i]["intent_id"] = enemies[i].moves.pick_random()
	_refresh_intent_labels()


func _say(text: String) -> void:
	message_label.text = text


# ============================ helpers ============================

func _alive_indexes() -> Array:
	var alive: Array = []
	for i in enemies.size():
		if int(enemies[i].get("hp", 0)) > 0:
			alive.append(i)
	return alive


## Does this move need the player to pick WHICH enemy? (single-target attacks
## when more than one enemy is standing — water hits everyone automatically)
func _needs_target_choice(move: Dictionary) -> bool:
	var is_attack: bool = move.get("effect", "damage") in ["damage", "multi_hit", "damage_recoil"]
	return is_attack and move.get("type", "") != "water" and _alive_indexes().size() > 1


# ============================ the turn loop ============================

func _begin_battle() -> void:
	busy = true
	end_turn_button.disabled = true
	_update_move_buttons()
	var enemy_names: Array = []
	for enemy in enemies:
		enemy_names.append(enemy.get("name", "???"))
	if enemies.size() > 1:
		_say("Uh oh — %s brought a pal! Two against one!" % " & ".join(enemy_names))
	elif enemies[0].get("is_boss", false):
		_say("%s blocks the way!\n\"This land belongs to the invasion now!\"" % enemy_names[0])
	else:
		_say("A wild %s wobbles closer!" % enemy_names[0])
	await _wait(1.2)
	_begin_player_turn()


func _begin_player_turn() -> void:
	player_block = 0  # yesterday's goo wall melts at sunrise
	gels_left = Moves.GELS_PER_TURN
	moves_used_this_turn = []
	_declare_intents()  # enemies announce their plans — read them!
	busy = false
	end_turn_button.disabled = false
	_update_move_buttons()
	_refresh_ui()
	_say("Your turn! %d gels — each move once. End Turn when done." % gels_left)


## Lock or unlock the controls mid-turn (while an animation plays).
func _set_controls_locked(locked: bool) -> void:
	busy = locked
	end_turn_button.disabled = locked
	_update_move_buttons()


## Keyboard shortcuts: 1-4 = moves, or 1-2 = pick a target while targeting.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var index := -1
	match event.keycode:
		KEY_1: index = 0
		KEY_2: index = 1
		KEY_3: index = 2
		KEY_4: index = 3
	if index < 0:
		return
	if awaiting_target:
		if index < enemies.size() and _alive_indexes().has(index):
			_on_target_chosen(index)
	elif not busy and index < RunManager.loadout.size():
		_on_move_pressed(RunManager.loadout[index])


func _on_move_pressed(move_id: String) -> void:
	if busy or awaiting_target or not _move_is_playable(move_id):
		return
	var move := Moves.get_move(move_id)
	if _needs_target_choice(move):
		# Wait for the player to click one of the enemies.
		pending_move_id = move_id
		awaiting_target = true
		for i in _alive_indexes():
			target_buttons[i].visible = true
		cancel_target_button.visible = true
		_say("%s — on WHICH slime? Click one! (or press 1/2)" % move.name)
		return
	var targets := _alive_indexes()
	await _play_move(move_id, targets[0] if targets.size() > 0 else 0)


func _on_target_chosen(index: int) -> void:
	if not awaiting_target:
		return
	awaiting_target = false
	_hide_target_buttons()
	await _play_move(pending_move_id, index)


func _on_cancel_target() -> void:
	awaiting_target = false
	pending_move_id = ""
	_hide_target_buttons()
	_say("Okay, pick a different move — %d gels left." % gels_left)


func _hide_target_buttons() -> void:
	for button in target_buttons:
		button.visible = false
	cancel_target_button.visible = false


func _on_end_turn_pressed() -> void:
	if busy or awaiting_target:
		return
	await _enemy_phase()


# ============================ player's moves ============================

func _play_move(move_id: String, target_index: int) -> void:
	_set_controls_locked(true)
	var move := Moves.get_move(move_id)
	gels_left -= int(move.get("cost", 1))
	moves_used_this_turn.append(move_id)
	moves_used_this_battle.append(move_id)
	_refresh_ui()

	_say("Goopzz used %s!" % move.name)
	goopzz_sprite.texture = SpritePaths.tex("goopzz_angry")  # game face ON

	# Little lunge so the move feels physical.
	var lunge := create_tween()
	lunge.tween_property(goopzz_sprite, "position", GOOPZZ_HOME + Vector2(60, -30), 0.18)
	lunge.tween_property(goopzz_sprite, "position", GOOPZZ_HOME, 0.22)

	if move.type == "sword":
		await _animate_sword_throw(target_index)
	else:
		await _wait(0.5)

	match move.get("effect", "damage"):
		"damage":
			if move.get("type", "") == "water":
				# Water's superpower: it splashes EVERYBODY.
				for i in _alive_indexes():
					await _hit_enemy(move, i)
					await _wait(0.2)
			else:
				await _hit_enemy(move, target_index)
		"multi_hit":
			for _hit_number in int(move.get("hits", 2)):
				await _hit_enemy(move, target_index)
				await _wait(0.25)
		"damage_recoil":
			await _hit_enemy(move, target_index)
			var recoil := int(move.get("recoil", 0))
			# Recoil is Goopzz bonking himself — block can't help with that.
			RunManager.player_hp = maxi(0, RunManager.player_hp - recoil)
			_say("Whoa — dizzy! Goopzz took %d recoil damage." % recoil)
			await _flash(goopzz_sprite)
		"damage_lifesteal":
			var dealt: int = await _hit_enemy(move, target_index)
			var slurped := mini(int(ceil(dealt / 2.0)),
				RunManager.player_max_hp - RunManager.player_hp)
			RunManager.player_hp += slurped
			_say("Slurp! Goopzz drank back %d HP!" % slurped)
			await _sparkle(goopzz_sprite)
		"heal":
			var healed := mini(int(move.get("power", 0)),
				RunManager.player_max_hp - RunManager.player_hp)
			RunManager.player_hp += healed
			_say("Goopzz recovered %d HP!" % healed)
			await _sparkle(goopzz_sprite)
		"block":
			player_block += int(move.get("power", 0))
			_say("Goopzz puffed up! BLOCK %d — it soaks hits until your next turn." % player_block)
			await _sparkle(goopzz_sprite)
		"heal_block":
			var amount := int(move.get("power", 0))
			var patched := mini(amount, RunManager.player_max_hp - RunManager.player_hp)
			RunManager.player_hp += patched
			player_block += amount
			_say("Tuck and roll! +%d HP and BLOCK %d." % [patched, player_block])
			await _sparkle(goopzz_sprite)
		"buff_attack":
			player_attack_bonus += int(move.get("power", 0))
			_say("BLORP! Goopzz's attack rose by %d!" % int(move.get("power", 0)))
			await _sparkle(goopzz_sprite)
		"debuff_attack":
			for i in _alive_indexes():
				enemies[i].atk_bonus = int(enemies[i].atk_bonus) - int(move.get("power", 0))
			_say("Sand everywhere! EVERY enemy's attack fell by %d!" % int(move.get("power", 0)))
			for i in _alive_indexes():
				await _flash(enemy_sprites[i])

	goopzz_sprite.texture = SpritePaths.tex("goopzz")
	_refresh_ui()
	await _wait(0.4)

	# Everyone down? Victory. Nothing left to play? Turn ends by itself.
	if _alive_indexes().is_empty():
		await _win_flow()
		return
	if RunManager.player_hp <= 0:  # Sword Spin recoil can end a run!
		await _lose_flow()
		return
	if not _any_move_playable():
		_say("Out of gels — the enemies take their turn!")
		await _wait(0.8)
		await _enemy_phase()
		return
	_set_controls_locked(false)
	_say("%d gel%s left — keep going, or End Turn." % [gels_left, "" if gels_left == 1 else "s"])


## One damaging hit against one enemy, with flash + shake + weakness quips.
## Returns the damage dealt (Slurp Slash heals from it).
func _hit_enemy(move: Dictionary, index: int) -> int:
	var enemy: Dictionary = enemies[index]
	var damage := _calc_damage(move, RunManager.player_attack + player_attack_bonus)
	enemy.hp = maxi(0, int(enemy.hp) - damage)
	_refresh_ui()
	var quip := ""
	if move.type == "sword":
		quip = " Slimes HATE swords!"
	elif move.type == "water":
		quip = " Sploosh!"
	_say("It hit %s for %d damage!%s" % [enemy.get("name", "???"), damage, quip])
	await _flash(enemy_sprites[index])
	if int(enemy.hp) <= 0:
		await _melt_enemy(index)
	return damage


## A beaten slime dramatically dissolves into puddle goo.
func _melt_enemy(index: int) -> void:
	_say("%s dissolved into puddle goo!" % enemies[index].get("name", "???"))
	var sprite: Sprite2D = enemy_sprites[index]
	var melt := create_tween()
	melt.tween_property(sprite, "scale", sprite.scale * Vector2(1.4, 0.05), 0.5)
	melt.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	await melt.finished
	_refresh_ui()


# ============================ enemies' turn ============================

func _enemy_phase() -> void:
	_set_controls_locked(true)
	for i in _alive_indexes():
		await _do_enemy_move(i)
		if RunManager.player_hp <= 0:
			await _lose_flow()
			return
		await _wait(0.3)
	_begin_player_turn()


func _do_enemy_move(index: int) -> void:
	var enemy: Dictionary = enemies[index]
	# Do exactly what was announced (falling back to random just in case).
	var intent_id: String = str(enemy.get("intent_id", ""))
	if intent_id == "":
		intent_id = enemy.moves.pick_random()
	var move := Moves.get_move(intent_id)
	enemy["intent_id"] = ""  # promise fulfilled — label clears on refresh
	_say("%s used %s!" % [enemy.get("name", "???"), move.name])
	var sprite: Sprite2D = enemy_sprites[index]
	sprite.texture = SpritePaths.tex("enemy_slime_attacking")

	var home: Vector2 = enemy_homes[index]
	var lunge := create_tween()
	lunge.tween_property(sprite, "position", home + Vector2(-60, 40), 0.18)
	lunge.tween_property(sprite, "position", home, 0.22)
	await _wait(0.5)

	match move.get("effect", "damage"):
		"damage":
			var attack: int = maxi(0, int(enemy.attack) + int(enemy.atk_bonus))
			var damage := _calc_damage(move, attack)
			# BLOCK soaks damage before HP does.
			var absorbed: int = mini(player_block, damage)
			player_block -= absorbed
			var got_through: int = damage - absorbed
			RunManager.player_hp = maxi(0, RunManager.player_hp - got_through)
			if absorbed > 0 and got_through == 0:
				_say("Goopzz's goo block soaked ALL %d damage!" % damage)
			elif absorbed > 0:
				_say("Block soaked %d — but %d got through!" % [absorbed, got_through])
			else:
				_say("Ouch! Goopzz took %d damage!" % damage)
			goopzz_sprite.texture = SpritePaths.tex("goopzz_angry")
			await _flash(goopzz_sprite)
			goopzz_sprite.texture = SpritePaths.tex("goopzz")
		"buff_attack":
			enemy.atk_bonus = int(enemy.atk_bonus) + int(move.get("power", 0))
			_say("%s is getting angrier! Its attack rose!" % enemy.get("name", "???"))
			await _sparkle(sprite)

	sprite.texture = SpritePaths.tex("enemy_slime")
	_refresh_ui()
	await _wait(0.35)


# ============================ the math ============================

## THE damage formula. Small on purpose:
##   (move power + attacker's attack) x type multiplier x random wiggle.
## Never less than 1. (Block is applied by whoever receives the hit.)
func _calc_damage(move: Dictionary, attacker_attack: int) -> int:
	var amount := float(int(move.get("power", 0)) + attacker_attack)
	amount *= float(Moves.TYPE_MULTIPLIER.get(move.get("type", "slime"), 1.0))
	amount *= randf_range(DAMAGE_WIGGLE_LOW, DAMAGE_WIGGLE_HIGH)
	return maxi(1, int(round(amount)))


# ============================ endings ============================

func _win_flow() -> void:
	_say("Victory! The beach is a little safer now." if enemies.size() == 1
		else "Victory! BOTH invaders are puddles now.")
	await _wait(0.9)

	# XP for every enemy beaten, and maybe a level up.
	var xp := 0
	for enemy in enemies:
		xp += int(enemy.get("xp", 10))
	var levels_gained := RunManager.add_xp(xp)
	_say("Goopzz gained %d XP!" % xp)
	await _wait(0.9)
	if levels_gained > 0:
		_say("LEVEL UP! Goopzz is now Lv %d! (+%d max HP, +%d attack)" % [
			RunManager.player_level,
			RunManager.LEVEL_UP_HP_BONUS * levels_gained,
			RunManager.LEVEL_UP_ATTACK_BONUS * levels_gained,
		])
		await _sparkle(goopzz_sprite)
		_refresh_ui()
		await _wait(1.1)

	# The Slay-the-Spire moment: pick 1 of 3 new moves.
	var choices := Moves.random_reward_choices(3, RunManager.loadout)
	if choices.size() > 0:
		var panel: MoveLearnPanel = MoveLearnPanelScene.instantiate()
		panel.open(choices, "Victory! Pick a new move:")
		add_child(panel)
		await panel.closed

	RunManager.battles_won += 1
	finished.emit(true)
	queue_free()


func _lose_flow() -> void:
	_refresh_ui()
	_say("Goopzz was splattered... The run is over!")
	var melt := create_tween()
	melt.tween_property(goopzz_sprite, "scale", goopzz_sprite.scale * Vector2(1.4, 0.05), 0.8)
	melt.parallel().tween_property(goopzz_sprite, "modulate:a", 0.2, 0.8)
	await _wait(1.6)
	finished.emit(false)
	queue_free()


# ============================ little animations ============================

## Waits even while the game tree is paused (battles run on top of a pause).
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Red flash + shake = "that hurt".
func _flash(sprite: Sprite2D) -> void:
	var home := sprite.position
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.35, 0.35), 0.08)
	tween.tween_property(sprite, "position", home + Vector2(14, 0), 0.05)
	tween.tween_property(sprite, "position", home - Vector2(14, 0), 0.05)
	tween.tween_property(sprite, "position", home, 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	await tween.finished


## Happy bounce = something good happened (heal, block, buff).
func _sparkle(sprite: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.4, 1.4, 1.1), 0.15)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	await tween.finished


## Goopzz's wooden sword spins across the screen into the chosen enemy.
func _animate_sword_throw(target_index: int) -> void:
	sword_sprite.visible = true
	sword_sprite.position = GOOPZZ_HOME
	sword_sprite.rotation = 0.0
	var target: Vector2 = enemy_homes[clampi(target_index, 0, enemy_homes.size() - 1)]
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sword_sprite, "position", target, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sword_sprite, "rotation", TAU * 2.0, 0.45)
	await tween.finished
	sword_sprite.visible = false
