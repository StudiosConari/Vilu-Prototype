extends Node

## Autoload. Estado global del MVP: indice de beat (0-7) y banderas de
## habilidad (arco, alas, guanaco). Es el UNICO punto que hace avanzar el
## progreso; expone senales para que HUD/escenas reaccionen. La persistencia
## delega en el autoload Save (un solo escritor del save.cfg).
##
## Uso:
##   GameManager.advance_beat()
##   GameManager.unlock("bow")
##   if GameManager.has_ability("wings"): ...

signal beat_changed(index: int)
signal ability_unlocked(ability: String)
signal logro_obtenido(id: String)
## Se emite una sola vez, cuando cae el último logro que faltaba.
signal prototipo_superado

const BEAT_COUNT := 8
const ABILITIES := ["bow", "wings", "guanaco", "talisman_frag_1", "talisman_frag_2"]

## Los logros del prototipo, EN ORDEN DE JUEGO. Tenerlos todos es superarlo.
##
## El orden importa para la pantalla de logros; la lógica no depende de él, cada
## uno se concede por su cuenta desde donde ocurre.
const LOGROS := [
	{"id": "tirana",      "titulo": "La Tirana",
	 "pista": "Descubrir a la Tirana y aprender el combo de 4 golpes y el disparo triple"},
	{"id": "mina",        "titulo": "Escape de la mina",
	 "pista": "Salir de la mina después de ver al Chupacabras"},
	{"id": "talisman_1",  "titulo": "El primer talismán",
	 "pista": "Llevarle a la bruja el primer fragmento"},
	{"id": "isluga",      "titulo": "Volcán Isluga",
	 "pista": "Hablar con el guardián del Isluga"},
	{"id": "alicanto",    "titulo": "El Alicanto",
	 "pista": "Rescatar al Alicanto"},
	{"id": "yastay",      "titulo": "El Yastay",
	 "pista": "Superar al Yastay"},
	{"id": "ojos_salado", "titulo": "Ojos del Salado",
	 "pista": "Llegar a la cima del Ojos del Salado"},
	{"id": "talisman_2",  "titulo": "El segundo talismán",
	 "pista": "Llevarle a la bruja el segundo fragmento"},
	{"id": "chupacabras", "titulo": "El Chupacabras",
	 "pista": "Vencer al Chupacabras"},
]

## Debug: si no está vacío, Game arranca cargando esta zona (selector del título).
var debug_start_zone := ""


func get_beat() -> int:
	return Save.beat_index


## Fija el beat actual (clampeado a rango valido) y persiste.
func set_beat(index: int) -> void:
	var clamped := clampi(index, 0, BEAT_COUNT - 1)
	if clamped == Save.beat_index:
		return
	Save.beat_index = clamped
	Save.save_progress()
	beat_changed.emit(clamped)


## Avanza al siguiente beat. No-op si ya se esta en el ultimo.
func advance_beat() -> void:
	set_beat(Save.beat_index + 1)


func has_ability(ability: String) -> bool:
	match ability:
		"bow":           return Save.has_bow
		"wings":         return Save.has_wings
		"guanaco":       return Save.has_guanaco
		"talisman_frag_1": return Save.has_talisman_1
		"talisman_frag_2": return Save.has_talisman_2
		_:
			push_warning("GameManager: habilidad desconocida '%s'" % ability)
			return false


## Desbloquea una habilidad y persiste. Emite ability_unlocked solo si cambio.
func unlock(ability: String) -> void:
	if has_ability(ability):
		return
	match ability:
		"bow":             Save.has_bow = true
		"wings":           Save.has_wings = true
		"guanaco":         Save.has_guanaco = true
		"talisman_frag_1": Save.has_talisman_1 = true
		"talisman_frag_2": Save.has_talisman_2 = true
		_:
			push_warning("GameManager: no se puede desbloquear '%s'" % ability)
			return
	Save.save_progress()
	ability_unlocked.emit(ability)


func tiene_logro(id: String) -> bool:
	return Save.logros.has(id)


## Cuántos lleva, para el contador del HUD.
func logros_obtenidos() -> int:
	return Save.logros.size()


func prototipo_completo() -> bool:
	for l in LOGROS:
		if not tiene_logro(l["id"]):
			return false
	return true


## Devuelve la ficha de un logro, o un diccionario vacío si el id no existe.
func logro(id: String) -> Dictionary:
	for l in LOGROS:
		if l["id"] == id:
			return l
	return {}


## Concede un logro y persiste. Repetirlo no hace nada, así que los puntos que
## lo llaman no necesitan llevar su propia bandera de "ya lo di".
##
## `prototipo_superado` se emite DESPUÉS de `logro_obtenido`, para que el HUD
## alcance a mostrar el último logro antes del cierre.
func conceder(id: String) -> void:
	if logro(id).is_empty():
		push_warning("GameManager: logro desconocido '%s'" % id)
		return
	if tiene_logro(id):
		return
	Save.logros.append(id)
	Save.save_progress()
	logro_obtenido.emit(id)
	if prototipo_completo():
		prototipo_superado.emit()


## Reinicia el progreso (util para tests y para "Nueva partida").
func reset_progress() -> void:
	Save.beat_index = 0
	Save.has_bow = false
	Save.has_wings = false
	Save.has_guanaco = false
	Save.has_talisman_1 = false
	Save.has_talisman_2 = false
	Save.logros = PackedStringArray()
	Save.save_progress()
	beat_changed.emit(0)
