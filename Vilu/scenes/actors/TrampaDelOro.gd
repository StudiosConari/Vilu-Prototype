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
## Margen alrededor de cada modelo para su disparador, en metros.
const MARGEN := 0.5
## Alto de la losa que detecta el pisotón: un cuerpo de pie entra de sobra.
const ALTO_PISADA := 2.6
## Cuánto se hunde la losa dentro del modelo, para que atrape aunque el jugador
## se apoye un poco encajado en la geometría.
const HUNDIDO := 0.4

var puente: Node3D = null
var camino: Node3D = null

var _armada := false
var _cayendo := false
var _origen := Vector3.ZERO


func _ready() -> void:
	if puente == null or camino == null:
		push_warning("TrampaDelOro: faltan el puente o el camino; la trampa no se arma")
		return
	_origen = camino.global_position
	_area_sobre(puente, _al_pisar_puente)
	_area_sobre(camino, _al_pisar_camino)


## Un disparador que cubre la PLANTA del modelo y se apoya sobre su cara
## superior, no una caja que lo envuelva entero.
##
## La diferencia importa: envolviendo el modelo, el disparador del puente medía
## trece metros de alto y se activaba pasando por debajo, sin pisar nada. Como
## lo que se quiere detectar es que alguien lo pise, basta una losa a la altura
## de los pies.
func _area_sobre(nodo: Node3D, quien: Callable) -> void:
	var caja := _caja_de(nodo)
	if caja.size == Vector3.ZERO:
		push_warning("TrampaDelOro: %s no tiene malla; sin disparador" % nodo.name)
		return
	var area := Area3D.new()
	area.name = "Disparador_" + nodo.name
	area.collision_layer = 0
	area.collision_mask = 2          # sólo el jugador
	add_child(area)

	var techo := caja.position.y + caja.size.y
	area.global_position = Vector3(
		caja.position.x + caja.size.x * 0.5,
		techo - HUNDIDO + ALTO_PISADA * 0.5,
		caja.position.z + caja.size.z * 0.5)

	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(
		caja.size.x + MARGEN * 2.0, ALTO_PISADA, caja.size.z + MARGEN * 2.0)
	cs.shape = forma
	area.add_child(cs)
	area.body_entered.connect(quien)


func _al_pisar_puente(cuerpo: Node3D) -> void:
	if _armada or not cuerpo.is_in_group("player"):
		return
	_armada = true
	_aviso("El puente cruje. El oro está cerca... y el suelo no se ve firme.")


func _al_pisar_camino(cuerpo: Node3D) -> void:
	# Sin haber pisado el puente no pasa nada: la trampa se arma al comprometerse
	# con el ramal, no por rozar el camino desde el otro lado.
	if _cayendo or not _armada or not cuerpo.is_in_group("player"):
		return
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
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())


## Caja envolvente de un nodo, en coordenadas de mundo.
func _caja_de(n: Node) -> AABB:
	var caja := AABB()
	var primero := true
	for m in _mallas_de(n):
		var a: AABB = m.global_transform * m.mesh.get_aabb()
		if primero:
			caja = a
			primero = false
		else:
			caja = caja.merge(a)
	return caja


func _mallas_de(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mallas_de(c))
	return out
