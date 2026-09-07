extends MeshInstance3D

## La lava quema: tocarla cuesta vida y devuelve al party al punto seguro.
##
## Se cuelga sobre una instancia de LavaToon.
##
## POR QUÉ HACE FALTA. El plano de lava es sólo una malla, sin colisión: se
## atraviesa y uno queda de pie en el lecho del cráter, bajo la superficie,
## mirando la lava como si fuera un techo naranja.
##
## Y esto NO lo arregla el umbral de caída. El suelo jugable del cráter baja más
## que el lecho de lava, así que no existe una altura que separe "me caí" de
## "estoy en la parte honda del nivel": hace falta saber que lo que se tocó fue
## lava, no una altura.

## Vida que cuesta el chapuzón.
@export var dano := 25.0

## Cuánto por debajo de la superficie sigue contando como lava. Generoso a
## propósito: el que la atraviesa a velocidad tiene que ser atrapado igual.
@export_range(1.0, 60.0, 0.5) var hondura := 14.0


func _ready() -> void:
	if mesh == null:
		push_warning("LavaQuema en %s: no hay malla de la que sacar el tamaño" % name)
		return
	var caja := mesh.get_aabb()

	var zona := Area3D.new()
	zona.name = "Quema"
	zona.collision_layer = 0
	zona.collision_mask = 2          # capa de los jugadores
	add_child(zona)

	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(maxf(caja.size.x, 1.0), hondura, maxf(caja.size.z, 1.0))
	cs.shape = forma
	# El techo de la caja queda en la superficie: se dispara al hundirse, no al
	# pasar volando por encima.
	cs.position = Vector3(caja.get_center().x,
		caja.get_center().y - hondura * 0.5, caja.get_center().z)
	zona.add_child(cs)

	_zona = zona


## El área, para poder preguntarle cada cuadro quién está dentro.
var _zona: Area3D = null


## Se pregunta MIENTRAS se está dentro, no sólo al entrar.
##
## `body_entered` avisa una vez, y esa vez se puede perder: si llega dentro de
## la ventana de gracia que sigue a un rescate, el aviso se descarta y no hay
## un segundo. El jugador seguía hundiéndose sin que nada lo sacara y acababa
## bajo el cráter, de pie sobre la cáscara del volcán, sin lava que lo alcanzara
## ni altura suficiente para contar como caída: atascado para siempre.
##
## Preguntando cada cuadro el rescate llega igual aunque el primer aviso se
## pierda, y de paso atrapa al que cruza la caja tan rápido que el motor no le
## registra la entrada. Que no se dispare en ráfaga es cosa de Game, que espera
## un mínimo entre rescates.
func _physics_process(_delta: float) -> void:
	if _zona == null:
		return
	for cuerpo in _zona.get_overlapping_bodies():
		if not cuerpo.is_in_group("player"):
			continue
		var juego := get_tree().get_first_node_in_group("game")
		if juego and juego.has_method("volver_al_punto_seguro"):
			juego.volver_al_punto_seguro("¡La lava quema! Volvés al punto seguro", dano)
		return
