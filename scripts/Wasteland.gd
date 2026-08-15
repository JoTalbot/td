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
	sand_mat.albedo_color = Color(0.78, 0.6, 0.38)
	sand_mat.roughness = 1.0
	sand.material_override = sand_mat
	add_child(sand)

	for i in TILE_COUNT:
		var tile := _make_tile()
		tile.position.z = i * TILE_LEN
		add_child(tile)
		_tiles.append(tile)


func _make_tile() -> Node3D:
	var tile := Node3D.new()

	# Полотно дороги
	var road := MeshInstance3D.new()
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(11.0, TILE_LEN)
	road.mesh = road_mesh
	road.position.y = 0.0
	road.material_override = Junk.metal(Color(0.45, 0.38, 0.3), 1.0, 0.0)
	tile.add_child(road)

	# Колеи
	for x in [-2.2, 2.2]:
		var track := MeshInstance3D.new()
		var tm := PlaneMesh.new()
		tm.size = Vector2(1.0, TILE_LEN)
		track.mesh = tm
		track.position = Vector3(x, 0.01, 0)
		track.material_override = Junk.metal(Color(0.36, 0.3, 0.23), 1.0, 0.0)
		tile.add_child(track)

	# Скалы и месы по сторонам
	for i in 10:
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
	for i in 3:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var wreck := Node3D.new()
		wreck.position = Vector3(side * _rng.randf_range(8.0, 16.0), 0, _rng.randf_range(0.0, TILE_LEN))
		wreck.rotation_degrees.y = _rng.randf_range(0, 360)
		Junk.box(wreck, Vector3(1.8, 0.6, 3.4), Vector3(0, 0.35, 0), Junk.rust(_rng), Vector3(0, 0, _rng.randf_range(-10, 10)))
		Junk.box(wreck, Vector3(1.6, 0.5, 1.4), Vector3(0, 0.8, -0.4), Junk.rust(_rng))
		tile.add_child(wreck)

	# Покосившиеся столbы с проводами
	for i in 2:
		var pole := Junk.cyl(tile, 0.1, 5.0, Vector3(-9.0, 2.3, i * (TILE_LEN * 0.5) + _rng.randf_range(0, 8)), Junk.metal(Color(0.3, 0.22, 0.15), 0.95, 0.1), Vector3(0, 0, _rng.randf_range(-8, 8)))
		Junk.box(pole, Vector3(1.6, 0.12, 0.12), Vector3(0, 2.1, 0), Junk.metal(Color(0.3, 0.22, 0.15), 0.95, 0.1))

	# Кустики перекати-поля
	for i in 5:
		var bush := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = _rng.randf_range(0.2, 0.5)
		bm.height = bm.radius * 1.6
		bush.mesh = bm
		bush.position = Vector3(_rng.randf_range(-25.0, 25.0), bm.radius * 0.5, _rng.randf_range(0.0, TILE_LEN))
		if absf(bush.position.x) < 6.0:
			bush.position.x = signf(bush.position.x) * 7.0
		bush.material_override = Junk.metal(Color(0.45, 0.38, 0.2), 1.0, 0.0)
		tile.add_child(bush)

	return tile


func _process(delta: float) -> void:
	for tile in _tiles:
		tile.position.z -= SCROLL_SPEED * speed_scale * delta
		if tile.position.z < -TILE_LEN * 1.5:
			tile.position.z += TILE_LEN * TILE_COUNT
