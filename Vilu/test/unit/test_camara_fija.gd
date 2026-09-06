extends GutTest

## La cámara del jugador: cuando está fija, el ratón no la toca.
##
## Se podía girar con el botón derecho y alejar con la rueda hasta 70 m, con el
## personaje convertido en un punto. Que esté fija o no lo decide la escena de
## Game en el inspector; lo que se prueba acá es que la casilla haga lo que dice.

const JUEGO := preload("res://scenes/core/Game.gd")


func _juego() -> Node3D:
	var g := Node3D.new()
	g.set_script(JUEGO)
	# NO se mete en el árbol: su _ready carga un mundo entero. Acá sólo se le
	# preguntan los ajustes de cámara y se le manda una rueda.
	autofree(g)
	return g


func test_esta_cerca() -> void:
	var d := float(_juego().get("cam_distance"))
	assert_lt(d, 12.0, "a 18 m se veía media quebrada y los personajes de lejos")
	assert_gt(d, 5.0, "pero no encima de la nuca")


func test_la_rueda_no_la_aleja() -> void:
	var g := _juego()
	var antes := float(g.get("cam_distance"))
	var rueda := InputEventAction.new()
	rueda.action = "cam_zoom_out"
	rueda.pressed = true
	g.call("_unhandled_input", rueda)
	assert_almost_eq(float(g.get("cam_distance")), antes, 0.01,
		"la rueda no cambia el plano")


func test_destildandola_vuelve_el_zoom() -> void:
	# Sigue estando por si algún día hace falta mirar el mapa desde arriba.
	var g := _juego()
	g.set("camara_fija", false)
	var antes := float(g.get("cam_distance"))
	var rueda := InputEventAction.new()
	rueda.action = "cam_zoom_out"
	rueda.pressed = true
	g.call("_unhandled_input", rueda)
	assert_gt(float(g.get("cam_distance")), antes, "sin fijar, la rueda aleja")
