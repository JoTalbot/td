extends Node3D
## Игровое поле: сетка, извилистый путь врагов, процедурный неоновый ландшафт.

const GRID_W := 12
const GRID_H := 9
const CELL := 2.0

## Путь врагов в координатах сетки (змейка).
const PATH_CELLS: Array[Vector2i] = [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 3), Vector2i(2, 2),
	Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4),
	Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
	Vector2i(8, 5), Vector2i(8, 4), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3),
	Vector2i(10, 4), Vector2i(10, 5), Vector2i(11, 5),
]

var towers: Dictionary = {}
var _path_set: Dictionary = {}
var path_points: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	for c in PATH_CELLS:
		_path_set[c] = true
		path_points.append(cell_to_world(c))
	_build_ground()
	_build_path_visual()
	_build_portals()


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x - GRID_W * 0.5 + 0.5) * CELL,
		0.0,
		(cell.y - GRID_H * 0.5 + 0.5) * CELL
	)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / CELL + GRID_W * 0.5)),
		int(floor(pos.z / CELL + GRID_H * 0.5))
	)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H


func is_buildable(cell: Vector2i) -> bool:
	return is_inside(cell) and not _path_set.has(cell) and not towers.has(cell)


func tower_at(cell: Vector2i) -> Node3D:
	return towers.get(cell)


func place_tower(cell: Vector2i, tower: Node3D) -> void:
	towers[cell] = tower
	tower.cell = cell
	add_child(tower)
	tower.position = cell_to_world(cell)


func remove_tower(cell: Vector2i) -> void:
	if towers.has(cell):
		towers[cell].queue_free()
		towers.erase(cell)


func center_position() -> Vector3:
	return Vector3.ZERO


func _neon_material(albedo: Color, emission: Color, energy: float = 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	m.metallic = 0.6
	m.roughness = 0.35
	return m


func _build_ground() -> void:
	# Тёмное основание
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(GRID_W * CELL + 4.0, 0.5, GRID_H * CELL + 4.0)
	base.mesh = base_mesh
	base.position.y = -0.3
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.03, 0.04, 0.09)
	base_mat.metallic = 0.8
	base_mat.roughness = 0.25
	base.material_override = base_mat
	add_child(base)

	# Плитки для строительства с лёгкой вариацией высоты и свечения
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(CELL * 0.92, 0.12, CELL * 0.92)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20250815
	for x in GRID_W:
		for y in GRID_H:
			var cell := Vector2i(x, y)
			if _path_set.has(cell):
				continue
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.position = cell_to_world(cell)
			tile.position.y = 0.0
			var shade := rng.randf_range(0.6, 1.0)
			tile.material_override = _neon_material(
				Color(0.05 * shade, 0.07 * shade, 0.14 * shade),
				Color(0.05, 0.12, 0.3) * shade,
				0.35
			)
			add_child(tile)

	# Декоративные парящие кристаллы по краям
	for i in 14:
		var crystal := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.5, rng.randf_range(0.8, 2.2), 0.5)
		crystal.mesh = prism
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(14.0, 20.0)
		crystal.position = Vector3(cos(angle) * radius, rng.randf_range(0.5, 3.0), sin(angle) * radius)
		crystal.rotation_degrees = Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 360), rng.randf_range(-15, 15))
		var hue := rng.randf_range(0.5, 0.9)
		crystal.material_override = _neon_material(
			Color.from_hsv(hue, 0.8, 0.3),
			Color.from_hsv(hue, 0.9, 1.0),
			2.5
		)
		add_child(crystal)


func _build_path_visual() -> void:
	var path_mesh := BoxMesh.new()
	path_mesh.size = Vector3(CELL, 0.08, CELL)
	var mat := _neon_material(Color(0.1, 0.05, 0.2), Color(0.5, 0.15, 1.0), 0.9)
	for c in PATH_CELLS:
		var seg := MeshInstance3D.new()
		seg.mesh = path_mesh
		seg.position = cell_to_world(c)
		seg.position.y = 0.02
		seg.material_override = mat
		add_child(seg)

	# Светящиеся направляющие линии по центру пути
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.25, 0.1, 0.25)
	var line_mat := _neon_material(Color(1, 1, 1), Color(0.8, 0.4, 1.0), 3.0)
	for i in range(path_points.size() - 1):
		var a := path_points[i]
		var b := path_points[i + 1]
		for j in 3:
			var dot := MeshInstance3D.new()
			dot.mesh = line_mesh
			dot.position = a.lerp(b, (j + 0.5) / 3.0)
			dot.position.y = 0.08
			dot.material_override = line_mat
			add_child(dot)


func _build_portals() -> void:
	var entry := _make_portal(Color(1.0, 0.2, 0.4))
	entry.position = path_points[0] + Vector3(-1.0, 1.2, 0.0)
	add_child(entry)

	var exit := _make_portal(Color(0.2, 0.9, 1.0))
	exit.position = path_points[path_points.size() - 1] + Vector3(1.0, 1.2, 0.0)
	add_child(exit)


func _make_portal(color: Color) -> MeshInstance3D:
	var portal := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.3
	portal.mesh = torus
	portal.rotation_degrees = Vector3(0, 0, 90)
	portal.material_override = _neon_material(color * 0.3, color, 3.5)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 6.0
	portal.add_child(light)
	return portal
