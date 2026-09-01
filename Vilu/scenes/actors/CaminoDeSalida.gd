extends Node3D

## Camino de salida del cráter: los bloques no están hasta que hacen falta.
##
## Se cuelga sobre un Node3D que tenga los bloques como hijos, EN EL ORDEN EN
## QUE SE PISAN. El orden es el del árbol de la escena, no el de los nombres ni
## el de las posiciones: así se reordena arrastrando en el editor, y el camino
## puede doblar o subir sin que haya que tocar nada de aquí.
##
## El ciclo completo:
##   hablás con el guardián  -> aparece el primero
##   pisás cerca de su borde -> el siguiente brota desde abajo y sube
##   ...y así hasta el último
##   te tirás del último     -> se hunden y desaparecen, del primero al último
##
## Los bloques brotan DESDE ABAJO y no de la nada porque un bloque que aparece
## de golpe no se lee como que el volcán te abre el camino, se lee como un fallo
## de dibujado.

const ENCAJAR := preload("res://scenes/core/EncajarModelo.gd")

## Otros nodos que viven el MISMO ciclo que el camino: no están hasta que el
## guardián lo abre, y se van cuando el camino se derrumba.
##
## Para la plataforma que baja al mundo. No es sólo estética: si estuviera
## desde el principio se podría bajar sin haber resuelto nada, y el camino que
## la precede no tendría sentido. Se le apaga también la colisión y las zonas,
## o sería un ascensor invisible que igual se puede usar.
##
## Se van al FINAL del derrumbe, después del último bloque, que es el momento
## que deja más margen para alcanzarlas.
@export var acompanan: Array[NodePath] = []

## Cuánto por debajo de su sitio aparece cada bloque, en metros.
@export_range(0.2, 8.0, 0.1) var brota_desde := 1.8

## Segundos que tarda en subir a su sitio.
@export_range(0.05, 3.0, 0.05) var duracion_subida := 0.5

## Fondo de la zona que dispara el siguiente bloque, medido hacia dentro desde
## el borde de salida. Con 1.4 hay que pisar el último tramo del bloque.
@export_range(0.2, 6.0, 0.1) var margen_borde := 1.4

## Segundos entre que salís del último bloque y que empieza el derrumbe.
##
## No es adorno: sin margen, el compañero que viene unos pasos atrás se queda
## sin suelo en el mismo instante en que vos cruzás, y cae a la lava.
@export_range(0.0, 10.0, 0.1) var retardo_derrumbe := 1.0

## Segundos entre que se desvanece un bloque y el siguiente, al final.
@export_range(0.0, 3.0, 0.05) var retardo_desaparicion := 0.3

## Segundos entre que termina la charla con el guardián y aparece el primer
## bloque. Es el hueco para la animación del guardián, que todavía no existe:
## cuando esté, se sube este número a lo que dure y no hay que tocar nada más.
@export_range(0.0, 10.0, 0.1) var retardo_inicial := 0.0

var _bloques: Array[Node3D] = []
var _cuerpos: Array[StaticBody3D] = []
var _capas: Array[int] = []
var _altura: Array[float] = []
var _hasta := -1
var _arrancado := false
var _desvaneciendo := false
var _extras: Array[Node3D] = []
var _cuerpos_extra: Array[CollisionObject3D] = []
var _capas_extra: Array[int] = []


func _ready() -> void:
	for h in get_children():
		if not (h is Node3D):
			continue
		var b := h as Node3D
		_bloques.append(b)
		_altura.append(b.position.y)
		var c := _buscar(b, "StaticBody3D") as StaticBody3D
		_cuerpos.append(c)
		_capas.append(c.collision_layer if c else 1)
		_esconder(_bloques.size() - 1)
	if _bloques.is_empty():
		push_warning("CaminoDeSalida en %s: no cuelga ningún bloque" % name)
	# Diferido: los nodos de `acompanan` pueden ir DESPUÉS que éste en la
	# escena, y varios guardan su capa de colisión en su propio _ready. Si se
	# les pusiera a cero antes, guardarían el cero como valor bueno.
	_preparar_acompanantes.call_deferred()


func _preparar_acompanantes() -> void:
	for r in acompanan:
		var n := get_node_or_null(r) as Node3D
		if n == null:
			push_warning("CaminoDeSalida en %s: no encuentro '%s'" % [name, r])
			continue
		_extras.append(n)
		_apagar(n)


func _apagar(n: Node) -> void:
	if n is Node3D:
		(n as Node3D).visible = false
	_tocar_cuerpos(n, true)


func _tocar_cuerpos(n: Node, apagar: bool) -> void:
	for c in n.get_children():
		if c is CollisionObject3D:
			var co := c as CollisionObject3D
			if apagar:
				_cuerpos_extra.append(co)
				_capas_extra.append(co.collision_layer)
				co.collision_layer = 0
			# El encendido se hace aparte, por índice, para no perder la capa.
		_tocar_cuerpos(c, apagar)


func _encender_acompanantes() -> void:
	for n in _extras:
		if is_instance_valid(n):
			n.visible = true
	for i in _cuerpos_extra.size():
		if is_instance_valid(_cuerpos_extra[i]):
			_cuerpos_extra[i].collision_layer = _capas_extra[i]


func _apagar_acompanantes() -> void:
	for i in _cuerpos_extra.size():
		if is_instance_valid(_cuerpos_extra[i]):
			_cuerpos_extra[i].collision_layer = 0
	for n in _extras:
		if is_instance_valid(n):
			n.visible = false


func _buscar(n: Node, clase: String) -> Node:
	for c in n.get_children():
		if c.is_class(clase):
			return c
		var hondo := _buscar(c, clase)
		if hondo:
			return hondo
	return null


func _esconder(i: int) -> void:
	_bloques[i].visible = false
	if _cuerpos[i]:
		_cuerpos[i].collision_layer = 0


## Lo llama el guardián al terminar la charla. Repetirlo no hace nada.
func activar() -> void:
	if _arrancado:
		return
	_arrancado = true
	if retardo_inicial <= 0.0:
		_aparecer(0)
		_encender_acompanantes()
		return
	get_tree().create_timer(retardo_inicial).timeout.connect(
		func() -> void:
			_aparecer(0)
			_encender_acompanantes())


func _aparecer(i: int) -> void:
	if i >= _bloques.size() or i <= _hasta or _desvaneciendo:
		return
	_hasta = i
	var b := _bloques[i]
	b.position.y = _altura[i] - brota_desde
	b.visible = true
	var t := create_tween()
	t.tween_property(b, "position:y", _altura[i], duracion_subida) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# La colisión entra recién arriba: si entrara al brotar, el jugador que está
	# en el bloque anterior se subiría a un escalón que todavía viene subiendo.
	t.tween_callback(func() -> void:
		if _cuerpos[i] and not _desvaneciendo:
			_cuerpos[i].collision_layer = _capas[i])
	_montar_zona(i)


## La zona que dispara lo siguiente. En los bloques del medio va pegada al borde
## de salida y llama al que viene; en el último va MÁS ALLÁ del borde y hacia
## abajo, para que la atrapes lo mismo si caminás hasta el final que si saltás.
func _montar_zona(i: int) -> void:
	var rumbo := _rumbo(i)
	var caja := ENCAJAR.envolvente(_bloques[i])
	var medio: float = absf(rumbo.x) * caja.size.x * 0.5 + absf(rumbo.z) * caja.size.z * 0.5
	var ancho: float = maxf(caja.size.x, caja.size.z)
	var ultimo: bool = i == _bloques.size() - 1

	var area := Area3D.new()
	area.name = "Borde"
	area.collision_layer = 0
	area.collision_mask = 2          # capa de los jugadores
	_bloques[i].add_child(area)

	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	if ultimo:
		# Un cajón alto y hondo justo pasando el borde: recoge tanto al que
		# camina de largo como al que se tira al vacío.
		forma.size = Vector3(ancho + 4.0, 40.0, ancho + 4.0)
		cs.position = _bloques[i].to_local(
			_bloques[i].global_position + rumbo * (medio + 2.5) + Vector3(0, -16.0, 0))
	else:
		forma.size = Vector3(
			maxf(absf(rumbo.x) * margen_borde, ancho),
			4.0,
			maxf(absf(rumbo.z) * margen_borde, ancho))
		cs.position = _bloques[i].to_local(
			_bloques[i].global_position + rumbo * (medio - margen_borde * 0.5)
			+ Vector3(0, 1.5, 0))
	cs.shape = forma
	area.add_child(cs)

	area.body_entered.connect(func(cuerpo: Node3D) -> void:
		if not cuerpo.is_in_group("player"):
			return
		if ultimo:
			_desvanecer()
		else:
			_aparecer(i + 1))


## Hacia dónde sigue el camino desde el bloque `i`. El último hereda el rumbo
## del anterior: no tiene siguiente al que apuntar, pero la salida va por ahí.
func _rumbo(i: int) -> Vector3:
	var a := i
	var b := i + 1
	if b >= _bloques.size():
		a = i - 1
		b = i
	if a < 0:
		return Vector3(0, 0, 1)
	var d: Vector3 = _bloques[b].global_position - _bloques[a].global_position
	d.y = 0.0
	if d.length() < 0.01:
		return Vector3(0, 0, 1)
	return d.normalized()


## Se hunden y se apagan, del primero al último.
##
## Cada bloque pierde la colisión cuando le toca hundirse a ÉL, no todos de
## entrada. La diferencia importa: cortarlas todas de golpe deja sin suelo a
## quien viene detrás sobre un bloque que en pantalla sigue entero, y el
## compañero se cae a la lava sin que nada lo explique.
func _desvanecer() -> void:
	if _desvaneciendo:
		return
	_desvaneciendo = true
	# Los acompañantes se van al final de todo: es el mayor margen posible para
	# alcanzarlos antes de que el camino termine de caerse.
	var ultimo: float = retardo_derrumbe + float(maxi(_bloques.size() - 1, 0)) * retardo_desaparicion
	var t0 := create_tween()
	t0.tween_interval(ultimo + duracion_subida)
	t0.tween_callback(_apagar_acompanantes)
	for i in _bloques.size():
		if not _bloques[i].visible:
			continue
		var t := create_tween()
		t.tween_interval(retardo_derrumbe + i * retardo_desaparicion)
		t.tween_callback(func() -> void:
			if _cuerpos[i]:
				_cuerpos[i].collision_layer = 0)
		t.tween_property(_bloques[i], "position:y",
			_altura[i] - brota_desde, duracion_subida) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void: _esconder(i))
