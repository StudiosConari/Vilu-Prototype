extends GutTest

## El juego en inglés: el español es la clave y el inglés sale de la tabla.

const IDIOMA := preload("res://scenes/core/Idioma.gd")


func after_each() -> void:
	TranslationServer.set_locale("es")


func after_all() -> void:
	Save.set_idioma("es")


func test_en_espanol_todo_queda_igual() -> void:
	TranslationServer.set_locale("es")
	assert_eq(IDIOMA.t("Ve al terminal de buses"), "Ve al terminal de buses")


func test_en_ingles_la_tabla_traduce() -> void:
	TranslationServer.set_locale("en")
	assert_eq(IDIOMA.t("Ve al terminal de buses"), "Go to the bus terminal")
	assert_eq(IDIOMA.t("Bruja"), "Witch")
	assert_eq(IDIOMA.t("Nueva partida"), "New game")
	assert_eq(IDIOMA.t("Texto que no existe en la tabla"), "Texto que no existe en la tabla",
		"lo que falta se queda en español, no como clave rara")


func test_el_guion_se_traduce_replica_a_replica() -> void:
	TranslationServer.set_locale("en")
	var guion := "~ start\nBruja: ¡Ese símbolo... lo conozco!\n=> preguntas\n~ preguntas\nBruja: ¿Tienen alguna otra pregunta?\n- No, gracias.\n\t=> END\n"
	var en := IDIOMA.guion(guion)
	assert_true(en.contains("~ start\n"), "las marcas se quedan")
	assert_true(en.contains("Witch: That symbol... I know it!"), "quién habla y qué dice, en inglés")
	assert_true(en.contains("- No, thank you.\n\t=> END"), "la respuesta también, con su sangría")
	assert_true(en.contains("=> preguntas\n~ preguntas"), "los saltos y títulos no se tocan")


func test_el_idioma_guardado_pone_el_locale() -> void:
	Save.set_idioma("en")
	assert_eq(TranslationServer.get_locale().substr(0, 2), "en")
	Save.set_idioma("es")
	assert_eq(TranslationServer.get_locale().substr(0, 2), "es")


func test_los_logros_y_las_misiones_salen_en_ingles() -> void:
	TranslationServer.set_locale("en")
	assert_eq(GameManager.titular_de_logro("tirana"), "First achievement: Cultural Investigator")
	var hud: CanvasLayer = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	await wait_frames(1)
	hud.call("_pintar_mision", {"texto": "Ve al terminal de buses", "total": 1}, 0)
	assert_true(String(hud.get("_mis_texto").text).begins_with("Go to the bus terminal"))
	hud.show_banner("¡HUYE!", 0.0)
	assert_eq(String(hud.get("_banner").text), "RUN!")
	hud.clear_banner()


## Todo diálogo del juego tiene su inglés: ninguna réplica se queda en español.
func test_todas_las_replicas_tienen_ingles() -> void:
	TranslationServer.set_locale("en")
	var sin: Array = []
	for ruta in ["res://scenes/actors/WitchNPC.gd", "res://scenes/actors/CarmenNPC.gd", "res://scenes/actors/PobladoHub.gd",
			"res://scenes/actors/YastayEncounter.gd", "res://scenes/actors/AlicantoRescate.gd", "res://scenes/actors/GuardianIsluga.gd",
			"res://scenes/actors/GuardianOjosSalado.gd", "res://scenes/actors/MinaCueva.gd", "res://scenes/puzzles/PuzzleIsluga.gd",
			"res://scenes/puzzles/CumbreCima.gd"]:
		var g := load(ruta) as GDScript
		for c in g.get_script_constant_map():
			var v = g.get_script_constant_map()[c]
			if not (v is String) or not String(v).begins_with("~ start"):
				continue
			for linea in String(v).split("\n"):
				var t := linea.strip_edges()
				if t == "" or t.begins_with("~") or t.begins_with("=>") or t.begins_with("-"):
					continue
				var que := t.substr(t.find(": ") + 2)
				if IDIOMA.t(que) == que and que.length() > 3:
					sin.append(que)
	assert_eq(sin.size(), 0, "sin inglés: %s" % ", ".join(PackedStringArray(sin)))


## El aviso de logro va arriba, chico, y no en la placa del centro.
func test_el_aviso_de_logro_es_chico_y_va_arriba() -> void:
	var hud: CanvasLayer = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	await wait_frames(1)
	var placa: PanelContainer = hud.get("_placa_de_logro")
	assert_not_null(placa, "tiene su propia placa")
	assert_lt(placa.anchor_top, 0.01, "arriba del todo")
	var aviso: Label = hud.get("_aviso")
	assert_lte(aviso.get_theme_font_size("font_size"), 20, "con letra chica")
	assert_false((hud.get("_cartel") as Control).is_ancestor_of(aviso), "y fuera de la placa del centro")
