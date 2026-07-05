extends Control
## ============================================================================
##  TitleScreen — the first thing you see. Shows Isaac's "SLIMANIA INVADED"
##  logo over the skybox art, tells the story in three lines, and waits for
##  ENTER (or SPACE) to start a fresh run.
## ============================================================================


func _ready() -> void:
	get_tree().paused = false  # safety: never arrive here frozen
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Isaac's skybox, dimmed, as the backdrop.
	var backdrop := TextureRect.new()
	backdrop.texture = SpritePaths.tex("skybox")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color(0.45, 0.45, 0.55)
	add_child(backdrop)

	# The big logo.
	var logo := TextureRect.new()
	logo.texture = SpritePaths.tex("logo_invaded")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(880, 240)
	logo.position = Vector2((1280.0 - 880.0) / 2.0, 70)
	add_child(logo)

	# Goopzz himself, saying hi from the corner.
	var goopzz := TextureRect.new()
	goopzz.texture = SpritePaths.tex("goopzz")
	goopzz.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	goopzz.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	goopzz.size = Vector2(170, 170)
	goopzz.position = Vector2(90, 470)
	add_child(goopzz)

	# The story, short and sweet.
	var story := UiHelpers.label(
		"Goopzz was the hero of Castletown... until the invader slimes came\n" +
		"and flung him all the way down to the beach.\n" +
		"Bounce back. Bonk everyone. Reclaim SLIMANIA.",
		20, Color(0.9, 0.95, 0.9)
	)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.custom_minimum_size = Vector2(1280, 0)
	story.position = Vector2(0, 350)
	add_child(story)

	# Blinking "press enter".
	var press := UiHelpers.label("—  PRESS ENTER TO START A RUN  —", 26, Color(0.75, 1.0, 0.8))
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.custom_minimum_size = Vector2(1280, 0)
	press.position = Vector2(0, 500)
	add_child(press)
	var blink := create_tween().set_loops()
	blink.tween_property(press, "modulate:a", 0.25, 0.6)
	blink.tween_property(press, "modulate:a", 1.0, 0.6)

	# Controls cheat-sheet.
	var controls := UiHelpers.label(
		"WASD / arrows — move      SPACE — hop over water      hold SHIFT — climb rocks\n" +
		"in battle: click a move, or press 1–4",
		16, Color(0.8, 0.8, 0.85)
	)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.custom_minimum_size = Vector2(1280, 0)
	controls.position = Vector2(0, 620)
	add_child(controls)

	var credit := UiHelpers.label("all art by Isaac", 14, Color(0.7, 0.75, 0.7))
	credit.position = Vector2(1130, 690)
	add_child(credit)


func _input(event: InputEvent) -> void:
	# ui_accept = ENTER or SPACE (built into Godot).
	if event.is_action_pressed("ui_accept"):
		RunManager.start_new_run()
		get_tree().change_scene_to_file("res://scenes/overworld.tscn")
