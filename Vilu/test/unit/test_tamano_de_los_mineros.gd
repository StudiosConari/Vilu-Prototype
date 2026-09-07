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


func test_los_otros_enemigos_conservan_su_tamano() -> void:
	# Sólo se igualó al minero. El Chupacabras es más grande a propósito y Lola
	# más chica: son criaturas, no gente.
	assert_gt(_altura_de("res://scenes/enemies/Chupacabras.tscn"), JUGADOR.ALTO_PERSONAJE,
		"el Chupacabras sigue siendo más grande")
	assert_lt(_altura_de("res://scenes/enemies/Lola.tscn"), JUGADOR.ALTO_PERSONAJE,
		"Lola sigue siendo más chica")
