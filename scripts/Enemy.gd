extends Node3D
## Враг: движется по пути, имеет полоску HP, эффекты замедления и смерти.

signal died(reward: int)
signal reached_base

var max_hp := 50
var hp := 50
var base_speed := 3.0
var reward := 10
var damage_to_base := 1
var enemy_color := Color(1.0, 0.3, 0.3)
var is_boss := false
var is_dying := false

var path: PackedVector3Array
var progress := 0.0
var _slow_multiplier := 1.0
var _slow_timer := 0.0

var _body: MeshInstance3D
var _hp_bar: MeshInstance3D
var _hp_mat: StandardMaterial3D
var _bob_phase := 0.0


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_bob_phase = randf() * TAU
	_build_visual()
	if path.size() > 0:
		global_position = path[0]


func _build_visual() -> void:
	_body = MeshInstance3D.new()
	if is_boss:
		var s := SphereMesh.new()
		s.radius = 0.7
		s.height = 1.4
		_body.mesh = s
	else:
		var caps := CapsuleMesh.new()
		caps.radius = 0.35
		caps.height = 1.0
		_body.mesh = caps
	var m := StandardMaterial3D.new()
	m.albedo_color = enemy_color * 0.4
	m.emission_enabled = true
	m.emission = enemy_color
	m.emission_energy_multiplier = 1.8
	m.metallic = 0.5
	m.roughness = 0.4
	_body.material_override = m
	_body.position.y = 0.7
	add_child(_body)

	# Полоска HP (billboard)
	_hp_bar = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.12)
	_hp_bar.mesh = quad
	_hp_mat = StandardMaterial3D.new()
	_hp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_mat.albedo_color = Color(0.2, 1.0, 0.4)
	_hp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.material_override = _hp_mat
	_hp_bar.position.y = 1.7
	add_child(_hp_bar)


func take_damage(amount: int, state: Node) -> void:
	if is_dying:
		return
	hp -= amount
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.scale.x = maxf(ratio, 0.01)
	_hp_mat.albedo_color = Color(1.0 - ratio * 0.8, ratio, 0.25)
	# Вспышка при попадании
	var flash := _body.material_override as StandardMaterial3D
	flash.emission_energy_multiplier = 4.0
	var tw := create_tween()
	tw.tween_property(flash, "emission_energy_multiplier", 1.8, 0.15)
	if hp <= 0:
		_die(state)


func apply_slow(factor: float, duration: float) -> void:
	_slow_multiplier = minf(_slow_multiplier, factor)
	_slow_timer = maxf(_slow_timer, duration)
	var m := _body.material_override as StandardMaterial3D
	m.albedo_color = Color(0.4, 0.6, 1.0) * 0.5


func _die(state: Node) -> void:
	is_dying = true
	if state != null:
		state.earn(reward)
	died.emit(reward)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y + 1.5, 0.3)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if is_dying or path.size() < 2:
		return
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_multiplier = 1.0
			var m := _body.material_override as StandardMaterial3D
			m.albedo_color = enemy_color * 0.4
	var speed := base_speed * _slow_multiplier
	progress += speed * delta

	var total := 0.0
	var moved := false
	for i in range(path.size() - 1):
		var seg_len := path[i].distance_to(path[i + 1])
		if progress <= total + seg_len:
			var t := (progress - total) / seg_len
			var pos := path[i].lerp(path[i + 1], t)
			_bob_phase += delta * 8.0
			pos.y = 0.15 + sin(_bob_phase) * 0.08
			var dir := path[i + 1] - path[i]
			global_position = pos
			if dir.length() > 0.01:
				_body.rotation.y = atan2(dir.x, dir.z)
			moved = true
			break
		total += seg_len
	if not moved:
		reached_base.emit()
		queue_free()
