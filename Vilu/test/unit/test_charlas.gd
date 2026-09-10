extends GutTest

## Las charlas de la pareja y lo que las dispara: la huida de la mina, la
## llegada a los volcanes, el señuelo del Yastay y las preguntas a la Bruja.

const CHARLA := preload("res://scenes/core/Charla.gd")
const JUGADOR := preload("res://scenes/actors/PlayerController.gd")
const JUEGO := preload("res://scenes/core/Game.gd")
const YASTAY := preload("res://scenes/actors/YastayEncounter.gd")
const BRUJA := preload("res://scenes/actors/WitchNPC.gd")


func before_each() -> void:
	GameManager.reset_progress()


func after_all() -> void:
	GameManager.reset_progress()


func test_cada_charla_se_dice_una_sola_vez() -> void:
	assert_true(GameManager.charla_pendiente("x"), "la primera vez, sí")
	assert_false(GameManager.charla_pendiente("x"), "la segunda, ya no")
	GameManager.reset_progress()
	assert_true(GameManager.charla_pendiente("x"), "una partida nueva la vuelve a permitir")


func test_una_vez_no_repite() -> void:
	# Sin árbol y sin espera dispararía el globo de verdad: se prueba sólo la
	# cuenta, con una espera que no vence mientras corre la suite: a 30 s el
	# globo se abría en mitad de otros tests y la pausa no podía abrirse.
	assert_true(CHARLA.una_vez(get_tree(), "prueba", "~ start\nA: b\n=> END\n", 100000.0))
	assert_false(CHARLA.una_vez(get_tree(), "prueba", "~ start\nA: b\n=> END\n", 100000.0))


## La huida de la mina deja la charla pendiente para el poblado.
func test_la_huida_de_la_mina_se_comenta_en_el_poblado() -> void:
	var src := (load("res://scenes/actors/MinaCueva.gd") as GDScript).source_code
	assert_true(src.contains("GameManager.huyo_de_la_mina = true"), "la mina avisa al escapar")
	var pob := (load("res://scenes/actors/PobladoHub.gd") as GDScript).source_code
	assert_true(pob.contains("huida_de_la_mina") and pob.contains("piel de gallina"),
		"y el poblado la dice al activarse")
	GameManager.huyo_de_la_mina = true
	GameManager.reset_progress()
	assert_false(GameManager.huyo_de_la_mina, "empezar de nuevo la borra")


## Las preguntas a la Bruja: un guion con dos títulos y cuatro respuestas.
func test_la_bruja_contesta_preguntas() -> void:
	for texto: String in [BRUJA.TALK_FRAG, BRUJA.TALK_WAIT]:
		var res: DialogueResource = DialogueManager.create_resource_from_text(texto)
		assert_not_null(res)
		var cues: Dictionary = res.get("cues")
		assert_true(cues.has("start") and cues.has("preguntas"),
			"arranca y salta a las preguntas")
		var respuestas := 0
		for l in res.get("lines").values():
			if String(l.get("type", "")) == "response":
				respuestas += 1
		assert_eq(respuestas, 4, "tres preguntas y la salida")
		assert_true(Array(res.get("character_names")).has("Emilia"), "Emilia describe al fantasma")
		assert_true(texto.contains("La Lola"), "el fantasma")
		assert_true(texto.contains("Chupacabras"), "el perro negro")
		assert_true(texto.contains("ojos blancos"), "los mineros")
		assert_true(texto.contains("- No, gracias."), "y una salida")
	assert_false(BRUJA.TALK_BOTH.contains("preguntas"), "con las dos piezas ya no se pregunta por la mina")


## Los volcanes hablan al llegar, una vez cada uno.
func test_los_volcanes_tienen_su_charla_de_llegada() -> void:
	var isluga := (load("res://scenes/puzzles/PuzzleIsluga.gd") as GDScript)
	var cumbre := (load("res://scenes/puzzles/CumbreCima.gd") as GDScript)
	assert_true(String(isluga.TALK_LLEGADA).contains("Parece una roca parada"))
	assert_true(String(cumbre.TALK_LLEGADA).contains("símbolo de guanaco"))
	assert_true(isluga.source_code.contains("llegada_isluga"), "el Isluga la dispara al montarse")
	assert_true(cumbre.source_code.contains("llegada_ojos_del_salado"), "y el Ojos del Salado también")


## El señuelo: Emilia se aleja del Yastay cuando lo tiene encima, se acerca
## cuando lo pierde, y no se sale del ruedo.
class Bicho extends Node3D:
	pass


func test_el_senuelo_se_aleja_y_no_se_sale_del_ruedo() -> void:
	var p: CharacterBody3D = load("res://scenes/actors/Player.tscn").instantiate()
	p.is_archer = false
	add_child_autofree(p)
	var yastay := Bicho.new()
	add_child_autofree(yastay)
	yastay.global_position = Vector3(0, 0, 0)
	p.global_position = Vector3(2.0, 0, 0)
	p.call("hacer_de_senuelo", yastay, Vector3.ZERO, 10.0)
	assert_true(bool(p.call("es_senuelo")), "está de señuelo")
	var rumbo: Vector3 = p.call("_senuelo_behavior")
	assert_gt(rumbo.dot(Vector3.RIGHT), 0.3, "con el bicho encima se aleja")
	p.global_position = Vector3(20.0, 0, 0)
	rumbo = p.call("_senuelo_behavior")
	assert_lt(rumbo.dot(Vector3.RIGHT), 0.0, "lejos del bicho y fuera del ruedo, vuelve")
	p.call("set_ai_mode", true)
	assert_false(bool(p.call("es_senuelo")), "cambiar de personaje lo corta")


## Con Emilia de señuelo el Yastay va por ella y no por quien se maneja.
class Senuelo extends Node3D:
	var activo := true

	func es_senuelo() -> bool:
		return activo


func test_el_yastay_persigue_al_senuelo() -> void:
	var y := Node3D.new()
	y.set_script(YASTAY)
	y.geometria_fijada = true
	var s := Senuelo.new()
	add_child_autofree(s)
	y.set("_senuelo", s)
	assert_eq(y.call("_presa"), s, "mientras hace de señuelo, es la presa")
	s.activo = false
	assert_ne(y.call("_presa"), s, "cuando deja de serlo, ya no")
	y.free()


## Al empezar a atacar, el Yastay se frena y la pareja habla.
func test_antes_de_atacar_hablan_y_el_yastay_espera() -> void:
	var src: String = (YASTAY as GDScript).source_code
	assert_true(src.contains("CHARLA.decir_y_luego(TALK_SENUELO, _empezar_el_senuelo)"),
		"la charla va antes de la persecución")
	assert_true(src.contains("if not is_instance_valid(_yastay) or _charlando:"),
		"y mientras dura, el Yastay no se mueve")
	assert_true(String(YASTAY.TALK_SEGUNDO).contains("Me está costando esquivarlo"))
	assert_true(src.contains("_sanados.size() == 2"), "al segundo guanaco, la otra charla")


## Pasar el control a alguien concreto.
class Cuerpo extends CharacterBody3D:
	var active := false

	func set_active(a: bool) -> void:
		active = a


func test_activar_a_alguien_del_party() -> void:
	var g: Node = JUEGO.new()
	var a := Cuerpo.new()
	var b := Cuerpo.new()
	add_child_autofree(a)
	add_child_autofree(b)
	g.set("party", [a, b])
	g.set("active_index", 0)
	g.call("_apply_active")
	g.call("activar_a", b)
	assert_eq(g.get("active_index"), 1)
	assert_true(b.active and not a.active)
	g.free()


## Al entrar a un interior la cámara se planta en el sitio nuevo.
func test_la_camara_se_planta_al_entrar_a_un_interior() -> void:
	var g: Node = JUEGO.new()
	var a := Cuerpo.new()
	add_child_autofree(a)
	g.set("party", [a])
	var region := Node3D.new()
	add_child_autofree(region)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	region.add_child(spawn)
	spawn.global_position = Vector3(300.0, 20.0, -50.0)
	g.set("_cam_focus", Vector3.ZERO)
	g.call("_move_to_spawn", region)
	var foco: Vector3 = g.get("_cam_focus")
	assert_lt(foco.distance_to(spawn.global_position), 5.0, "el foco ya está allá, sin viajar")
	g.free()


## «Ve al terminal de buses» se cumple al pisar el terminal, no al tocar el bus.
func test_el_terminal_es_una_zona_alrededor_del_bus() -> void:
	var w := (load("res://scenes/core/WorldRoot.gd") as GDScript)
	assert_gte(float(w.RADIO_DEL_TERMINAL), 15.0, "abarca las cuerdas y las bancas")
	assert_true(w.source_code.contains("_construir_zona_del_terminal(hijo.name"), "una por bus")
	assert_true(w.source_code.contains('Misiones.hecho("terminal")'), "y cumple la misión al entrar")
