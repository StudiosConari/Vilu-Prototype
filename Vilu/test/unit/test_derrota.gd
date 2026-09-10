extends GutTest

## Con la vida a cero el jugador cae derrotado y el party vuelve al inicio de
## la zona. Antes llegar a cero no cambiaba nada: se seguía jugando con la
## barra vacía.

const JUGADOR := preload("res://scenes/actors/PlayerController.gd")
const JUEGO := preload("res://scenes/core/Game.gd")


func _jugador() -> CharacterBody3D:
	var p: CharacterBody3D = JUGADOR.new()
	p.active = true
	p.health = p.max_health
	return p


func test_a_cero_de_vida_avisa_que_murio() -> void:
	var p := _jugador()
	watch_signals(p)
	p.take_damage(p.max_health * 2)
	assert_eq(p.health, 0)
	assert_true(p.is_dead())
	assert_signal_emitted(p, "died")
	p.free()


func test_derrotado_no_recibe_mas_dano_y_revive_entero() -> void:
	var p := _jugador()
	p.take_damage(p.max_health)
	p.derrotar()
	assert_true(p.esta_derrotado())
	watch_signals(p)
	p.take_damage(10)
	assert_signal_not_emitted(p, "died", "derrotado ya no vuelve a morir")
	p.revivir()
	assert_false(p.esta_derrotado())
	assert_eq(p.health, p.max_health, "revive con toda la vida")
	assert_signal_emitted(p, "health_changed")
	p.free()


func test_el_juego_espera_un_momento_y_no_se_derrota_dos_veces() -> void:
	assert_gt(JUEGO.DERROTA_ESPERA, 0.5, "hay tiempo de ver la caída")
	assert_lt(JUEGO.DERROTA_ESPERA, 5.0, "pero no se hace eterno")
	var g: Node = JUEGO.new()
	assert_true(g.has_method("_al_caer_derrotado"))
	assert_true(g.has_method("_levantarse"))
	assert_false(bool(g.get("_derrotando")))
	g.free()


func test_el_aviso_de_derrota_esta_traducido() -> void:
	TranslationServer.set_locale("en")
	assert_ne(tr(JUEGO.AVISO_DE_DERROTA), JUEGO.AVISO_DE_DERROTA)
	assert_ne(tr(JUEGO.AVISO_DE_DERROTA_ELLA), JUEGO.AVISO_DE_DERROTA_ELLA)
	TranslationServer.set_locale("es")
	assert_true(JUEGO.AVISO_DE_DERROTA_ELLA.begins_with("Derrotada"), "en femenino para Emilia")
