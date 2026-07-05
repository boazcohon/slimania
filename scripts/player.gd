class_name Player
extends CharacterBody2D
## ============================================================================
##  Player — Goopzz's overworld body.
## ----------------------------------------------------------------------------
##  Top-down movement like Among Us / Undertale: walk freely in four
##  directions (and diagonals). Goopzz can also:
##    * JUMP  (SPACE) — a short hop that carries him safely over water.
##      There's a cooldown so it can't be spammed.
##    * CLIMB (hold SHIFT near rocks) — climb over rock walls for a short
##      time. If his grip (stamina) runs out mid-wall, he SLIPS back to where
##      he started. Slimes are not great climbers... yet. (Phase 2: the
##      climbing gloves from Kath will make this way better!)
##
##  Everything visual (sprite, shadow, camera) is built in code in _ready()
##  so this one file tells the whole story of how Goopzz works.
## ============================================================================

signal died  # fired when HP reaches 0 in the overworld (water damage)

# ------------------------- easy tuning knobs -------------------------
@export var move_speed := 300.0        # normal walking speed (Goopzz is fast!)
@export var air_speed := 340.0         # speed while mid-hop (helps clear water)
@export var jump_duration := 0.45      # seconds Goopzz stays in the air
@export var jump_cooldown := 0.9       # seconds before he can hop again
@export var jump_height := 46.0        # how high the sprite lifts (visual only)
@export var climb_speed := 130.0       # climbing is slow and careful
@export var climb_max_stamina := 1.8   # seconds of grip before slipping
@export var climb_recharge_rate := 1.2 # grip regained per second on the ground
@export var water_damage := 5          # HP lost when touching water
@export var hurt_safety_time := 1.0    # invincibility seconds after getting hurt

const SPRITE_SCALE := 0.14  # Isaac's art is 512px; this shrinks it to ~72px

# ------------------------- state -------------------------
var is_airborne := false
var jump_time_left := 0.0
var jump_cooldown_left := 0.0
var climb_stamina := 0.0
var is_climbing := false
var is_slipping := false           # true while a tween drags Goopzz back
var climb_entry_point := Vector2.ZERO
var last_safe_position := Vector2.ZERO
var hurt_timer := 0.0
var water_overlaps := 0            # how many water pools we're touching
var climb_zone_overlaps := 0       # how many climb zones we're touching
var climb_wall_rects: Array = []   # solid wall rectangles (set by overworld.gd)
var wobble_time := 0.0

var body_sprite: Sprite2D
var shadow: Sprite2D
var camera: Camera2D


func _ready() -> void:
	climb_stamina = climb_max_stamina
	last_safe_position = global_position
	# Top-down games need FLOATING motion — the default mode thinks gravity
	# exists and we'd "fall" sideways.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build_body()


## Create the sprite, shadow, collision shape, water/climb sensor and camera.
func _build_body() -> void:
	# --- physics layers ---
	# layer 1 = the player. He bumps into climbable rocks (2) and borders (6).
	collision_layer = 1
	collision_mask = 0
	set_collision_mask_value(2, true)
	set_collision_mask_value(6, true)

	# --- shadow (drawn first so it's underneath) ---
	# The shadow stays on the ground during a hop — that's what sells the jump.
	shadow = Sprite2D.new()
	var shadow_texture := GradientTexture2D.new()
	shadow_texture.width = 96
	shadow_texture.height = 40
	shadow_texture.fill = GradientTexture2D.FILL_RADIAL
	shadow_texture.fill_from = Vector2(0.5, 0.5)
	shadow_texture.fill_to = Vector2(0.5, 0.0)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.0)])
	shadow_texture.gradient = gradient
	shadow.texture = shadow_texture
	shadow.position = Vector2(0, 28)
	add_child(shadow)

	# --- Goopzz himself ---
	body_sprite = Sprite2D.new()
	body_sprite.texture = SpritePaths.tex("goopzz")
	body_sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(body_sprite)

	# --- collision circle ---
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)

	# --- sensor: notices water pools (layer 4) and climb zones (layer 5) ---
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 0
	sensor.set_collision_mask_value(4, true)
	sensor.set_collision_mask_value(5, true)
	var sensor_shape := CollisionShape2D.new()
	var sensor_circle := CircleShape2D.new()
	sensor_circle.radius = 20.0
	sensor_shape.shape = sensor_circle
	sensor.add_child(sensor_shape)
	add_child(sensor)
	sensor.area_entered.connect(_on_sensor_area_entered)
	sensor.area_exited.connect(_on_sensor_area_exited)

	# --- camera that follows Goopzz around the room ---
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)


func _on_sensor_area_entered(area: Area2D) -> void:
	match area.get_meta("kind", ""):
		"water":
			water_overlaps += 1
		"climb":
			climb_zone_overlaps += 1


func _on_sensor_area_exited(area: Area2D) -> void:
	match area.get_meta("kind", ""):
		"water":
			water_overlaps = maxi(0, water_overlaps - 1)
		"climb":
			climb_zone_overlaps = maxi(0, climb_zone_overlaps - 1)


func _physics_process(delta: float) -> void:
	jump_cooldown_left = maxf(0.0, jump_cooldown_left - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)

	if is_slipping:
		return  # a tween is carrying Goopzz back — no controls until he lands

	_handle_climbing(delta)
	_handle_jumping(delta)
	_handle_walking()
	_handle_water()
	_animate(delta)


func _handle_walking() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := move_speed
	if is_climbing:
		speed = climb_speed
	elif is_airborne:
		speed = air_speed
	velocity = input_dir * speed
	move_and_slide()

	# Remember the last spot where Goopzz stood safely on dry sand. If water
	# gets him, this is where he bounces back to.
	if not is_airborne and not is_climbing and water_overlaps == 0:
		last_safe_position = global_position


func _handle_jumping(delta: float) -> void:
	var wants_jump := Input.is_action_just_pressed("jump")
	if wants_jump and not is_airborne and not is_climbing and jump_cooldown_left <= 0.0:
		is_airborne = true
		jump_time_left = jump_duration
		jump_cooldown_left = jump_cooldown + jump_duration

	if is_airborne:
		jump_time_left -= delta
		# The body rises and falls along a smooth arc while the shadow stays
		# put — classic top-down jump trick.
		var progress := 1.0 - jump_time_left / jump_duration  # 0 → 1
		body_sprite.position.y = -sin(progress * PI) * jump_height
		if jump_time_left <= 0.0:
			is_airborne = false
			body_sprite.position.y = 0.0


func _handle_climbing(delta: float) -> void:
	if is_climbing:
		climb_stamina -= delta
		var on_wall := _inside_climb_wall()
		if climb_zone_overlaps == 0 and not on_wall:
			_stop_climbing()  # made it across — back to normal walking
		elif climb_stamina <= 0.0 or not Input.is_action_pressed("climb"):
			if on_wall:
				_slip_back()  # ran out of grip in the middle of the wall!
			else:
				_stop_climbing()
	else:
		climb_stamina = minf(climb_max_stamina, climb_stamina + climb_recharge_rate * delta)
		# You need at least half a grip bar to start a climb — this stops
		# frantic half-second climb spam at the wall's edge.
		var can_start := Input.is_action_pressed("climb") \
			and climb_zone_overlaps > 0 \
			and climb_stamina >= climb_max_stamina * 0.5 \
			and not is_airborne
		if can_start:
			_start_climbing()


func _start_climbing() -> void:
	is_climbing = true
	climb_entry_point = global_position
	# While climbing, ignore the rock layer (2) so Goopzz can move "over" the
	# rocks. Border walls (6) still block him.
	set_collision_mask_value(2, false)
	body_sprite.modulate = Color(1.15, 1.15, 1.15)  # slight highlight = "up high"


func _stop_climbing() -> void:
	is_climbing = false
	set_collision_mask_value(2, true)
	body_sprite.modulate = Color.WHITE


## Is Goopzz's center actually inside a solid rock wall right now?
func _inside_climb_wall() -> bool:
	for rect in climb_wall_rects:
		if rect.has_point(global_position):
			return true
	return false


## Grip ran out mid-wall: slide back to where the climb started.
func _slip_back() -> void:
	_stop_climbing()
	climb_stamina = 0.0
	is_slipping = true
	velocity = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "global_position", climb_entry_point, 0.45) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: is_slipping = false)


func _handle_water() -> void:
	# Airborne slimes fly safely OVER water. Grounded slimes get zapped and
	# bounce back to the last dry spot they stood on.
	if water_overlaps > 0 and not is_airborne and hurt_timer <= 0.0:
		take_damage(water_damage)
		is_slipping = true
		velocity = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(self, "global_position", last_safe_position, 0.3)
		tween.tween_callback(func() -> void: is_slipping = false)


## Lose HP with a little "ouch" flash. Used by water (and by anything else
## you might add later — spikes? falling coconuts?).
func take_damage(amount: int) -> void:
	RunManager.player_hp -= amount
	hurt_timer = hurt_safety_time
	body_sprite.texture = SpritePaths.tex("goopzz_angry")  # ouch face!
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", Color(1.0, 0.4, 0.4), 0.08)
	tween.tween_property(body_sprite, "modulate", Color.WHITE, 0.3)
	tween.tween_callback(func() -> void: body_sprite.texture = SpritePaths.tex("goopzz"))
	if RunManager.player_hp <= 0:
		RunManager.player_hp = 0
		died.emit()


## Squash-and-stretch wobble while moving — the "I am made of goo" feeling.
func _animate(delta: float) -> void:
	wobble_time += delta
	if velocity.length() > 10.0 and not is_airborne:
		var wobble := sin(wobble_time * 14.0) * 0.06
		body_sprite.scale = Vector2(
			SPRITE_SCALE * (1.0 + wobble),
			SPRITE_SCALE * (1.0 - wobble)
		)
		if absf(velocity.x) > 1.0:
			body_sprite.flip_h = velocity.x < 0.0  # face the way he's going
	else:
		body_sprite.scale = body_sprite.scale.lerp(Vector2.ONE * SPRITE_SCALE, 10.0 * delta)
	# The shadow shrinks a little while airborne (Goopzz is further from it).
	shadow.scale = Vector2.ONE * (0.75 if is_airborne else 1.0)


# ------------- helpers the HUD uses to draw the little meters -------------

## 0.0 = just jumped, 1.0 = ready to jump again.
func jump_ready_fraction() -> float:
	return 1.0 - clampf(jump_cooldown_left / (jump_cooldown + jump_duration), 0.0, 1.0)


## How full the climb-grip bar is, 0.0 to 1.0.
func climb_fraction() -> float:
	return clampf(climb_stamina / climb_max_stamina, 0.0, 1.0)
