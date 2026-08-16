extends Node3D
## Камера погони: смотрит на грузовик сзади-сверху, drag — орбита, pinch — зум.

var camera: Camera3D
var _pivot: Node3D

var _distance := 20.0
var _yaw := 180.0     # смотрим с хвоста грузовика вперёд по ходу движения
var _pitch := -52.0

var _touches: Dictionary = {}
var _last_pinch_dist := 0.0
var _gesturing := false
var _trauma := 0.0           # тряска камеры: 0..1, затухает сама
var trauma_scale := 1.0      # пользовательская интенсивность 0..1
var _cinematic_target: Node3D = null
var _cinematic_return: Node3D = null
var _cinematic_timer := 0.0


## Встряхнуть камеру (таран, взрыв босса). Сила ~0.15..0.8.
func add_trauma(a: float) -> void:
	_trauma = minf(_trauma + a * trauma_scale, 1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pivot = Node3D.new()
	add_child(_pivot)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	_pivot.add_child(camera)
	_update_transform()


func focus_on(target: Vector3) -> void:
	_pivot.position = target
	_update_transform()


func is_gesturing() -> bool:
	return _gesturing


## Короткий кинематографический пролёт к боссу с возвратом на фуру.
func cinematic_focus(target: Node3D, return_target: Node3D, duration: float = 2.2) -> void:
	if target == null or not is_instance_valid(target):
		return
	_cinematic_target = target
	_cinematic_return = return_target
	_cinematic_timer = duration
	var tween := create_tween()
	tween.tween_property(camera, "fov", 47.0, 0.35)
	tween.tween_interval(maxf(duration - 0.8, 0.2))
	tween.tween_property(camera, "fov", 60.0, 0.45)


## Тряска: оффсеты дрожат пропорционально квадрату trauma, затухают плавно.
func _process(delta: float) -> void:
	if _cinematic_timer > 0.0:
		_cinematic_timer -= delta
		if _cinematic_target != null and is_instance_valid(_cinematic_target):
			_pivot.position = _pivot.position.lerp(_cinematic_target.global_position + Vector3.UP * 1.2, minf(delta * 3.5, 1.0))
			_update_transform()
		if _cinematic_timer <= 0.0:
			if _cinematic_return != null and is_instance_valid(_cinematic_return):
				_pivot.position = _cinematic_return.global_position + Vector3.UP
				_update_transform()
			_cinematic_target = null
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	if _trauma > 0.0:
		var p := _trauma * _trauma
		camera.h_offset = randf_range(-0.24, 0.24) * p * 3.0
		camera.v_offset = randf_range(-0.24, 0.24) * p * 3.0
	elif camera.h_offset != 0.0 or camera.v_offset != 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _update_transform() -> void:
	_pivot.rotation_degrees = Vector3(0, _yaw, 0)
	var pitch_basis := Basis(Vector3.RIGHT, deg_to_rad(_pitch))
	camera.position = pitch_basis * Vector3(0, 0, _distance)
	camera.look_at_from_position(_pivot.position + _pivot.basis * camera.position, _pivot.position + Vector3(0, 1.0, 0))


func _unhandled_input(event: InputEvent) -> void:
	if _cinematic_timer > 0.0:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			if _touches.size() < 2:
				_last_pinch_dist = 0.0
			if _touches.is_empty():
				_gesturing = false
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_yaw -= event.relative.x * 0.25
			_pitch = clampf(_pitch - event.relative.y * 0.15, -75.0, -25.0)
			_gesturing = true
			_update_transform()
		elif _touches.size() == 2:
			var pts := _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
			if _last_pinch_dist > 0.0:
				_distance = clampf(_distance - (d - _last_pinch_dist) * 0.05, 10.0, 34.0)
				_update_transform()
			_last_pinch_dist = d
			_gesturing = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - 1.5, 10.0, 34.0)
			_update_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + 1.5, 10.0, 34.0)
			_update_transform()
