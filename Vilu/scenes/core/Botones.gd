extends Node

## Traduce los carteles de "[E] Hablar" al botón del mando que toque.
##
## EL PROBLEMA. Los textos del juego llevan la tecla escrita —"[E] Hablar",
## "[G] embestir · [Q] montar"— y son cincuenta y tantos repartidos por todo el
## proyecto. Jugando con mando no sirven de nada: dicen que pulses una tecla que
## no tenés delante.
##
## LA SOLUCIÓN. No se tocan los textos: se traducen AL SALIR, en el HUD y en los
## carteles del mundo. Un sitio en vez de cincuenta y cinco, y el código sigue
## leyéndose con teclas, que es como está escrito el resto.
##
## QUÉ BOTÓN LE TOCA A CADA TECLA lo dice el `InputMap`, no una tabla escrita
## aquí: si la E es de `interact` y `interact` está en la X del mando, entonces
## "[E]" es "[X]". Cambiar un control cambia los carteles solo.

const CONTROLES := preload("res://scenes/ui/PanelDeControles.gd")

## Alias de lo que aparece escrito en los textos y no coincide con el nombre que
## le da Godot a la tecla. Los carteles están en español y Godot no.
const ALIAS := {
	"ESPACIO": "SPACE",
	"ESC": "ESCAPE",
	"INTRO": "ENTER",
}

## Si lo último que se tocó fue un mando. Mientras nadie toque nada, no.
var _con_mando := false

## Tecla -> botón, en mayúsculas. Se calcula la primera vez que hace falta.
var _tabla := {}


const REMAPEO := preload("res://scenes/core/Remapeo.gd")


func _ready() -> void:
	# En procesos sin ventana esto no pinta nada, pero tampoco estorba: sin
	# eventos, `_con_mando` se queda en false y `traducir` devuelve el texto tal
	# cual.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Los controles que el jugador cambió, puestos al arrancar. `Save` ya los
	# leyó: va antes en la lista de autoloads.
	if has_node("/root/Save"):
		var mapa = get_node("/root/Save").get("controles")
		if mapa is Dictionary and not (mapa as Dictionary).is_empty():
			REMAPEO.aplicar(mapa)


## Tira la tabla tecla -> botón para que se arme de nuevo con el mapa actual.
func olvidar_tabla() -> void:
	_tabla = {}


## Se mira TODO lo que entra, sin consumir nada.
##
## `_input` y no `_unhandled_input`: los menús se tragan sus eventos, y si sólo
## se mirara lo que sobra, navegar el menú con el mando no contaría como usar el
## mando y los carteles del juego seguirían en teclas.
func _input(e: InputEvent) -> void:
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		_con_mando = true
	elif e is InputEventKey or e is InputEventMouseButton or e is InputEventMouseMotion:
		_con_mando = false


func usando_mando() -> bool:
	return _con_mando


## El mismo texto, con las teclas cambiadas por botones si toca.
func traducir(texto: String) -> String:
	if not _con_mando or texto == "" or not "[" in texto:
		return texto
	var r := ""
	var i := 0
	while i < texto.length():
		var a := texto.find("[", i)
		if a < 0:
			r += texto.substr(i)
			break
		var b := texto.find("]", a)
		if b < 0:
			r += texto.substr(i)
			break
		r += texto.substr(i, a - i)
		var dentro := texto.substr(a + 1, b - a - 1)
		r += "[%s]" % boton_de(dentro)
		i = b + 1
	return r


## Con qué se hace eso en el mando. Devuelve la misma tecla si no se sabe: un
## cartel con la tecla es menos malo que un cartel vacío.
func boton_de(tecla: String) -> String:
	if _tabla.is_empty():
		_tabla = _armar_tabla()
	var k := tecla.strip_edges().to_upper()
	k = String(ALIAS.get(k, k))
	return String(_tabla.get(k, tecla))


## Tecla -> botón, sacado del mapa de entrada de verdad.
##
## Se recorre acción por acción: de cada una se saca cómo se hace con teclado y
## cómo con mando, y eso empareja las dos. No hay ninguna correspondencia escrita
## a mano que se pueda quedar vieja.
func _armar_tabla() -> Dictionary:
	var t := {}
	for a in InputMap.get_actions():
		var tecla := ""
		var boton := ""
		for e in InputMap.action_get_events(a):
			if tecla == "" and (e is InputEventKey or e is InputEventMouseButton):
				tecla = CONTROLES.nombre_de(e, false)
			if boton == "":
				boton = CONTROLES.nombre_de(e, true)
		if tecla != "" and boton != "":
			t[tecla.to_upper()] = boton
	return t
