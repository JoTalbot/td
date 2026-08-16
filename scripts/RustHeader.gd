extends Label
## Клёпаная металлическая табличка-заголовок для экранов и секций UI.

var _accent := Color(0.95, 0.75, 0.35)


func setup(label: String, font_size: int = 24, accent := Color(0.95, 0.75, 0.35)) -> void:
	text = label
	_accent = accent
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size.y = maxf(54.0, float(font_size + 28))
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", Color(1.0, 0.92, 0.73))
	add_theme_color_override("font_outline_color", Color(0.055, 0.03, 0.012, 0.98))
	add_theme_constant_override("outline_size", 3)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.16, 0.105, 0.058, 0.97)
	plate.border_color = accent.darkened(0.3)
	plate.border_width_left = 4
	plate.border_width_top = 3
	plate.border_width_right = 6
	plate.border_width_bottom = 6
	plate.corner_radius_top_left = 7
	plate.corner_radius_top_right = 2
	plate.corner_radius_bottom_left = 2
	plate.corner_radius_bottom_right = 7
	plate.content_margin_left = 28.0
	plate.content_margin_right = 28.0
	plate.content_margin_top = 8.0
	plate.content_margin_bottom = 9.0
	plate.shadow_color = Color(0.02, 0.01, 0.004, 0.85)
	plate.shadow_size = 6
	plate.shadow_offset = Vector2(3, 4)
	add_theme_stylebox_override("normal", plate)
	queue_redraw()


func _draw() -> void:
	# Болты по углам и сварочные риски — только по краям, текст остаётся чистым.
	var dark := Color(0.04, 0.025, 0.012, 0.95)
	var metal := _accent.darkened(0.38)
	for p in [Vector2(12, 12), Vector2(size.x - 13, 12), Vector2(12, size.y - 13), Vector2(size.x - 13, size.y - 13)]:
		draw_circle(p, 4.0, dark)
		draw_circle(p - Vector2(0.8, 0.8), 2.0, metal)
		draw_line(p - Vector2(1.5, 0), p + Vector2(1.5, 0), dark, 1.0)
	if size.x > 180.0:
		draw_line(Vector2(34, 8), Vector2(64, 5), Color(0.9, 0.48, 0.17, 0.28), 1.5)
		draw_line(Vector2(size.x - 70, size.y - 6), Vector2(size.x - 38, size.y - 9), dark, 1.5)
