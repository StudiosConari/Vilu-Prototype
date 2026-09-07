extends GutTest

## Un interior puede decir DÓNDE se reaparece al morir, aparte de por dónde se
## entra.
##
## No son lo mismo: al Isluga se llega por la boca del cráter, y caerse a la lava
## y volver ahí obliga a rehacer la subida entera. El marcador se arrastra en el
## editor, sin tocar código.

const JUEGO := preload("res://scenes/core/Game.gd")


func test_el_isluga_tiene_su_marcador() -> void:
	var esc := load("res://scenes/puzzles/Isluga.tscn") as PackedScene
	var raiz := esc.instantiate()
	add_child_autofree(raiz)
	await wait_frames(2)
	var m := raiz.find_child(JUEGO.MARCADOR_DE_RESCATE, true, false) as Node3D
	assert_not_null(m, "el Isluga declara dónde reaparecer al caer a la lava")


func test_se_busca_en_profundidad() -> void:
	# Da igual de qué nodo cuelgue: así se puede arrastrar a donde haga falta sin
	# que deje de encontrarse. Es la misma lección que costó el PlayerSpawn
	# cuando el cráter se agrupó bajo un nodo.
	var texto := FileAccess.get_file_as_string("res://scenes/core/Game.gd")
	var i := texto.find("func _punto_de_rescate")
	assert_gt(i, 0, "existe la búsqueda")
	assert_true(texto.substr(i, 400).contains("find_child(MARCADOR_DE_RESCATE, true, false)"),
		"busca recursivamente")


func test_sin_marcador_manda_el_punto_de_siempre() -> void:
	# Las demás zonas no lo tienen y no pueden cambiar de comportamiento.
	for escena: String in ["res://scenes/regions/Mina.tscn", "res://scenes/regions/Iglesia.tscn"]:
		var raiz := (load(escena) as PackedScene).instantiate()
		add_child_autofree(raiz)
		await wait_frames(1)
		assert_null(raiz.find_child(JUEGO.MARCADOR_DE_RESCATE, true, false),
			"%s sigue sin marcador propio" % escena.get_file())
