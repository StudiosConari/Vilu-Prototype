extends Node3D

## Bloque que se hunde bajo la lava al pisarlo y vuelve solo un rato después.
##
## Se cuelga sobre el nodo raíz de la instancia del .glb. No hay que preparar
## nada: encuentra la malla y el cuerpo del importador, se fabrica su propio
## disparador y calcula cuánto tiene que bajar para quedar tapado.
##
## El ciclo, tal como se lee en pantalla:
##   pisas -> tiembla 1 s (el aviso) -> se hunde -> 6 s abajo -> vuelve a subir
##
## El temblor no es adorno. Sin él, un bloque que se va justo cuando lo pisás es
## una trampa invisible: sólo se aprende muriendo. Con el aviso, el puzzle pasa
## a ser de ritmo, que es lo que se quiere.

const ENCAJAR := preload("res://scenes/core/EncajarModelo.gd")
const ANIMABLE := preload("res://scenes/core/CuerpoAnimable.gd")

@export_group("Tiempos")
## Segundos entre que lo pisan y que empieza a caer.
@export_range(0.0, 10.0, 0.05) var aviso := 1.5
## Lo que tarda en hundirse.
@export_range(0.05, 5.0, 0.05) var caida := 0.45
## Segundos que se queda abajo antes de volver.
@export_range(0.5, 30.0, 0.1) var vuelve_tras := 6.0
## Lo que tarda en volver a su sitio.
@export_range(0.05, 5.0, 0.05) var regreso := 0.9

@export_group("Hundimiento")
## Superficie bajo la que tiene que quedar. Vacío = busca sola la lava más
## cercana entre sus hermanos (cualquier nodo cuyo nombre empiece por "Lava").
@export var superficie: NodePath
## Cuánto queda su cara superior POR DEBAJO de esa superficie, en metros.
@export_range(0.0, 5.0, 0.05) var margen := 0.7
## Cuánto baja si no encuentra superficie de referencia.
@export var profundidad := 2.5

@export_group("Cadena")
## Bloque que empieza a temblar después de éste. Encadenados forman el derrumbe
## que persigue al jugador: una sola pisada recorre la fila entera.
@export var siguiente: NodePath

## Segundos entre que este bloque empieza a temblar y que arranca el siguiente.
## Es el que marca a qué velocidad hay que correr.
@export_range(0.0, 5.0, 0.05) var retardo_cadena := 0.5

@export_group("Aviso")
## Amplitud del temblor, en metros.
@export_range(0.0, 0.5, 0.005) var temblor := 0.06

enum Estado { QUIETO, AVISANDO, CAYENDO, ABAJO, VOLVIENDO }

var _cuerpo: AnimatableBody3D = null
var _capa := 1
var _base := 0.0
var _fondo := 0.0
var _estado: int = Estado.QUIETO
var _t := 0.0


func _ready() -> void:
	_cuerpo = ANIMABLE.convertir(self, "Bloque")
	if _cuerpo == null:
		push_warning("BloqueQueSeHunde en %s: el modelo no trae ni malla ni colisión" % name)
		set_physics_process(false)
		return
	_capa = _cuerpo.collision_layer
	_base = _cuerpo.position.y
	_fondo = _base - _cuanto_baja()
	_montar_disparador()
	set_physics_process(true)


## Cuánto tiene que bajar para que su cara de arriba quede tapada.
func _cuanto_baja() -> float:
	var sup := _superficie()
	if sup == null:
		return profundidad
	# Se mide la CARA SUPERIOR, no el origen: es la que tiene que desaparecer.
	var techo := _techo_del_bloque()
	var d: float = techo - sup.global_position.y + margen
	return d if d > 0.2 else profundidad


func _superficie() -> Node3D:
	if not superficie.is_empty():
		return get_node_or_null(superficie) as Node3D
	var padre := get_parent()
	if padre == null:
		return null
	var mejor: Node3D = null
	var mejor_d := INF
	for h in padre.get_children():
		if not (h is Node3D) or not str(h.name).begins_with("Lava"):
			continue
		var otro := h as Node3D
		var plano := Vector2(otro.global_position.x - global_position.x,
			otro.global_position.z - global_position.z)
		if plano.length() < mejor_d:
			mejor_d = plano.length()
			mejor = otro
	return mejor


func _techo_del_bloque() -> float:
	var caja := ENCAJAR.envolvente(self)
	if caja.size.y <= 0.001:
		return global_position.y
	return global_position.y + caja.end.y


## Disparador propio: una losa fina justo sobre la cara de arriba.
##
## Va colgado del cuerpo y no de la raíz para que baje con él: si se quedara
## arriba, el bloque hundido seguiría detectando al que pasa por encima y se
## rearmaría solo.
func _montar_disparador() -> void:
	var caja := ENCAJAR.envolvente(self)
	var area := Area3D.new()
	area.name = "Pisada"
	area.collision_layer = 0
	area.collision_mask = 2            # capa de los jugadores
	_cuerpo.add_child(area)

	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(maxf(caja.size.x, 0.5), 0.8, maxf(caja.size.z, 0.5))
	cs.shape = forma
	cs.position = Vector3(caja.get_center().x, caja.end.y + 0.35, caja.get_center().z)
	area.add_child(cs)

	area.body_entered.connect(func(cuerpo: Node3D) -> void:
		if cuerpo.is_in_group("player"):
			disparar())


## Lo arranca desde fuera: lo llama el bloque anterior de la cadena, o el propio
## disparador al pisarlo. Ignora al que ya está temblando, cayendo o abajo.
func disparar() -> void:
	if _estado != Estado.QUIETO:
		return
	_estado = Estado.AVISANDO
	_t = 0.0
	_encadenar()


## Pasa el aviso al siguiente tras `retardo_cadena`. El siguiente hace lo mismo
## con el suyo, así que la cadena se propaga sola sin nadie que la dirija.
##
## Si la cadena se cierra en anillo no hay bucle infinito: `disparar` sólo actúa
## sobre un bloque QUIETO, y al dar la vuelta ya no queda ninguno.
func _encadenar() -> void:
	if siguiente.is_empty():
		return
	var n := get_node_or_null(siguiente)
	if n == null or not n.has_method("disparar"):
		push_warning("BloqueQueSeHunde en %s: no encuentro '%s'" % [name, siguiente])
		return
	get_tree().create_timer(retardo_cadena).timeout.connect(
		func() -> void:
			if is_instance_valid(n):
				n.disparar())


func _physics_process(delta: float) -> void:
	_t += delta
	match _estado:
		Estado.AVISANDO:
			# Vibración horizontal, cada vez más nerviosa.
			var f: float = _t / maxf(aviso, 0.001)
			var a: float = temblor * f
			_cuerpo.position.x = sin(_t * 46.0) * a
			_cuerpo.position.z = cos(_t * 37.0) * a
			if _t >= aviso:
				_cuerpo.position.x = 0.0
				_cuerpo.position.z = 0.0
				_estado = Estado.CAYENDO
				_t = 0.0
		Estado.CAYENDO:
			var k: float = clampf(_t / caida, 0.0, 1.0)
			_cuerpo.position.y = lerpf(_base, _fondo, k * k)   # acelera al caer
			if k >= 1.0:
				# Abajo deja de estorbar: si conservara la colisión, el jugador
				# que cayó con él se quedaría de pie bajo la lava.
				_cuerpo.collision_layer = 0
				_estado = Estado.ABAJO
				_t = 0.0
		Estado.ABAJO:
			if _t >= vuelve_tras:
				_estado = Estado.VOLVIENDO
				_t = 0.0
		Estado.VOLVIENDO:
			var k2: float = clampf(_t / regreso, 0.0, 1.0)
			_cuerpo.position.y = lerpf(_fondo, _base, smoothstep(0.0, 1.0, k2))
			if k2 >= 1.0:
				_cuerpo.collision_layer = _capa
				_estado = Estado.QUIETO
				_t = 0.0
