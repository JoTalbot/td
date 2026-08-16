extends SubViewportContainer
## Вращаемый 3D-предпросмотр корпуса и косметики мастерства в Шоуруме.
## Drag вращает фуру, pinch/колесо меняют приближение.

const Truck := preload("res://scripts/Truck.gd")

var _pivot: Node3D
var _truck: Node3D
var _camera: Camera3D
var _distance := 15.8
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _mouse_dragging := false
var _manual_timer := 0.0


func setup(hull_id: String, mastered_count: int, cosmetics: Dictionary, paint: String = "rust") -> void:
	custom_minimum_size = Vector2(640, 230)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_preview_input)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.055, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.48, 0.3)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	viewport.add_child(env)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_truck = Truck.new()
	_truck.hull_id = hull_id
	_pivot.add_child(_truck)
	_truck.apply_paint_scheme(paint)
	_truck.apply_route_cosmetics(mastered_count, cosmetics)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.4
	viewport.add_child(light)
	_camera = Camera3D.new()
	viewport.add_child(_camera)
	_update_camera()


func _process(delta: float) -> void:
	_manual_timer = maxf(_manual_timer - delta, 0.0)
	if _pivot != null and _manual_timer <= 0.0:
		_pivot.rotation.y += delta * 0.35


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_distance = _current_pinch_distance()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		_manual_timer = 2.5
		if _touches.size() >= 2:
			var distance := _current_pinch_distance()
			if _pinch_distance > 0.0:
				_distance = clampf(_distance - (distance - _pinch_distance) * 0.025, 10.0, 23.0)
				_update_camera()
			_pinch_distance = distance
		elif _pivot != null:
			_pivot.rotation.y += event.relative.x * 0.012
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(10.0, _distance - 1.0)
			_update_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(23.0, _distance + 1.0)
			_update_camera()
		_manual_timer = 2.5
	elif event is InputEventMouseMotion and _mouse_dragging and _pivot != null:
		_pivot.rotation.y += event.relative.x * 0.012
		_manual_timer = 2.5


func _current_pinch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var points := _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _update_camera() -> void:
	if _camera == null:
		return
	var direction := Vector3(0.6, 0.38, 0.72).normalized()
	_camera.position = direction * _distance
	_camera.look_at_from_position(_camera.position, Vector3(0, 1.2, 0))
