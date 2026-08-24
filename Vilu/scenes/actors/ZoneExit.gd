extends Area3D

## Salida de zona reutilizable. Al entrar el Player, pide a Game viajar a la
## región destino (con fundido). Opcionalmente requiere un beat mínimo.
## Requiere collision_mask que incluya la capa del jugador (2).

@export var target_region := ""
@export var require_beat := -1   # si >=0, solo activa cuando GameManager.get_beat() >= este
@export var require_abilities: Array = []   # exige tener estas habilidades ("wings","guanaco")
@export var prompt := ""          # si no está vacío, requiere pulsar [E] en vez de auto

## Tamaño del área, en metros. En cero deja el que trae la escena.
##
## El de fábrica son 24 x 4 x 2: un muro ancho y de poco fondo, pensado para
## cruzar el BORDE de una zona. Como puerta de un edificio eso dispara desde
## media plaza, así que la iglesia y compañía piden algo como 8 x 5 x 3.
##
## Va como propiedad exportada y no como override del CollisionShape hijo
## porque Godot no conserva bien esos overrides: al reguardar la escena desde
## el editor se perdió dos veces y el trigger volvió solo a los 24 m.
@export var tamano := Vector3.ZERO

## Se desarma al viajar y se rearma cuando el jugador se baja de encima.
##
## ANTES era un `_used` de un solo uso que nadie reseteaba: entrar a la Mina
## lo dejaba en true PARA SIEMPRE y no se podía volver a entrar nunca. En el
## diseño lineal no se notaba porque cada salida se cruzaba una vez y la
## escena se reconstruía; en mundo abierto `enter_interior` sólo ESCONDE el
## mundo, así que el mismo nodo —y el mismo latch— sobreviven a todo.
##
## Hace falta igual algún guardia, no basta con borrarlo: al salir de la Mina
## reaparecés en (80, 0.5, 55), que cae DENTRO de este mismo trigger. Sin
## guardia, salir te volvería a meter en un bucle. Con éste, el trigger queda
## dormido hasta que te bajás de él.
var _armado := true


func _ready() -> void:
	monitoring = true
	set_physics_process(false)   # sólo hace falta mientras está desarmado
	_aplicar_tamano()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _aplicar_tamano() -> void:
	if tamano == Vector3.ZERO:
		return
	for h in get_children():
		if not (h is CollisionShape3D):
			continue
		var cs := h as CollisionShape3D
		if not (cs.shape is BoxShape3D):
			continue
		# DUPLICAR antes de tocar: la forma viene de ZoneExit.tscn y es la MISMA
		# instancia para todas las salidas del juego. Redimensionarla en sitio
		# le cambiaría el tamaño a todas.
		var caja: BoxShape3D = (cs.shape as BoxShape3D).duplicate()
		caja.size = tamano
		cs.shape = caja
		return


func _has_abilities() -> bool:
	for a in require_abilities:
		if not GameManager.has_ability(a):
			return false
	return true


func _can_use() -> bool:
	if not _armado or target_region == "":
		return false
	if require_beat >= 0 and GameManager.get_beat() < require_beat:
		return false
	return _has_abilities()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not _has_abilities():
		_hint_missing()
		return
	if prompt != "":
		if body.has_method("set_interactable"):
			body.set_interactable(self)  # el Player mostrará el prompt y llamará interact()
	else:
		_travel()


func _hint_missing() -> void:
	var falta := []
	for a in require_abilities:
		if not GameManager.has_ability(a):
			falta.append("ALAS" if a == "wings" else ("GUANACO" if a == "guanaco" else a))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner("Te falta: %s — consíguelo antes de seguir" % ", ".join(falta))
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(hud) and hud.has_method("clear_banner"):
				hud.clear_banner())


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("clear_interactable"):
		body.clear_interactable(self)


# Llamado por el Player al pulsar [T] (cuando hay prompt).
func interact(_player: Node) -> void:
	_travel()


func _travel() -> void:
	if not _can_use():
		return
	_armado = false
	set_physics_process(true)
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("go_to"):
		game.go_to(target_region)


## Rearma el trigger cuando el jugador ya no lo está pisando.
##
## Se consulta el solape en vez de escuchar `body_exited` a propósito: entrar a
## un interior deja el mundo en PROCESS_MODE_DISABLED, y a través de ese apagón
## las señales de entrada y salida no son de fiar. Preguntar por el solape sí
## lo es. Sólo corre mientras está desarmado, así que no cuesta nada.
func _physics_process(_delta: float) -> void:
	if _armado:
		set_physics_process(false)
		return
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			return
	_armado = true
	set_physics_process(false)
