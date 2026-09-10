extends RefCounted

## Controles configurables: cambia una tecla o un botón de una acción, resuelve
## los choques con otra acción intercambiándolos, y deja el resultado en un
## diccionario que `Save` guarda y `Botones` vuelve a aplicar al arrancar.
##
## Teclado y mando van POR SEPARADO: cambiar la tecla de saltar no toca el botón
## del mando, y al revés. Cada acción guarda sus eventos en dos listas,
## "teclado" (teclas y botones del ratón) y "mando" (botones y ejes).
##
## Se usa sin instanciar:
##   const REMAPEO := preload("res://scenes/core/Remapeo.gd")
##   var mapa := REMAPEO.asignar(Save.controles, "jump", evento, true)
##   Save.set_controles(mapa)          # guarda y aplica

## Las acciones que se pueden cambiar. Moverse y mirar quedan fuera: son cuatro
## acciones cada una y con el stick no tiene sentido asignarlas de a una.
const EDITABLES := [
	"run", "jump", "rodar", "attack", "triple_arrow", "interact",
	"guanaco", "guanaco_montar", "guanaco_charge", "swap_ai", "swap_hold", "marcos", "ui_cancel",
]

const TECLADO := "teclado"
const MANDO := "mando"


## ¿Este evento es del mando o del teclado y ratón?
static func es_de_mando(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


static func _clase(con_mando: bool) -> String:
	return MANDO if con_mando else TECLADO


## ¿Sirve para asignar? Sólo pulsaciones limpias: nada de eco, nada de rueda
## del ratón, y un eje del mando sólo si está empujado de verdad.
static func es_asignable(e: InputEvent, con_mando: bool) -> bool:
	if con_mando:
		if e is InputEventJoypadButton:
			return (e as InputEventJoypadButton).pressed
		if e is InputEventJoypadMotion:
			return absf((e as InputEventJoypadMotion).axis_value) >= 0.6
		return false
	if e is InputEventKey:
		var k := e as InputEventKey
		return k.pressed and not k.echo and not es_escape(k)
	if e is InputEventMouseButton:
		var m := e as InputEventMouseButton
		return m.pressed and m.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	return false


## Escape se reserva para cancelar. Se mira la tecla física y la lógica: un
## evento real trae las dos, uno armado en una prueba puede traer sólo una.
static func es_escape(k: InputEventKey) -> bool:
	return k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE


## Un evento, en algo que `ConfigFile` pueda guardar.
static func serializar(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		var k := e as InputEventKey
		return {"t": "tecla", "k": k.physical_keycode if k.physical_keycode != 0 else k.keycode}
	if e is InputEventMouseButton:
		return {"t": "raton", "b": (e as InputEventMouseButton).button_index}
	if e is InputEventJoypadButton:
		return {"t": "boton", "b": (e as InputEventJoypadButton).button_index}
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		return {"t": "eje", "a": m.axis, "v": signf(m.axis_value)}
	return {}


## El camino de vuelta. Null si el diccionario no dice nada que se entienda.
static func deserializar(d: Dictionary) -> InputEvent:
	match String(d.get("t", "")):
		"tecla":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.get("k", 0)) as Key
			return k
		"raton":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("b", 0)) as MouseButton
			return m
		"boton":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d.get("b", 0)) as JoyButton
			return b
		"eje":
			var j := InputEventJoypadMotion.new()
			j.axis = int(d.get("a", 0)) as JoyAxis
			j.axis_value = float(d.get("v", 1.0))
			return j
	return null


## ¿Dos eventos son "el mismo botón"? Se compara lo que importa y no el objeto:
## dos InputEventKey de la misma tecla son la misma tecla.
static func iguales(a: InputEvent, b: InputEvent) -> bool:
	return serializar(a) == serializar(b)


## Los eventos que hoy tiene una acción, de una sola clase.
static func eventos_de(accion: String, con_mando: bool) -> Array:
	var out: Array = []
	if not InputMap.has_action(accion):
		return out
	for e in InputMap.action_get_events(accion):
		if es_de_mando(e) == con_mando:
			out.append(e)
	return out


## Le pone a `accion` el evento `nuevo` en lugar de lo que tuviera de esa clase.
##
## Si otra acción editable ya usaba ese botón, se intercambian: la otra se queda
## con lo que tenía ésta. Así nunca quedan dos acciones en el mismo botón ni una
## acción sin botón, que son las dos maneras de dejar el juego injugable desde
## el menú de opciones.
##
## Devuelve el mapa actualizado; NO lo guarda. `Save.set_controles` guarda y
## aplica.
static func asignar(mapa: Dictionary, accion: String, nuevo: InputEvent,
		con_mando: bool) -> Dictionary:
	var m := mapa.duplicate(true)
	if not accion in EDITABLES or not InputMap.has_action(accion):
		return m
	var clase := _clase(con_mando)
	var previos := eventos_de(accion, con_mando)

	# El choque: alguien más tenía este botón.
	for otra: String in EDITABLES:
		if otra == accion or not InputMap.has_action(otra):
			continue
		for e in eventos_de(otra, con_mando):
			if iguales(e, nuevo):
				_reemplazar(otra, con_mando, previos)
				_anotar(m, otra, clase, previos)
				break

	_reemplazar(accion, con_mando, [nuevo])
	_anotar(m, accion, clase, [nuevo])
	return m


## Deja el InputMap como dice el mapa guardado. Lo que el mapa no mencione se
## queda como viene en project.godot.
static func aplicar(mapa: Dictionary) -> void:
	for accion: String in mapa.keys():
		if not InputMap.has_action(accion):
			continue
		var por_clase: Dictionary = mapa[accion]
		for clase: String in [TECLADO, MANDO]:
			if not por_clase.has(clase):
				continue
			var eventos: Array = []
			for d in por_clase[clase]:
				var e := deserializar(d)
				if e != null:
					eventos.append(e)
			if not eventos.is_empty():
				_reemplazar(accion, clase == MANDO, eventos)


## Todo de fábrica otra vez.
static func restablecer() -> void:
	InputMap.load_from_project_settings()


static func _reemplazar(accion: String, con_mando: bool, eventos: Array) -> void:
	for e in eventos_de(accion, con_mando):
		InputMap.action_erase_event(accion, e)
	for e in eventos:
		InputMap.action_add_event(accion, e)


static func _anotar(m: Dictionary, accion: String, clase: String, eventos: Array) -> void:
	if not m.has(accion):
		m[accion] = {}
	var lista: Array = []
	for e in eventos:
		var d := serializar(e)
		if not d.is_empty():
			lista.append(d)
	m[accion][clase] = lista
