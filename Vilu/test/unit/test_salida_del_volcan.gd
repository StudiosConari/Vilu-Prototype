extends GutTest

## Salir de un volcán al que llegaste CRUZANDO EL PORTAL.
##
## El fallo real: el portal del guardián te lleva de un volcán al otro, pero sólo
## cambia la escena del interior; el mundo de debajo sigue siendo el que había.
## Y la marca de "por dónde entré" apunta al PRIMER volcán. Saliendo del Isluga
## —que es de Tarapacá— aparecías en mitad de Atacama, con la misión pidiéndote
## volver a la mina, que WorldRoot sólo construye en Tarapacá.

const JUEGO := preload("res://scenes/core/Game.gd")
const PUERTA := preload("res://scenes/actors/ZoneExit.gd")

const TARAPACA := "res://scenes/core/World.tscn"
const ATACAMA := "res://scenes/core/WorldAtacama.tscn"


## El juego como caja de herramientas: NO se mete en el árbol, porque su _ready
## monta el mundo entero. Sólo se le piden las consultas sobre puertas.
func _juego() -> Node:
	var j: Node = JUEGO.new()
	autofree(j)
	return j


## Los mundos se leen como TEXTO, sin instanciarlos. Montar World.tscn entero
## para contar puertas tarda un mundo y llena la salida de avisos del motor que
## no tienen que ver con esto.
func _puertas_declaradas(ruta: String) -> Array:
	var f := FileAccess.open(ruta, FileAccess.READ)
	assert_not_null(f, "se puede leer %s" % ruta)
	if f == null:
		return []
	var r: Array = []
	var re := RegEx.create_from_string('target_region = "([^"]+)"')
	for m in re.search_all(f.get_as_text()):
		r.append(m.get_string(1))
	return r


## Una puerta de mentira, con el mismo guion que las de verdad.
func _puerta(hacia: String, en: Vector3, alto: float) -> Node3D:
	var p := Area3D.new()
	p.set_script(PUERTA)
	p.target_region = hacia
	p.tamano = Vector3(16.0, alto, 16.0)
	add_child_autofree(p)
	p.global_position = en
	return p


func _mundo_con(puertas: Array) -> Node3D:
	var m := Node3D.new()
	add_child_autofree(m)
	# Colgadas de un hijo, como en las escenas de verdad: las subidas a los
	# volcanes viven dentro de un nodo "Subida ...", no en la raíz.
	var rama := Node3D.new()
	rama.name = "Subida"
	m.add_child(rama)
	for p: Node3D in puertas:
		p.reparent(rama, true)
	return m


# ─── El reparto de puertas entre mundos ──────────────────────────────────────

func test_cada_volcan_vive_en_su_region() -> void:
	# Es la premisa del fallo: si algún día los dos volcanes están en el mismo
	# mundo, este test avisa de que el arreglo dejó de hacer falta.
	var tarapaca := _puertas_declaradas(TARAPACA)
	var atacama := _puertas_declaradas(ATACAMA)
	assert_has(tarapaca, "Isluga", "el Isluga se sube desde Tarapacá")
	assert_does_not_have(atacama, "Isluga", "y no desde Atacama")
	assert_has(atacama, "OjosDelSalado", "el Ojos del Salado, desde Atacama")
	assert_does_not_have(tarapaca, "OjosDelSalado", "y no desde Tarapacá")


func test_encuentra_la_puerta_aunque_cuelgue_de_un_hijo() -> void:
	var j := _juego()
	j.set("world", _mundo_con([_puerta("Isluga", Vector3(79, 5, -14), 8.0)]))
	assert_not_null(j.call("_puerta_hacia", "Isluga"),
		"con Tarapacá cargado, la subida al Isluga está a mano")


func test_la_puerta_del_otro_mundo_no_aparece() -> void:
	var j := _juego()
	j.set("world", _mundo_con([_puerta("Isluga", Vector3(79, 5, -14), 8.0)]))
	assert_null(j.call("_puerta_hacia", "OjosDelSalado"),
		"es de la otra región, y ese null es lo que dispara el cambio de mundo")


func test_sin_mundo_no_hay_puerta() -> void:
	assert_null(_juego().call("_puerta_hacia", "Isluga"),
		"sin mundo cargado no se inventa ninguna")


# ─── Dónde deja al party ─────────────────────────────────────────────────────

func test_se_sale_al_pie_de_la_puerta_no_por_el_techo() -> void:
	var j := _juego()
	var p := _puerta("Isluga", Vector3(79, 5, -14), 8.0)
	var pie: Vector3 = j.call("_al_pie_de", p)
	assert_almost_eq(pie.y, 1.0, 0.01,
		"el origen del disparador está en su centro, a 5 m; su pie está a 1")
	assert_almost_eq(pie.x, 79.0, 0.01, "sin moverse en horizontal")


func test_sin_puerta_no_devuelve_una_posicion_cualquiera() -> void:
	assert_eq(_juego().call("_al_pie_de", null), Vector3.INF,
		"INF es lo que exit_interior entiende como 'no sé, usá el respaldo'")


# ─── La cámara ───────────────────────────────────────────────────────────────

func test_la_camara_se_planta_en_el_sitio_nuevo() -> void:
	# Interpolar está bien caminando, pero un teletransporte mueve al party
	# cientos de metros: al abrirse el fundido veías a los personajes como dos
	# puntitos en el horizonte mientras la cámara cruzaba el mapa.
	var j := _juego()
	j.set("_cam_focus", Vector3(0, 0, 0))
	j.set("_cam_dist_actual", -1.0)
	j.call("_pegar_la_camara", Vector3(500, 20, -300))
	var foco: Vector3 = j.get("_cam_focus")
	assert_almost_eq(foco.x, 500.0, 0.01, "el foco salta, no viaja")
	assert_almost_eq(foco.z, -300.0, 0.01)
	assert_gt(float(j.get("_cam_dist_actual")), 0.0,
		"y la distancia queda resuelta, no en su valor de 'sin calcular'")
