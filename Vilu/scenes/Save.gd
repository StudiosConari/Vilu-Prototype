extends Node

# Persistencia: mejor oleada y volumenes (user://save.cfg). Autoload (antes que Sfx).
# Durante los tests (gut) se redirige a otro archivo para NO pisar la partida real.

var PATH := "user://save.cfg"


func _init() -> void:
	for a in OS.get_cmdline_args():
		if "gut" in a:
			PATH = "user://test_save.cfg"
			break

var best_wave := 0
var music_vol := 0.7  # 0..1
var sfx_vol := 0.85

# --- Progreso del MVP (seccion "g") ---
# GameManager es el dueño de la logica; aqui solo se almacena. Un unico
# escritor (_write) para no pisar secciones entre si.
var beat_index := 0
var has_bow := false
var has_wings := false
var has_guanaco := false


func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		best_wave = int(c.get_value("d", "best_wave", 0))
		music_vol = float(c.get_value("d", "music_vol", 0.7))
		sfx_vol = float(c.get_value("d", "sfx_vol", 0.85))
		beat_index = int(c.get_value("g", "beat_index", 0))
		has_bow = bool(c.get_value("g", "has_bow", false))
		has_wings = bool(c.get_value("g", "has_wings", false))
		has_guanaco = bool(c.get_value("g", "has_guanaco", false))


func _write() -> void:
	var c := ConfigFile.new()
	c.set_value("d", "best_wave", best_wave)
	c.set_value("d", "music_vol", music_vol)
	c.set_value("d", "sfx_vol", sfx_vol)
	c.set_value("g", "beat_index", beat_index)
	c.set_value("g", "has_bow", has_bow)
	c.set_value("g", "has_wings", has_wings)
	c.set_value("g", "has_guanaco", has_guanaco)
	c.save(PATH)


# Llamado por GameManager tras mutar el progreso.
func save_progress() -> void:
	_write()


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
