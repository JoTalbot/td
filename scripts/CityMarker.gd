extends Button
## Метка города на карте: большая эмблема и подпись без рамки.

var city_name := ""
var _current := false
var _has_poi := false
var _ending := "ongoing"
var _caption: Label


func setup(label: String, texture: Texture2D, font_size: int = 18) -> void:
	city_name = label
	text = ""
	flat = true
	custom_minimum_size = Vector2(142, 132)
	size = custom_minimum_size
	tooltip_text = label
	# Сам Button без текста, но сохраняем единый минимум темы для UI-аудита.
	add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color.TRANSPARENT
		empty.set_content_margin_all(0)
		add_theme_stylebox_override(state, empty)

	var emblem := TextureRect.new()
	emblem.texture = texture
	emblem.position = Vector2(30, 0)
	emblem.size = Vector2(82, 82)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(emblem)

	_caption = Label.new()
	_caption.position = Vector2(0, 84)
	_caption.size = Vector2(142, 48)
	_caption.text = label
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", font_size)
	_caption.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_caption.add_theme_color_override("font_outline_color", Color(0.06, 0.025, 0.008, 1.0))
	_caption.add_theme_constant_override("outline_size", 4)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)

	mouse_entered.connect(_animate_hover.bind(true))
	mouse_exited.connect(_animate_hover.bind(false))
	pressed.connect(_animate_press)
	queue_redraw()


func set_marks(current: bool, has_poi: bool) -> void:
	_current = current
	_has_poi = has_poi
	_caption.text = city_name
	_caption.add_theme_color_override("font_color", Color(1.0, 0.7, 0.28) if current else Color(1.0, 0.9, 0.7))
	queue_redraw()


func set_story_ending(ending: String) -> void:
	_ending = ending
	match ending:
		"allied": self_modulate = Color(0.82, 1.0, 0.72)
		"mercenary": self_modulate = Color(1.0, 0.82, 0.48)
		"betrayed": self_modulate = Color(1.0, 0.52, 0.42)
		_: self_modulate = Color.WHITE
	queue_redraw()


func _animate_hover(on: bool) -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * (1.06 if on else 1.0), 0.1)


func _animate_press() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.94, 0.94), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func _draw() -> void:
	# Только маленькие статусные метки — никакой рамки вокруг эмблемы.
	if _current:
		draw_circle(Vector2(12, 92), 5.0, Color(1.0, 0.48, 0.16, 0.95))
	if _ending != "ongoing":
		var ending_color := Color(0.45, 0.9, 0.35) if _ending == "allied" else (Color(1.0, 0.72, 0.2) if _ending == "mercenary" else Color(0.95, 0.2, 0.12))
		draw_arc(Vector2(71, 41), 43, 0, TAU, 32, ending_color, 4.0)
	if _has_poi:
		draw_circle(Vector2(size.x - 18, 18), 11.0, Color(0.9, 0.66, 0.2, 0.95))
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 23, 24), "?", HORIZONTAL_ALIGNMENT_CENTER, 10, 17, Color(0.1, 0.06, 0.02))
