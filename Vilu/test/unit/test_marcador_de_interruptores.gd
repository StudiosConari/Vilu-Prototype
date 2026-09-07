extends GutTest

## Los interruptores de los dos volcanes llevan marcador mientras falten.
##
## Sin él hay que adivinar cuáles quedan por accionar en un cráter lleno de
## piedras iguales. En el Ojos del Salado es peor todavía: ese cubo está TAPADO
## a propósito por una muralla móvil, así que además hay que adivinar dónde está.

const INTERRUPTOR := preload("res://scenes/actors/InterruptorGolpeable.gd")
const FLECHAZO := preload("res://scenes/actors/ArrowSwitch.gd")
const GUIA := preload("res://scenes/core/GuiaDeObjetivos.gd")


func _cubo(mision: String) -> Node3D:
	var n := Node3D.new()
	var cuerpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cuerpo.add_child(cs)
	n.add_child(cuerpo)
	n.set_script(INTERRUPTOR)
	n.set("mision", mision)
	add_child_autofree(n)
	return n


func test_el_interruptor_se_marca_hasta_que_se_usa() -> void:
	var c := _cubo("isluga_volcan")
	assert_true(c.is_in_group("objetivo_isluga_volcan"), "se señala mientras falte")
	c.call("golpear", 10.0, Vector3.ZERO)
	assert_false(c.is_in_group("objetivo_isluga_volcan"), "y se apaga al accionarlo")


func test_sin_mision_no_se_marca() -> void:
	# Casi todos los interruptores del juego no son objetivo de nada.
	var c := _cubo("")
	var de_objetivo := 0
	for g in c.get_groups():
		if String(g).begins_with("objetivo_"):
			de_objetivo += 1
	assert_eq(de_objetivo, 0, "no entra en ningún grupo de objetivo")


func test_el_del_ojos_del_salado_tambien() -> void:
	var a: Area3D = FLECHAZO.new()
	a.set("mision", "ojos_volcan")
	add_child_autofree(a)
	await wait_frames(1)
	assert_true(a.is_in_group("objetivo_ojos_volcan"), "el cubo de la flecha se señala")


func test_las_escenas_los_tienen_declarados() -> void:
	# El guardián de las escenas: la lógica puede estar bien y no verse nada si
	# nadie rellenó `mision`.
	var isluga := FileAccess.get_file_as_string("res://scenes/puzzles/Isluga.tscn")
	assert_eq(isluga.count('mision = "isluga_volcan"'), 8,
		"los seis cubos del cráter y los dos del ascensor")
	var ojos := FileAccess.get_file_as_string("res://scenes/puzzles/OjosDelSalado.tscn")
	assert_eq(ojos.count('mision = "ojos_volcan"'), 1, "y el cubo de la flecha")


func test_no_se_muestran_mas_de_cuatro_a_la_vez() -> void:
	# Entre los ocho interruptores del Isluga y el guardián son nueve, y nueve
	# esferas flotando a la vez dejan de ser una guía.
	assert_lte(GUIA.MARCAS_A_LA_VEZ, 4, "hay tope")
	assert_gte(GUIA.MARCAS_A_LA_VEZ, 4,
		"pero al menos cuatro: las misiones de los guanacos y los cazadores son de a cuatro")
