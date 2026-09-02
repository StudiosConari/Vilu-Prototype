extends Node3D

## La trampa del oro de la quebrada del Alicanto.
##
## Dos piezas separadas a propósito:
##
##   EL PUENTE (`puente_derrumbable_*`) no se cae. Sólo ARMA la trampa: pisarlo
##   es comprometerse con el ramal del oro.
##
##   EL CAMINO (`camino_derrumbable_*`) es el que cede, y sólo si el puente ya
##   fue pisado. Quien salte ahí buscando el oro se va abajo con él y reaparece
##   en el poblado, antes de la subida: pierde todo el trayecto.
##
## Reemplaza a las ocho losas de CSG que generaba AlicantoRescate. Aquéllas eran
## del greybox; ahora la trampa son los modelos puestos a mano.
##
## Los nodos se localizan POR NOMBRE y no por ruta: en la escena quedaron
## colgando de sitios raros —ambos terminaron dentro del área de la persona
## herida— y una ruta fija se rompería al reacomodarlos.

## Cuánto baja el camino al ceder, en metros. Lo bastante para que no se pueda
## volver a saltar a él mientras se derrumba.
const CAIDA := 12.0
## Lo que tarda en irse abajo.
const DURACION := 1.1
## Desde que empieza a caer hasta que el jugador reaparece. Deja ver la caída.
const ESPERA_RESPAWN := 1.3

var puente: Node3D = null
var camino: Node3D = null

var _armada := false
var _cayendo := false
var _origen := Vector3.ZERO


func _ready() -> void:
	if puente == null or camino == null:
		push_warning("TrampaDelOro: faltan el puente o el camino; la trampa no se arma")
		set_physics_process(false)
		return
	_origen = camino.global_position


## Se mira QUÉ PISA el jugador, no en qué caja está metido.
##
## Antes eran dos Area3D con la planta de cada modelo. No servía: el puente y el
## camino se solapan cinco metros, así que parado en la punta del puente ya
## estabas dentro del área del camino y el oro se derrumbaba antes de saltar.
## Agrandar o achicar las cajas no lo arregla, porque el solape está en los
## modelos mismos.
##
## Un rayo corto bajo los pies sí distingue: dice sobre cuál de los dos estás
## apoyado. Es exactamente "apenas toque la tierra del frente".
func _physics_process(_delta: float) -> void:
	if _cayendo or camino == null:
		return
	var p := _jugador()
	if p == null:
		return
	var pisa := _que_pisa(p)
	if pisa == null:
		return
	if not _armada and _es_parte_de(pisa, puente):
		_armada = true
		_aviso("El puente cruje. El oro está cerca... y el suelo no se ve firme.")
	elif _armada and _es_parte_de(pisa, camino):
		_derrumbar()


func _jugador() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and "active" in p and p.active:
			return p
	return null


## Sobre qué cuerpo está parado: rayo corto desde los tobillos hacia abajo.
func _que_pisa(p: Node3D) -> Node:
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return null
	var desde: Vector3 = p.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 1.6)
	q.collision_mask = 1
	if p is CollisionObject3D:
		q.exclude = [(p as CollisionObject3D).get_rid()]
	var r := esp.intersect_ray(q)
	return r.get("collider") if not r.is_empty() else null


func _es_parte_de(nodo: Node, raiz: Node) -> bool:
	var n := nodo
	while n != null:
		if n == raiz:
			return true
		n = n.get_parent()
	return false


## Se lo lleva abajo. Sólo pasa si ya pisó el puente: la trampa se arma al
## comprometerse con el ramal, no por rozar el camino desde el otro lado.
func _derrumbar() -> void:
	_cayendo = true
	_aviso("¡El oro cede bajo tus pies!")

	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(camino, "global_position", _origen - Vector3(0.0, CAIDA, 0.0), DURACION)
	t.parallel().tween_property(camino, "rotation:z", camino.rotation.z + 0.35, DURACION)

	get_tree().create_timer(ESPERA_RESPAWN).timeout.connect(_devolver_al_poblado)


func _devolver_al_poblado() -> void:
	var juego := get_tree().get_first_node_in_group("game")
	if juego != null and juego.has_method("teleport_to"):
		juego.teleport_to("Poblado")
	# Se rearma tras el viaje: la trampa tiene que poder volver a funcionar, o
	# el segundo intento regalaría el oro.
	get_tree().create_timer(ESPERA_RESPAWN + 1.2).timeout.connect(_rearmar)


func _rearmar() -> void:
	if camino == null:
		return
	camino.global_position = _origen
	camino.rotation.z = 0.0
	_cayendo = false
	_armada = false


func _aviso(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_banner"):
		hud.show_banner(texto)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			# El HUD se vuelve a buscar acá dentro en vez de capturarlo: una lambda que
			# captura un nodo y sobrevive a que lo liberen da "Lambda capture at index 0
			# was freed", aunque se compruebe is_instance_valid antes de usarlo.
			var h := get_tree().get_first_node_in_group("hud")
			if h != null and h.has_method("clear_banner"):
				h.clear_banner())

