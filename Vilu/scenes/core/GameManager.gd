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

const BEAT_COUNT := 8
const ABILITIES := ["bow", "wings", "guanaco"]


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
		"bow": return Save.has_bow
		"wings": return Save.has_wings
		"guanaco": return Save.has_guanaco
		_:
			push_warning("GameManager: habilidad desconocida '%s'" % ability)
			return false


## Desbloquea una habilidad y persiste. Emite ability_unlocked solo si cambio.
func unlock(ability: String) -> void:
	if has_ability(ability):
		return
	match ability:
		"bow": Save.has_bow = true
		"wings": Save.has_wings = true
		"guanaco": Save.has_guanaco = true
		_:
			push_warning("GameManager: no se puede desbloquear '%s'" % ability)
			return
	Save.save_progress()
	ability_unlocked.emit(ability)


## Reinicia el progreso (util para tests y para "Nueva partida").
func reset_progress() -> void:
	Save.beat_index = 0
	Save.has_bow = false
	Save.has_wings = false
	Save.has_guanaco = false
	Save.save_progress()
	beat_changed.emit(0)
