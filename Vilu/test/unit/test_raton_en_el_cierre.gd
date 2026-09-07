extends GutTest

## La pantalla de cierre suelta el ratón.
##
## EL FALLO. Desde que la cámara sigue al puntero, jugar lo mantiene capturado.
## Game lo suelta en cuanto hay una pantalla modal, pero decidía quién era con
## `n is CanvasItem`, y un CanvasLayer tiene `visible` sin ser CanvasItem: la
## pantalla de logros no contaba. Al terminar el prototipo salía «PROTOTIPO
## SUPERADO» sin cursor con el que pulsar «Volver al título».

const LOGROS := preload("res://scenes/ui/PantallaLogros.gd")
const JUEGO := preload("res://scenes/core/Game.gd")


func test_el_cierre_es_una_pantalla_modal() -> void:
	var p: CanvasLayer = LOGROS.new()
	add_child_autofree(p)
	await wait_frames(1)
	assert_true(p.is_in_group("pantalla_modal"),
		"para que Game sepa que tiene que soltar el ratón")


func test_un_canvaslayer_cuenta_como_pantalla() -> void:
	# La comprobación mira la PROPIEDAD `visible`, no la clase. Con `is
	# CanvasItem` un CanvasLayer se colaba sin contar.
	var capa := CanvasLayer.new()
	add_child_autofree(capa)
	assert_true(JUEGO.alguna_visible([capa]), "el CanvasLayer visible cuenta")
	capa.visible = false
	assert_false(JUEGO.alguna_visible([capa]), "y escondido deja de contar")


func test_sin_pantallas_el_raton_se_queda_capturado() -> void:
	# Jugando, el puntero es la cámara: soltarlo de más sería igual de molesto.
	assert_false(JUEGO.alguna_visible([]), "sin menús, nada que soltar")
