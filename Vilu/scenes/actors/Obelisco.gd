extends Node3D

## Obelisco rúnico: se activa con [E] y derriba una barrera.
##
## Se cuelga sobre el nodo raíz de la instancia del .glb y se le indica en
## `barrera` qué prop cae al encenderlo. Sirve para cualquier par
## interruptor/obstáculo, no sólo para los dos de la mina.
##
## La zona de interacción se crea acá y no se pone en la escena porque el modelo
## viene con la escala metida en el transform del nodo —los obeliscos de la mina
## van a ×1.44 y ×1.28— y un CollisionShape3D hijo hereda ese factor: un radio de
## 2.5 escrito a mano acabaría midiendo 3.6 m en uno y 3.2 m en el otro. Creando
## la zona por código se puede deshacer la escala y que `alcance` sean metros de
## verdad en los dos.

const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")
const MUDA := preload("res://scenes/core/MudaDeAsset.gd")

## Prop que cae al activarlo. Vacío = no derriba nada (sólo se enciende).
@export var barrera: NodePath

## Algo que se despierta al activarlo: lo que estaba encerrado detrás.
##
## Va aparte de `barrera` porque no siempre coinciden —una barrera puede tapar
## un pasillo vacío— y porque lo de detrás no tiene por qué ser un enemigo: basta
## con que tenga un método `despertar()`.
@export var despierta: NodePath

## Texto del cartel del HUD mientras estás al lado.
@export var prompt := "[E] Activar el obelisco"

## Cartel al activarlo. Vacío = sin cartel.
@export var mensaje := "El obelisco se enciende y la barrera cede"

## Radio de la zona de interacción, en metros.
@export var alcance := 2.5

## Color del brillo que queda cuando está activo.
@export var color_activo := Color(0.45, 0.85, 1.0)

## Lo que hay que romper ANTES de poder encenderlo.
##
## El primero de la mina está detrás de una barricada de tablones, y se podía
## encender igual: la zona de interacción mide 2,5 m de radio y no sabe nada de
## lo que haya en medio, así que bastaba con arrimarse por el otro lado y pulsar
## [E]. La barricada quedaba de adorno y el tramo se saltaba entero.
##
## Se listan los `Destructible` que lo tapan. Mientras alguno siga en pie, el
## obelisco no responde y dice por qué.
@export var requiere: Array[NodePath] = []

## Qué se lee al intentar encenderlo con el camino todavía tapado.
@export var aviso_bloqueado := "Los tablones tapan el obelisco. Rompelos primero."

## Versión del modelo a la que se cambia al encenderlo.
##
## Los del Isluga tienen una gemela con la energía verde. Vacío = no se cambia
## de modelo y sólo se enciende la luz, como el resto de los obeliscos.
@export var modelo_activo: PackedScene

## Cuánto dura el destello que tapa el cambio, en segundos. El modelo cambia
## de golpe; esto sólo es el fogonazo que hace que no se vea el corte.
@export var muda_segundos := 0.35

## Se enciende. Lo escucha la mina para saber cuántos van: el ocultista del
## pasillo desaparece al segundo.
signal activado

var _activado := false
var _zona: Area3D = null
## Si la última vez que se miró seguía tapado. Sirve para cambiar el cartel
## sólo cuando cambia, no cada cuadro.
var _tapado := false


func _ready() -> void:
	# La guía de misión le pone un marcador mientras siga apagado.
	add_to_group("objetivo_obeliscos")
	_zona = Area3D.new()
	_zona.collision_layer = 0
	_zona.collision_mask  = 2      # capa de los jugadores
	_zona.set_script(INTERACT_SCR)
	_zona.prompt = prompt
	add_child(_zona)

	# Deshacer la escala del nodo para que el radio se lea en metros.
	var f := global_transform.basis.get_scale()
	_zona.scale = Vector3(1.0 / maxf(f.x, 0.001), 1.0 / maxf(f.y, 0.001), 1.0 / maxf(f.z, 0.001))

	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = alcance
	cs.shape = sph
	cs.position.y = 1.0            # a la altura del pecho, no de los pies
	_zona.add_child(cs)

	_zona.interacted.connect(_on_interacted)
	_tapado = esta_bloqueado()
	_zona.prompt = _cartel_de_la_zona()


## Mientras esté tapado, el cartel del HUD dice que hay que romper los
## tablones, no «[E] Activar»: ofrecer algo que no se puede hacer se lee como
## que el obelisco se activa igual desde este lado.
func _process(_delta: float) -> void:
	if _activado or _zona == null or requiere.is_empty():
		return
	var tapado := esta_bloqueado()
	if tapado == _tapado:
		return
	_tapado = tapado
	_zona.prompt = _cartel_de_la_zona()
	# Si el jugador ya está dentro de la zona, el HUD tiene el cartel viejo.
	for p in get_tree().get_nodes_in_group("player"):
		if p.get("_interactable") == _zona and p.has_method("set_interactable"):
			p.set_interactable(_zona)


func _cartel_de_la_zona() -> String:
	return aviso_bloqueado if _tapado else prompt


func _on_interacted(jugador: Node) -> void:
	if _activado:
		return
	if esta_bloqueado():
		if aviso_bloqueado != "":
			_cartel(aviso_bloqueado)
		return
	activar(true)
	# Retirar la zona: sin esto el cartel del HUD se queda puesto mientras el
	# jugador siga al lado de un obelisco que ya no hace nada.
	if jugador and jugador.has_method("clear_interactable"):
		jugador.clear_interactable(_zona)


## ¿Queda algo por romper de lo que lo tapa?
##
## Lo que ya no está —porque se rompió y se liberó el nodo— no bloquea: cuenta
## como hecho. Lo que sigue en pie y sabe decir si está roto, se le pregunta; lo
## que ni siquiera es un destructible, si existe, bloquea.
func esta_bloqueado() -> bool:
	for ruta in requiere:
		var n := get_node_or_null(ruta)
		if n == null:
			continue
		if n.has_method("esta_roto") and bool(n.call("esta_roto")):
			continue
		return true
	return false


## Lo enciende. Con `avisar` a false, en silencio y sin efectos de sonido.
##
## OJO: `activar()` NO comprueba la barricada. Es a propósito: la mina la llama
## para dejar los obeliscos encendidos al volver para el duelo, y ahí no hay que
## volver a romper nada. El requisito se comprueba donde se decide, que es al
## pulsar [E].
##
## Se puede llamar sin jugador delante: la mina lo usa para dejar los obeliscos
## ya activados cuando volvés al duelo con el Chupacabras: encontrarte las
## barreras otra vez de pie, después de haberlas tirado, sería deshacerte el
## trabajo.
func activar(avisar := true) -> void:
	if _activado:
		return
	_activado = true
	activado.emit()
	remove_from_group("objetivo_obeliscos")
	Misiones.hecho("obeliscos")
	_encender()
	_derribar()
	_despertar_a_lo_de_detras()
	if avisar:
		if mensaje != "":
			_cartel(mensaje)
		Sfx.play_at("fire", global_position, -3.0, 1.6)
	if _zona != null:
		_zona.queue_free()
		_zona = null


## Brillo azul que deja claro cuál ya se usó.
func _encender() -> void:
	var luz := OmniLight3D.new()
	luz.light_color  = color_activo
	luz.omni_range   = 5.0
	luz.light_energy = 0.0
	add_child(luz)
	# En local: el nodo está escalado, así que 1.2 m de altura real son 1.2
	# dividido por la escala.
	var f := global_transform.basis.get_scale()
	luz.position.y = 1.2 / maxf(f.y, 0.001)
	create_tween().tween_property(luz, "light_energy", 2.4, 0.5)
	MUDA.mudar(self, modelo_activo, muda_segundos)


func _despertar_a_lo_de_detras() -> void:
	if despierta.is_empty():
		return
	var n := get_node_or_null(despierta)
	if n == null:
		push_warning("Obelisco en %s: no encuentro '%s' para despertar" % [name, despierta])
		return
	if n.has_method("despertar"):
		n.call("despertar")


func _derribar() -> void:
	if barrera.is_empty():
		return
	var n := get_node_or_null(barrera)
	if n == null:
		push_warning("Obelisco en %s: no encuentro la barrera '%s'" % [name, barrera])
		return

	# El paso se abre YA. La caída es sólo adorno: si se esperara al final del
	# tween habría un segundo entero en el que la barrera se ve cayendo pero
	# todavía frena al jugador.
	for cuerpo in _cuerpos(n):
		cuerpo.collision_layer = 0
		cuerpo.collision_mask  = 0

	if n is not Node3D:
		n.queue_free()
		return

	# Se hunde y se encoge, en vez de girar: estos props traen la escala metida
	# en el transform y sin igualar en los tres ejes -la barrera 2 va a
	# (7.08, 3.68, 4.42)-, así que tocarles la rotación los deforma. Mover la
	# posición y multiplicar la escala respeta cualquier basis.
	var n3 := n as Node3D
	var t := create_tween().set_parallel(true)
	t.tween_property(n3, "position", n3.position - Vector3(0.0, 2.0, 0.0), 0.9) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(n3, "scale", n3.scale * 0.75, 0.9)
	t.chain().tween_callback(n3.queue_free)
	Sfx.play_at("kick", n3.global_position, -2.0, 0.7)


## Todos los cuerpos de colisión que trae la instancia importada, a cualquier
## profundidad: el importador de glTF los cuelga con nombre autogenerado, así
## que se buscan por tipo y nunca por nombre.
func _cuerpos(n: Node) -> Array[CollisionObject3D]:
	var out: Array[CollisionObject3D] = []
	if n is CollisionObject3D:
		out.append(n as CollisionObject3D)
	for c in n.get_children():
		out.append_array(_cuerpos(c))
	return out


func _cartel(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(texto)
		get_tree().create_timer(3.5).timeout.connect(func() -> void:
			# El HUD se vuelve a buscar acá dentro en vez de capturarlo: una lambda que
			# captura un nodo y sobrevive a que lo liberen da "Lambda capture at index 0
			# was freed", aunque se compruebe is_instance_valid antes de usarlo.
			var h := get_tree().get_first_node_in_group("hud")
			if h != null and h.has_method("clear_banner"):
				h.clear_banner())
