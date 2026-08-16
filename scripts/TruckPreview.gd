extends SubViewportContainer
## Вращаемый 3D-предпросмотр корпуса и косметики мастерства в Шоуруме.

const Truck := preload("res://scripts/Truck.gd")

var _pivot: Node3D
var _truck: Node3D


func setup(hull_id: String, mastered_count: int, cosmetics: Dictionary) -> void:
	custom_minimum_size = Vector2(640, 230)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_truck.apply_route_cosmetics(mastered_count, cosmetics)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.4
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(9.5, 6.2, 11.5)
	viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 1.2, 0))


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation.y += delta * 0.35
