class_name EnemySlime
extends CharacterBody2D
## ============================================================================
##  Enemy — one red invader slime wandering the beach.
## ----------------------------------------------------------------------------
##  Behavior is simple on purpose:
##    * WANDER — drift around lazily, picking a new direction now and then.
##    * CHASE  — if Goopzz gets within `detect_radius` pixels, charge at him
##               (and switch to Isaac's angry attack sprite).
##  Touching Goopzz starts a battle — the overworld listens for the
##  `touched_player` signal and handles the rest.
##
##  Stats (HP, attack, moves...) are NOT decided here. The overworld calls
##  setup() with a stats dictionary from RunManager.make_enemy_stats(), so
##  one Enemy scene can be a weak baby slime or the big boss.
## ============================================================================

signal touched_player(enemy: EnemySlime)

# ------------------------- easy tuning knobs -------------------------
@export var wander_speed := 60.0
@export var chase_speed := 175.0    # slower than Goopzz's 300 — you can run away!
@export var detect_radius := 380.0  # how far the slime can "see"

const SPRITE_SCALE := 0.13  # Isaac's art is 512px; this shrinks it to ~66px

var stats: Dictionary = {}
var buddy_stats: Dictionary = {}  # non-empty = this slime brought a pal (DUO!)
var player: Node2D = null
var wander_direction := Vector2.ZERO
var wander_timer := 0.0
var wobble_time := 0.0
var is_chasing := false

var body_sprite: Sprite2D


## The overworld calls this right after creating the enemy, BEFORE it enters
## the tree — so _ready() below can rely on `stats` being filled in.
## Pass a second stats dictionary as `buddy` to make this a duo: the pal
## walks alongside in the overworld and joins the battle as a 2nd enemy.
func setup(enemy_stats: Dictionary, player_node: Node2D, buddy: Dictionary = {}) -> void:
	stats = enemy_stats
	player = player_node
	buddy_stats = buddy


func _ready() -> void:
	# Safety net: if you press F6 to run enemy.tscn by itself, invent stats.
	if stats.is_empty():
		stats = RunManager.make_enemy_stats(1)

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	# layer 3 = enemies. They bump into rocks (2), each other (3), borders (6)
	# and the invisible "no swimming" fences around water (7) — red slimes
	# are scared of water too, so Goopzz can escape by hopping over a pool!
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)
	set_collision_mask_value(6, true)
	set_collision_mask_value(7, true)

	var size_scale: float = stats.get("sprite_scale", 1.0)

	# The pal walks slightly behind and to the side (added first = drawn
	# underneath). It's just a costume out here — the REAL second slime
	# appears in battle.
	if not buddy_stats.is_empty():
		var buddy_sprite := Sprite2D.new()
		buddy_sprite.texture = SpritePaths.tex("enemy_slime")
		buddy_sprite.scale = Vector2.ONE * SPRITE_SCALE * 0.8 \
			* float(buddy_stats.get("sprite_scale", 1.0))
		buddy_sprite.position = Vector2(42, 14)
		add_child(buddy_sprite)

	body_sprite = Sprite2D.new()
	body_sprite.texture = SpritePaths.tex("enemy_slime")
	body_sprite.scale = Vector2.ONE * SPRITE_SCALE * size_scale
	add_child(body_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0 * size_scale
	shape.shape = circle
	add_child(shape)

	# Name tag floating above, e.g. "Angry Red  Lv 3" (duos get "& pal").
	var tag := "%s  Lv %d" % [stats.get("name", "Slime"), stats.get("level", 1)]
	if not buddy_stats.is_empty():
		tag = "%s & pal  Lv %d" % [stats.get("name", "Slime"), stats.get("level", 1)]
	var name_label := UiHelpers.label(tag, 15, Color(1.0, 0.82, 0.82))
	name_label.custom_minimum_size = Vector2(160, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-80, -52.0 - 30.0 * size_scale)
	add_child(name_label)

	# A slightly bigger circle that notices when Goopzz touches this slime.
	var touch_area := Area2D.new()
	touch_area.collision_layer = 0
	touch_area.collision_mask = 1  # only the player is on layer 1
	var touch_shape := CollisionShape2D.new()
	var touch_circle := CircleShape2D.new()
	touch_circle.radius = 30.0 * size_scale
	touch_shape.shape = touch_circle
	touch_area.add_child(touch_shape)
	add_child(touch_area)
	touch_area.body_entered.connect(_on_body_touched)


func _on_body_touched(_body: Node) -> void:
	# Only the player can trigger this (collision mask), so: battle time!
	touched_player.emit(self)


func _physics_process(delta: float) -> void:
	var distance_to_player := INF
	if player != null and is_instance_valid(player):
		distance_to_player = global_position.distance_to(player.global_position)

	is_chasing = distance_to_player < detect_radius

	if is_chasing:
		# Charge straight at Goopzz, angry face on.
		var chase_dir := (player.global_position - global_position).normalized()
		velocity = chase_dir * chase_speed
		_set_sprite("enemy_slime_attacking")
	else:
		# Lazy wandering: every couple of seconds pick a new direction
		# (or stand still — slimes love standing still).
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(1.5, 3.0)
			if randf() < 0.3:
				wander_direction = Vector2.ZERO
			else:
				wander_direction = Vector2.from_angle(randf() * TAU)
		velocity = wander_direction * wander_speed
		_set_sprite("enemy_slime")

	move_and_slide()
	_animate(delta)


func _set_sprite(nickname: String) -> void:
	var wanted := SpritePaths.tex(nickname)
	if body_sprite.texture != wanted:
		body_sprite.texture = wanted


## The same squash-and-stretch wobble Goopzz has — everyone here is goo.
func _animate(delta: float) -> void:
	wobble_time += delta
	var size_scale: float = stats.get("sprite_scale", 1.0)
	var base := SPRITE_SCALE * size_scale
	if velocity.length() > 5.0:
		var wobble := sin(wobble_time * 10.0) * 0.05
		body_sprite.scale = Vector2(base * (1.0 + wobble), base * (1.0 - wobble))
		if absf(velocity.x) > 1.0:
			body_sprite.flip_h = velocity.x < 0.0
	else:
		body_sprite.scale = body_sprite.scale.lerp(Vector2.ONE * base, 10.0 * delta)
