extends Area3D

## Parada de bus: el viaje entre los dos mundos del juego.
##
## NO es un ZoneExit. Aquél cambia de zona dentro del mismo mundo, o entra a un
## interior escondiendo el mundo detrás. Esto descarga el mundo ENTERO y monta
## el otro, que es una escena distinta con su propio terreno.
##
## No hay nada que colocar a mano: las crea WorldRoot al arrancar, una por cada
## bus que encuentre en la escena. Así funciona igual en World.tscn y en
## WorldAtacama.tscn sin tocar ninguna de las dos.

## Nombre del bus del que cuelga.
##
## Sirve para llegar al bus HOMÓLOGO del otro mundo: si te subís al bus3,
## aparecés junto al bus3 de allá. Como los dos mundos salieron de la misma
## copia, los nombres coinciden; si allá no existe, Game usa cualquier otro.
var bus := ""

## Lo lee el Player para el cartel de "[E] ...". El nombre de la región destino
## lo pone Game, que es quien sabe cuál es el otro mundo.
var prompt := "[E] Viajar"

var _usado := false


func _ready() -> void:
	# Capa 0: no hay que detectarla a ella, sólo que ella detecte al jugador,
	# que vive en la capa 2.
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)


func _al_entrar(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("player") and cuerpo.has_method("set_interactable"):
		cuerpo.set_interactable(self)
		# Llegar a la parada YA cumple la misión de buscar el terminal; viajar
		# es la siguiente.
		Misiones.hecho("terminal")


func _al_salir(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("player") and cuerpo.has_method("clear_interactable"):
		cuerpo.clear_interactable(self)


## Lo llama el Player al pulsar E teniendo esta parada delante.
func interact(_quien: Node) -> void:
	# Sin rearme, a diferencia del ZoneExit: al viajar, el mundo entero —esta
	# parada incluida— se libera. No queda nadie a quien rearmar.
	if _usado:
		return
	var juego := get_tree().get_first_node_in_group("game")
	if juego == null or not juego.has_method("viajar_en_bus"):
		return
	_usado = true
	juego.viajar_en_bus(bus)
