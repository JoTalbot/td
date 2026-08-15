extends Node
## Процедурные звуки: синтез на лету, без аудиофайлов (0 байт ассетов).
## Один AudioStreamGenerator, полифония — микс активных голосов в _process.

const MIX_RATE := 22050

var _player: AudioStreamPlayer
var _play: AudioStreamGeneratorPlayback
var _samples: Dictionary = {}   # имя -> PackedVector2Array
var _active: Array = []         # голоса: {"data", "pos" (float), "pitch", "vol"}


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.4
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -5.0
	add_child(_player)
	_player.play()
	_play = _player.get_stream_playback()
	_build_samples()


## Запустить звук. pitch > 1 выше/короче, < 1 ниже/длиннее.
func play(sound: String, vol := 1.0, pitch := 1.0) -> void:
	if not _samples.has(sound) or _active.size() >= 8:
		return
	_active.append({"data": _samples[sound], "pos": 0.0, "pitch": pitch, "vol": vol})


func _process(_delta: float) -> void:
	if _play == null:
		return
	# На слабом железе и в headless буфер может не дренажиться — ограничиваем кадр
	var avail := mini(_play.get_frames_available(), 2205)
	if avail <= 0:
		return
	# Миксуем голоса и пушим покадрово (push_frames в 4.2 недоступен)
	for i in avail:
		var f := Vector2.ZERO
		for v in _active:
			var data: PackedVector2Array = v["data"]
			var idx := int(v["pos"])
			if idx < data.size():
				f += data[idx] * float(v["vol"])
				v["pos"] = float(v["pos"]) + float(v["pitch"])
		_play.push_frame(Vector2(clampf(f.x, -0.95, 0.95), clampf(f.y, -0.95, 0.95)))
	for i in range(_active.size() - 1, -1, -1):
		if float(_active[i]["pos"]) >= (_active[i]["data"] as PackedVector2Array).size():
			_active.remove_at(i)


## --- Синтез сэмплов ---
func _build_samples() -> void:
	_samples["shot"] = _noise_hit(0.06, 0.0, 6.0)            # пулемёт
	_samples["flame"] = _noise_hit(0.14, 0.0, 2.4)           # огнемёт — шипение
	_samples["cannon"] = _noise_hit(0.22, 70.0, 4.0)         # пушка
	_samples["mortar"] = _noise_hit(0.18, 110.0, 4.5)        # мортирный выхлоп
	_samples["zap"] = _tone(1500.0, 0.09, "square", -0.8)    # тесла-разряд
	_samples["harpoon"] = _tone(700.0, 0.06, "tri", 0.6)     # гарпун
	_samples["explosion"] = _noise_hit(0.45, 60.0, 2.8)      # подрыв рейдера
	_samples["big_boom"] = _noise_hit(0.75, 45.0, 2.2)       # босс/корсар
	_samples["ram"] = _noise_hit(0.09, 170.0, 5.0)           # таран по фуре
	_samples["click"] = _tone(1150.0, 0.035, "tri")          # кнопки
	_samples["ability"] = _tone(520.0, 0.14, "saw", 0.5)     # способность
	var earn := _tone(880.0, 0.055, "tri")
	earn.append_array(_tone(1320.0, 0.09, "tri"))
	_samples["earn"] = earn                                  # сделка/награда
	_samples["horn"] = _tone(196.0, 0.35, "saw", 0.12)       # старт волны
	_samples["boss"] = _tone(58.0, 0.65, "saw", -0.15)       # рык босса
	_samples["repair"] = _tone(1250.0, 0.1, "tri", 0.4)      # ремкомплект
	_samples["jam"] = _tone(240.0, 0.3, "square", -0.6)      # скрежет заклинившего орудия


## Шумовой удар с экспоненциальным затуханием + низкий гул (tone Hz, 0 — без).
func _noise_hit(dur: float, tone: float, punch: float) -> PackedVector2Array:
	var n := int(dur * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242  # детерминированное «железо», без рандома между запусками
	var phase := 0.0
	var lpf := 0.0
	for i in n:
		var t := float(i) / float(n)
		var env: float = exp(-punch * t * 6.0)
		var noise := rng.randf_range(-1.0, 1.0)
		lpf = lerpf(lpf, noise, 0.4)
		var g := 0.0
		if tone > 0.0:
			phase += tone * TAU / MIX_RATE
			g = sin(phase)
		var s := (lpf * 0.7 + g * 0.5) * env
		out[i] = Vector2(s, s)
	return out


## Тональная нота: sine/square/saw/tri, slide — сдвиг частоты к концу (доли).
func _tone(freq: float, dur: float, kind: String, slide := 0.0) -> PackedVector2Array:
	var n := int(dur * MIX_RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var att := minf(t * 50.0, 1.0)
		var env: float = att * exp(-3.5 * float(i) / float(n))
		var f := freq * (1.0 + slide * float(i) / float(n))
		phase += f * TAU / MIX_RATE
		var s := 0.0
		match kind:
			"square":
				s = 0.6 if sin(phase) > 0.0 else -0.6
			"saw":
				s = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
			"tri":
				s = asin(sin(phase)) * 0.9
			_:
				s = sin(phase)
		s *= env
		out[i] = Vector2(s, s)
	return out
