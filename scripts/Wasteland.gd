extends Node3D
## Несущаяся навстречу пустошь: дорога, скалы, кости машин, столбы.
## Мир движется назад мимо неподвижного грузовика (+Z -> -Z).

const Junk := preload("res://scripts/Junk.gd")

const SCROLL_SPEED := 22.0
const TILE_LEN := 60.0
const TILE_COUNT := 3

var speed_scale := 1.0
var _tiles: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0xD15E7
	# Бесконечный песок под всем
	var sand := MeshInstance3D.new()
	var sand_mesh := PlaneMesh.new()
	sand_mesh.size = Vector2(400, 400)
	sand.mesh = sand_mesh
	sand.position.y = -0.05
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.52, 0.31, 0.16) if Junk.quality_high else Color(0.7, 0.5, 0.3)
	sand_mat.roughness = 1.0
	sand.material_override = sand_mat
	add_child(sand)
	if Junk.quality_high:
		_build_distant_mesas()

	for i in TILE_COUNT:
		var tile := _make_tile()
		tile.position.z = i * TILE_LEN
		add_child(tile)
		_tiles.append(tile)


func _build_distant_mesas() -> void:
	# Огромный пыльный диск солнца — эмиссия без дополнительного источника света.
	var sun_disc := MeshInstance3D.new()
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 7.5
	sun_mesh.height = 15.0
	sun_disc.mesh = sun_mesh
	sun_disc.position = Vector3(-58, 38, 105)
	var sun_mat := StandardMaterial3D.new()
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.albedo_color = Color(1.0, 0.38, 0.11)
	sun_mat.emission_enabled = true
	sun_mat.emission = Color(1.0, 0.22, 0.045)
	sun_mat.emission_energy_multiplier = 2.8
	sun_disc.material_override = sun_mat
	add_child(sun_disc)
	# Силуэты на горизонте дают глубину без теней и дорогих текстур.
	var mesa_mat := Junk.metal(Color(0.25, 0.105, 0.055), 1.0, 0.0)
	for i in 14:
		var mesa := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		var h := _rng.randf_range(10.0, 28.0)
		mesh.size = Vector3(_rng.randf_range(12.0, 30.0), h, _rng.randf_range(8.0, 18.0))
		mesa.mesh = mesh
		var side := -1.0 if i % 2 == 0 else 1.0
		mesa.position = Vector3(side * _rng.randf_range(42.0, 85.0), h * 0.45 - 1.0, _rng.randf_range(-90.0, 130.0))
		mesa.rotation_degrees.y = _rng.randf_range(-25.0, 25.0)
		mesa.material_override = mesa_mat
		add_child(mesa)


func _make_tile() -> Node3D:
	var tile := Node3D.new()

	# Полотно дороги
	var road := MeshInstance3D.new()
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(11.0, TILE_LEN)
	road.mesh = road_mesh
	road.position.y = 0.0
	road.material_override = Junk.metal(Color(0.24, 0.18, 0.14) if Junk.quality_high else Color(0.42, 0.34, 0.27), 1.0, 0.0)
	tile.add_child(road)

	# Колеи
	for x in [-2.2, 2.2]:
		var track := MeshInstance3D.new()
		var tm := PlaneMesh.new()
		tm.size = Vector2(1.0, TILE_LEN)
		track.mesh = tm
		track.position = Vector3(x, 0.01, 0)
		track.material_override = Junk.metal(Color(0.25, 0.19, 0.14), 1.0, 0.0)
		tile.add_child(track)
	# Разбитые обочины отделяют колею от пустыни.
	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := PlaneMesh.new()
		shoulder_mesh.size = Vector2(2.4, TILE_LEN)
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(side * 6.6, -0.015, 0)
		shoulder.material_override = Junk.metal(Color(0.38, 0.22, 0.12), 1.0, 0.0)
		tile.add_child(shoulder)
	if Junk.quality_high:
		# Трещины, заплаты и сорванные куски асфальта.
		for i in 12:
			var crack_len := _rng.randf_range(0.7, 2.5)
			Junk.box(tile, Vector3(_rng.randf_range(0.035, 0.08), 0.025, crack_len),
				Vector3(_rng.randf_range(-4.8, 4.8), 0.018, _rng.randf_range(0.0, TILE_LEN)),
				Junk.metal(Color(0.095, 0.065, 0.045), 1.0, 0.0), Vector3(0, _rng.randf_range(-55, 55), 0))
		for i in 5:
			Junk.box(tile, Vector3(_rng.randf_range(0.8, 2.0), 0.03, _rng.randf_range(0.5, 1.6)),
				Vector3(_rng.randf_range(-4.2, 4.2), 0.02, _rng.randf_range(0.0, TILE_LEN)),
				Junk.metal(Color(0.31, 0.23, 0.17), 1.0, 0.0), Vector3(0, _rng.randf_range(0, 360), 0))

	# Скалы и месы по сторонам
	var rock_count := 14 if Junk.quality_high else 7
	for i in rock_count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var rock := MeshInstance3D.new()
		var rm := PrismMesh.new()
		var h := _rng.randf_range(2.0, 9.0)
		rm.size = Vector3(_rng.randf_range(3.0, 9.0), h, _rng.randf_range(2.5, 6.0))
		rock.mesh = rm
		rock.position = Vector3(side * _rng.randf_range(11.0, 30.0), h * 0.5 - 0.2, _rng.randf_range(0.0, TILE_LEN))
		rock.rotation_degrees = Vector3(0, _rng.randf_range(0, 360), _rng.randf_range(-4, 4))
		rock.material_override = Junk.metal(Color(0.6, 0.42, 0.28).lightened(_rng.randf_range(-0.08, 0.08)), 1.0, 0.0)
		tile.add_child(rock)

	# Ржавые остовы машин
	var wreck_count := 4 if Junk.quality_high else 2
	for i in wreck_count:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var wreck := Node3D.new()
		wreck.position = Vector3(side * _rng.randf_range(8.0, 16.0), 0, _rng.randf_range(0.0, TILE_LEN))
		wreck.rotation_degrees.y = _rng.randf_range(0, 360)
		Junk.box(wreck, Vector3(1.8, 0.6, 3.4), Vector3(0, 0.35, 0), Junk.rust(_rng), Vector3(0, 0, _rng.randf_range(-10, 10)))
		Junk.box(wreck, Vector3(1.6, 0.5, 1.4), Vector3(0, 0.8, -0.4), Junk.rust(_rng))
		tile.add_child(wreck)

	# Покосившиеся столbы с проводами
	var pole_count := 3 if Junk.quality_high else 1
	for i in pole_count:
		var pole := Junk.cyl(tile, 0.1, 5.0, Vector3(-9.0, 2.3, i * (TILE_LEN * 0.5) + _rng.randf_range(0, 8)), Junk.metal(Color(0.3, 0.22, 0.15), 0.95, 0.1), Vector3(0, 0, _rng.randf_range(-8, 8)))
		Junk.box(pole, Vector3(1.6, 0.12, 0.12), Vector3(0, 2.1, 0), Junk.metal(Color(0.3, 0.22, 0.15), 0.95, 0.1))

	# Кустики перекати-поля
	var bush_count := 8 if Junk.quality_high else 3
	for i in bush_count:
		var bush := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = _rng.randf_range(0.2, 0.5)
		bm.height = bm.radius * 1.6
		bush.mesh = bm
		bush.position = Vector3(_rng.randf_range(-25.0, 25.0), bm.radius * 0.5, _rng.randf_range(0.0, TILE_LEN))
		if absf(bush.position.x) < 6.0:
			bush.position.x = signf(bush.position.x) * 7.0
		bush.material_override = Junk.metal(Color(0.38, 0.26, 0.12), 1.0, 0.0)
		tile.add_child(bush)
	if Junk.quality_high:
		# Самодельные дорожные вехи, черепа и канистры оживляют передний план.
		for i in 6:
			var side := -1.0 if i % 2 == 0 else 1.0
			var z := 5.0 + i * 9.0 + _rng.randf_range(-2.0, 2.0)
			Junk.cyl(tile, 0.045, 1.3, Vector3(side * 6.1, 0.6, z), Junk.metal(Color(0.22, 0.14, 0.09), 0.9, 0.45), Vector3(0, 0, side * 5.0))
			Junk.box(tile, Vector3(0.42, 0.28, 0.08), Vector3(side * 6.1, 1.18, z), Junk.metal(Color(0.67, 0.26, 0.08), 0.75, 0.35), Vector3(0, _rng.randf_range(-12, 12), side * 5.0))
		for i in 3:
			var can_side := -1.0 if _rng.randf() < 0.5 else 1.0
			Junk.box(tile, Vector3(0.38, 0.55, 0.22), Vector3(can_side * _rng.randf_range(7.0, 10.0), 0.27, _rng.randf_range(0, TILE_LEN)), Junk.rust(_rng), Vector3(0, _rng.randf_range(0, 360), _rng.randf_range(-8, 8)))

	return tile


func _process(delta: float) -> void:
	for tile in _tiles:
		tile.position.z -= SCROLL_SPEED * speed_scale * delta
		if tile.position.z < -TILE_LEN * 1.5:
			tile.position.z += TILE_LEN * TILE_COUNT
