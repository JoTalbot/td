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


func _ready() -> void:
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
	mesh.material_override = m
	add_child(mesh)


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dying:
		queue_free()
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
		"flame":
			Junk.explosion(get_tree().current_scene, global_position, 0.5)
		_:
			pass
	queue_free()
