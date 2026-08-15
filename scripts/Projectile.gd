extends Node3D
## Снаряды: пуля-трассер, струя огня, гарпун с тросом, фугасный снаряд.

const Junk := preload("res://scripts/Junk.gd")

var target: Node3D
var damage: int
var speed := 30.0
var color: Color
var kind: String
var slow_factor := -1.0
var splash := 0.0
var state: Node

# Баллистика мортиры: летим по дуге в точку с упреждением
var _lob_from := Vector3.ZERO
var _lob_to := Vector3.ZERO
var _lob_t := 0.0
var _lob_time := 0.0
var _lob_height := 4.0


func configure(p_target: Node3D, st: Dictionary, p_color: Color, p_kind: String, p_state: Node) -> void:
	target = p_target
	damage = st["damage"]
	color = p_color
	kind = p_kind
	state = p_state
	slow_factor = st.get("slow", -1.0)
	splash = st.get("splash", 0.0)
	match kind:
		"bullet": speed = 45.0
		"flame": speed = 16.0
		"harpoon": speed = 34.0
		"shell": speed = 26.0
		"mortar": speed = 0.0   # движение дугой, не по прямой


func _ready() -> void:
	add_to_group("projectiles")   # для бюджетов/замеров производительности
	var mesh := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	match kind:
		"bullet":
			var box := BoxMesh.new()
			box.size = Vector3(0.06, 0.06, 0.5)
			mesh.mesh = box
		"flame":
			var s := SphereMesh.new()
			s.radius = 0.22
			s.height = 0.44
			mesh.mesh = s
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.8
		"harpoon":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.06
			c.height = 0.7
			mesh.mesh = c
			mesh.rotation_degrees = Vector3(-90, 0, 0)
			m.emission_energy_multiplier = 0.4
		"shell":
			var s2 := SphereMesh.new()
			s2.radius = 0.14
			s2.height = 0.28
			mesh.mesh = s2
		"mortar":
			# Самодельная мина: цилиндричек с хвостовым оперением
			var s3 := SphereMesh.new()
			s3.radius = 0.2
			s3.height = 0.4
			mesh.mesh = s3
	mesh.material_override = m
	add_child(mesh)
	if kind == "mortar":
		var fin := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.3, 0.3, 0.04)
		fin.mesh = fm
		fin.position = Vector3(0, 0.3, 0)
		fin.material_override = m
		mesh.add_child(fin)


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dying:
		queue_free()
		return
	if kind == "mortar":
		_lob_step(delta)
		return
	var aim := target.global_position + Vector3.UP * 0.6
	var to_target := aim - global_position
	var step := speed * delta
	if to_target.length() <= step:
		_hit()
		return
	look_at(aim, Vector3.UP)
	global_position += to_target.normalized() * step
	if kind == "flame":
		scale = scale.lerp(Vector3.ONE * 1.8, delta * 3.0)


## Полёт мины по дуге: фиксируем точку цели с упреждением, прилет — сплэш.
func _lob_start() -> void:
	_lob_from = global_position
	# Упреждение: цель едет к фуре — бьём чуть вперёд по курсу
	_lob_to = target.global_position + Vector3.UP * 0.4
	if "chase_speed" in target:
		var fly_time := clampf(_lob_from.distance_to(_lob_to) / 22.0, 0.6, 1.4)
		var dir: Vector3 = -Vector3(global_position - _lob_to).normalized()
		_lob_to += Vector3(dir.x, 0, dir.z) * target.chase_speed * fly_time * 0.4
		_lob_time = fly_time
	else:
		_lob_time = 1.0
	_lob_height = clampf(_lob_from.distance_to(_lob_to) * 0.22, 3.0, 7.0)
	_lob_t = 0.0


func _lob_step(delta: float) -> void:
	if _lob_time <= 0.0:
		_lob_start()
	_lob_t += delta / _lob_time
	if _lob_t >= 1.0:
		global_position = _lob_to
		_hit()
		return
	var pos := _lob_from.lerp(_lob_to, _lob_t)
	pos.y += sin(_lob_t * PI) * _lob_height
	global_position = pos
	# Мина переворачивается в полёте
	rotation.x += delta * 6.0


func _hit() -> void:
	if is_instance_valid(target) and not target.is_dying:
		target.take_damage(damage, state)
		if slow_factor > 0.0:
			target.apply_slow(slow_factor, 1.6)
		if splash > 0.0:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy == target or not is_instance_valid(enemy) or enemy.is_dying:
					continue
				if enemy.global_position.distance_to(global_position) <= splash:
					enemy.take_damage(int(damage * 0.5), state)
	match kind:
		"shell":
			Junk.explosion(get_tree().current_scene, global_position, 1.2)
		"mortar":
			Junk.explosion(get_tree().current_scene, global_position, 1.8)
		"flame":
			Junk.explosion(get_tree().current_scene, global_position, 0.5)
		_:
			pass
	queue_free()
