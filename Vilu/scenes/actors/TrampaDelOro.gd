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


## Los cristales de oro que hay sembrados sobre el camino.
const PREFIJO_ORO := "cristal_de_oro"

## Cuánto se agranda la planta del camino al buscar el oro que lleva encima, en
## metros. Los cristales asoman por los bordes de la losa.
@export var margen_del_oro := 2.5


func _ready() -> void:
	if puente == null or camino == null:
		push_warning("TrampaDelOro: faltan el puente o el camino; la trampa no se arma")
		set_physics_process(false)
		return
	_origen = camino.global_position
	_adoptar_el_oro()


## Cuelga del camino el oro que lleva encima.
##
## Los cristales están puestos en la escena como HERMANOS del camino, así que al
## derrumbarse la losa el oro se quedaba flotando en el aire, sobre el vacío.
## Adoptándolos pasan a caer, girar y volver con ella sin animarlos aparte.
##
## Se eligen por posición y no por nombre: hay cristales sembrados por toda la
## quebrada, y sólo tienen que irse abajo los que están sobre el trozo que cede.
func _adoptar_el_oro() -> void:
	var zona := camino.get_parent()
	if zona == null:
		return
	var caja := _planta(camino).grow(margen_del_oro)
	var adoptados := 0
	for n: Node3D in _oro_de(zona):
		if not caja.has_point(Vector3(n.global_position.x, caja.get_center().y,
				n.global_position.z)):
			continue
		# `owner` a null antes de mudarlo: si no, Godot avisa de que su dueño ya
		# no lo contiene. Lo mismo que hizo falta con las piezas del arco.
		n.owner = null
		n.reparent(camino, true)
		adoptados += 1
	if adoptados == 0:
		push_warning("TrampaDelOro: no encuentro oro sobre el camino que se cae")


## La caja del camino en el mundo, aplanada a su altura media: lo que interesa
## es qué cristales caen DENTRO de su planta, no a qué altura están.
func _planta(n: Node3D) -> AABB:
	var caja := AABB(n.global_position, Vector3.ZERO)
	for mi in _mallas(n):
		var c: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		caja = caja.merge(c)
	caja.position.y = caja.get_center().y - 50.0
	caja.size.y = 100.0
	return caja


func _mallas(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		if h is MeshInstance3D:
			r.append(h)
		r.append_array(_mallas(h))
	return r


func _oro_de(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		if h is Node3D and String(h.name).begins_with(PREFIJO_ORO):
			r.append(h)
	return r


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
	# La misión cambia AL REAPARECER, no al pisar el oro: cayéndote no estás
	# mirando el recuadro, y al volver al poblado lo primero que querés saber es
	# qué te toca hacer otra vez.
	Misiones.reintentar("camino")
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

