extends GutTest

## Los marcos de los personajes en el HUD y la pantalla de la [P].

const HUD_ESCENA := "res://scenes/ui/HUD.tscn"
const PANTALLA := preload("res://scenes/ui/PantallaMarcos.gd")
const JUGADOR := preload("res://scenes/actors/PlayerController.gd")


class Actor extends Node:
	signal health_changed(current: int, maximum: int)
	signal energy_changed(current: int, maximum: int)
	enum AiMode { SIGUIENDO, FROZEN, SENUELO }
	var is_archer := false
	var ai_mode: int = AiMode.SIGUIENDO
	var health := 100
	var max_health := 100
	var energy := 100.0
	var max_energy := 100
	var _charging := false
	var _charge_t := 0.0
	var charge_time := 0.4


var _logros_antes: PackedStringArray
var _marco_emilia_antes := ""
var _marco_benjamin_antes := ""


func before_each() -> void:
	_logros_antes = Save.logros.duplicate()
	_marco_emilia_antes = Save.marco_emilia
	_marco_benjamin_antes = Save.marco_benjamin
	Save.marco_emilia = "clasico"
	Save.marco_benjamin = "clasico"


func after_each() -> void:
	Save.logros = _logros_antes
	Save.marco_emilia = _marco_emilia_antes
	Save.marco_benjamin = _marco_benjamin_antes
	get_tree().paused = false


func _hud() -> CanvasLayer:
	var hud: CanvasLayer = (load(HUD_ESCENA) as PackedScene).instantiate()
	add_child_autofree(hud)
	return hud


func _par() -> Array:
	var emilia := Actor.new()
	var benjamin := Actor.new()
	benjamin.is_archer = true
	add_child_autofree(emilia)
	add_child_autofree(benjamin)
	return [emilia, benjamin]


func _ruta(t: TextureRect) -> String:
	return String(t.get_meta("ruta", ""))


func test_el_arte_de_los_marcos_existe() -> void:
	for f in ["panel_emilia", "panel_benjamin", "retrato_emilia", "retrato_benjamin",
			"amurrada_emilia", "amurrado_benjamin", "alterno_emilia", "alterno_benjamin",
			"amurrada_alterna_emilia", "amurrado_alterno_benjamin",
			"barra_vida", "barra_energia", "barra_carga"]:
		assert_true(ResourceLoader.exists("res://textures/ui/hud/%s.png" % f), f)


func test_el_activo_lleva_el_marco_grande_y_el_otro_el_chico() -> void:
	var hud := _hud()
	var par := _par()
	hud.bind_player(par[0])
	hud.bind_companero(par[1])
	var retrato: TextureRect = hud.get("_retrato")
	var chico: TextureRect = hud.get("_chico")
	assert_true((hud.get("_marcos") as Control).visible, "el marco se ve con alguien atado")
	assert_string_ends_with(_ruta(retrato), "retrato_emilia.png")
	assert_string_ends_with(_ruta(hud.get("_panel")), "panel_emilia.png")
	assert_true(chico.visible)
	assert_string_ends_with(_ruta(chico), "retrato_benjamin.png", "tras [R] el otro sigue: marco chico")


func test_con_t_el_companero_sale_amurrado() -> void:
	var hud := _hud()
	var par := _par()
	hud.bind_player(par[1])
	hud.bind_companero(par[0])
	par[0].ai_mode = Actor.AiMode.FROZEN
	hud.call("_process", 0.016)
	assert_string_ends_with(_ruta(hud.get("_chico")), "amurrada_emilia.png")
	assert_string_ends_with(_ruta(hud.get("_retrato")), "retrato_benjamin.png")
	# Vuelve a seguir: se le pasa el enojo.
	par[0].ai_mode = Actor.AiMode.SIGUIENDO
	hud.call("_process", 0.016)
	assert_string_ends_with(_ruta(hud.get("_chico")), "retrato_emilia.png")


func test_sin_nadie_atado_no_se_ve_el_marco() -> void:
	var hud := _hud()
	hud.call("_process", 0.016)
	assert_false((hud.get("_marcos") as Control).visible)


func test_las_barras_siguen_la_vida_la_energia_y_la_carga() -> void:
	var hud := _hud()
	var par := _par()
	var emilia: Actor = par[0]
	hud.bind_player(emilia)
	emilia.health_changed.emit(25, 100)
	emilia.energy_changed.emit(50, 100)
	var barras: Dictionary = hud.get("_barras")
	assert_almost_eq(float(barras["vida"].value), 0.25, 0.001)
	assert_almost_eq(float(barras["energia"].value), 0.5, 0.001)
	emilia._charging = true
	emilia._charge_t = 0.2
	hud.call("_process", 0.016)
	assert_almost_eq(float(barras["carga"].value), 0.5, 0.001, "la carga a la mitad")
	emilia._charging = false
	hud.call("_process", 0.016)
	assert_almost_eq(float(barras["carga"].value), 0.0, 0.001)


func test_los_rotulos_se_traducen() -> void:
	var hud := _hud()
	var marcos: Control = hud.get("_marcos")
	var rotulo := marcos.get_node("RotuloVida") as Label
	assert_eq(rotulo.text, "Vida")
	assert_eq(tr("Energía"), "Energía")
	TranslationServer.set_locale("en")
	assert_eq(tr("Vida"), "Health")
	assert_eq(tr("Carga"), "Charge")
	TranslationServer.set_locale("es")


func test_el_marco_alterno_solo_con_el_logro_del_ojos_del_salado() -> void:
	Save.marco_emilia = "alterno"
	Save.logros = PackedStringArray()
	assert_eq(GameManager.marco_de("emilia"), "clasico", "elegido pero sin el logro")
	Save.logros = PackedStringArray(["ojos_salado"])
	assert_eq(GameManager.marco_de("emilia"), "alterno")
	assert_eq(GameManager.marco_de("benjamin"), "clasico", "Benjamín sigue con el suyo")
	var hud := _hud()
	var par := _par()
	hud.bind_player(par[0])
	hud.bind_companero(par[1])
	assert_string_ends_with(_ruta(hud.get("_retrato")), "alterno_emilia.png")
	assert_string_ends_with(_ruta(hud.get("_chico")), "retrato_benjamin.png")
	# El alterno va también en el amurrado: plantada con [T], Emilia sigue con
	# su corona.
	Save.marco_benjamin = "alterno"
	hud.bind_player(par[1])
	hud.bind_companero(par[0])
	par[0].ai_mode = Actor.AiMode.FROZEN
	hud.call("_process", 0.016)
	assert_string_ends_with(_ruta(hud.get("_retrato")), "alterno_benjamin.png")
	assert_string_ends_with(_ruta(hud.get("_chico")), "amurrada_alterna_emilia.png")


func test_el_jugador_de_verdad_tiene_lo_que_el_hud_lee() -> void:
	var p := JUGADOR.new()
	assert_true("is_archer" in p)
	assert_true("ai_mode" in p)
	assert_true("_charging" in p and "_charge_t" in p and "charge_time" in p)
	assert_eq(int(p.AiMode.FROZEN), int(Actor.AiMode.FROZEN))
	p.free()


func test_la_pantalla_de_la_p_para_el_juego_y_lista_los_logros() -> void:
	var raiz := Node.new()
	add_child_autofree(raiz)
	var p := PANTALLA.mostrar(raiz)
	assert_true(get_tree().paused, "el tiempo se para mientras está abierta")
	assert_true(p.is_in_group("pantalla_modal"))
	assert_not_null(p.find_child("Marco", true, false), "lleva el marco dibujado")
	var etiquetas: Dictionary = p.get("_etiquetas")
	assert_eq(etiquetas["emilia"].text, "Clásico")
	p.cerrar()
	await get_tree().process_frame
	assert_false(get_tree().paused, "al cerrar sigue el juego")


func test_el_selector_no_deja_elegir_el_alterno_bloqueado() -> void:
	Save.logros = PackedStringArray()
	var raiz := Node.new()
	add_child_autofree(raiz)
	var p := PANTALLA.mostrar(raiz)
	p.cambiar("benjamin", 1)
	assert_eq(Save.marco_benjamin, "clasico")
	var etiquetas: Dictionary = p.get("_etiquetas")
	assert_eq(etiquetas["benjamin"].text, PANTALLA.BLOQUEADO)
	p.cerrar()


func test_el_selector_guarda_el_alterno_cuando_esta_ganado() -> void:
	Save.logros = PackedStringArray(["ojos_salado"])
	var raiz := Node.new()
	add_child_autofree(raiz)
	var p := PANTALLA.mostrar(raiz)
	p.cambiar("benjamin", 1)
	assert_eq(Save.marco_benjamin, "alterno")
	var retratos: Dictionary = p.get("_retratos")
	assert_string_ends_with((retratos["benjamin"].texture as Texture2D).resource_path, "alterno_benjamin.png")
	p.cambiar("benjamin", 1)
	assert_eq(Save.marco_benjamin, "clasico", "da la vuelta")
	p.cerrar()


func test_la_accion_marcos_es_la_p_y_se_puede_cambiar() -> void:
	assert_true(InputMap.has_action("marcos"))
	var con_p := false
	for e in InputMap.action_get_events("marcos"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_P:
			con_p = true
	assert_true(con_p)
	var remapeo := load("res://scenes/core/Remapeo.gd") as GDScript
	assert_has(remapeo.EDITABLES, "marcos")


func test_el_letrero_menciona_la_p() -> void:
	var hud := _hud()
	assert_string_contains(hud.texto_del_letrero_de_controles(), "[P]")
