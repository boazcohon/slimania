class_name PauseMenu
extends CanvasLayer
## ============================================================================
##  PauseMenu — press ESC to freeze the world and take a breath.
## ----------------------------------------------------------------------------
##  Buttons: Resume, Restart Run (fresh run from Room 1), Quit to Title.
##  The overworld creates one of these and listens to `menu_opened` /
##  `menu_closed` — that's how an in-progress battle gets frozen too (battles
##  normally IGNORE the engine's pause on purpose, so the overworld flips the
##  battle's process mode off while the menu is up).
##  The menu is careful to remember whether the game was ALREADY paused
##  (mid-battle, mid-popup) and puts things back exactly as it found them.
## ============================================================================

signal menu_opened
signal menu_closed

var is_open := false
var was_paused := false  # was the game already paused when the menu opened?
var panel_root: Control


func _ready() -> void:
	# The menu must work while everything else is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # draw on top of absolutely everything

	panel_root = Control.new()
	panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks underneath
	panel_root.add_child(dim)

	var window := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.16, 0.98)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(26)
	style.border_color = Color(0.18, 0.65, 0.35)
	style.set_border_width_all(3)
	window.add_theme_stylebox_override("panel", style)
	window.position = Vector2(470, 175)
	panel_root.add_child(window)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	window.add_child(column)

	var title := UiHelpers.label("PAUSED", 34, Color(0.8, 1.0, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var resume := UiHelpers.styled_button("Resume", Color(0.18, 0.65, 0.35), 20)
	resume.custom_minimum_size = Vector2(300, 0)
	resume.pressed.connect(close)
	column.add_child(resume)

	var restart := UiHelpers.styled_button("Restart Run", Color(0.62, 0.44, 0.22), 20)
	restart.pressed.connect(_on_restart_pressed)
	column.add_child(restart)

	var quit := UiHelpers.styled_button("Quit to Title", Color(0.55, 0.36, 0.72), 20)
	quit.pressed.connect(_on_quit_pressed)
	column.add_child(quit)

	var reminder := UiHelpers.label(
		"WASD move · SPACE hop · SHIFT climb · 1–4 battle moves",
		13, Color(0.7, 0.75, 0.7)
	)
	reminder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(reminder)

	panel_root.visible = false


## ESC (Godot's built-in "ui_cancel" action) toggles the menu.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_open:
			close()
		else:
			open()


func open() -> void:
	if is_open:
		return
	is_open = true
	was_paused = get_tree().paused
	get_tree().paused = true
	panel_root.visible = true
	menu_opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	panel_root.visible = false
	get_tree().paused = was_paused  # back exactly how we found it
	menu_closed.emit()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	RunManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
