extends Node3D

## Bloque que no está hasta que se accionan todos sus objetivos.
##
## Se cuelga sobre el nodo raíz de la instancia del .glb. Arranca invisible y
## sin colisión; cuando los interruptores de `objetivos` están todos accionados,
## brota desde abajo y se queda.
##
## Los interruptores le avisan con `objetivo` + `metodo = "revisar"`, pero el
## aviso sólo sirve de disparo: la cuenta NO se lleva sumando avisos, se lleva
## preguntándole a cada interruptor si ya está usado. Así da igual que uno avise
## dos veces o que se golpeen en cualquier orden.

## Los interruptores que hay que accionar. Cada uno tiene que responder a
## `esta_usado()`; los que no, se ignoran con un aviso en consola.
@export var objetivos: Array[NodePath] = []

## Otros nodos que tampoco existen hasta resolver el puzzle.
##
## Se oculta el nodo ENTERO, con todo lo que cuelgue de él, así que apuntando al
## contenedor de un camino se ocultan sus bloques con una sola entrada, y los que
## se agreguen después quedan incluidos sin tocar nada.
##
## No basta con esconderlos: a un bloque invisible pero sólido se le puede saltar
## igual, y eso es peor que verlo. Se les quita también la colisión.
@export var oculta_tambien: Array[NodePath] = []

## Cuánto por debajo de su sitio aparece, en metros.
@export_range(0.2, 8.0, 0.1) var brota_desde := 1.5

## Segundos que tarda en subir.
@export_range(0.05, 3.0, 0.05) var duracion := 0.5

## Cartel del HUD al aparecer. Vacío = sin cartel.
@export var mensaje := ""

var _cuerpo: StaticBody3D = null
var _capa := 1
var _alto := 0.0
var _abierto := false
var _extras: Array[Node3D] = []
var _cuerpos_extra: Array[CollisionObject3D] = []
var _capas_extra: Array[int] = []


func _ready() -> void:
	_alto = position.y
	_cuerpo = _buscar(self, "StaticBody3D") as StaticBody3D
	if _cuerpo:
		_capa = _cuerpo.collision_layer
		_cuerpo.collision_layer = 0
	else:
		push_warning("BloqueCondicionado en %s: el modelo no trae cuerpo de colisión" % name)
	visible = false
	# Diferido a propósito: los nodos de `oculta_tambien` pueden ir DESPUÉS que
	# éste en la escena, y varios guardan su capa de colisión en su propio
	# _ready. Si se les pusiera a cero antes, guardarían el cero como valor
	# bueno y al volver no serían sólidos nunca más.
	_ocultar_extras.call_deferred()
	if objetivos.is_empty():
		push_warning("BloqueCondicionado en %s: no tiene objetivos, no aparecerá nunca" % name)


func _ocultar_extras() -> void:
	for r in oculta_tambien:
		var n := get_node_or_null(r) as Node3D
		if n == null:
			push_warning("BloqueCondicionado en %s: no encuentro '%s'" % [name, r])
			continue
		_extras.append(n)
		n.visible = false
		_apagar_cuerpos(n)


func _apagar_cuerpos(n: Node) -> void:
	for c in n.get_children():
		if c is CollisionObject3D:
			var co := c as CollisionObject3D
			_cuerpos_extra.append(co)
			_capas_extra.append(co.collision_layer)
			co.collision_layer = 0
		_apagar_cuerpos(c)


func _buscar(n: Node, clase: String) -> Node:
	for c in n.get_children():
		if c.is_class(clase):
			return c
		var hondo := _buscar(c, clase)
		if hondo:
			return hondo
	return null


## Lo llaman los interruptores al accionarse. Mira el estado de TODOS, no lleva
## una cuenta propia: golpear dos veces el mismo no adelanta nada.
func revisar() -> void:
	if _abierto:
		return
	for r in objetivos:
		var n := get_node_or_null(r)
		if n == null:
			push_warning("BloqueCondicionado en %s: no encuentro '%s'" % [name, r])
			return
		if not n.has_method("esta_usado"):
			push_warning("BloqueCondicionado en %s: %s no responde a esta_usado()" % [name, n.name])
			continue
		if not n.call("esta_usado"):
			return
	_abrir()


## Cuántos faltan. Para el HUD o para depurar desde la consola.
func cuantos_faltan() -> int:
	var n := 0
	for r in objetivos:
		var o := get_node_or_null(r)
		if o and o.has_method("esta_usado") and not o.call("esta_usado"):
			n += 1
	return n


func _abrir() -> void:
	_abierto = true
	position.y = _alto - brota_desde
	visible = true
	var t := create_tween()
	t.tween_property(self, "position:y", _alto, duracion) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# La colisión entra recién arriba: si entrara al brotar, el jugador se
	# subiría a un escalón que todavía viene subiendo.
	t.tween_callback(func() -> void:
		if _cuerpo:
			_cuerpo.collision_layer = _capa)
	for n in _extras:
		if is_instance_valid(n):
			n.visible = true
	for i in _cuerpos_extra.size():
		if is_instance_valid(_cuerpos_extra[i]):
			_cuerpos_extra[i].collision_layer = _capas_extra[i]
	if mensaje != "":
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_banner"):
			hud.show_banner(mensaje)
