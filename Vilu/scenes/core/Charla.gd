extends RefCounted

const IDIOMA := preload("res://scenes/core/Idioma.gd")

## Las charlas de la pareja: lo que Emilia y Benjamín se dicen al llegar a un
## sitio o después de un susto.
##
## Son diálogos del Dialogue Manager como los de cualquier personaje, pero sin
## nadie a quien hablarle: los dispara la escena. Y salen UNA sola vez por
## partida, aunque se vuelva al sitio: GameManager se acuerda de cuáles ya se
## dijeron y las olvida al empezar de nuevo.
##
## Se usa sin instanciar:
##   const CHARLA := preload("res://scenes/core/Charla.gd")
##   CHARLA.una_vez(get_tree(), "llegada_isluga", TEXTO, 1.0)

const BALLOON := "res://scenes/ui/GloboDeDialogo.tscn"


## Abre el globo con este guion, ya mismo.
##
## Sin nadie a quien hablarle —sin un jugador en el árbol— no se abre nada:
## pasa en los tests, que montan una escena suelta y a los dos segundos
## saltaba un globo de verdad en mitad de otra prueba.
static func decir(texto: String) -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol != null and arbol.get_nodes_in_group("player").is_empty():
		return
	var res := DialogueManager.create_resource_from_text(IDIOMA.guion(texto))
	DialogueManager.show_dialogue_balloon_scene(BALLOON, res, "start")


## La dice si no se dijo todavía en esta partida, `espera` segundos después.
## Devuelve si la va a decir.
static func una_vez(arbol: SceneTree, id: String, texto: String, espera := 0.0) -> bool:
	if not GameManager.charla_pendiente(id):
		return false
	if espera <= 0.0 or arbol == null:
		decir(texto)
	else:
		arbol.create_timer(espera).timeout.connect(decir.bind(texto))
	return true


## La dice y, al cerrarse el globo, llama a `despues`.
static func decir_y_luego(texto: String, despues: Callable) -> void:
	DialogueManager.dialogue_ended.connect(despues.unbind(1), CONNECT_ONE_SHOT)
	decir(texto)
