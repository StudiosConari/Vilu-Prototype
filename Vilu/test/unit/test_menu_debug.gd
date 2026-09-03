extends "res://addons/gut/test.gd"

## El selector de zonas del menú de inicio.
##
## Entrar por una parada tiene que dejar el prototipo como estaría de haber
## llegado jugando: el beat, las habilidades Y los logros de todo lo anterior.
## Sin los logros, elegir la parada del Chupacabras dejaba el duelo imposible
## —lo exige los ocho previos—, o sea que el prototipo no se podía cerrar desde
## el menú.

const TITULO := preload("res://scenes/TitleScreen.gd")


func after_all() -> void:
	GameManager.reset_progress()


func _menu() -> Node:
	var t: Node = Control.new()
	t.set_script(TITULO)
	add_child_autofree(t)
	await wait_frames(2)
	return t


## Las paradas van en el mismo orden que los logros del juego. Si alguien
## reordena una lista y no la otra, entrar por una parada daría por hechos
## logros de más o de menos.
func test_el_orden_del_menu_sigue_al_de_los_logros() -> void:
	var del_menu: PackedStringArray = []
	for z in TITULO.DEBUG_ZONES:
		if String(z["otorga"]) != "":
			del_menu.append(str(z["otorga"]))
	var del_juego: PackedStringArray = []
	for l in GameManager.LOGROS:
		del_juego.append(str(l["id"]))
	assert_eq(del_menu, del_juego,
		"cada logro tiene su parada, y en el mismo orden")


func test_toda_parada_otorga_un_logro_conocido() -> void:
	for z in TITULO.DEBUG_ZONES:
		var id: String = z["otorga"]
		if id == "":
			continue
		assert_false(GameManager.logro(id).is_empty(),
			"'%s' es un logro que existe" % id)


## La que importa: elegir el Chupacabras tiene que dejar el duelo disponible.
func test_la_parada_del_chupacabras_deja_el_duelo_listo() -> void:
	var t := await _menu()
	var i := -1
	for k in TITULO.DEBUG_ZONES.size():
		if String(TITULO.DEBUG_ZONES[k]["otorga"]) == "chupacabras":
			i = k
	assert_gt(i, -1, "hay una parada para el Chupacabras")
	if i < 0:
		return

	GameManager.reset_progress()
	for id in t._logros_previos(i):
		GameManager.conceder(id)

	# La misma condición que usa la cueva de la mina para plantar el duelo.
	var falta := ""
	for l in GameManager.LOGROS:
		if l["id"] != "chupacabras" and not GameManager.tiene_logro(l["id"]):
			falta = str(l["id"])
	assert_eq(falta, "", "no falta ningún logro previo para el duelo")
	assert_false(GameManager.tiene_logro("chupacabras"),
		"el suyo NO se da hecho: es el que hay que ganar ahí")


func test_cada_parada_da_por_hecho_lo_anterior_y_nada_mas() -> void:
	var t := await _menu()
	for i in TITULO.DEBUG_ZONES.size():
		var previos: PackedStringArray = t._logros_previos(i)
		var propio: String = TITULO.DEBUG_ZONES[i]["otorga"]
		assert_false(propio != "" and propio in previos,
			"la parada %d no se regala su propio logro" % i)
		# Y ninguno de los que vienen después.
		for j in range(i, TITULO.DEBUG_ZONES.size()):
			var posterior: String = TITULO.DEBUG_ZONES[j]["otorga"]
			assert_false(posterior != "" and posterior in previos,
				"la parada %d no adelanta el logro de la %d" % [i, j])


## Interiores: no son zonas del mundo, se cargan aparte.
const INTERIORES := ["Mina", "Final", "Iglesia", "Isluga", "OjosDelSalado"]
const TARAPACA := "res://scenes/core/World.tscn"


func _tiene_nodo(escena: PackedScene, nombre: String) -> bool:
	var st := escena.get_state()
	for i in st.get_node_count():
		if String(st.get_node_name(i)) == nombre:
			return true
	return false


## Cada parada tiene que existir en el mundo que declara.
##
## El mapa está partido en dos y Alicanto y Yastay viven SÓLO en Atacama, pero
## sus entradas no declaraban mundo, o sea que apuntaban a Tarapacá. Ahí
## `has_zone` daba falso, Game intentaba abrirlas como interior —que tampoco
## son— y te dejaba tirado en el spawn de Tarapacá.
func test_cada_parada_existe_en_el_mundo_que_declara() -> void:
	for z in TITULO.DEBUG_ZONES:
		var zona: String = z["zona"]
		if zona in INTERIORES:
			continue
		var ruta: String = z["mundo"] if String(z["mundo"]) != "" else TARAPACA
		assert_true(_tiene_nodo(load(ruta) as PackedScene, zona),
			"la zona '%s' de la parada '%s' está en %s"
			% [zona, z["nombre"], ruta.get_file()])
