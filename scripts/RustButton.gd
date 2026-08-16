extends Button
## Графическая кнопка из клёпаного ржавого металла для всего интерфейса.
## Фон, фаски, тени, заклёпки и царапины рисуются процедурно — без тяжёлых текстур.

var _accent := Color(0.95, 0.75, 0.35)


func setup(label: String, accent := Color(0.95, 0.75, 0.35)) -> void:
	text = label
	_accent = accent
	custom_minimum_size.y = 58.0
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", Color(1.0, 0.92, 0.76))
	add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.84))
	add_theme_color_override("font_pressed_color", Color(1.0, 0.82, 0.48))
	add_theme_color_override("font_disabled_color", Color(0.52, 0.47, 0.4))
	add_theme_color_override("font_outline_color", Color(0.08, 0.045, 0.02, 0.95))
	add_theme_constant_override("outline_size", 2)
	add_theme_constant_override("h_separation", 8)
	add_theme_stylebox_override("normal", _plate_style(
		Color(0.22, 0.145, 0.075, 0.98), accent, false))
	add_theme_stylebox_override("hover", _plate_style(
		Color(0.32, 0.205, 0.095, 1.0), accent.lightened(0.18), false))
	add_theme_stylebox_override("focus", _plate_style(
		Color(0.27, 0.17, 0.08, 1.0), accent.lightened(0.28), false))
	add_theme_stylebox_override("pressed", _plate_style(
		Color(0.13, 0.085, 0.05, 1.0), accent.darkened(0.12), true))
	add_theme_stylebox_override("disabled", _plate_style(
		Color(0.095, 0.075, 0.055, 0.94), Color(0.3, 0.26, 0.21), false))
	queue_redraw()


func _plate_style(bg: Color, edge: Color, inset: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge.darkened(0.18)
	sb.border_width_left = 4 if inset else 3
	sb.border_width_top = 4 if inset else 3
	sb.border_width_right = 2 if inset else 5
	sb.border_width_bottom = 2 if inset else 5
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 9.0
	sb.shadow_color = Color(0.025, 0.015, 0.008, 0.8)
	sb.shadow_size = 5 if not inset else 2
	sb.shadow_offset = Vector2(2, 3) if not inset else Vector2(1, 1)
	return sb


func _draw() -> void:
	# Четыре заклёпки и короткие сварочные царапины превращают обычный Control
	# в физическую металлическую плашку, не мешая читаемости подписи.
	var rivet := _accent.darkened(0.42)
	var glint := _accent.lightened(0.2)
	var points := [
		Vector2(9, 9), Vector2(size.x - 10, 9),
		Vector2(9, size.y - 10), Vector2(size.x - 10, size.y - 10),
	]
	for p in points:
		draw_circle(p, 3.2, Color(0.045, 0.03, 0.018, 0.9))
		draw_circle(p - Vector2(0.7, 0.7), 1.5, rivet)
		draw_circle(p - Vector2(1.1, 1.1), 0.55, glint)
	if size.x >= 90.0:
		draw_line(Vector2(22, 7), Vector2(36, 5), Color(0.72, 0.42, 0.18, 0.34), 1.3)
		draw_line(Vector2(size.x - 40, size.y - 6), Vector2(size.x - 24, size.y - 8), Color(0.04, 0.025, 0.015, 0.7), 1.4)
