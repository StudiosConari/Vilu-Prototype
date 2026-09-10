extends Node

# Audio generado por codigo (sin archivos). SFX de impacto + musica de fondo en loop.
# Uso: Sfx.play("punch"/"kick"/"jump"/"hit"/"fire"/"boss")

const RATE := 22050

var _sounds: Dictionary = {}
var _players: Array = []
var _players3d: Array = []
var _next := 0
var _next3d := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	for i in 12:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_players.append(pl)
	for i in 12:
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = 45.0
		p3.unit_size = 7.0
		add_child(p3)
		_players3d.append(p3)
	# Impactos: golpe grave + "click" de choque (percusivo).
	_sounds["punch"] = _gen_hit(0.13, 95.0, 0.62, 9.0, 0.85)
	_sounds["kick"] = _gen_hit(0.19, 62.0, 0.52, 6.5, 0.65)
	_sounds["hit"] = _gen_hit(0.07, 170.0, 0.82, 13.0, 0.9)
	# Tonales.
	_sounds["jump"] = _gen_tone(0.20, 280.0, 640.0, 0.28, 2.2)
	_sounds["fire"] = _gen_tone(0.28, 520.0, 180.0, 0.7, 1.2)
	_sounds["boss"] = _gen_tone(0.40, 85.0, 42.0, 0.5, 1.6)
	# Los del arco son grabados, no generados. Si falta el archivo se quedan con
	# el tono sintético de siempre: mejor un sonido feo que un juego mudo.
	for id: String in GRABADOS:
		var s := _grabado(GRABADOS[id])
		if s != null:
			_sounds[id] = s
	# Musica de fondo (loop).
	_music = AudioStreamPlayer.new()
	_base = _musica_de_fondo()
	_music.stream = _base
	add_child(_music)
	apply_music()
	_music.play()


## Efectos que vienen de un archivo en vez de generarse.
##
## Los `.m4a` que llegaron no los lee Godot —admite wav, ogg y mp3—, así que se
## convirtieron a wav mono de 44,1 kHz con el audaspace que trae Blender. Son
## cortos (0,7 s y 0,3 s): en wav no hay que descomprimir nada al dispararlos.
const GRABADOS := {
	"tensar_arco": "res://audio/sfx/tensar_arco.wav",
	"flecha": "res://audio/sfx/flecha.wav",
	# La cadena de Emilia, un sonido por golpe. Son cuatro distintos a propósito:
	# con uno solo repetido cuatro veces el combo suena a tartamudeo, y lo que hay
	# que oír es que la cadena AVANZA — puño, cruzado, patada y el remate.
	"golpe_puno": "res://audio/sfx/golpe_puno.mp3",
	"golpe_cruzado": "res://audio/sfx/golpe_cruzado.mp3",
	"golpe_patada": "res://audio/sfx/golpe_patada.mp3",
	"golpe_patada_final": "res://audio/sfx/golpe_patada_final.mp3",
	# El grito de Lola al despertar detrás de los tablones.
	"grito_lola": "res://audio/sfx/grito_lola.mp3",
}


func _grabado(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		push_warning("Sfx: falta %s; se usa el sonido generado" % ruta)
		return null
	return load(ruta) as AudioStream


## La canción del juego.
##
## Hasta ahora la música se GENERABA por código —cuatro acordes en bucle, hechos
## a mano con senos— porque el prototipo no tenía ni un archivo de audio. Ya lo
## tiene. La generada se queda como respaldo: si el archivo faltara, el juego
## sigue sonando en vez de quedarse mudo.
const CANCION := "res://audio/musica/map_of_embers.mp3"


func _musica_de_fondo() -> AudioStream:
	if ResourceLoader.exists(CANCION):
		var s := load(CANCION) as AudioStream
		if s != null:
			return s
	push_warning("Sfx: falta %s; suena la música generada" % CANCION)
	return _gen_music()


func apply_music() -> void:
	if _music:
		_music.volume_db = linear_to_db(maxf(Save.music_vol, 0.0001)) - 8.0


## La canción de un sitio en particular: la mina tiene la suya.
##
## Cambia la pista del reproductor y la deja sonando desde el principio. Si le
## pasan la que ya suena no hace nada, para no cortarla al pasar de una zona a
## otra que comparte música. Con null vuelve a la del juego.
func poner_musica(pista: AudioStream) -> void:
	if _music == null:
		return
	if pista == null:
		volver_a_la_musica_del_juego()
		return
	if _music.stream == pista and _music.playing:
		return
	_music.stream = pista
	apply_music()
	_music.play()


## De vuelta a la canción del juego, la de siempre.
func volver_a_la_musica_del_juego() -> void:
	if _music == null:
		return
	if _base == null:
		_base = _musica_de_fondo()
	if _music.stream == _base and _music.playing:
		return
	_music.stream = _base
	apply_music()
	_music.play()


## La pista que suena ahora. Lo consultan los tests.
func musica_actual() -> AudioStream:
	return _music.stream if _music != null else null


## La canción del juego, guardada para poder volver a ella.
var _base: AudioStream = null


func play(sfx_name: String, volume_db: float = -4.0, pitch: float = 1.0) -> void:
	if not _sounds.has(sfx_name) or Save.sfx_vol <= 0.001:
		return
	var pl: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	pl.stream = _sounds[sfx_name]
	pl.volume_db = volume_db + linear_to_db(maxf(Save.sfx_vol, 0.0001))
	pl.pitch_scale = pitch
	pl.play()


func play_at(sfx_name: String, pos: Vector3, volume_db: float = -1.0, pitch: float = 1.0) -> void:
	# Sonido posicional 3D (se oye segun donde ocurre; la camara es el listener).
	if not _sounds.has(sfx_name) or Save.sfx_vol <= 0.001:
		return
	var pl: AudioStreamPlayer3D = _players3d[_next3d]
	_next3d = (_next3d + 1) % _players3d.size()
	pl.stream = _sounds[sfx_name]
	pl.global_position = pos
	pl.volume_db = volume_db + linear_to_db(maxf(Save.sfx_vol, 0.0001))
	pl.pitch_scale = pitch
	pl.play()


func set_music(on: bool) -> void:
	if _music == null:
		return
	if on and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()


func _gen_hit(dur: float, freq: float, noise: float, decay: float, click: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var frac := float(i) / float(n)
		var t := float(i) / float(RATE)
		var env: float = exp(-frac * decay)
		var body := sin(TAU * freq * t)
		var nz := randf() * 2.0 - 1.0
		var cl := 0.0
		if t < 0.004:
			cl = (randf() * 2.0 - 1.0) * (1.0 - t / 0.004) * click
		var s: float = body * (1.0 - noise) * 0.7 + nz * noise + cl
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 30000.0))
	return _wav(data)


func _gen_tone(dur: float, f0: float, f1: float, noise: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var frac := float(i) / float(n)
		var t := float(i) / float(RATE)
		var env: float = pow(1.0 - frac, decay)
		var freq: float = lerpf(f0, f1, frac)
		var s: float = sin(TAU * freq * t) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 30000.0))
	return _wav(data)


func _tri(f: float, t: float) -> float:
	var p: float = f * t - floorf(f * t)
	return 4.0 * absf(p - 0.5) - 1.0


func _gen_music() -> AudioStreamWAV:
	var bpm := 108.0
	var spb := 60.0 / bpm
	var eighth := spb * 0.5
	# Am - F - C - G (pop menor).
	var chords := [
		[220.0, 261.63, 329.63], [174.61, 220.0, 261.63],
		[130.81, 164.81, 196.0], [196.0, 246.94, 293.66],
	]
	var steps_per_bar := 8
	var total_steps := chords.size() * steps_per_bar
	var total_dur := float(total_steps) * eighth
	var n := int(total_dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(RATE)
		var step := int(t / eighth) % total_steps
		var chord: Array = chords[int(step / float(steps_per_bar))]
		var note: float = chord[(step % steps_per_bar) % chord.size()]
		var st_t := t - float(step) * eighth
		var lead := _tri(note, t) * exp(-st_t * 6.0) * 0.22
		var bass := sin(TAU * (chord[0] * 0.5) * t) * exp(-fmod(t, spb) * 3.0) * 0.30
		data.encode_s16(i * 2, int(clampf(lead + bass, -1.0, 1.0) * 26000.0))
	var w := _wav(data)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
