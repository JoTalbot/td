extends Node3D
## Орудие на слоте грузовика: самодельный визуал, поиск цели, стрельба.

const WeaponData := preload("res://scripts/WeaponData.gd")
const Projectile := preload("res://scripts/Projectile.gd")
const Junk := preload("res://scripts/Junk.gd")

var type_id: String
var level: int = 0
var slot_index: int = -1
var state: Node

var _cooldown := 0.0
var _turret: Node3D
var _flash: OmniLight3D
var _select_ring: MeshInstance3D


func setup(p_type: String, p_state: Node) -> void:
	type_id = p_type
	state = p_state


func _def() -> Dictionary:
	return WeaponData.DEFS[type_id]


func stats() -> Dictionary:
	return _def()["levels"][level]


func upgrade_cost() -> int:
	return stats()["upgrade"]


func sell_value() -> int:
	var total: int = _def()["cost"]
	for i in level:
		total += _def()["levels"][i]["upgrade"]
	return int(total * 0.6)


func upgrade() -> void:
	level = mini(level + 1, _def()["levels"].size() - 1)
	_turret.scale = Vector3.ONE * (1.0 + level * 0.16)


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	# Станина
	Junk.cyl(self, 0.32, 0.25, Vector3(0, 0.15, 0), Junk.metal(Color(0.3, 0.27, 0.22), 0.8, 0.6))

	_turret = Node3D.new()
	_turret.position.y = 0.42
	add_child(_turret)

	match type_id:
		"mgun":
			# Спарка стволов + короб с лентой
			Junk.box(_turret, Vector3(0.45, 0.3, 0.5), Vector3(0, 0.1, 0), Junk.metal(Color(0.28, 0.26, 0.22), 0.75, 0.65))
			Junk.cyl(_turret, 0.05, 0.9, Vector3(-0.1, 0.15, 0.55), Junk.metal(Color(0.15, 0.15, 0.15), 0.5, 0.85), Vector3(90, 0, 0))
			Junk.cyl(_turret, 0.05, 0.9, Vector3(0.1, 0.15, 0.55), Junk.metal(Color(0.15, 0.15, 0.15), 0.5, 0.85), Vector3(90, 0, 0))
			Junk.box(_turret, Vector3(0.2, 0.25, 0.3), Vector3(0.3, 0.1, -0.1), Junk.metal(Color(0.35, 0.3, 0.15), 0.8, 0.5))
		"flamer":
			# Баллон + раструб
			Junk.cyl(_turret, 0.22, 0.55, Vector3(0, 0.15, -0.15), Junk.metal(Color(0.6, 0.2, 0.12), 0.6, 0.6), Vector3(90, 0, 0))
			Junk.cyl(_turret, 0.09, 0.6, Vector3(0, 0.15, 0.4), Junk.metal(Color(0.2, 0.2, 0.2), 0.6, 0.8), Vector3(90, 0, 0))
			var nozzle := MeshInstance3D.new()
			var nm := CylinderMesh.new()
			nm.top_radius = 0.16
			nm.bottom_radius = 0.08
			nm.height = 0.25
			nozzle.mesh = nm
			nozzle.position = Vector3(0, 0.15, 0.75)
			nozzle.rotation_degrees = Vector3(90, 0, 0)
			nozzle.material_override = Junk.metal(Color(0.12, 0.12, 0.12), 0.7, 0.7)
			_turret.add_child(nozzle)
		"harpoon":
			# Арбалетная рама + гарпун
			Junk.box(_turret, Vector3(0.7, 0.12, 0.2), Vector3(0, 0.1, 0.15), Junk.metal(Color(0.35, 0.28, 0.18), 0.85, 0.4))
			Junk.box(_turret, Vector3(0.1, 0.1, 1.0), Vector3(0, 0.18, 0.2), Junk.metal(Color(0.3, 0.3, 0.3), 0.6, 0.75))
			Junk.spike(_turret, 0.07, 0.3, Vector3(0, 0.18, 0.8), Vector3(90, 0, 0))
		"cannon":
			# Толстый ствол + щит
			Junk.box(_turret, Vector3(0.55, 0.4, 0.55), Vector3(0, 0.15, -0.05), Junk.metal(Color(0.32, 0.3, 0.26), 0.8, 0.6))
			var barrel := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.13
			bm.bottom_radius = 0.17
			bm.height = 1.1
			barrel.mesh = bm
			barrel.position = Vector3(0, 0.2, 0.6)
			barrel.rotation_degrees = Vector3(90, 0, 0)
			barrel.material_override = Junk.metal(Color(0.18, 0.18, 0.18), 0.55, 0.85)
			_turret.add_child(barrel)
			Junk.box(_turret, Vector3(0.8, 0.55, 0.08), Vector3(0, 0.25, 0.32), Junk.rust(RandomNumberGenerator.new()))

	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.75, 0.35)
	_flash.light_energy = 0.0
	_flash.omni_range = 3.5
	_flash.position = Vector3(0, 0.2, 0.8)
	_turret.add_child(_flash)

	_select_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.58
	_select_ring.mesh = ring
	var rm2 := StandardMaterial3D.new()
	rm2.albedo_color = Color(1.0, 0.8, 0.3)
	rm2.emission_enabled = true
	rm2.emission = Color(1.0, 0.75, 0.2)
	rm2.emission_energy_multiplier = 1.2
	rm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_select_ring.material_override = rm2
	_select_ring.position.y = 0.1
	_select_ring.visible = false
	add_child(_select_ring)


func set_selected(on: bool) -> void:
	_select_ring.visible = on


func _process(delta: float) -> void:
	_flash.light_energy = maxf(_flash.light_energy - delta * 10.0, 0.0)
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	var aim := target.global_position + Vector3.UP * 0.6
	var flat := aim
	flat.y = _turret.global_position.y
	if _turret.global_position.distance_to(flat) > 0.1:
		_turret.look_at(flat, Vector3.UP)
		_turret.rotate_object_local(Vector3.UP, PI)  # стволы построены вдоль +Z
	_shoot(target)
	_cooldown = 1.0 / float(stats()["fire_rate"])


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	var r: float = stats()["range"]
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d <= r and d < best_d:
			best_d = d
			best = enemy
	return best


func _shoot(target: Node3D) -> void:
	_flash.light_energy = 2.5
	var proj: Node3D = Projectile.new()
	proj.configure(target, stats(), _def()["color"], _def()["kind"], state)
	get_tree().current_scene.add_child(proj)
	proj.global_position = _turret.global_position + _turret.global_transform.basis.z * 0.8 + Vector3.UP * 0.2
