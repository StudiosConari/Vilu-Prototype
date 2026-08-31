extends "res://addons/gut/test.gd"

## La pantalla de cierre del prototipo.

const PANTALLA := preload("res://scenes/ui/PantallaLogros.gd")
const GAME := preload("res://scenes/core/Game.tscn")

## Mismo motivo que en test_world: cargar Game.tscn levanta Terrain3D, que llama
## a una función que Godot 4.7 marcó obsoleta. Es una GDExtension, no se puede
## arreglar desde el proyecto, y GUT toma cualquier error del motor como fallo.
var _errores_antes = null


func before_all() -> void:
	_errores_antes = gut.error_tracker.treat_engine_errors_as
	gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.NOTHING

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	if _errores_antes != null:
		gut.error_tracker.treat_engine_errors_as = _errores_antes
	GameManager.reset_progress()


func _filas(n: Node, acc: Array) -> void:
	if n is HBoxContainer:
		acc.append(n)
	for c in n.get_children():
		_filas(c, acc)


func _textos(n: Node, acc: Array) -> void:
	if n is Label:
		acc.append((n as Label).text)
	for c in n.get_children():
		_textos(c, acc)


func test_lista_los_nueve_logros() -> void:
	for l in GameManager.LOGROS:
		GameManager.conceder(l["id"])
	var p: CanvasLayer = PANTALLA.mostrar(self)
	autofree(p)
	var filas: Array = []
	_filas(p, filas)
	assert_eq(filas.size(), GameManager.LOGROS.size(), "una fila por logro")
	var textos: Array = []
	_textos(p, textos)
	assert_has(textos, "PROTOTIPO SUPERADO")
	assert_has(textos, "9 de 9 logros")
	for l in GameManager.LOGROS:
		assert_has(textos, str(l["titulo"]), "aparece el título de cada logro")


func test_el_logro_que_falta_se_muestra_como_pista() -> void:
	# La pantalla no da por hecho que estén los nueve: si se abriera antes de
	# tiempo tiene que verse qué falta, no mentir.
	for l in GameManager.LOGROS:
		if l["id"] != "chupacabras":
			GameManager.conceder(l["id"])
	var p: CanvasLayer = PANTALLA.mostrar(self)
	autofree(p)
	var textos: Array = []
	_textos(p, textos)
	assert_has(textos, "8 de 9 logros")
	assert_has(textos, str(GameManager.logro("chupacabras")["pista"]),
		"del que falta se muestra cómo conseguirlo")
	assert_does_not_have(textos, str(GameManager.logro("chupacabras")["titulo"]))


func test_esconde_el_hud() -> void:
	var hud := CanvasLayer.new()
	hud.add_to_group("hud")
	add_child_autofree(hud)
	assert_true(hud.visible)
	var p: CanvasLayer = PANTALLA.mostrar(self)
	autofree(p)
	assert_false(hud.visible, "el HUD no se transparenta detrás del cierre")


func test_el_juego_escucha_el_cierre() -> void:
	GameManager.reset_progress()
	var game := GAME.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(GameManager.prototipo_superado.is_connected(game._al_superar_el_prototipo),
		"Game engancha el cierre, así que el último logro puede caer en cualquier zona")
