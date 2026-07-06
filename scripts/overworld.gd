extends Node2D
## ============================================================================
##  Overworld — one beach room of the run.
## ----------------------------------------------------------------------------
##  This scene rebuilds itself every room: it reads the current room's recipe
##  from RunManager.ROOMS and spawns the sand, walls, water, rocks, enemies,
##  pickups, the exit door, Goopzz, and the HUD.
##
##  The room is exactly the size of Isaac's sand art (1920 x 1024). The black
##  band along the top of that art IS the room's top wall — you can see it,
##  Among-Us style, but you can't walk into it.
##
##  Flow of a room:
##    1. Fight (or run from) every slime — touching one starts a battle.
##    2. When all slimes are gone the red gate on the right unlocks.
##    3. Walk through the exit → next room (or VICTORY after the last one).
##  If Goopzz's HP hits zero — in battle or in the water — the run ends.
## ============================================================================

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const PickupScene := preload("res://scenes/pickup.tscn")
const BattleScene := preload("res://scenes/battle.tscn")
const MoveLearnPanelScene := preload("res://scenes/move_learn_panel.tscn")

const ROOM_SIZE := Vector2(1920, 1024)  # the size of Isaac's sand art
const TOP_WALL_HEIGHT := 258.0          # the black band at the top of that art
const BORDER := 26.0                    # thickness of the other three walls
const EXIT_RECT := Rect2(1856, 540, 64, 170)  # the gate in the right wall
const PLAYER_SPAWN := Vector2(200, 760)

## Which ground art each area uses (add new areas here — mountain, volcano...).
const AREA_BACKDROPS: Dictionary = {
	"beach": "beach_sand",
	"forest": "forest_ground",
}
## The beach art has its own painted black top wall. Other areas don't, so we
## paint one in this color (dark forest green for now).
const FOREST_TOP_WALL_COLOR := Color(0.07, 0.16, 0.09)

var player: Player
var enemies_left := 0
var exit_open := false
var battle_cooldown := 0.0    # grace period so battles don't chain instantly
var room_wall_rects: Array = []

# HUD pieces we refresh every frame.
var hud: CanvasLayer
var hp_bar: ProgressBar
var hp_text: Label
var attack_label: Label
var xp_bar: ProgressBar
var xp_text: Label
var name_label: Label
var guide: GuideSlime
var slimes_left_label: Label
var jump_bar: ProgressBar
var climb_bar: ProgressBar
var loadout_labels: Array = []
var toast_label: Label
var exit_gate: StaticBody2D
var exit_sign: Label


func _ready() -> void:
	# Never start a room frozen (pausing is how battles stop the world).
	get_tree().paused = false
	var config := RunManager.room_config()
	_build_backdrop(config)
	_build_borders()
	_build_climb_walls(config)   # before the player, so he gets the wall list
	_build_water(config)
	_build_exit()
	_build_player()
	_build_enemies(config)
	_build_pickups(config)
	_build_hud(config)
	_toast("Room %d/%d — %s" % [RunManager.current_room, RunManager.total_rooms(), config.title])


func _process(delta: float) -> void:
	battle_cooldown = maxf(0.0, battle_cooldown - delta)
	_refresh_hud()


# ============================ building the room ============================

func _build_backdrop(config: Dictionary) -> void:
	var area: String = config.get("area", "beach")
	var backdrop := Sprite2D.new()
	backdrop.texture = SpritePaths.tex(AREA_BACKDROPS.get(area, "beach_sand"))
	backdrop.centered = false  # its top-left corner is the room's (0, 0)
	# Stretch whatever size the art is to exactly fill the room.
	var texture_size := backdrop.texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		backdrop.scale = ROOM_SIZE / texture_size
	add_child(backdrop)

	# Beach art comes with its own painted top wall (the black band). For any
	# other area we paint the visible top wall ourselves, Among-Us style.
	if area != "beach":
		var top_wall := ColorRect.new()
		top_wall.color = FOREST_TOP_WALL_COLOR
		top_wall.size = Vector2(ROOM_SIZE.x, TOP_WALL_HEIGHT)
		top_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(top_wall)
		# A lighter strip along its base — the faux-3D "sunlit edge".
		var edge := ColorRect.new()
		edge.color = FOREST_TOP_WALL_COLOR.lightened(0.3)
		edge.position = Vector2(0, TOP_WALL_HEIGHT - 14)
		edge.size = Vector2(ROOM_SIZE.x, 14)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(edge)


## An invisible-or-colored solid rectangle. Used for borders and rock walls.
## `layer` picks the physics layer: 6 = solid border, 2 = climbable rock.
func _add_solid_rect(rect: Rect2, color: Color, layer: int, show_color: bool = true) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(layer, true)
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	if show_color:
		var visual := ColorRect.new()
		visual.color = color
		visual.size = rect.size
		visual.position = -rect.size / 2.0
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(visual)
	add_child(body)
	return body


func _build_borders() -> void:
	var black := Color(0.05, 0.05, 0.05)
	# Top wall: the black band Isaac painted — collision only, no extra visual.
	_add_solid_rect(Rect2(0, 0, ROOM_SIZE.x, TOP_WALL_HEIGHT), black, 6, false)
	# Left, bottom, and right walls (the right one leaves a gap for the exit).
	_add_solid_rect(Rect2(0, 0, BORDER, ROOM_SIZE.y), black, 6)
	_add_solid_rect(Rect2(0, ROOM_SIZE.y - BORDER, ROOM_SIZE.x, BORDER), black, 6)
	_add_solid_rect(Rect2(ROOM_SIZE.x - BORDER, 0, BORDER, EXIT_RECT.position.y), black, 6)
	_add_solid_rect(
		Rect2(ROOM_SIZE.x - BORDER, EXIT_RECT.end.y, BORDER, ROOM_SIZE.y - EXIT_RECT.end.y),
		black, 6
	)


func _build_climb_walls(config: Dictionary) -> void:
	room_wall_rects = []
	for rect in config.get("climb_walls", []):
		room_wall_rects.append(rect)

		# The solid rock (layer 2 — the player switches this layer off
		# while climbing, which is what lets him pass over the top).
		_add_solid_rect(rect, Color(0.48, 0.42, 0.34), 2)

		# Faux-3D touches: a lighter "sunlit top edge" and a darker base.
		var top_edge := ColorRect.new()
		top_edge.color = Color(0.62, 0.55, 0.45)
		top_edge.position = rect.position
		top_edge.size = Vector2(rect.size.x, 16)
		top_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(top_edge)
		var base_edge := ColorRect.new()
		base_edge.color = Color(0.33, 0.28, 0.22)
		base_edge.position = Vector2(rect.position.x, rect.end.y - 12)
		base_edge.size = Vector2(rect.size.x, 12)
		base_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(base_edge)
		# TODO(Isaac): a real rock/cliff texture would look amazing here.

		var climb_sign := UiHelpers.label("hold SHIFT\nto climb!", 16, Color(1.0, 0.95, 0.8))
		climb_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		climb_sign.custom_minimum_size = Vector2(rect.size.x + 80, 0)
		climb_sign.position = Vector2(rect.position.x - 40, rect.position.y + 30)
		add_child(climb_sign)

		# The "climb zone" — an area a bit bigger than the rock. Standing in
		# it (and holding SHIFT) is what lets the player start climbing.
		var zone := Area2D.new()
		zone.set_meta("kind", "climb")
		zone.collision_layer = 0
		zone.set_collision_layer_value(5, true)
		zone.collision_mask = 0
		zone.position = rect.get_center()
		var zone_shape := CollisionShape2D.new()
		var zone_box := RectangleShape2D.new()
		zone_box.size = rect.size + Vector2(68, 68)
		zone_shape.shape = zone_box
		zone.add_child(zone_shape)
		add_child(zone)


func _build_water(config: Dictionary) -> void:
	for rect in config.get("water", []):
		# Looks: pale foam edge underneath, animated blue pool on top.
		# TODO(Isaac): hand-drawn water art would be perfect here.
		var foam := ColorRect.new()
		foam.color = Color(0.85, 0.95, 1.0, 0.5)
		foam.position = rect.position - Vector2(6, 6)
		foam.size = rect.size + Vector2(12, 12)
		foam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(foam)
		var pool := ColorRect.new()
		pool.color = Color(0.22, 0.5, 0.78, 0.85)
		pool.position = rect.position
		pool.size = rect.size
		pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pool)
		var shimmer := create_tween().set_loops()
		shimmer.tween_property(pool, "color:a", 0.65, 0.9)
		shimmer.tween_property(pool, "color:a", 0.85, 0.9)

		# The hazard itself: an area the player's sensor notices. It doesn't
		# block walking — walking in is ALLOWED, it just really hurts.
		# It's noticeably smaller than the visual pool: between this shrink and
		# the player's sensor circle, Goopzz's toes can brush the edge safely.
		var hazard := Area2D.new()
		hazard.set_meta("kind", "water")
		hazard.collision_layer = 0
		hazard.set_collision_layer_value(4, true)
		hazard.collision_mask = 0
		hazard.position = rect.get_center()
		var hazard_shape := CollisionShape2D.new()
		var hazard_box := RectangleShape2D.new()
		hazard_box.size = Vector2(
			maxf(24.0, rect.size.x - 48.0),
			maxf(24.0, rect.size.y - 48.0)
		)
		hazard_shape.shape = hazard_box
		hazard.add_child(hazard_shape)
		add_child(hazard)

		# An invisible fence on layer 7 that ONLY enemies collide with —
		# red slimes won't chase you across water. Hop to safety!
		var fence := StaticBody2D.new()
		fence.collision_layer = 0
		fence.set_collision_layer_value(7, true)
		fence.position = rect.get_center()
		var fence_shape := CollisionShape2D.new()
		var fence_box := RectangleShape2D.new()
		fence_box.size = rect.size
		fence_shape.shape = fence_box
		fence.add_child(fence_shape)
		add_child(fence)


func _build_exit() -> void:
	exit_sign = UiHelpers.label("EXIT →", 26, Color(1.0, 0.5, 0.5))
	exit_sign.position = Vector2(EXIT_RECT.position.x - 130, EXIT_RECT.get_center().y - 18)
	add_child(exit_sign)

	# The locked gate: a red slab blocking the gap until the room is cleared.
	exit_gate = _add_solid_rect(EXIT_RECT, Color(0.7, 0.2, 0.2, 0.95), 6)
	var lock_label := UiHelpers.label("clear all\nslimes!", 15, Color(1.0, 0.85, 0.85))
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.custom_minimum_size = Vector2(140, 0)
	lock_label.position = Vector2(-70, -20)
	exit_gate.add_child(lock_label)

	# The trigger that actually moves you on. It sits INSIDE the gate's spot,
	# so it can only be reached once the gate is gone.
	var exit_area := Area2D.new()
	exit_area.collision_layer = 0
	exit_area.collision_mask = 1
	exit_area.position = EXIT_RECT.get_center() + Vector2(20, 0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(EXIT_RECT.size.x - 30, EXIT_RECT.size.y - 10)
	shape.shape = box
	exit_area.add_child(shape)
	add_child(exit_area)
	exit_area.body_entered.connect(_on_exit_entered)


func _build_player() -> void:
	player = PlayerScene.instantiate()
	player.position = PLAYER_SPAWN
	add_child(player)
	player.climb_wall_rects = room_wall_rects
	player.died.connect(_on_player_died)
	# Keep the camera inside the room.
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = int(ROOM_SIZE.x)
	player.camera.limit_bottom = int(ROOM_SIZE.y)
	player.camera.make_current()


func _build_enemies(config: Dictionary) -> void:
	enemies_left = 0
	for enemy_config in config.get("enemies", []):
		var enemy: EnemySlime = EnemyScene.instantiate()
		enemy.setup(
			RunManager.make_enemy_stats(
				enemy_config.get("level", 1),
				enemy_config.get("boss", false)
			),
			player
		)
		enemy.position = enemy_config.get("pos", ROOM_SIZE / 2.0)
		enemy.touched_player.connect(_on_enemy_touched_player)
		add_child(enemy)
		enemies_left += 1


func _build_pickups(config: Dictionary) -> void:
	for pickup_config in config.get("pickups", []):
		var pickup: Pickup = PickupScene.instantiate()
		pickup.kind = pickup_config.get("kind", "move")
		pickup.position = pickup_config.get("pos", ROOM_SIZE / 2.0)
		pickup.collected.connect(_on_pickup_collected)
		add_child(pickup)


# ============================ battles ============================

func _on_enemy_touched_player(enemy: EnemySlime) -> void:
	# Ignore touches right after a battle (so you can step away) and any
	# touches while the world is already paused for a battle or pop-up.
	if battle_cooldown > 0.0 or get_tree().paused:
		return
	get_tree().paused = true  # freezes player + enemies; the battle runs on top
	var battle: BattleScreen = BattleScene.instantiate()
	battle.setup(enemy.stats)
	battle.finished.connect(_on_battle_finished.bind(enemy))
	add_child(battle)


func _on_battle_finished(won: bool, enemy: Node) -> void:
	get_tree().paused = false
	battle_cooldown = 1.5
	if won:
		enemy.queue_free()
		enemies_left -= 1
		if enemies_left <= 0:
			_open_exit()
		else:
			_toast("%d slime%s left!" % [enemies_left, "" if enemies_left == 1 else "s"])
	else:
		_end_run()


func _open_exit() -> void:
	exit_open = true
	exit_gate.queue_free()
	exit_sign.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	_toast("Room clear! The exit is open →")
	guide.say("Room clear! Head through the exit on the right when you're ready.")


func _on_exit_entered(_body: Node) -> void:
	if not exit_open:
		return
	exit_open = false  # only trigger once
	if RunManager.is_last_room():
		RunManager.run_won = true
		_end_run()
	else:
		RunManager.advance_room()
		get_tree().reload_current_scene()  # same scene, next room's recipe


func _on_player_died() -> void:
	_end_run()


## The run is over (win or lose) — the game-over screen reads RunManager
## to know which one it was.
func _end_run() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")


# ============================ pickups ============================

func _on_pickup_collected(pickup: Pickup) -> void:
	if pickup.kind == "heal":
		var healed: int = mini(pickup.HEAL_AMOUNT, RunManager.player_max_hp - RunManager.player_hp)
		RunManager.player_hp += healed
		_toast("Mmm, jelly! +%d HP" % healed)
		pickup.queue_free()
	else:
		pickup.queue_free()
		var choices := Moves.random_reward_choices(3, RunManager.loadout)
		if choices.is_empty():
			_toast("You already know every move! (+10 XP instead)")
			RunManager.add_xp(10)
			return
		get_tree().paused = true
		var panel: MoveLearnPanel = MoveLearnPanelScene.instantiate()
		panel.open(choices, "You found a Move Disc!")
		hud.add_child(panel)
		panel.closed.connect(func() -> void: get_tree().paused = false)


# ============================ HUD ============================

func _build_hud(config: Dictionary) -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)

	# --- top-left: Goopzz's vitals ---
	name_label = UiHelpers.label("", 22)
	name_label.position = Vector2(20, 10)
	hud.add_child(name_label)

	hp_bar = UiHelpers.styled_bar(Color(0.2, 0.8, 0.4), Vector2(260, 22))
	hp_bar.position = Vector2(20, 42)
	hud.add_child(hp_bar)
	hp_text = UiHelpers.label("", 16)
	hp_text.position = Vector2(290, 40)
	hud.add_child(hp_text)

	# Attack sits between HP and XP so you can watch it grow with level-ups.
	# (In battle, this number gets added to every damaging move's power.)
	attack_label = UiHelpers.label("", 16, Color(1.0, 0.85, 0.6))
	attack_label.position = Vector2(20, 68)
	hud.add_child(attack_label)

	xp_bar = UiHelpers.styled_bar(Color(0.7, 0.5, 0.9), Vector2(260, 10))
	xp_bar.position = Vector2(20, 96)
	hud.add_child(xp_bar)
	xp_text = UiHelpers.label("", 13)
	xp_text.position = Vector2(290, 90)
	hud.add_child(xp_text)

	# --- top-center: where you are ---
	var room_label := UiHelpers.label(
		"Room %d/%d — %s" % [RunManager.current_room, RunManager.total_rooms(), config.title], 24
	)
	room_label.custom_minimum_size = Vector2(1280, 0)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.position = Vector2(0, 10)
	hud.add_child(room_label)

	slimes_left_label = UiHelpers.label("", 16, Color(1.0, 0.8, 0.8))
	slimes_left_label.custom_minimum_size = Vector2(1280, 0)
	slimes_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slimes_left_label.position = Vector2(0, 44)
	hud.add_child(slimes_left_label)

	# --- top-right: the four equipped moves ---
	var moves_header := UiHelpers.label("MOVES", 16, Color(0.8, 0.9, 0.8))
	moves_header.position = Vector2(1060, 12)
	hud.add_child(moves_header)
	loadout_labels = []
	for slot in Moves.MAX_LOADOUT_SIZE:
		var slot_label := UiHelpers.label("", 17)
		slot_label.position = Vector2(1060, 40 + slot * 26)
		hud.add_child(slot_label)
		loadout_labels.append(slot_label)

	# --- bottom-left: hop + climb meters ---
	var hop_label := UiHelpers.label("HOP", 14)
	hop_label.position = Vector2(20, 640)
	hud.add_child(hop_label)
	jump_bar = UiHelpers.styled_bar(Color(0.95, 0.85, 0.3), Vector2(120, 12))
	jump_bar.max_value = 1.0
	jump_bar.position = Vector2(75, 644)
	hud.add_child(jump_bar)

	var climb_label := UiHelpers.label("GRIP", 14)
	climb_label.position = Vector2(20, 664)
	hud.add_child(climb_label)
	climb_bar = UiHelpers.styled_bar(Color(0.9, 0.55, 0.25), Vector2(120, 12))
	climb_bar.max_value = 1.0
	climb_bar.position = Vector2(75, 668)
	hud.add_child(climb_bar)

	# --- bottom-right: Blurpo the guide slime delivers this room's hint ---
	guide = GuideSlime.new()
	hud.add_child(guide)
	guide.say(config.get("hint", ""))

	# --- pop-up announcements ("Room clear!") ---
	toast_label = UiHelpers.label("", 28, Color(1.0, 1.0, 0.85))
	toast_label.custom_minimum_size = Vector2(1280, 0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.position = Vector2(0, 150)
	toast_label.modulate.a = 0.0
	hud.add_child(toast_label)


func _refresh_hud() -> void:
	if player == null or not is_instance_valid(player):
		return
	name_label.text = "Goopzz  Lv %d" % RunManager.player_level
	hp_bar.max_value = RunManager.player_max_hp
	hp_bar.value = RunManager.player_hp
	hp_text.text = "%d / %d" % [RunManager.player_hp, RunManager.player_max_hp]
	attack_label.text = "Attack: %d" % RunManager.player_attack
	xp_bar.max_value = RunManager.xp_to_next_level()
	xp_bar.value = RunManager.player_xp
	xp_text.text = "XP %d / %d" % [RunManager.player_xp, RunManager.xp_to_next_level()]
	jump_bar.value = player.jump_ready_fraction()
	climb_bar.value = player.climb_fraction()
	slimes_left_label.text = "Slimes left: %d" % enemies_left if enemies_left > 0 else "Head for the exit!"
	for slot in loadout_labels.size():
		if slot < RunManager.loadout.size():
			var move := Moves.get_move(RunManager.loadout[slot])
			loadout_labels[slot].text = "%d. %s · %s" % [slot + 1, move.name, move.type]
			loadout_labels[slot].add_theme_color_override(
				"font_color", Moves.type_color(move.type).lightened(0.35)
			)
		else:
			loadout_labels[slot].text = "%d. —" % [slot + 1]


## Show a big announcement in the middle of the screen, then fade it out.
func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.7)
