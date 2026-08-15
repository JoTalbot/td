extends Node3D
## Башня: процедурный неоновый визуал, поиск цели, стрельба, апгрейды.

const TowerData := preload("res://scripts/TowerData.gd")
const Projectile := preload("res://scripts/Projectile.gd")

var type_id: String
var level: int = 0
var cell: Vector2i
var board: Node3D
var state: Node

var _cooldown := 0.0
var _head: Node3D
var _ring: MeshInstance3D
var _range_indicator: MeshInstance3D
var _muzzle_light: OmniLight3D


func setup(p_type: String, p_board: Node3D, p_state: Node) -> void:
	type_id = p_type
	board = p_board
	state = p_state


func _def() -> Dictionary:
	return TowerData.DEFS[type_id]


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
	_refresh_visual_scale()


func _ready() -> void:
	_build_visual()


func _neon_mat(albedo: Color, emission: Color, energy: float = 1.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	m.metallic = 0.7
	m.roughness = 0.3
	return m


func _build_visual() -> void:
	var color: Color = _def()["color"]

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.55
	base_mesh.bottom_radius = 0.75
	base_mesh.height = 0.5
	base.mesh = base_mesh
	base.position.y = 0.3
	base.material_override = _neon_mat(Color(0.08, 0.09, 0.16), color * 0.4, 0.8)
	add_child(base)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	_ring.mesh = torus
	_ring.position.y = 0.6
	_ring.material_override = _neon_mat(color * 0.3, color, 2.5)
	add_child(_ring)

	_head = Node3D.new()
	_head.position.y = 1.1
	add_child(_head)

	var body := MeshInstance3D.new()
	match type_id:
		"pulse":
			var s := SphereMesh.new()
			s.radius = 0.4
			s.height = 0.8
			body.mesh = s
		"rail":
			var b := BoxMesh.new()
			b.size = Vector3(0.3, 0.3, 1.5)
			body.mesh = b
			body.position.z = -0.3
		"cryo":
			var p := PrismMesh.new()
			p.size = Vector3(0.7, 0.9, 0.7)
			body.mesh = p
		"tesla":
			var c := CylinderMesh.new()
			c.top_radius = 0.08
			c.bottom_radius = 0.35
			c.height = 1.2
			body.mesh = c
			body.position.y = 0.2
	body.material_override = _neon_mat(color * 0.35, color, 2.2)
	_head.add_child(body)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = color
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 4.0
	_head.add_child(_muzzle_light)

	_range_indicator = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	_range_indicator.mesh = disc
	var rmat := _neon_mat(Color(color.r, color.g, color.b, 0.12), color, 0.5)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color.a = 0.12
	_range_indicator.material_override = rmat
	_range_indicator.position.y = 0.05
	_range_indicator.visible = false
	add_child(_range_indicator)
	_refresh_visual_scale()


func _refresh_visual_scale() -> void:
	var s := 1.0 + level * 0.18
	if _head:
		_head.scale = Vector3.ONE * s
	if _range_indicator:
		var r: float = stats()["range"]
		_range_indicator.scale = Vector3(r, 1.0, r)


func set_selected(on: bool) -> void:
	_range_indicator.visible = on


func _process(delta: float) -> void:
	_ring.rotate_y(delta * 1.5)
	_muzzle_light.light_energy = maxf(_muzzle_light.light_energy - delta * 8.0, 0.0)
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_head.look_at(target.global_position + Vector3.UP * 0.5, Vector3.UP)
	_shoot(target)
	_cooldown = 1.0 / float(stats()["fire_rate"])


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_progress := -1.0
	var r: float = stats()["range"]
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d <= r and enemy.progress > best_progress:
			best_progress = enemy.progress
			best = enemy
	return best


func _shoot(target: Node3D) -> void:
	_muzzle_light.light_energy = 3.0
	var st := stats()
	var proj: Node3D = Projectile.new()
	proj.configure(target, st, _def()["color"], type_id, state)
	get_tree().current_scene.add_child(proj)
	proj.global_position = _head.global_position
