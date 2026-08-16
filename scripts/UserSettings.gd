extends Node
## Пользовательские настройки: сохраняются отдельно от кампании и мета-прогресса.

signal changed(key: String)

const SAVE_PATH := "user://user_settings.save"
const DEFAULTS := {
	"ui_size": "huge",       # large | huge; текущий крупный UI — huge
	"sound": 80,              # 0..100
	"vibration": true,
	"shake": 100,             # 0 | 50 | 100
	"effects": "full",       # full | economy
	"ui_theme": "rust",      # rust | bone | copper | war
	"show_fps": false,
	"map_zoom": 1.0,
	"map_pan_x": 0.0,
	"map_pan_y": 0.0,
}

var values: Dictionary = DEFAULTS.duplicate(true)


func _init() -> void:
	_load_settings()


func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value) -> void:
	if not DEFAULTS.has(key) or values.get(key) == value:
		return
	values[key] = value
	_save_settings()
	changed.emit(key)


func font_size(base: int) -> int:
	# «Очень крупный» совпадает с новым дизайном, «Крупный» компактнее на 10%.
	var scale := 1.0 if String(get_value("ui_size")) == "huge" else 0.9
	return maxi(18, int(round(base * scale)))


func sound_gain() -> float:
	return clampf(float(get_value("sound")) / 100.0, 0.0, 1.0)


func shake_gain() -> float:
	return clampf(float(get_value("shake")) / 100.0, 0.0, 1.0)


func particle_gain() -> float:
	return 0.55 if String(get_value("effects")) == "economy" else 1.0


func map_view() -> Dictionary:
	return {"zoom": float(values["map_zoom"]), "pan": Vector2(float(values["map_pan_x"]), float(values["map_pan_y"]))}


func save_map_view(zoom: float, pan: Vector2) -> void:
	values["map_zoom"] = clampf(zoom, 1.0, 2.4)
	values["map_pan_x"] = pan.x
	values["map_pan_y"] = pan.y
	_save_settings()


func vibrate(duration_ms: int = 35, _amplitude: float = 0.45) -> void:
	if bool(get_value("vibration")):
		# Godot 4.2 принимает только длительность; параметр силы оставлен для будущих версий.
		Input.vibrate_handheld(duration_ms)


func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in DEFAULTS:
			if parsed.has(key):
				values[key] = parsed[key]
	_sanitize()


func _sanitize() -> void:
	if String(values["ui_size"]) not in ["large", "huge"]:
		values["ui_size"] = DEFAULTS["ui_size"]
	values["sound"] = clampi(int(values["sound"]), 0, 100)
	values["vibration"] = bool(values["vibration"])
	values["show_fps"] = bool(values["show_fps"])
	var shake_value := int(values["shake"])
	values["shake"] = 0 if shake_value < 25 else (50 if shake_value < 75 else 100)
	if String(values["effects"]) not in ["full", "economy"]:
		values["effects"] = DEFAULTS["effects"]
	if String(values["ui_theme"]) not in ["rust", "bone", "copper", "war"]:
		values["ui_theme"] = DEFAULTS["ui_theme"]
	values["map_zoom"] = clampf(float(values["map_zoom"]), 1.0, 2.4)
	values["map_pan_x"] = float(values["map_pan_x"])
	values["map_pan_y"] = float(values["map_pan_y"])


func _save_settings() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(values))
