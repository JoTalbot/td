extends Node
## Активные способности экипажа: «Залп», «Щит», «Нитро».
## У каждой свой кулдаун; визуал процедурный, из хлама (Junk).

signal feedback(text: String)

const AbilityData := preload("res://scripts/AbilityData.gd")
const Junk := preload("res://scripts/Junk.gd")

var state: Node
var truck: Node3D
var wasteland: Node

## Множитель кулдаунов (мета-улучшение «Ветераны экипажа»).
var cooldown_mult := 1.0

## id легендарных способностей, выкованных навсегда (кузня трофеев).
var unlocked_legendary: Array = []

var _magnet_timer := 0.0
var _magnet_node: Node3D = null

var _last_stand_timer := 0.0
var _last_stand_light: OmniLight3D = null

var _cooldowns: Dictionary = {}   # id -> осталось секунд

var _shield_timer := 0.0
var _shield_node: Node3D = null

var _nitro_timer := 0.0
var _nitro_fx_timer := 0.0
var _nitro_base_scale := 1.0


func setup(p_state: Node, p_truck: Node3D, p_wasteland: Node) -> void:
	state = p_state
	truck = p_truck
	wasteland = p_wasteland
	for id in AbilityData.DEFS:
		_cooldowns[id] = 0.0


func cooldown_left(id: String) -> float:
	return maxf(float(_cooldowns.get(id, 0.0)), 0.0)


func is_ready(id: String) -> bool:
	return state != null and not state.is_game_over and cooldown_left(id) <= 0.0


func _process(delta: float) -> void:
	for id in _cooldowns:
		if _cooldowns[id] > 0.0:
			_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)
	_tick_shield(delta)
	_tick_nitro(delta)
	_tick_magnet(delta)
	_tick_last_stand(delta)


func _tick_shield(delta: float) -> void:
	if _shield_timer <= 0.0:
		return
	_shield_timer -= delta
	if _shield_node != null:
		# Под конец клетка мигает — скоро спадёт
		_shield_node.visible = _shield_timer > 1.5 or fmod(_shield_timer * 8.0, 1.0) < 0.75
	if _shield_timer <= 0.0 and _shield_node != null:
		_shield_node.visible = false


func _tick_nitro(delta: float) -> void:
	if _nitro_timer <= 0.0:
		return
	_nitro_timer -= delta
	_nitro_fx_timer -= delta
	# Пламя из выхлопных труб, пока длится форсаж
	if _nitro_fx_timer <= 0.0 and truck != null:
		_nitro_fx_timer = 0.35
		for side in [-1.0, 1.0]:
			Junk.explosion(get_tree().current_scene,
				truck.global_position + Vector3(side * 1.3, 2.6, 4.6), 0.55)
	if _nitro_timer <= 0.0 and wasteland != null:
		# Возвращаем скорость мира — если её меняли снаружи (апгрейд движка), не трогаем
		var expected := _nitro_base_scale * AbilityData.NITRO_WORLD_BOOST
		if absf(wasteland.speed_scale - expected) < 0.01:
			wasteland.speed_scale = _nitro_base_scale


## Возвращает true, если способность реально сработала (для звука в Main).
func try_activate(id: String) -> bool:
	var def: Dictionary = AbilityData.DEFS[id]
	if bool(def.get("legendary", false)) and not unlocked_legendary.has(id):
		feedback.emit("«%s» — легендарка! Выкуйте в кузне трофеев." % def["name"])
		return false
	if not is_ready(id):
		if state != null and not state.is_game_over:
			feedback.emit("%s ещё не готово!" % def["name"])
		return false
	_cooldowns[id] = float(def["cooldown"]) * cooldown_mult
	match id:
		"barrage":
			_do_barrage()
		"shield":
			_do_shield()
		"nitro":
			_do_nitro()
		"magnet":
			_do_magnet()
		"last_stand":
			_do_last_stand()
	return true


func _do_barrage() -> void:
	# Ракетный залп: серия взрывов по всем живым рейдерам.
	var enemies := get_tree().get_nodes_in_group("enemies")
	var idx := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		var e: Node3D = enemy
		var pos: Vector3 = e.global_position + Vector3.UP * 1.0
		# Разносим удары по времени — залп идёт «градом» слева направо
		var tw := create_tween()
		tw.tween_interval(idx * 0.1)
		tw.tween_callback(func() -> void:
			if is_instance_valid(e) and not e.is_dying:
				Junk.explosion(get_tree().current_scene, pos, 1.1)
				e.take_damage(AbilityData.BARRAGE_DAMAGE, state)
		)
		idx += 1
	if idx == 0:
		_cooldowns["barrage"] = 0.0  # пустой залп не наказываем кулдауном
		feedback.emit("Нет целей для залпа!")
	else:
		feedback.emit("🚀 Залп по %d целям!" % idx)


func _do_shield() -> void:
	# Самодельная клетка из арматуры: фура неуязвима.
	if _shield_node == null:
		_shield_node = _build_shield_cage()
		truck.add_child(_shield_node)
	state.grant_invulnerability(AbilityData.SHIELD_DURATION)
	_shield_timer = AbilityData.SHIELD_DURATION
	_shield_node.visible = true
	feedback.emit("🛡 Щит-клетка на %.0f с!" % AbilityData.SHIELD_DURATION)


func _build_shield_cage() -> Node3D:
	var cage := Node3D.new()
	cage.name = "ShieldCage"
	# Полупрозрачный купол «халтурной сварки»
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 5.6
	sm.height = 11.2
	dome.mesh = sm
	dome.scale = Vector3(0.82, 0.8, 1.15)
	dome.position = Vector3(0, 1.4, 0.8)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.95, 0.7, 0.25, 0.10)
	dm.emission_enabled = true
	dm.emission = Color(0.95, 0.65, 0.2)
	dm.emission_energy_multiplier = 0.4
	dome.material_override = dm
	cage.add_child(dome)
	# Стальные обручи — будто клетка, сваренная из арматуры
	for i in 4:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 4.55
		ring.mesh = tm
		ring.rotation_degrees.x = 90.0
		ring.position = Vector3(0, 0.2 + i * 1.6, 0.8)
		ring.scale = Vector3(1.0, 1.0, 1.25)
		ring.material_override = Junk.metal(Color(0.6, 0.45, 0.25), 0.5, 0.85)
		cage.add_child(ring)
	cage.visible = false
	return cage


func _do_nitro() -> void:
	# Форсаж: пламя в трубах, рейдеры резко отстают.
	_nitro_base_scale = wasteland.speed_scale if wasteland != null else 1.0
	if wasteland != null:
		wasteland.speed_scale = _nitro_base_scale * AbilityData.NITRO_WORLD_BOOST
	_nitro_timer = AbilityData.NITRO_DURATION
	_nitro_fx_timer = 0.0
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		enemy.apply_slow(AbilityData.NITRO_SLOW, AbilityData.NITRO_SLOW_TIME)
		count += 1
	if count > 0:
		feedback.emit("🔥 Нитро! %d машин отстают!" % count)
	else:
		feedback.emit("🔥 Нитро!")


## --- Легендарные способности (выковываются навсегда в кузне трофеев) ---

## «Хламный магнит»: воющее кольцо тянет лом — +50% лома за всё, пока воет.
func _do_magnet() -> void:
	state.loot_magnet = AbilityData.MAGNET_DURATION
	_magnet_timer = AbilityData.MAGNET_DURATION
	if _magnet_node == null:
		_magnet_node = _build_magnet_ring()
		truck.add_child(_magnet_node)
	_magnet_node.visible = true
	feedback.emit("🧲 Магнит воет: +50%% лома %.0f сек!" % AbilityData.MAGNET_DURATION)


func _build_magnet_ring() -> Node3D:
	var ring_root := Node3D.new()
	ring_root.name = "LootMagnet"
	var tor := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.14
	tm.outer_radius = 6.2
	tor.mesh = tm
	tor.rotation_degrees.x = 90.0
	tor.position.y = 0.3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.5, 0.75, 1.0, 0.35)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.65, 1.0)
	m.emission_energy_multiplier = 0.8
	tor.material_override = m
	ring_root.add_child(tor)
	# Летающий хлам по орбите
	for i in 8:
		Junk.spike(ring_root, 0.09, 0.5,
			Vector3(cos(float(i) * TAU / 8.0) * 6.2, 0.32, sin(float(i) * TAU / 8.0) * 6.2))
	ring_root.visible = false
	return ring_root


func _tick_magnet(delta: float) -> void:
	if _magnet_timer <= 0.0:
		return
	_magnet_timer -= delta
	if _magnet_node != null:
		_magnet_node.rotation.y += delta * 2.2
		var s := 1.0 + sin(_magnet_timer * 6.0) * 0.06
		_magnet_node.scale = Vector3(s, 1.0, s)
		if _magnet_timer <= 0.0:
			_magnet_node.visible = false


## «Последний рубеж»: боевое безумие — темп всех орудий удваивается.
func _do_last_stand() -> void:
	state.fire_rate_mult = AbilityData.LAST_STAND_MULT
	_last_stand_timer = AbilityData.LAST_STAND_DURATION
	if _last_stand_light == null:
		_last_stand_light = OmniLight3D.new()
		_last_stand_light.light_color = Color(1.0, 0.3, 0.2)
		_last_stand_light.light_energy = 0.0
		_last_stand_light.omni_range = 7.0
		_last_stand_light.position = Vector3(0, 3.0, 0.0)
		truck.add_child(_last_stand_light)
	_last_stand_light.visible = true
	feedback.emit("🪓 Последний рубеж! Орудия палят вдвое чаще!")


func _tick_last_stand(delta: float) -> void:
	if _last_stand_timer <= 0.0:
		return
	_last_stand_timer -= delta
	if _last_stand_light != null:
		_last_stand_light.light_energy = 1.6 + sin(_last_stand_timer * 10.0) * 0.7
	if _last_stand_timer <= 0.0:
		state.fire_rate_mult = 1.0
		if _last_stand_light != null:
			_last_stand_light.visible = false
