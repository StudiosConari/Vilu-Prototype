extends Node

## Autoload. La lista de misiones del prototipo, en orden, y por dónde va.
##
## Es una CADENA: hay una misión activa cada vez, con su contador, y al
## completarse se queda dos segundos en pantalla marcada como hecha antes de
## dar paso a la siguiente. Esa pausa es a propósito: sin ella el jugador ve
## cambiar el texto y no llega a enterarse de que cumplió algo.
##
## Cada misión declara `total` (cuántas veces hay que hacerla) y, si la cierra
## un logro, el `logro` que le corresponde. Ese dato sirve para dos cosas: para
## saltar la cadena hasta donde toca cuando se entra por el menú de depuración,
## y para no tener que repetir en dos sitios qué hito cierra cada tramo.
##
## Las escenas NO conocen la cadena: sólo avisan de lo que pasó, con
## `Misiones.hecho("id")`. Si esa no es la misión activa, no pasa nada. Así se
## puede entrar por la mitad del juego sin que nada se rompa.

signal cambio(mision: Dictionary)
signal avance(hechos: int, total: int)
signal cadena_terminada

## Lo que se espera en pantalla antes de pasar a la siguiente.
const ESPERA := 2.0

const CADENA := [
	{"id": "carmen",        "texto": "Habla con Carmen, la guía del museo", "total": 1},
	{"id": "pistas",        "texto": "Habla con las 4 personas del pueblo", "total": 4},
	{"id": "tirana",        "texto": "Busca a la verdadera Tirana", "total": 1,
	 "logro": "tirana"},
	{"id": "mina",          "texto": "Busca la mina cerca del poblado", "total": 1},
	{"id": "obeliscos",     "texto": "Activa ambos obeliscos", "total": 2},
	{"id": "fondo_mina",    "texto": "Investiga el final de la mina", "total": 1,
	 "logro": "mina"},
	{"id": "talisman_1",    "texto": "Entrega el talismán a la bruja del poblado",
	 "total": 1, "logro": "talisman_1"},
	{"id": "isluga_cima",   "texto": "Sube a la cima del Isluga", "total": 1},
	{"id": "isluga_volcan", "texto": "Activa el volcán", "total": 1,
	 "logro": "isluga"},
	{"id": "terminal",      "texto": "Ve al terminal de buses", "total": 1},
	{"id": "viajar",        "texto": "Viaja a Atacama", "total": 1},
	{"id": "alicanto",      "texto": "Busca al Alicanto", "total": 1},
	{"id": "camino",        "texto": "Elige tu camino", "total": 1,
	 "texto_reintento": "Elige BIEN tu camino", "logro": "alicanto"},
	{"id": "bar",           "texto": "Escucha los rumores en el bar", "total": 1},
	{"id": "yastay",        "texto": "Busca al Yastay", "total": 1},
	{"id": "guanacos",      "texto": "Ayuda a los 4 guanacos", "total": 4,
	 "logro": "yastay"},
	{"id": "cazadores",     "texto": "Revisa a los 4 cazadores inconscientes", "total": 4},
	{"id": "talisman_2",    "texto": "Lleva los dos talismanes a la bruja", "total": 1,
	 "logro": "talisman_2"},
	{"id": "ojos_cima",     "texto": "Sube a la cima del volcán Ojos del Salado", "total": 1},
	{"id": "ojos_volcan",   "texto": "Activa el volcán", "total": 1},
	{"id": "portal",        "texto": "Viaja por los volcanes hacia el Isluga", "total": 1,
	 "logro": "ojos_salado"},
	{"id": "volver_mina",   "texto": "Vuelve a la mina", "total": 1},
	{"id": "chupacabras",   "texto": "Derrota al Chupacabras", "total": 1,
	 "logro": "chupacabras"},
]

var _indice := 0
var _hechos := 0
## Mientras dura la pausa de celebración no se cuenta nada más.
var _celebrando := false
## Misiones que se pueden reintentar y ya se fallaron una vez (el camino del
## Alicanto: si eliges el malo, el texto cambia y se vuelve a pedir).
var _reintentos := {}
## Avisos que llegaron mientras se celebraba la anterior.
var _pendientes: Array = []
## Avisos que llegaron ANTES de que su misión estuviera activa, por id.
##
## Pasa de verdad y deja la cadena colgada: los cuerpos de los cazadores se
## pueden revisar mientras la misión que corre todavía es la de los guanacos,
## y esos avisos se tiraban. Al llegarle el turno a "cazadores" ya no quedaban
## cuatro cuerpos por revisar, sólo tres, y el contador se quedaba en 3/4 para
## siempre. Guardados aquí, se aplican en cuanto la misión se activa.
var _adelantados := {}


## Qué misiones cierra el llegar a cada zona o región.
##
## Una zona puede cerrar varias —a la mina se va dos veces— y no hace falta
## saber cuál toca: `hecho()` sólo hace caso si es la misión activa.
const AL_LLEGAR := {
	"Mina": ["mina", "volver_mina"],
	"Alicanto": ["alicanto"],
	"Yastay": ["yastay"],
	# Al Isluga se llega dos veces: subiendo desde Tarapacá al principio, y otra
	# por el portal entre volcanes al final.
	"Isluga": ["isluga_cima", "portal"],
	"OjosDelSalado": ["ojos_cima"],
}


func _ready() -> void:
	# Entrar por el menú de depuración concede los logros de todo lo anterior:
	# la cadena tiene que aparecer donde corresponde, no en la primera misión.
	sincronizar_con_los_logros()
	# Nueve de las misiones las cierra un logro que ya existía. Se enganchan de
	# una vez en vez de repartir llamadas por nueve escenas.
	GameManager.logro_obtenido.connect(_al_conseguir_logro)
	TravelManager.region_changed.connect(_al_cambiar_de_region)
	# La cadena vive en un autoload y sobrevive al cambio de escena: sin esto,
	# empezar una partida nueva la dejaba donde estuviera de la anterior.
	GameManager.progreso_reiniciado.connect(_volver_a_empezar)


func _volver_a_empezar() -> void:
	_reintentos.clear()
	_adelantados.clear()
	_pendientes.clear()
	sincronizar_con_los_logros()


func _al_conseguir_logro(id: String) -> void:
	# Se busca la misión que cierra este logro y se avisa como cualquier otro
	# hecho: si es la activa, se cumple; si todavía no le toca, `hecho` la deja
	# anotada para cuando le llegue el turno.
	#
	# Antes sólo se miraba la misión ACTIVA y, si no era la suya, el logro se
	# tiraba. Con «El Correcaminos» eso dejaba la cadena colgada para siempre:
	# el talismán se puede agarrar y salir huyendo de la mina con un solo
	# obelisco encendido, así que el logro llegaba mientras la misión activa era
	# todavía «Activa ambos obeliscos». Al encender el segundo aparecía
	# «Investiga el final de la mina» esperando un logro que ya se tenía y que
	# no se vuelve a conceder.
	for m in CADENA:
		if String(m.get("logro", "")) == id:
			hecho(String(m["id"]), int(m.get("total", 1)))
			return


func _al_cambiar_de_region(region: String) -> void:
	# Viajar a Atacama es su propia misión, y además se llega a las regiones que
	# son zonas por su cuenta (el Isluga, el Ojos del Salado).
	if region.contains("Atacama"):
		hecho("viajar")
	llegue_a(region)


## Avisa de que se llegó a una zona o región. Lo llama el mundo.
##
## Llegar a un sitio también da por hechas las misiones de pasillo que quedaban
## antes —«Ve al terminal», «Viaja a Atacama»—, siempre que ninguna de ellas
## cierre un logro que todavía no se tiene. Entrando por la parada del Alicanto
## desde el menú la cadena quedaba en «Ve al terminal de buses», que no cierra
## ningún logro y que en Atacama ya no se puede hacer.
func llegue_a(id: String) -> void:
	for m in AL_LLEGAR.get(id, []):
		_saltar_hasta(String(m))
		hecho(String(m))


## Adelanta la cadena hasta `id` si lo que hay en medio es sólo de pasillo.
##
## Lo que cierra un logro no se salta nunca: ir a la mina desde el principio no
## puede dar por hecha a la Tirana. Y no se salta hacia atrás ni durante la
## celebración de otra misión.
func _saltar_hasta(id: String) -> void:
	if terminada() or _celebrando:
		return
	var destino := _indice_de(id)
	if destino <= _indice:
		return
	for i in range(_indice, destino):
		var logro := String(CADENA[i].get("logro", ""))
		if logro != "" and not GameManager.tiene_logro(logro):
			return
	_indice = destino
	_hechos = int(_adelantados.get(id, 0))
	_adelantados.erase(id)
	cambio.emit(actual())
	avance.emit(_hechos, _total())


## Deja la cadena en la primera misión que aún no esté cerrada por un logro.
func sincronizar_con_los_logros() -> void:
	_hechos = 0
	_celebrando = false
	# Se busca el ÚLTIMO tramo ya cerrado y se empieza en el siguiente. Parar en
	# el primero sin logro no vale: la mayoría de las misiones no cierran
	# ninguno, y la cadena se quedaba siempre en la primera.
	var ultimo := -1
	for i in CADENA.size():
		var id: String = String(CADENA[i].get("logro", ""))
		if id != "" and GameManager.tiene_logro(id):
			ultimo = i
	_indice = ultimo + 1
	cambio.emit(actual())
	avance.emit(_hechos, _total())


func actual() -> Dictionary:
	if _indice >= CADENA.size():
		return {}
	var m: Dictionary = CADENA[_indice].duplicate()
	if _reintentos.has(m["id"]) and m.has("texto_reintento"):
		m["texto"] = m["texto_reintento"]
	return m


func hechos() -> int:
	return _hechos


func terminada() -> bool:
	return _indice >= CADENA.size()


## Avisa de que pasó algo. Si no es lo que toca ahora, no hace nada.
##
## Las escenas llaman a esto sin saber en qué punto va la cadena: es lo que
## permite entrar por la mitad del juego, o repetir una zona, sin que se
## descuadre nada.
func hecho(id: String, cuantos := 1) -> void:
	if terminada():
		return
	# Durante los dos segundos de celebración no se cuenta, pero TAMPOCO se
	# tira: hay sitios que cierran dos misiones seguidas de un solo golpe —la
	# cima del Ojos del Salado cierra subir y activar— y el segundo aviso llega
	# mientras el primero todavía se está celebrando.
	if _celebrando:
		_pendientes.append([id, cuantos, false])
		return
	if String(actual()["id"]) != id:
		_anotar_para_despues(id, cuantos, false)
		return
	_hechos = mini(_hechos + cuantos, _total())
	avance.emit(_hechos, _total())
	if _hechos >= _total():
		_celebrar()


## Avisa de CUÁNTAS van en total, no de que pasó una más.
##
## Para las misiones que llevan una lista —los cuatro guanacos, los cuatro
## cuerpos—: la escena ya sabe cuántos lleva, y decirlo entero es a prueba de
## avisos perdidos. Sumando de a uno, un aviso que se cae por el camino
## descuadra el contador para siempre; diciendo "van 4", el último aviso
## cierra la misión aunque los tres anteriores se hubieran perdido.
func contar(id: String, van: int) -> void:
	if terminada():
		return
	if _celebrando:
		_pendientes.append([id, van, true])
		return
	if String(actual()["id"]) != id:
		_anotar_para_despues(id, van, true)
		return
	_hechos = mini(maxi(_hechos, van), _total())
	avance.emit(_hechos, _total())
	if _hechos >= _total():
		_celebrar()


## Guarda un aviso que llegó antes de tiempo, si es de una misión que aún no
## llegó. Los de misiones ya pasadas se ignoran, como siempre.
func _anotar_para_despues(id: String, cuantos: int, absoluto: bool) -> void:
	if _indice_de(id) <= _indice:
		return
	var previo := int(_adelantados.get(id, 0))
	_adelantados[id] = maxi(previo, cuantos) if absoluto else previo + cuantos


func _indice_de(id: String) -> int:
	for i in CADENA.size():
		if String(CADENA[i]["id"]) == id:
			return i
	return -1


## Marca que esta misión se falló y hay que repetirla, con otro texto.
func reintentar(id: String) -> void:
	if terminada() or String(actual()["id"]) != id:
		return
	_reintentos[id] = true
	_hechos = 0
	cambio.emit(actual())
	avance.emit(_hechos, _total())


func _total() -> int:
	return int(CADENA[_indice].get("total", 1)) if not terminada() else 1


## La deja hecha en pantalla un momento y pasa a la siguiente.
func _celebrar() -> void:
	_celebrando = true
	await get_tree().create_timer(ESPERA).timeout
	_celebrando = false
	_indice += 1
	_hechos = 0
	if terminada():
		_pendientes.clear()
		_adelantados.clear()
		cambio.emit({})
		cadena_terminada.emit()
		return
	cambio.emit(actual())
	avance.emit(_hechos, _total())
	# Los avisos que llegaron durante la celebración, ahora sí. Y antes que
	# ésos, lo que ya se había hecho de esta misión sin que tocara todavía.
	var cola: Array = _pendientes.duplicate()
	_pendientes.clear()
	var id_nuevo := String(actual()["id"])
	if _adelantados.has(id_nuevo):
		cola.push_front([id_nuevo, int(_adelantados[id_nuevo]), true])
		_adelantados.erase(id_nuevo)
	for aviso in cola:
		if bool(aviso[2]):
			contar(String(aviso[0]), int(aviso[1]))
		else:
			hecho(String(aviso[0]), int(aviso[1]))
