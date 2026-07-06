class_name UiHelpers
extends RefCounted
## ============================================================================
##  UiHelpers — little factory functions for UI pieces we build over and over
##  (labels with outlines, colored HP bars, chunky colored buttons).
##  They are "static" so you call them without creating anything:
##      var bar := UiHelpers.styled_bar(Color.RED, Vector2(260, 22))
## ============================================================================


## A text label with a dark outline so it stays readable on top of any art.
static func label(text: String, font_size: int = 20, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l


## A progress bar with rounded corners and a custom fill color.
## Used for HP, XP, jump cooldown and climb stamina.
static func styled_bar(fill_color: Color, bar_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = bar_size
	bar.size = bar_size
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.55)
	background.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## A chunky colored button (used for battle moves and menu choices).
static func styled_button(text: String, bg_color: Color, font_size: int = 20) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	button.add_theme_constant_override("outline_size", 4)

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)

	var hover := normal.duplicate()
	hover.bg_color = bg_color.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = bg_color.darkened(0.2)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.3, 0.3, 0.3, 0.7)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover.duplicate())
	return button
