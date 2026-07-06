extends Control
## ============================================================================
##  GameOver — shown when the run ends, win OR lose.
##  Reads RunManager to know which one happened and to show the run's stats,
##  then ENTER goes back to the title screen (where a fresh run begins).
##  This restart-from-the-top loop IS the roguelike part.
## ============================================================================

## Rotating tips Blurpo shares after a defeat — add your own!
const TIPS: Array = [
	"Tip: slimes are weak to swords. Good thing you HAVE one.",
	"Tip: Goo Shield right before a boss's turn cuts the hit in half.",
	"Tip: you can hop OVER water with SPACE. Enemies can't follow you!",
	"Tip: Battle Cry stacks — two cries, double the fury.",
	"Tip: enemies are slower than you. Sometimes running away IS the plan.",
	"Tip: Move Discs on the sand teach brand-new moves. Grab them!",
]


func _ready() -> void:
	get_tree().paused = false  # safety: never arrive here frozen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var won := RunManager.run_won

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.12, 0.07) if won else Color(0.12, 0.05, 0.06)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# Goopzz, victorious — or the smug invader, if he got you.
	var face := TextureRect.new()
	face.texture = SpritePaths.tex("goopzz") if won else SpritePaths.tex("enemy_slime")
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size = Vector2(220, 220)
	face.position = Vector2((1280.0 - 220.0) / 2.0, 60)
	add_child(face)

	var title := UiHelpers.label(
		"VICTORY!" if won else "GAME OVER",
		56, Color(0.6, 1.0, 0.7) if won else Color(1.0, 0.55, 0.55)
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(1280, 0)
	title.position = Vector2(0, 300)
	add_child(title)

	var message: String
	if won:
		message = "You bonked Duke Mulch and freed the beach AND the forest!\nNext stop: Forest Town... (coming in Phase 2)"
	else:
		message = "Goopzz melted into a sad little puddle...\nbut slimes ALWAYS bounce back."
	var subtitle := UiHelpers.label(message, 22, Color(0.9, 0.9, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size = Vector2(1280, 0)
	subtitle.position = Vector2(0, 390)
	add_child(subtitle)

	var stats := UiHelpers.label(
		"Reached room %d/%d   ·   Battles won: %d   ·   Final level: %d" % [
			RunManager.current_room, RunManager.total_rooms(),
			RunManager.battles_won, RunManager.player_level,
		],
		20, Color(0.8, 0.85, 0.8)
	)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.custom_minimum_size = Vector2(1280, 0)
	stats.position = Vector2(0, 470)
	add_child(stats)

	# Blurpo the guide slime hands out a tip after a defeat — or a well-earned
	# cheer after a win.
	var guide := GuideSlime.new()
	add_child(guide)
	if won:
		guide.say("You did it, hero! The invaders are running scared. See you in Forest Town!")
	else:
		guide.say(TIPS.pick_random())

	var press := UiHelpers.label("—  PRESS ENTER TO PLAY AGAIN  —", 24, Color(0.9, 0.95, 0.9))
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.custom_minimum_size = Vector2(1280, 0)
	press.position = Vector2(0, 520)
	add_child(press)
	var blink := create_tween().set_loops()
	blink.tween_property(press, "modulate:a", 0.25, 0.6)
	blink.tween_property(press, "modulate:a", 1.0, 0.6)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
