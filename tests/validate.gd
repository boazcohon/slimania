extends SceneTree
## ============================================================================
##  validate.gd — a tiny smoke test. It loads every script and scene in the
##  game and reports anything that fails to compile. Run it from a terminal
##  in the project folder (handy after big edits, no clicking required):
##
##      godot --headless -s tests/validate.gd
##
##  You don't need this to play the game — it's just a safety net.
## ============================================================================

const FILES: Array = [
	"res://scripts/sprite_paths.gd",
	"res://scripts/moves.gd",
	"res://scripts/run_manager.gd",
	"res://scripts/ui_helpers.gd",
	"res://scripts/guide_slime.gd",
	"res://scripts/pause_menu.gd",
	"res://scripts/player.gd",
	"res://scripts/enemy.gd",
	"res://scripts/pickup.gd",
	"res://scripts/move_learn_panel.gd",
	"res://scripts/battle.gd",
	"res://scripts/overworld.gd",
	"res://scripts/title_screen.gd",
	"res://scripts/game_over.gd",
	"res://scenes/title_screen.tscn",
	"res://scenes/overworld.tscn",
	"res://scenes/player.tscn",
	"res://scenes/enemy.tscn",
	"res://scenes/pickup.tscn",
	"res://scenes/battle.tscn",
	"res://scenes/move_learn_panel.tscn",
	"res://scenes/game_over.tscn",
]


func _initialize() -> void:
	var failures := 0
	for path in FILES:
		var resource := load(path)
		if resource == null:
			push_error("FAILED to load: %s" % path)
			failures += 1
		else:
			print("ok: %s" % path)
	# Also make sure every sprite nickname points at a real file.
	# (We load the script directly instead of using the autoload, because
	# autoloads aren't set up when Godot runs a lone script with -s.)
	var sprite_paths: Dictionary = load("res://scripts/sprite_paths.gd").PATHS
	for nickname in sprite_paths:
		if not ResourceLoader.exists(sprite_paths[nickname]):
			push_error("MISSING art file for '%s': %s" % [nickname, sprite_paths[nickname]])
			failures += 1
	if failures == 0:
		print("\nAll %d files loaded cleanly. Slimania is good to goo." % FILES.size())
	quit(1 if failures > 0 else 0)
