extends Node3D
## Самонаводящийся светящийся снаряд с эффектами (замедление, цепная молния).

var target: Node3D
var damage: int
var speed := 22.0
var color: Color
var kind: String
var slow_factor := -1.0
var chain := 0
var state: Node

var _trail_timer := 0.0


func configure(p_target: Node3D, st: Dictionary, p_color: Color, p_kind: String, p_state: Node) -> void:
	target = p_target
	damage = st["damage"]
	color = p_color
	kind = p_kind
	state = p_state
	slow_factor = st.get("slow", -1.0)
	chain = st.get("chain", 0)
	if kind == "rail":
		speed = 40.0


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.15
	s.height = 0.3
	mesh.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	mesh.material_override = m
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dying:
		queue_free()
		return
	var to_target := target.global_position + Vector3.UP * 0.5 - global_position
	var step := speed * delta
	if to_target.length() <= step:
		_hit()
		return
	global_position += to_target.normalized() * step
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_spawn_trail()
		_trail_timer = 0.03


func _spawn_trail() -> void:
	var puff := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.16
	puff.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material_override = m
	get_tree().current_scene.add_child(puff)
	puff.global_position = global_position
	var tw := puff.create_tween()
	tw.tween_property(puff, "scale", Vector3.ONE * 0.05, 0.35)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(puff.queue_free)


func _hit() -> void:
	if is_instance_valid(target) and not target.is_dying:
		target.take_damage(damage, state)
		if slow_factor > 0.0:
			target.apply_slow(slow_factor, 2.0)
		if chain > 0:
			_chain_lightning()
	_explosion()
	queue_free()


func _chain_lightning() -> void:
	var hit_list: Array = [target]
	var current: Node3D = target
	var dmg := damage
	for i in chain:
		var next: Node3D = null
		var best := 4.0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.is_dying or hit_list.has(enemy):
				continue
			var d: float = current.global_position.distance_to(enemy.global_position)
			if d < best:
				best = d
				next = enemy
		if next == null:
			break
		dmg = int(dmg * 0.7)
		_draw_arc(current.global_position, next.global_position)
		next.take_damage(dmg, state)
		hit_list.append(next)
		current = next


func _draw_arc(a: Vector3, b: Vector3) -> void:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.5)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.3)
	m.emission_energy_multiplier = 5.0
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, m)
	var rng := RandomNumberGenerator.new()
	for i in 7:
		var t := i / 6.0
		var p := a.lerp(b, t) + Vector3.UP * 0.5
		if i > 0 and i < 6:
			p += Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.4), rng.randf_range(-0.3, 0.3))
		im.surface_add_vertex(p)
	im.surface_end()
	get_tree().current_scene.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(mi.queue_free)


func _explosion() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 7.0
	mat.gravity = Vector3(0, -4, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	mat.color = color
	particles.process_material = mat
	var pm := SphereMesh.new()
	pm.radius = 0.06
	pm.height = 0.12
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 3.0
	pm.material = draw_mat
	particles.draw_pass_1 = pm
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	var tw := particles.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(particles.queue_free)
