extends GutTest

## El guanaco invocado acompaña a Benjamín TAMBIÉN hacia arriba y hacia abajo.
##
## El fallo: subido a una plataforma, el guanaco se quedaba abajo flotando a la
## altura donde lo invocaste, y lo mismo al descender.

const GUANACO := preload("res://scenes/actors/GuanacoCompanion.gd")


## Un Benjamín de mentira: lo justo para que el guanaco lo encuentre y sepa si
## está pisando algo.
class BenjaFalso extends Node3D:
	var is_archer := true
	var pisando := true

	func is_on_floor() -> bool:
		return pisando


func _benja(en: Vector3) -> BenjaFalso:
	var b := BenjaFalso.new()
	b.add_to_group("player")
	add_child_autofree(b)
	b.global_position = en
	b.add_child(Node3D.new())
	b.get_child(0).name = "Visual"
	return b


## El guanaco sin construir el modelo: sólo interesa a qué altura se pone.
func _guanaco(en: Vector3) -> Node3D:
	var g := Node3D.new()
	g.set_script(GUANACO)
	add_child_autofree(g)
	g.global_position = en
	g.set("_base_y", en.y)
	g.set("_ready_done", true)
	return g


func test_sube_con_la_plataforma() -> void:
	var b := _benja(Vector3(0, 5, 0))
	var g := _guanaco(Vector3(1.8, 0, 0))
	# Un segundo de perseguirlo, en pasos de frame.
	for i in 60:
		g.call("_follow_benja", 1.0 / 60.0)
	assert_almost_eq(float(g.get("_base_y")), 5.0, 0.2, "lo alcanza arriba")


func test_baja_con_la_plataforma() -> void:
	var b := _benja(Vector3(0, 0, 0))
	var g := _guanaco(Vector3(1.8, 4, 0))
	for i in 60:
		g.call("_follow_benja", 1.0 / 60.0)
	assert_almost_eq(float(g.get("_base_y")), 0.0, 0.2, "y lo alcanza abajo")


func test_no_lo_sigue_por_el_aire_al_saltar() -> void:
	var b := _benja(Vector3(0, 0, 0))
	var g := _guanaco(Vector3(1.8, 0, 0))
	# En pleno salto: Benjamín va por arriba y NO está pisando nada.
	b.pisando = false
	b.global_position = Vector3(0, 2.5, 0)
	for i in 30:
		g.call("_follow_benja", 1.0 / 60.0)
	assert_almost_eq(float(g.get("_base_y")), 0.0, 0.01,
		"el guanaco se queda en el suelo: no salta con vos")


func test_un_desnivel_enorme_se_salta_de_una() -> void:
	var b := _benja(Vector3(0, 40, 0))
	var g := _guanaco(Vector3(1.8, 0, 0))
	g.call("_follow_benja", 1.0 / 60.0)
	assert_almost_eq(float(g.get("_base_y")), 40.0, 0.01,
		"un teletransporte no se persigue a paso de guanaco")
