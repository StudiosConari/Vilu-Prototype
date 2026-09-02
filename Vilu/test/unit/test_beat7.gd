extends "res://addons/gut/test.gd"

## Beat 7 — Cumbre multinivel: la cima requiere a LOS DOS; llegar arriba arma la cuerda.

const CUMBRE := preload("res://scenes/puzzles/OjosDelSalado.tscn")

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func _fake_player() -> Node3D:
	var n := Node3D.new()
	n.add_to_group("player")
	add_child_autofree(n)
	return n


func test_final_needs_both_to_solve() -> void:
	var c := CUMBRE.instantiate()
	add_child_autofree(c)
	watch_signals(c)
	c._on_final_enter(_fake_player())
	assert_false(c.is_solved(), "con un solo personaje en la cima no se resuelve")
	c._on_final_enter(_fake_player())
	assert_true(c.is_solved(), "con LOS DOS en la cima, resuelto")
	assert_signal_emitted(c, "reached_summit")
	assert_eq(GameManager.get_beat(), 7, "resolver entra al Beat 7")


## La corriente del final ya NO la abre el cubo del greybox.
##
## Aquel `ArrowSwitch` quedó sin malla, o sea invisible, y encima solapado con un
## bloque visible que hace otra cosa. Ahora la abren LOS DOS personajes al pisar
## juntos la última pasarela, que es lo que se comprueba acá.
func test_updraft2_needs_both_players_on_final_walkway() -> void:
	var c := CUMBRE.instantiate()
	add_child_autofree(c)
	var updraft2 := c.get_node("Updraft2")
	assert_false(updraft2.active, "la corriente del final arranca inactiva")

	var pasarela := c.find_child("camino_de_ladrillos_de_piedra5", true, false)
	assert_not_null(pasarela, "tiene que existir la pasarela final")

	# Se paran cuerpos DE VERDAD encima, en la capa del jugador, y se deja correr
	# la física: así se prueba la regla tal como la vive el juego.
	var alto := _alto_de(pasarela)
	var uno := _falso_jugador(c, pasarela, alto, 0.6)
	for i in 4:
		await get_tree().physics_frame
	c.call("_vigilar_corriente_final")
	assert_false(updraft2.active, "con un personaje solo no se abre")

	var dos := _falso_jugador(c, pasarela, alto, -0.6)
	for i in 4:
		await get_tree().physics_frame
	c.call("_vigilar_corriente_final")
	assert_true(updraft2.active, "con los dos encima se abre la corriente")
	uno.queue_free()
	dos.queue_free()


## Un cuerpo del tamaño del jugador, en su capa y su grupo, parado sobre `pas`.
func _falso_jugador(padre: Node, pas: Node3D, alto: float, desvio: float) -> CharacterBody3D:
	var p := CharacterBody3D.new()
	p.collision_layer = 2
	p.collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	p.add_child(cs)
	padre.add_child(p)
	p.add_to_group("player")
	p.global_position = Vector3(pas.global_position.x + desvio, alto + 0.05,
		pas.global_position.z)
	return p


## Altura de la cara superior de la pasarela.
func _alto_de(pas: Node3D) -> float:
	var cs := _primera_forma(pas)
	if cs == null or cs.shape == null:
		return pas.global_position.y
	var ab: AABB = cs.shape.get_debug_mesh().get_aabb()
	return cs.global_position.y + ab.end.y * cs.global_transform.basis.get_scale().y


func _primera_forma(n: Node) -> CollisionShape3D:
	for h in n.get_children():
		if h is CollisionShape3D:
			return h
		var x := _primera_forma(h)
		if x != null:
			return x
	return null


func test_reaching_platform1_arms_rope() -> void:
	var c := CUMBRE.instantiate()
	add_child_autofree(c)
	var rope1 := c.get_node("Rope1")
	assert_false(rope1.armed, "la cuerda arranca sin armar")
	c._on_platform1_reached(_fake_player())
	assert_true(rope1.armed, "llegar a Platform_1 arma la cuerda para el otro")
