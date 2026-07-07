class_name MoveLearnPanel
extends Control
## ============================================================================
##  MoveLearnPanel — the "pick a new move" pop-up.
## ----------------------------------------------------------------------------
##  Used in two places:
##    * after WINNING a battle (pick 1 of 3, Slay-the-Spire style)
##    * when touching a Move Disc pickup in the overworld
##
##  Flow:
##    1. Shows up to 3 move cards + a Skip button.
##    2. If Goopzz's four slots have room → learn it instantly.
##    3. If the slots are FULL → a second screen asks which old move to forget
##       (exactly like Pokemon's "forget a move?" moment).
##  When the choice is over it fires `closed` and removes itself.
##
##  HOW TO USE (see battle.gd / overworld.gd):
##      var panel := MoveLearnPanelScene.instantiate()
##      panel.open(["mega_bonk", "splash"], "Pick a new move:")
##      add_child(panel)
##      await panel.closed
## ============================================================================

signal closed

var choice_ids: Array = []
var header_text := "Pick a new move:"
var pending_move_id := ""  # remembered between screen 1 and screen 2

var window: PanelContainer
var content: VBoxContainer


## Call BEFORE add_child() — stores what to offer; _ready() builds the UI.
func open(move_choices: Array, header: String) -> void:
	choice_ids = move_choices
	header_text = header


func _ready() -> void:
	# The pop-up must keep working while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Safety net for pressing F6 on this scene alone: offer random moves.
	if choice_ids.is_empty():
		choice_ids = Moves.random_reward_choices(3, RunManager.loadout)

	# Dim everything behind the pop-up.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# The pop-up window itself, centered on screen.
	window = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.16, 0.97)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	style.border_color = Color(0.18, 0.65, 0.35)
	style.set_border_width_all(3)
	window.add_theme_stylebox_override("panel", style)
	add_child(window)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	window.add_child(content)

	_show_choice_screen()


## The window sizes itself to its content, and content changes between the
## two screens — so we wait a couple of frames for the layout to settle,
## then slide the window to the middle.
func _recenter_soon() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	window.position = (get_viewport_rect().size - window.size) / 2.0


## Screen 1: the move cards + Skip.
func _show_choice_screen() -> void:
	_clear_content()
	var header := UiHelpers.label(header_text, 26, Color(0.8, 1.0, 0.85))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	content.add_child(cards)
	for move_id in choice_ids:
		cards.add_child(_make_move_card(move_id))

	var skip := UiHelpers.styled_button("Skip — keep my moves", Color(0.35, 0.35, 0.4), 16)
	skip.pressed.connect(_finish)
	content.add_child(skip)
	_recenter_soon()


## One clickable card describing one move.
func _make_move_card(move_id: String) -> Control:
	var move := Moves.get_move(move_id)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(240, 0)
	card.add_theme_constant_override("separation", 6)

	var pick_button := UiHelpers.styled_button(move.name, Moves.type_color(move.type), 20)
	pick_button.pressed.connect(_on_move_chosen.bind(move_id))
	card.add_child(pick_button)

	var stats_line := "%s  ·  %d gel  ·  power %d" % [
		str(move.type).to_upper(), int(move.get("cost", 1)), int(move.get("power", 0)),
	]
	if move.get("effect", "") == "multi_hit":
		stats_line += "  x%d hits" % int(move.get("hits", 2))
	var info := UiHelpers.label(stats_line, 14, Color(0.85, 0.85, 0.85))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(info)

	var description := UiHelpers.label(str(move.get("description", "")), 14, Color(0.7, 0.75, 0.7))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(240, 60)
	card.add_child(description)
	return card


func _on_move_chosen(move_id: String) -> void:
	if RunManager.loadout.size() < Moves.MAX_LOADOUT_SIZE:
		RunManager.loadout.append(move_id)
		_finish()
	else:
		pending_move_id = move_id
		_show_forget_screen()


## Screen 2: slots are full — forget which old move?
func _show_forget_screen() -> void:
	_clear_content()
	var new_move := Moves.get_move(pending_move_id)
	var header := UiHelpers.label(
		"Your 4 slots are full!\nForget which move to learn %s?" % new_move.name,
		22, Color(1.0, 0.9, 0.7)
	)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	for slot in RunManager.loadout.size():
		var old_move := Moves.get_move(RunManager.loadout[slot])
		var forget_button := UiHelpers.styled_button(
			"Forget %s" % old_move.name, Moves.type_color(old_move.type), 18
		)
		forget_button.pressed.connect(_on_forget_chosen.bind(slot))
		content.add_child(forget_button)

	var keep := UiHelpers.styled_button("Actually, keep my old moves", Color(0.35, 0.35, 0.4), 16)
	keep.pressed.connect(_finish)
	content.add_child(keep)
	_recenter_soon()


func _on_forget_chosen(slot: int) -> void:
	RunManager.loadout[slot] = pending_move_id
	_finish()


func _clear_content() -> void:
	for child in content.get_children():
		child.queue_free()


func _finish() -> void:
	closed.emit()
	queue_free()
