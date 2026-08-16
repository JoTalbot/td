extends Node3D
## Динамическая визуальная погода: ясный зной, пыльный фронт и пеплопад.
## Боевые параметры не меняет — этим занимается RoadEvents.

signal announced(text: String)

const Junk := preload("res://scripts/Junk.gd")

var env: Environment
var truck: Node3D
var active := false
var current := "clear"
var _timer := 22.0
var _rng := RandomNumberGenerator.new()
var _ash: GPUParticles3D


func setup(p_env: Environment, p_truck: Node3D) -> void:
	env = p_env
	truck = p_truck
	_rng.seed = 0xA57F11
	if Junk.quality_high:
		_build_ash()


func set_active(on: bool) -> void:
	active = on
	if _ash != null:
		_ash.emitting = on and current == "ash"


func _process(delta: float) -> void:
	if truck != null:
		global_position = truck.global_position + Vector3(0, 10, 0)
	if not active or env == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(28.0, 45.0)
		var choices := ["clear", "dust", "ash"] if Junk.quality_high else ["clear", "dust"]
		var next: String = choices[_rng.randi() % choices.size()]
		if next == current:
			next = choices[(choices.find(next) + 1) % choices.size()]
		_apply(next)


func _apply(id: String) -> void:
	current = id
	var fog_color := Color(0.82, 0.52, 0.25)
	var fog_density := 0.009
	var saturation := 1.18
	var sky_top := Color(0.20, 0.29, 0.36)
	var sky_horizon := Color(1.0, 0.58, 0.26)
	match id:
		"dust":
			fog_color = Color(0.68, 0.38, 0.16)
			fog_density = 0.018 if Junk.quality_high else 0.011
			saturation = 1.05
			sky_top = Color(0.34, 0.24, 0.18)
			sky_horizon = Color(0.92, 0.43, 0.13)
			announced.emit("ПЫЛЬНЫЙ ФРОНТ накрыл дорогу")
		"ash":
			fog_color = Color(0.28, 0.24, 0.23)
			fog_density = 0.014
			saturation = 0.78
			sky_top = Color(0.10, 0.11, 0.14)
			sky_horizon = Color(0.52, 0.22, 0.12)
			announced.emit("ПЕПЛОПАД: небо над пустошью почернело")
		_:
			announced.emit("Пыль рассеялась — снова ясный зной")
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(env, "fog_light_color", fog_color, 2.8)
	tween.tween_property(env, "fog_density", fog_density, 2.8)
	tween.tween_property(env, "adjustment_saturation", saturation, 2.8)
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky_mat != null:
		tween.tween_property(sky_mat, "sky_top_color", sky_top, 2.8)
		tween.tween_property(sky_mat, "sky_horizon_color", sky_horizon, 2.8)
	if _ash != null:
		_ash.emitting = id == "ash"


func _build_ash() -> void:
	_ash = GPUParticles3D.new()
	_ash.amount = 90
	_ash.lifetime = 3.5
	_ash.visibility_aabb = AABB(Vector3(-18, -14, -18), Vector3(36, 28, 36))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12, 1, 12)
	process.direction = Vector3(0.25, -1.0, -0.4)
	process.spread = 18.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.0
	process.gravity = Vector3(0.4, -1.2, -1.0)
	process.scale_min = 0.04
	process.scale_max = 0.12
	process.color = Color(0.16, 0.14, 0.13, 0.7)
	_ash.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.16)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.12, 0.11, 0.1, 0.65)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	_ash.draw_pass_1 = mesh
	_ash.emitting = false
	add_child(_ash)
