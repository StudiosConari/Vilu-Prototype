extends "res://addons/gut/test.gd"

## Beat 4 — Isluga: cada uno activa con [E] su obelisco, que pone en marcha el
## ASCENSOR del otro; arriba, hablar con el guardián supera el desafío.

const ISLUGA := preload("res://scenes/puzzles/Isluga.tscn")

## Los nodos se buscan por NOMBRE en todo el árbol, igual que hace el juego.
## Con rutas fijas, agrupar el cráter bajo un nodo `Crater` rompía los tests sin
## que nada estuviera mal en la lógica.

func before_each() -> void:
	GameManager.reset_progress()

func after_all() -> void:
	GameManager.reset_progress()


func test_cube_activates_the_other_vert() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	assert_false(c.vert_active("BenjaminVert"), "arranca inactivo")
	c.find_child("EmiliaCube", true, false).activated.emit()   # Emilia activa el ascensor de Benjamín
	assert_true(c.vert_active("BenjaminVert"))
	assert_false(c.vert_active("EmiliaVert"))
	c.find_child("BenjaminCube", true, false).activated.emit()  # Benjamín activa el de Emilia
	assert_true(c.vert_active("EmiliaVert"))


func test_el_obelisco_no_se_acciona_a_golpes() -> void:
	# El diseño cambió: estos se accionan con [E]. El test viejo los golpeaba dos
	# veces y esperaba que se activaran, que es justo lo que ya no debe pasar.
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	var cube := c.find_child("EmiliaCube", true, false)
	watch_signals(cube)
	cube.take_damage()
	cube.take_damage()
	cube.take_damage()
	assert_false(cube.is_done(), "los golpes no lo accionan")
	assert_signal_not_emitted(cube, "activated")


func test_el_obelisco_se_acciona_al_interactuar() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	var cube := c.find_child("EmiliaCube", true, false)
	watch_signals(cube)
	cube._al_interactuar(null)
	assert_true(cube.is_done(), "con [E] queda accionado de una")
	assert_signal_emitted(cube, "activated")


func test_hablar_con_el_guardian_supera_el_desafio() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	watch_signals(c)
	assert_false(c.is_solved(), "arranca sin superar")
	c.superar()
	assert_true(c.is_solved())
	assert_signal_emitted(c, "solved")
	assert_true(GameManager.tiene_logro("isluga"), "concede el logro de la zona")
	assert_eq(GameManager.get_beat(), 4, "y avanza el beat")


func test_superar_dos_veces_no_repite() -> void:
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	c.superar()
	watch_signals(c)
	c.superar()
	assert_signal_not_emitted(c, "solved", "la segunda charla no vuelve a superarlo")


func test_no_depende_de_los_cubos_de_altura_que_ya_no_estan() -> void:
	# Regresión de un fallo real: la condición de superado exigía cuatro "cubos
	# de altura" por personaje. Ese piso se quitó del nivel y nadie tocó la
	# condición, así que el desafío quedó IMPOSIBLE y el beat 4 no avanzaba.
	var c := ISLUGA.instantiate()
	add_child_autofree(c)
	assert_null(c.get_node_or_null("EmiliaTopCubes"), "ese piso ya no existe")
	assert_null(c.get_node_or_null("BenjaminTopCubes"))
	c.superar()
	assert_true(c.is_solved(), "y aun así se supera")


# ─── El anillo del cráter aguanta más ────────────────────────────────────────
#
# Los 16 bloques que rodean el anillo de rocas del cráter forman un cuadrado
# cerrado, y son por los que hay que dar la vuelta entera. Con el aviso de 1,5 s
# de los demás no daba el tiempo: se cruzaban corriendo o no se cruzaban.

## Los del anillo, por nombre. El resto de los 55 bloques del volcán siguen con
## su tiempo de siempre.
const ANILLO := ["bloques_de_espuma_morada6", "bloques_de_espuma_morada27",
	"bloques_de_espuma_morada28", "bloques_de_espuma_morada29",
	"bloques_de_espuma_morada30", "bloques_de_espuma_morada31",
	"bloques_de_espuma_morada32", "bloques_de_espuma_morada33",
	"bloques_de_espuma_morada34", "bloques_de_espuma_morada35",
	"bloques_de_espuma_morada36", "bloques_de_espuma_morada37",
	"bloques_de_espuma_morada38", "bloques_de_espuma_morada39",
	"bloques_de_espuma_morada40", "bloques_de_espuma_morada41"]

const HUNDE := preload("res://scenes/actors/BloqueQueSeHunde.gd")


func _avisos_del_isluga() -> Dictionary:
	var st := (load("res://scenes/puzzles/Isluga.tscn") as PackedScene).get_state()
	var r := {}
	for i in st.get_node_count():
		var nombre := String(st.get_node_name(i))
		var es_bloque := false
		var aviso := -1.0
		for j in st.get_node_property_count(i):
			var prop := String(st.get_node_property_name(i, j))
			if prop == "script":
				var s: Script = st.get_node_property_value(i, j)
				es_bloque = s != null \
					and String(s.resource_path).ends_with("BloqueQueSeHunde.gd")
			elif prop == "aviso":
				aviso = float(st.get_node_property_value(i, j))
		if es_bloque:
			r[nombre] = aviso
	return r


func test_los_del_anillo_aguantan_el_doble() -> void:
	var avisos := _avisos_del_isluga()
	var porDefecto: float = HUNDE.new().aviso
	for n in ANILLO:
		assert_true(avisos.has(n), "el bloque '%s' sigue en la escena" % n)
		if not avisos.has(n):
			continue
		assert_gt(float(avisos[n]), porDefecto,
			"'%s' aguanta más que los demás" % n)


func test_los_demas_siguen_igual() -> void:
	# El cambio es SÓLO del anillo: si se le sube el tiempo a todo el volcán, el
	# puzzle de las plataformas deja de ser un puzzle.
	var avisos := _avisos_del_isluga()
	var tocados := 0
	for n in avisos:
		if n in ANILLO:
			continue
		if float(avisos[n]) >= 0.0:
			tocados += 1
	assert_eq(tocados, 0, "ningún otro bloque lleva tiempo propio")


func test_son_dieciseis_y_estan_todos() -> void:
	var avisos := _avisos_del_isluga()
	var con_tiempo := 0
	for n in avisos:
		if float(avisos[n]) >= 0.0:
			con_tiempo += 1
	assert_eq(con_tiempo, ANILLO.size(), "los 16 del anillo, ni uno más")
