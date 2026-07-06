class_name Pickup
extends Area2D
## ============================================================================
##  Pickup — a floating goodie on the sand. Two kinds so far:
##    "move" — a Move Disc (like a Pokemon TM): touch it to choose a new move.
##    "heal" — a jelly donut that restores HP on the spot.
##  The overworld decides WHERE pickups appear (see ROOMS in run_manager.gd)
##  and WHAT happens when they're collected — this script just looks pretty,
##  bobs up and down, and yells `collected` when Goopzz touches it.
##
##  Want a new pickup kind (a key? a coin? climbing gloves for Phase 2)?
##  Add an `elif kind == "..."` visual below and handle it in
##  overworld.gd's _on_pickup_collected().
## ============================================================================

signal collected(pickup: Pickup)

const HEAL_AMOUNT := 20  # HP restored by a "heal" pickup

var kind := "move"  # set by overworld.gd right after instantiating


func _ready() -> void:
	# Only the player (layer 1) can pick things up.
	collision_layer = 0
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	shape.shape = circle
	add_child(shape)

	var icon := Sprite2D.new()
	var caption: Label
	if kind == "heal":
		# TODO(Isaac): draw a jelly donut PNG! Until then: a pink glowy blob.
		var blob := GradientTexture2D.new()
		blob.width = 56
		blob.height = 56
		blob.fill = GradientTexture2D.FILL_RADIAL
		blob.fill_from = Vector2(0.5, 0.5)
		blob.fill_to = Vector2(0.5, 0.0)
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([
			Color(1.0, 0.45, 0.65, 1.0), Color(1.0, 0.45, 0.65, 0.0),
		])
		blob.gradient = gradient
		icon.texture = blob
		caption = UiHelpers.label("+%d HP" % HEAL_AMOUNT, 16, Color(1.0, 0.75, 0.85))
	else:
		# Isaac's rainbow Move Disc (Slimania's answer to a Pokemon TM).
		icon.texture = SpritePaths.tex("move_disc")
		icon.scale = Vector2.ONE * 0.06  # the art is 1024px; show it ~60px wide
		caption = UiHelpers.label("Move Disc!", 16, Color(0.75, 1.0, 0.8))
	add_child(icon)

	caption.custom_minimum_size = Vector2(160, 0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(-80, 34)
	add_child(caption)

	# Gentle bobbing so pickups catch the eye.
	var tween := create_tween().set_loops()
	tween.tween_property(icon, "position:y", -10.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(icon, "position:y", 0.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node) -> void:
	collected.emit(self)
