extends GutTest

## Que caer a la lava del Isluga SIEMPRE te saque de ahí.
##
## El fallo que arregla: la ventana de gracia que sigue a un rescate —puesta
## para cortar los bucles de muerte— se comía el aviso de la lava, porque el
## aviso llegaba una sola vez, al entrar. Quien tocaba la lava dentro de esa
## ventana no volvía a ningún sitio: seguía hundiéndose y terminaba de pie bajo
## el cráter, sobre la cáscara del volcán, donde ni hay lava que lo alcance ni
## altura suficiente para contar como caída. De ahí sólo se sale cerrando el
## juego, que es bastante peor que el bucle que la gracia venía a evitar.

const JUEGO := preload("res://scenes/core/Game.gd")
const LAVA := preload("res://scenes/actors/LavaQuema.gd")


## Un Game de verdad, sin meter en el árbol: `decidir_rescate` sólo mira sus
## propias variables, así que no hace falta el mundo ni la cámara ni el HUD.
func _juego(gracia: float, espera: float) -> Node:
	var g: Node = JUEGO.new()
	g.set("_gracia", gracia)
	g.set("_espera_de_rescate", espera)
	return g


func test_en_gracia_igual_te_saca_de_la_lava() -> void:
	var g := _juego(1.0, 0.0)          # acaba de reaparecer
	var d: Array = g.call("decidir_rescate")
	assert_true(bool(d[0]), "en gracia también te saca de la lava")
	g.free()


func test_en_gracia_no_cobra_el_dano() -> void:
	var g := _juego(1.0, 0.0)
	var d: Array = g.call("decidir_rescate")
	assert_false(bool(d[1]), "la gracia sigue protegiendo del daño")
	g.free()


func test_pasada_la_gracia_vuelve_a_doler() -> void:
	var g := _juego(0.0, 0.0)
	var d: Array = g.call("decidir_rescate")
	assert_true(bool(d[0]) and bool(d[1]), "fuera de la gracia el chapuzón cuesta vida")
	g.free()


func test_no_dispara_en_rafaga() -> void:
	# La lava pregunta cada cuadro: sin una espera mínima serían sesenta
	# rescates por segundo mientras dure el contacto.
	var g := _juego(0.0, 0.3)
	var d: Array = g.call("decidir_rescate")
	assert_false(bool(d[0]), "con la espera puesta no se rescata otra vez")
	g.free()


func test_la_espera_entre_rescates_es_corta() -> void:
	# Corta a propósito: sólo evita la ráfaga. Si fuera larga volveríamos al
	# problema de partida —quedarte dentro de la lava sin que nada te saque—,
	# que es justo lo que no puede pasar.
	assert_lt(JUEGO.RESCATE_MINIMO, 1.0, "menos de un segundo")
	assert_gt(JUEGO.RESCATE_MINIMO, 0.0, "pero no cero")
	assert_lt(JUEGO.RESCATE_MINIMO, JUEGO.GRACIA_TRAS_REAPARECER,
		"y más corta que la gracia, o la gracia no serviría de nada")


func test_la_lava_mira_cada_cuadro_no_solo_al_entrar() -> void:
	# La otra mitad del arreglo: aunque Game rescatara siempre, con
	# `body_entered` el aviso llega UNA vez y si se pierde no hay segunda.
	var l = LAVA.new()
	assert_true(l.has_method("_physics_process"),
		"la lava comprueba mientras estás dentro, no sólo al entrar")
	l.free()
