extends GutTest

## Que los mineros corruptos midan lo mismo que los protagonistas.
##
## Estaban a 1,8 m frente a los 2,2 de Emilia y Benjamín, y en pantalla se leían
## como enemigos menores en vez de como gente del tamaño de uno. La diferencia
## venía de que a los protagonistas se los agrandó y a ellos no.

const JUGADOR := preload("res://scenes/actors/PlayerController.gd")


func _altura_de(escena: String) -> float:
	var st := (load(escena) as PackedScene).get_state()
	for i in st.get_node_count():
		for j in st.get_node_property_count(i):
			if String(st.get_node_property_name(i, j)) == "altura_visual":
				return float(st.get_node_property_value(i, j))
	return -1.0


func test_el_minero_mide_lo_que_los_protagonistas() -> void:
	assert_almost_eq(_altura_de("res://scenes/enemies/MineroCorrupto.tscn"),
		JUGADOR.ALTO_PERSONAJE, 0.01,
		"el minero mide lo mismo que Emilia y Benjamín")


func test_los_jefes_son_mas_grandes_que_los_protagonistas() -> void:
	# Sólo se igualó al minero, que es gente. Los jefes se leen como jefes desde
	# que aparecen, y eso empieza por el tamaño.
	#
	# Lola estaba en 1,7 —más chica que Emilia y Benjamín, que miden 2,2— y sale
	# de detrás de los tablones sin imponer nada. Ahora es la más grande de las
	# tres criaturas.
	assert_gt(_altura_de("res://scenes/enemies/Chupacabras.tscn"), JUGADOR.ALTO_PERSONAJE,
		"el Chupacabras es más grande")
	assert_gt(_altura_de("res://scenes/enemies/Lola.tscn"), JUGADOR.ALTO_PERSONAJE,
		"Lola también, que es la jefa de la mina")


func test_al_crecer_lola_su_alcance_la_acompana() -> void:
	# Creció medio metro largo: con el alcance de antes, sus brazos llegaban más
	# lejos de lo que ella podía pegar y el golpe se veía atravesar al jugador
	# sin hacer nada.
	var l: CharacterBody3D = (load("res://scenes/enemies/Lola.tscn") as PackedScene).instantiate()
	assert_gt(l.attack_range, 2.2, "el alcance sube con el tamaño")
	l.free()
