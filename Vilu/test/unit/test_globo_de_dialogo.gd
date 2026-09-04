extends "res://addons/gut/test.gd"

## El globo de diálogo del juego.
##
## Es una copia del globo de EJEMPLO del Dialogue Manager, que es lo que el
## propio addon te dice que hagas: el suyo se pinta encima un cartel que dice
## "This is an example balloon…" y no hay forma de quitarlo desde fuera, porque
## lo añade su script al arrancar.
##
## Estos tests vigilan las dos cosas por las que existe la copia: que el cartel
## no esté, y que el panel lleve el mismo estilo que el recuadro de misiones.

const GLOBO := preload("res://scenes/ui/GloboDeDialogo.tscn")

## Los del recuadro de misiones (ver HUD._montar_misiones).
const FONDO := Color(0.06, 0.07, 0.10)
const BORDE := Color(0.85, 0.80, 0.55)


func _botones(n: Node, r: Array) -> Array:
	if n is Button:
		r.append(n)
	for h in n.get_children():
		_botones(h, r)
	return r


func test_no_lleva_el_cartel_del_addon() -> void:
	var g: CanvasLayer = GLOBO.instantiate()
	add_child_autofree(g)
	await wait_frames(3)
	for b: Button in _botones(g, []):
		assert_false(b.text.contains("example balloon"),
			"nada de 'This is an example balloon…' encima del diálogo")


func test_lleva_el_estilo_del_recuadro_de_misiones() -> void:
	var g: CanvasLayer = GLOBO.instantiate()
	add_child_autofree(g)
	await wait_frames(3)
	var panel: PanelContainer = g.get_node_or_null("Balloon/MarginContainer/PanelContainer")
	assert_not_null(panel, "el globo tiene su panel")
	if panel == null:
		return
	var caja := panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(caja)
	if caja == null:
		return
	assert_almost_eq(caja.bg_color.r, FONDO.r, 0.01, "mismo fondo oscuro")
	assert_almost_eq(caja.bg_color.g, FONDO.g, 0.01)
	assert_almost_eq(caja.bg_color.b, FONDO.b, 0.01)
	assert_lt(caja.bg_color.a, 1.0, "y translúcido, no negro macizo")
	assert_almost_eq(caja.border_color.r, BORDE.r, 0.01, "mismo borde dorado")
	assert_gt(caja.border_width_top, 0, "con borde")
	assert_gt(caja.corner_radius_top_left, 0, "y esquinas redondeadas")


## Y que nadie se haya quedado apuntando al del addon.
func test_nadie_usa_ya_el_globo_del_addon() -> void:
	var pendientes: PackedStringArray = []
	for ruta in _guiones("res://scenes"):
		var f := FileAccess.open(ruta, FileAccess.READ)
		if f == null:
			continue
		if f.get_as_text().contains("example_balloon.tscn"):
			pendientes.append(ruta)
	assert_eq(pendientes.size(), 0,
		"todos usan el globo del juego (faltan: %s)" % ", ".join(pendientes))


func _guiones(dir: String) -> PackedStringArray:
	var r: PackedStringArray = []
	for d in DirAccess.get_directories_at(dir):
		r.append_array(_guiones(dir + "/" + d))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			r.append(dir + "/" + f)
	return r
