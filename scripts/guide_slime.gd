class_name GuideSlime
extends Control
## ============================================================================
##  GuideSlime — meet BLURPO, the purple help slime!
## ----------------------------------------------------------------------------
##  Blurpo sits in the bottom-right corner with a speech bubble and tells you
##  what to do — room hints, tips after a defeat, congratulations after a win.
##  He replaces the boring hint text that used to sit at the bottom of the
##  screen.
##
##  Any scene can hire him:
##      var guide := GuideSlime.new()
##      hud.add_child(guide)      # or add_child(...) on a full-screen Control
##      guide.say("Hop over the water with SPACE!")
##  say("") hides the bubble.
##
##  PHASE 2 NOTE: this is THE help slime from Isaac's roadmap — the ally who
##  shows up to help later in the story. For now he coaches from the corner;
##  later he can become a real character walking around in the world.
## ============================================================================

var bubble: PanelContainer
var bubble_label: Label
var slime_image: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Blurpo himself, bottom-right ---
	slime_image = TextureRect.new()
	slime_image.texture = SpritePaths.tex("help_slime")
	slime_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slime_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slime_image.size = Vector2(110, 110)
	slime_image.position = Vector2(1145, 580)
	slime_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slime_image)

	var name_tag := UiHelpers.label("Blurpo", 14, Color(0.85, 0.75, 1.0))
	name_tag.custom_minimum_size = Vector2(110, 0)
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.position = Vector2(1145, 688)
	add_child(name_tag)

	# A gentle bob, because standing perfectly still is not a slime thing.
	var bob := create_tween().set_loops()
	bob.tween_property(slime_image, "position:y", 574.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(slime_image, "position:y", 580.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# --- the speech bubble, to Blurpo's left ---
	bubble = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.96, 1.0, 0.95)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	style.border_color = Color(0.55, 0.36, 0.72)  # Blurpo purple
	style.set_border_width_all(3)
	bubble.add_theme_stylebox_override("panel", style)
	bubble.position = Vector2(680, 565)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)

	bubble_label = Label.new()
	bubble_label.add_theme_font_size_override("font_size", 16)
	bubble_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.2))
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.custom_minimum_size = Vector2(430, 0)
	bubble.add_child(bubble_label)

	bubble.visible = false


## Make Blurpo say something. An empty string hides the bubble.
func say(text: String) -> void:
	if text.strip_edges() == "":
		bubble.visible = false
		return
	bubble_label.text = text
	bubble.visible = true
	# A little "pop" so new advice catches the eye.
	bubble.scale = Vector2(0.85, 0.85)
	var pop := create_tween()
	pop.tween_property(bubble, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
