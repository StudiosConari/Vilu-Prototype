extends Node

# Persistencia: mejor oleada y volumenes (user://save.cfg). Autoload (antes que Sfx).

const PATH := "user://save.cfg"

var best_wave := 0
var music_vol := 0.7  # 0..1
var sfx_vol := 0.85


func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		best_wave = int(c.get_value("d", "best_wave", 0))
		music_vol = float(c.get_value("d", "music_vol", 0.7))
		sfx_vol = float(c.get_value("d", "sfx_vol", 0.85))


func _write() -> void:
	var c := ConfigFile.new()
	c.set_value("d", "best_wave", best_wave)
	c.set_value("d", "music_vol", music_vol)
	c.set_value("d", "sfx_vol", sfx_vol)
	c.save(PATH)


func record_wave(w: int) -> void:
	if w > best_wave:
		best_wave = w
		_write()


func set_music_vol(v: float) -> void:
	music_vol = clampf(v, 0.0, 1.0)
	_write()
	if Engine.has_singleton("Sfx") or has_node("/root/Sfx"):
		get_node("/root/Sfx").apply_music()


func set_sfx_vol(v: float) -> void:
	sfx_vol = clampf(v, 0.0, 1.0)
	_write()
