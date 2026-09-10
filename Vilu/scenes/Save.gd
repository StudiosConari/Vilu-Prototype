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
## Volumen general: manda sobre los otros dos. Es el bus Master.
var master_vol := 1.0
## Idioma de la interfaz: "es" o "en". Por ahora sólo cambia el panel de
## opciones, que tiene su dibujo en cada idioma.
var idioma := "es"

## Si el juego arranca a pantalla completa.
##
## Por defecto SÍ: es un juego, y la primera impresión no debería ser una
## ventanita. Quien prefiera ventana lo cambia una vez y queda guardado.
var pantalla_completa := true

# --- Progreso del MVP (seccion "g") ---
# GameManager es el dueño de la logica; aqui solo se almacena. Un unico
# escritor (_write) para no pisar secciones entre si.
var beat_index := 0
var has_bow := false
var has_wings := false
var has_guanaco := false
var has_talisman_1 := false
var has_talisman_2 := false

## Logros conseguidos, por id. Va como lista y no como un bool por logro para
## que agregar uno nuevo no obligue a tocar el guardado en tres sitios.
var logros: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		best_wave = int(c.get_value("d", "best_wave", 0))
		music_vol = float(c.get_value("d", "music_vol", 0.7))
		sfx_vol = float(c.get_value("d", "sfx_vol", 0.85))
		master_vol = float(c.get_value("d", "master_vol", 1.0))
		idioma = String(c.get_value("d", "idioma", "es"))
		pantalla_completa = bool(c.get_value("d", "pantalla_completa", true))
		beat_index = int(c.get_value("g", "beat_index", 0))
		has_bow = bool(c.get_value("g", "has_bow", false))
		has_wings = bool(c.get_value("g", "has_wings", false))
		has_guanaco = bool(c.get_value("g", "has_guanaco", false))
		has_talisman_1 = bool(c.get_value("g", "has_talisman_1", false))
		has_talisman_2 = bool(c.get_value("g", "has_talisman_2", false))
		logros = PackedStringArray(c.get_value("g", "logros", PackedStringArray()))
		var ctrl = c.get_value("c", "mapa", {})
		controles = ctrl if ctrl is Dictionary else {}
	aplicar_pantalla()
	aplicar_master()


func _write() -> void:
	var c := ConfigFile.new()
	c.set_value("d", "best_wave", best_wave)
	c.set_value("d", "music_vol", music_vol)
	c.set_value("d", "sfx_vol", sfx_vol)
	c.set_value("d", "master_vol", master_vol)
	c.set_value("d", "idioma", idioma)
	c.set_value("d", "pantalla_completa", pantalla_completa)
	c.set_value("g", "beat_index", beat_index)
	c.set_value("g", "has_bow", has_bow)
	c.set_value("g", "has_wings", has_wings)
	c.set_value("g", "has_guanaco", has_guanaco)
	c.set_value("g", "has_talisman_1", has_talisman_1)
	c.set_value("g", "has_talisman_2", has_talisman_2)
	c.set_value("g", "logros", logros)
	c.set_value("c", "mapa", controles)
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


func set_master_vol(v: float) -> void:
	master_vol = clampf(v, 0.0, 1.0)
	_write()
	aplicar_master()


## El volumen general va al bus Master: así baja todo, música y efectos.
func aplicar_master() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_vol, 0.0001)))


func set_idioma(cual: String) -> void:
	idioma = "en" if cual == "en" else "es"
	_write()


## Los controles que el jugador cambió: acción -> {"teclado": [...], "mando": [...]}.
## Vacío quiere decir «los de fábrica». Ver Remapeo.gd.
var controles: Dictionary = {}


## Guarda un mapa de controles y lo aplica en el acto. Con un mapa vacío se
## vuelve a los de fábrica.
func set_controles(mapa: Dictionary) -> void:
	controles = mapa.duplicate(true)
	_write()
	var remapeo := load("res://scenes/core/Remapeo.gd") as GDScript
	remapeo.restablecer()
	remapeo.aplicar(controles)
	# Los carteles "[E] Hablar" se traducen con una tabla que se arma una vez;
	# con controles nuevos hay que armarla otra vez.
	if has_node("/root/Botones"):
		get_node("/root/Botones").call("olvidar_tabla")


## Pantalla completa o ventana. Se guarda y se aplica en el acto.
##
## EXCLUSIVE_FULLSCREEN no: `FULLSCREEN` en Godot es sin bordes a pantalla
## completa, que cambia de ventana al instante y deja pasar al escritorio sin
## que la pantalla parpadee al cambiar de modo de vídeo.
func set_pantalla_completa(si: bool) -> void:
	pantalla_completa = si
	_write()
	aplicar_pantalla()


## Deja la ventana como diga lo guardado.
##
## Se llama también al arrancar: el ajuste no sirve de nada si sólo vale para la
## sesión en que se tocó.
##
## No hace nada sin ventana de verdad —los tests corren en headless, y ahí pedir
## un cambio de modo es pedirle algo a un servidor de pantalla que no existe—.
func aplicar_pantalla() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN \
		if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED)
