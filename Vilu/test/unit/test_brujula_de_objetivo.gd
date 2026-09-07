extends GutTest

## La flecha del borde sólo tiene que salir cuando el objetivo NO se ve.
##
## Si sale estando el objetivo a la vista se pisa con el marcador y la pantalla
## queda con dos cosas diciendo lo mismo, una de ellas mal puesta.

const GUIA := preload("res://scenes/core/GuiaDeObjetivos.gd")
const MARCADOR := preload("res://scenes/actors/MarcadorDeObjetivo.gd")


class GameFalso extends Node3D:
	var hud: CanvasLayer = null
	var puerta: Node3D = null

	func puerta_hacia(_id: String) -> Node3D:
		return null


## Una cámara mirando a -Z desde el origen, y la guía colgando de un Game falso.
func _escena() -> Array:
	var g := GameFalso.new()
	add_child_autofree(g)
	var cam := Camera3D.new()
	g.add_child(cam)
	cam.global_position = Vector3.ZERO
	cam.look_at(Vector3(0.0, 0.0, -10.0), Vector3.UP)
	cam.current = true
	var guia := Node.new()
	guia.set_script(GUIA)
	g.add_child(guia)
	# Una misión inventada, y los objetivos en su grupo: es el camino de verdad.
	# Metiéndolos a mano en `_marcas` no duraban, porque el repaso de la guía
	# corre en su `_process` y borra lo que no pertenezca a la misión activa.
	guia.set("_mision", MISION)
	return [guia, cam]


const MISION := "prueba_de_brujula"


## Un objetivo en `donde`. El marcador se lo pone la guía, como en el juego.
func _objetivo(guia: Node, donde: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child_autofree(n)
	n.global_position = donde
	n.add_to_group("objetivo_" + MISION)
	guia.call("_repasar")
	return n


func test_no_hay_flecha_si_el_objetivo_se_ve() -> void:
	var e := _escena()
	var guia: Node = e[0]
	# Justo delante de la cámara, a nueve metros: el caso de la captura.
	_objetivo(guia, Vector3(0.0, 0.0, -9.0))
	await wait_frames(2)
	var m: Array = guia.call("_mira")
	assert_true(bool(m[0]), "hay objetivo")
	assert_true(bool(m[1]), "y está en pantalla, así que la flecha sobra")


func test_hay_flecha_si_queda_a_la_espalda() -> void:
	var e := _escena()
	var guia: Node = e[0]
	_objetivo(guia, Vector3(0.0, 0.0, 12.0))     # detrás de la cámara
	await wait_frames(2)
	var m: Array = guia.call("_mira")
	assert_true(bool(m[0]), "hay objetivo")
	assert_false(bool(m[1]), "a la espalda no se ve: hace falta la flecha")


func test_hay_flecha_si_queda_muy_al_costado() -> void:
	var e := _escena()
	var guia: Node = e[0]
	# Delante, pero tan al costado que se sale del encuadre.
	_objetivo(guia, Vector3(60.0, 0.0, -9.0))
	await wait_frames(2)
	var m: Array = guia.call("_mira")
	assert_false(bool(m[1]), "fuera de cuadro: hace falta la flecha")


func test_a_la_espalda_apunta_hacia_atras_y_no_al_reves() -> void:
	# `unproject_position` de algo que está detrás devuelve el punto ESPEJADO:
	# sin corregirlo, la flecha apuntaría justo al contrario de donde hay que ir.
	var e := _escena()
	var guia: Node = e[0]
	_objetivo(guia, Vector3(8.0, 0.0, 12.0))     # detrás y a la DERECHA
	await wait_frames(2)
	var m: Array = guia.call("_mira")
	var p: Vector2 = m[2]
	var centro: Vector2 = get_viewport().get_visible_rect().size * 0.5
	assert_gt(p.x, centro.x, "detrás y a la derecha: la flecha va a la derecha")
