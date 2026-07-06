class_name BattleScreen
extends CanvasLayer
## ============================================================================
##  Battle — the Pokemon-style battle screen.
## ----------------------------------------------------------------------------
##  Touching an enemy in the overworld opens this on top of the (paused)
##  world. Turns go:
##      you pick one of your 4 moves  →  it happens (with wiggles and flashes)
##      →  the enemy picks a move  →  it happens  →  back to you.
##  First slime to hit 0 HP dissolves. Winning gives XP (maybe a LEVEL UP!)
##  and a pick-1-of-3 new move reward. Losing ends the run.
##
##  All the NUMBERS (damage, multipliers) come from moves.gd and the enemy
##  stats dictionary — this file is the referee, not the rulebook.
##
##  HOW THE OVERWORLD USES IT:
##      var battle := BattleScene.instantiate()
##      battle.setup(enemy.stats)      # BEFORE add_child!
##      add_child(battle)
##      battle.finished.connect(...)   # tells you true (won) / false (lost)
## ============================================================================

signal finished(won: bool)

const MoveLearnPanelScene := preload("res://scenes/move_learn_panel.tscn")

# How hard a hit can randomly swing: every hit is multiplied by a random
# number between these two, so battles never feel like a spreadsheet.
const DAMAGE_WIGGLE_LOW := 0.85
const DAMAGE_WIGGLE_HIGH := 1.15

# ------------------------- battle state -------------------------
var enemy_stats: Dictionary = {}
var player_shielded := false      # Goo Shield is up → next hit halved
var player_attack_bonus := 0      # from Battle Cry
var enemy_attack_bonus := 0       # from War Cry (goes negative from Sand Throw)
var busy := true                  # true while animations play (buttons locked)

# ------------------------- UI pieces -------------------------
var goopzz_sprite: Sprite2D
var enemy_sprite: Sprite2D
var sword_sprite: Sprite2D
var message_label: Label
var player_hp_bar: ProgressBar
var player_hp_text: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_text: Label
var move_buttons: Array = []

var goopzz_home := Vector2(350, 400)   # where Goopzz stands on the stage
var enemy_home := Vector2(930, 230)    # where the enemy stands


## Called by overworld.gd BEFORE add_child, so _ready can build around it.
func setup(stats: Dictionary) -> void:
	# duplicate(true) = our own copy; battle damage must not touch the
	# original until the fight is decided.
	enemy_stats = stats.duplicate(true)


func _ready() -> void:
	# The whole battle keeps running while the overworld underneath is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10  # draw on top of the overworld HUD

	# Safety net: pressing F6 on battle.tscn alone spawns a practice dummy.
	if enemy_stats.is_empty():
		enemy_stats = RunManager.make_enemy_stats(1)

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

	# --- the two fighters ---
	var enemy_scale: float = enemy_stats.get("sprite_scale", 1.0)
	enemy_sprite = Sprite2D.new()
	enemy_sprite.texture = SpritePaths.tex("enemy_slime")
	enemy_sprite.scale = Vector2.ONE * 0.33 * enemy_scale
	enemy_sprite.position = enemy_home
	add_child(enemy_sprite)

	goopzz_sprite = Sprite2D.new()
	goopzz_sprite.texture = SpritePaths.tex("goopzz")
	goopzz_sprite.scale = Vector2.ONE * 0.35
	goopzz_sprite.position = goopzz_home
	add_child(goopzz_sprite)

	# Goopzz's sword — hidden until a sword move flies it at the enemy.
	sword_sprite = Sprite2D.new()
	sword_sprite.texture = SpritePaths.tex("sword")
	sword_sprite.scale = Vector2.ONE * 0.28
	sword_sprite.position = goopzz_home
	sword_sprite.visible = false
	add_child(sword_sprite)

	# --- enemy info (top-left, like Pokemon) ---
	var enemy_name := UiHelpers.label(
		"%s  Lv %d" % [enemy_stats.get("name", "???"), enemy_stats.get("level", 1)], 22
	)
	enemy_name.position = Vector2(110, 75)
	add_child(enemy_name)

	enemy_hp_bar = UiHelpers.styled_bar(Color(0.85, 0.25, 0.25), Vector2(300, 20))
	enemy_hp_bar.position = Vector2(110, 110)
	add_child(enemy_hp_bar)

	enemy_hp_text = UiHelpers.label("", 16)
	enemy_hp_text.position = Vector2(420, 106)
	add_child(enemy_hp_text)

	# --- player info (bottom-left) ---
	var player_name := UiHelpers.label("Goopzz  Lv %d" % RunManager.player_level, 22)
	player_name.position = Vector2(110, 462)
	add_child(player_name)

	player_hp_bar = UiHelpers.styled_bar(Color(0.2, 0.8, 0.4), Vector2(300, 20))
	player_hp_bar.position = Vector2(110, 497)
	add_child(player_hp_bar)

	player_hp_text = UiHelpers.label("", 16)
	player_hp_text.position = Vector2(420, 493)
	add_child(player_hp_text)

	# --- message line ("Goopzz used Bonk!") ---
	message_label = UiHelpers.label("", 20, Color(1.0, 1.0, 0.9))
	message_label.position = Vector2(110, 540)
	message_label.custom_minimum_size = Vector2(520, 100)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message_label)

	# --- the four move buttons (bottom-right) ---
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(660, 480)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)

	move_buttons.clear()
	for slot in RunManager.loadout.size():
		var move_id: String = RunManager.loadout[slot]
		var move := Moves.get_move(move_id)
		var text := "%d. %s" % [slot + 1, move.name]
		if move.get("effect", "") in ["damage", "multi_hit", "damage_recoil"]:
			text += "  (%d)" % int(move.get("power", 0))
		var button := UiHelpers.styled_button(text, Moves.type_color(move.type), 18)
		button.custom_minimum_size = Vector2(250, 62)
		button.tooltip_text = str(move.get("description", ""))
		button.pressed.connect(_on_move_pressed.bind(move_id))
		grid.add_child(button)
		move_buttons.append(button)

	_refresh_bars()


func _refresh_bars() -> void:
	player_hp_bar.max_value = RunManager.player_max_hp
	player_hp_bar.value = RunManager.player_hp
	player_hp_text.text = "%d / %d" % [RunManager.player_hp, RunManager.player_max_hp]
	enemy_hp_bar.max_value = enemy_stats.get("max_hp", 1)
	enemy_hp_bar.value = enemy_stats.get("hp", 0)
	enemy_hp_text.text = "%d / %d" % [enemy_stats.get("hp", 0), enemy_stats.get("max_hp", 1)]


func _say(text: String) -> void:
	message_label.text = text


func _set_buttons_enabled(enabled: bool) -> void:
	busy = not enabled
	for button in move_buttons:
		button.disabled = not enabled


# ============================ the turn loop ============================

func _begin_battle() -> void:
	_set_buttons_enabled(false)
	if enemy_stats.get("is_boss", false):
		_say("%s blocks the way!\n\"This beach belongs to the invasion now!\"" % enemy_stats.name)
	else:
		_say("A wild %s wobbles closer!" % enemy_stats.name)
	await _wait(1.1)
	_say("Pick a move! (click, or press 1–4)")
	_set_buttons_enabled(true)


## Keyboard shortcut: number keys 1-4 press the matching move button.
func _input(event: InputEvent) -> void:
	if busy or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var index := -1
	match event.keycode:
		KEY_1: index = 0
		KEY_2: index = 1
		KEY_3: index = 2
		KEY_4: index = 3
	if index >= 0 and index < RunManager.loadout.size():
		_on_move_pressed(RunManager.loadout[index])


func _on_move_pressed(move_id: String) -> void:
	if busy:
		return
	_set_buttons_enabled(false)
	await _do_player_move(move_id)
	if enemy_stats.hp <= 0:
		await _win_flow()
		return
	await _do_enemy_move()
	if RunManager.player_hp <= 0:
		await _lose_flow()
		return
	_say("Pick a move!")
	_set_buttons_enabled(true)


# ============================ player's turn ============================

func _do_player_move(move_id: String) -> void:
	var move := Moves.get_move(move_id)
	_say("Goopzz used %s!" % move.name)
	goopzz_sprite.texture = SpritePaths.tex("goopzz_angry")  # game face ON

	# Little lunge toward the enemy so the move feels physical.
	var lunge := create_tween()
	lunge.tween_property(goopzz_sprite, "position", goopzz_home + Vector2(60, -30), 0.18)
	lunge.tween_property(goopzz_sprite, "position", goopzz_home, 0.22)

	if move.type == "sword":
		await _animate_sword_throw()
	else:
		await _wait(0.5)

	match move.get("effect", "damage"):
		"damage":
			await _hit_enemy(move)
		"multi_hit":
			for _hit_number in int(move.get("hits", 2)):
				await _hit_enemy(move)
				await _wait(0.25)
		"damage_recoil":
			await _hit_enemy(move)
			var recoil := int(move.get("recoil", 0))
			RunManager.player_hp = maxi(0, RunManager.player_hp - recoil)
			_say("Whoa — dizzy! Goopzz took %d recoil damage." % recoil)
			await _flash(goopzz_sprite)
		"heal":
			var healed := mini(int(move.get("power", 0)),
				RunManager.player_max_hp - RunManager.player_hp)
			RunManager.player_hp += healed
			_say("Goopzz recovered %d HP!" % healed)
			await _sparkle(goopzz_sprite)
		"shield":
			player_shielded = true
			_say("Goopzz puffed up into a goo wall! The next hit will bounce off (half damage).")
			await _sparkle(goopzz_sprite)
		"buff_attack":
			player_attack_bonus += int(move.get("power", 0))
			_say("BLORP! Goopzz's attack rose by %d!" % int(move.get("power", 0)))
			await _sparkle(goopzz_sprite)
		"debuff_attack":
			enemy_attack_bonus -= int(move.get("power", 0))
			_say("Sand everywhere! %s's attack fell by %d!" % [enemy_stats.name, int(move.get("power", 0))])
			await _flash(enemy_sprite)

	goopzz_sprite.texture = SpritePaths.tex("goopzz")
	_refresh_bars()
	await _wait(0.55)


## One damaging hit against the enemy, with flash + shake + weakness quips.
func _hit_enemy(move: Dictionary) -> void:
	var damage := _calc_damage(move, RunManager.player_attack + player_attack_bonus, false)
	enemy_stats.hp = maxi(0, enemy_stats.hp - damage)
	_refresh_bars()
	var quip := ""
	if move.type == "sword":
		quip = " Slimes HATE swords!"
	elif move.type == "water":
		quip = " Sploosh! Super soggy!"
	_say("It hit %s for %d damage!%s" % [enemy_stats.name, damage, quip])
	await _flash(enemy_sprite)


# ============================ enemy's turn ============================

func _do_enemy_move() -> void:
	await _wait(0.35)
	var move := Moves.get_move(enemy_stats.moves.pick_random())
	_say("%s used %s!" % [enemy_stats.name, move.name])
	enemy_sprite.texture = SpritePaths.tex("enemy_slime_attacking")

	var lunge := create_tween()
	lunge.tween_property(enemy_sprite, "position", enemy_home + Vector2(-60, 40), 0.18)
	lunge.tween_property(enemy_sprite, "position", enemy_home, 0.22)
	await _wait(0.5)

	match move.get("effect", "damage"):
		"damage":
			var attack: int = maxi(0, enemy_stats.attack + enemy_attack_bonus)
			var damage := _calc_damage(move, attack, player_shielded)
			if player_shielded:
				player_shielded = false
				_say("Goo Shield softened the blow! Only %d damage." % damage)
			else:
				_say("Ouch! Goopzz took %d damage!" % damage)
			RunManager.player_hp = maxi(0, RunManager.player_hp - damage)
			goopzz_sprite.texture = SpritePaths.tex("goopzz_angry")
			await _flash(goopzz_sprite)
			goopzz_sprite.texture = SpritePaths.tex("goopzz")
		"buff_attack":
			enemy_attack_bonus += int(move.get("power", 0))
			_say("%s is getting angrier! Its attack rose!" % enemy_stats.name)
			await _sparkle(enemy_sprite)

	enemy_sprite.texture = SpritePaths.tex("enemy_slime")
	_refresh_bars()
	await _wait(0.45)


# ============================ the math ============================

## THE damage formula. Small on purpose:
##   (move power + attacker's attack) x type multiplier x random wiggle,
##   halved if the defender has a shield up. Never less than 1.
func _calc_damage(move: Dictionary, attacker_attack: int, defender_shielded: bool) -> int:
	var amount := float(int(move.get("power", 0)) + attacker_attack)
	amount *= float(Moves.TYPE_MULTIPLIER.get(move.get("type", "slime"), 1.0))
	amount *= randf_range(DAMAGE_WIGGLE_LOW, DAMAGE_WIGGLE_HIGH)
	if defender_shielded:
		amount *= 0.5
	return maxi(1, int(round(amount)))


# ============================ endings ============================

func _win_flow() -> void:
	_say("%s dissolved into puddle goo! Victory!" % enemy_stats.name)
	var melt := create_tween()
	melt.tween_property(enemy_sprite, "scale", enemy_sprite.scale * Vector2(1.4, 0.05), 0.6)
	melt.parallel().tween_property(enemy_sprite, "modulate:a", 0.0, 0.6)
	await _wait(1.0)

	# XP, and maybe a level up.
	var xp := int(enemy_stats.get("xp", 10))
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
		_refresh_bars()
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
	_refresh_bars()
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


## Happy bounce = something good happened (heal, shield, buff).
func _sparkle(sprite: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.4, 1.4, 1.1), 0.15)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	await tween.finished


## Goopzz's wooden sword spins across the screen into the enemy. Swords are
## SUPER effective — this animation is the reason why (well, that and lore).
func _animate_sword_throw() -> void:
	sword_sprite.visible = true
	sword_sprite.position = goopzz_home
	sword_sprite.rotation = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sword_sprite, "position", enemy_home, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sword_sprite, "rotation", TAU * 2.0, 0.45)
	await tween.finished
	sword_sprite.visible = false
