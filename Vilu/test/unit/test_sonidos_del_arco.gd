extends GutTest

## Los dos sonidos del arco: tensar y disparar.
##
## Llegaron como `.m4a`, que Godot no lee —admite wav, ogg y mp3—, así que se
## convirtieron a wav mono de 44,1 kHz. Son cortos, y en wav no hay que
## descomprimir nada al dispararlos.

const SFX := preload("res://scenes/Sfx.gd")
const JUGADOR := preload("res://scenes/actors/PlayerController.gd")


func test_los_dos_archivos_estan_en_el_proyecto() -> void:
	for id: String in SFX.GRABADOS:
		var ruta := String(SFX.GRABADOS[id])
		assert_true(ResourceLoader.exists(ruta), "existe %s" % ruta)
		var s := load(ruta) as AudioStream
		assert_not_null(s, "%s carga como audio" % id)
		assert_gt(s.get_length(), 0.0, "%s tiene duración" % id)


func test_son_cortos_como_un_efecto() -> void:
	# Si alguno viniera de varios segundos sería música, no un efecto, y se
	# solaparía consigo mismo al disparar seguido.
	for id: String in SFX.GRABADOS:
		var s := load(String(SFX.GRABADOS[id])) as AudioStream
		assert_lt(s.get_length(), 3.0, "%s dura lo que un efecto" % id)


func test_el_banco_los_carga() -> void:
	var s: Node = SFX.new()
	add_child_autofree(s)
	await wait_frames(2)
	var banco: Dictionary = s.get("_sounds")
	for id: String in SFX.GRABADOS:
		assert_true(banco.has(id), "el banco tiene '%s'" % id)
		assert_not_null(banco[id], "y no es nulo")


func test_el_disparo_ya_no_usa_el_tono_generado() -> void:
	# El arco sonaba con "fire", un tono sintético compartido con otras cosas.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/PlayerController.gd")
	assert_false(texto.contains('Sfx.play("fire"'),
		"el arco ya no dispara el tono generado")
	assert_true(texto.contains('Sfx.play("flecha"'), "usa el sonido grabado")
	assert_true(texto.contains('Sfx.play("tensar_arco"'), "y el de tensar")


func test_tensar_suena_solo_con_el_arquero() -> void:
	# Emilia también mantiene el clic para el golpe cargado; ahí no hay arco que
	# tensar.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/PlayerController.gd")
	var i := texto.find('Sfx.play("tensar_arco"')
	assert_gt(i, 0, "está en el código")
	var antes := texto.substr(maxi(0, i - 120), 120)
	assert_true(antes.contains("is_archer"), "va dentro de la rama del arquero")
