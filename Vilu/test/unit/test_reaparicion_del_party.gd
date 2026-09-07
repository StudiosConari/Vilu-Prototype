extends GutTest

## Dónde aparece el party al reaparecer.
##
## Al segundo y al tercero se los corre 2,5 m a cada lado para que no salgan
## amontonados. Eso da por sentado cinco metros de suelo, y en el cráter del
## Isluga no los hay: medido, a 2,5 m del punto de aparición el suelo está
## VEINTICUATRO metros más abajo. O sea que cada reaparición mandaba a dos de
## los tres a la lava.

const JUEGO := preload("res://scenes/core/Game.gd")


## El Game NO se mete en el árbol: su `_ready` monta un mundo entero. Acá sólo
## se le pide la cuenta, y el espacio de física se lo presta el personaje.
func _juego() -> Node3D:
	var g := Node3D.new()
	g.set_script(JUEGO)
	autofree(g)
	return g


## Una loseta de suelo de `lado` metros, centrada en `donde`.
func _loseta(donde: Vector3, lado: float) -> StaticBody3D:
	var s := StaticBody3D.new()
	s.collision_layer = 1
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(lado, 0.5, lado)
	cs.shape = caja
	s.add_child(cs)
	add_child_autofree(s)
	s.global_position = donde
	return s


## Alguien a quien colocar, que es de quien sale el espacio de física.
func _personaje() -> Node3D:
	var p := Node3D.new()
	add_child_autofree(p)
	return p


func test_con_suelo_de_sobra_se_reparten() -> void:
	var centro := Vector3(500, 0, 0)
	_loseta(centro + Vector3(0, -1, 0), 20.0)
	await wait_physics_frames(2)
	var off := Vector3(2.5, 0, 0)
	assert_almost_eq(_juego().call("_si_hay_suelo", centro, off, _personaje()),
		off, Vector3.ONE * 0.01, "hay dónde pisar: se aparta como siempre")


func test_sobre_una_plataforma_angosta_no_se_apartan() -> void:
	# Loseta de 2 m: a 2,5 m del centro ya no hay nada. En otro rincón del mundo
	# para que no la pise la loseta ancha del test anterior.
	var centro := Vector3(-500, 0, 0)
	_loseta(centro + Vector3(0, -1, 0), 2.0)
	await wait_physics_frames(2)
	var g := _juego()
	var quien := _personaje()
	assert_almost_eq(g.call("_si_hay_suelo", centro, Vector3(2.5, 0, 0), quien),
		Vector3.ZERO, Vector3.ONE * 0.01,
		"no hay suelo al lado: aparece en el punto, no en el aire")
	assert_almost_eq(g.call("_si_hay_suelo", centro, Vector3(-2.5, 0, 0), quien),
		Vector3.ZERO, Vector3.ONE * 0.01, "ni del otro lado")


func test_el_del_medio_nunca_se_mueve() -> void:
	assert_almost_eq(
		_juego().call("_si_hay_suelo", Vector3.ZERO, Vector3.ZERO, _personaje()),
		Vector3.ZERO, Vector3.ONE * 0.01,
		"el primero va al punto exacto, haya suelo o no")


# ─── El corta-bucles ─────────────────────────────────────────────────────────
#
# Reaparecer y volver a morir en el acto encadenaba muertes sin fin, y de un
# bucle así no se sale: hay que cerrar la ventana. Después de reaparecer hay un
# rato en que nada te vuelve a matar.

func test_no_se_puede_morir_dos_veces_seguidas() -> void:
	var g := _juego()
	assert_gte(float(g.get("GRACIA_TRAS_REAPARECER")), 1.0,
		"la gracia dura lo suficiente para salir de donde te mató")

	# Recién reaparecido: la lava no vuelve a mandarte al punto seguro.
	g.set("_gracia", 1.5)
	g.set("_resetting", false)
	var antes := float(g.get("_gracia"))
	g.call("volver_al_punto_seguro", "lava", 0.0)
	assert_almost_eq(float(g.get("_gracia")), antes, 0.01,
		"la segunda muerte no dispara otra reaparición")


func test_pasada_la_gracia_vuelve_a_valer() -> void:
	var g := _juego()
	g.set("_gracia", 0.0)
	g.set("_resetting", false)
	# Sin party ni HUD no llega a colocar a nadie, pero sí arranca la gracia, que
	# es lo que prueba que la reaparición ocurrió.
	g.call("volver_al_punto_seguro", "lava", 0.0)
	assert_almost_eq(float(g.get("_gracia")),
		float(g.get("GRACIA_TRAS_REAPARECER")), 0.01,
		"pasada la gracia, morir vuelve a reaparecerte")
