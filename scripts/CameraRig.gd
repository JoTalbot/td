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


func _ready() -> void:
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


func _update_transform() -> void:
	_pivot.rotation_degrees = Vector3(0, _yaw, 0)
	var pitch_basis := Basis(Vector3.RIGHT, deg_to_rad(_pitch))
	camera.position = pitch_basis * Vector3(0, 0, _distance)
	camera.look_at_from_position(_pivot.position + _pivot.basis * camera.position, _pivot.position + Vector3(0, 1.0, 0))


func _unhandled_input(event: InputEvent) -> void:
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
