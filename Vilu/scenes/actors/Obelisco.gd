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

var _activado := false
var _zona: Area3D = null


func _ready() -> void:
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


func _on_interacted(jugador: Node) -> void:
	if _activado:
		return
	_activado = true
	_encender()
	_derribar()
	_despertar_a_lo_de_detras()
	if mensaje != "":
		_cartel(mensaje)
	Sfx.play_at("fire", global_position, -3.0, 1.6)

	# Retirar la zona: sin esto el cartel del HUD se queda puesto mientras el
	# jugador siga al lado de un obelisco que ya no hace nada.
	if jugador and jugador.has_method("clear_interactable"):
		jugador.clear_interactable(_zona)
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
