extends Node

## Pone un marcador sobre lo que hay que hacer, y una flecha en el borde de la
## pantalla cuando eso queda fuera de cuadro.
##
## El problema que resuelve: el recuadro de misiones dice QUÉ hacer —«activa
## ambos obeliscos»— pero no DÓNDE, y el mapa es grande. Quien no se sabe el
## juego de memoria da vueltas.
##
## Cómo sabe dónde está cada objetivo, en este orden:
##
##   1. **Por grupo.** Cualquier nodo del grupo `objetivo_<id>` es objetivo de
##      la misión `<id>`. Es la vía general y la que usan los objetos que crean
##      los scripts —Carmen, los obeliscos, los guanacos heridos—: una línea
##      donde se crean y ya quedan marcados. Puede haber varios a la vez, y los
##      que van desapareciendo —un guanaco curado— se llevan su marcador.
##   2. **Por destino.** Las misiones de «ve a tal sitio» no tienen un objeto:
##      tienen una zona. Para esas se busca la puerta que lleva allí, que ya
##      declara a dónde va en `target_region`. Sin tocar nada del mundo.
##
## Se vuelve a mirar cada poco, no una sola vez al cambiar de misión: los
## objetivos aparecen y desaparecen mientras la misión sigue viva.

const MARCADOR := preload("res://scenes/actors/MarcadorDeObjetivo.gd")

## Misiones que se cumplen llegando a un sitio: se marca la puerta que lleva allí.
const DESTINOS := {
	"mina": "Mina",
	"volver_mina": "Mina",
	"alicanto": "Alicanto",
	"yastay": "Yastay",
	"isluga_cima": "Isluga",
	"ojos_cima": "OjosDelSalado",
	"portal": "Isluga",
}

## Cada cuánto se rebusca. Medio segundo no se nota y cuesta nada.
const REPASO := 0.5

var _game: Node = null
var _mision := ""
var _marcas := {}          ## nodo objetivo -> su marcador
var _reloj := 0.0
var _brujula: Control = null


func _ready() -> void:
	_game = get_parent()
	Misiones.cambio.connect(_al_cambiar_mision)
	var m: Dictionary = Misiones.actual()
	_mision = String(m.get("id", "")) if not m.is_empty() else ""


func _al_cambiar_mision(m: Dictionary) -> void:
	_mision = String(m.get("id", "")) if not m.is_empty() else ""
	_limpiar()


func _process(delta: float) -> void:
	_reloj -= delta
	if _reloj <= 0.0:
		_reloj = REPASO
		_repasar()
	_pintar_brujula()


## Cuelga marcadores de lo que falte y quita los de lo que ya no está.
func _repasar() -> void:
	var quiero := _objetivos()
	for n: Node3D in _marcas.keys():
		if not is_instance_valid(n) or not quiero.has(n):
			var vieja: Node = _marcas[n]
			if is_instance_valid(vieja):
				vieja.queue_free()
			_marcas.erase(n)
	for n in quiero:
		if _marcas.has(n):
			continue
		var marca: Node3D = MARCADOR.new(MARCADOR.alto_de(n))
		n.add_child(marca)
		_marcas[n] = marca


## Dónde hay que ir ahora mismo. Vacío si la misión no sabe señalar su sitio.
func _objetivos() -> Array[Node3D]:
	var r: Array[Node3D] = []
	if _mision == "":
		return r
	for n in get_tree().get_nodes_in_group("objetivo_" + _mision):
		if n is Node3D and (n as Node3D).is_inside_tree():
			r.append(n as Node3D)
	if not r.is_empty():
		return r
	# Sin objetos marcados: será una misión de ir a un sitio.
	var zona := String(DESTINOS.get(_mision, ""))
	if zona != "" and _game != null and _game.has_method("puerta_hacia"):
		var puerta: Node3D = _game.call("puerta_hacia", zona)
		if puerta != null:
			r.append(puerta)
	return r


func _limpiar() -> void:
	for n: Node3D in _marcas.keys():
		var m: Node = _marcas[n]
		if is_instance_valid(m):
			m.queue_free()
	_marcas.clear()


# ─────────────────────────── la flecha del borde ───────────────────────────
#
# El marcador del mundo sólo sirve si el objetivo está delante. Cuando queda a
# la espalda o fuera de cuadro —que es la mitad del tiempo— hace falta algo que
# diga «por ahí»: una flecha pegada al borde de la pantalla, apuntando, con los
# metros que faltan.

const BRUJULA_MARGEN := 64.0
const ORO := Color(0.96, 0.84, 0.46)


func _brujula_lista() -> Control:
	if _brujula != null and is_instance_valid(_brujula):
		return _brujula
	var hud: Node = _game.get("hud") if _game != null and "hud" in _game else null
	if hud == null:
		return null
	_brujula = Control.new()
	_brujula.name = "BrujulaDeObjetivo"
	_brujula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brujula.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brujula.draw.connect(_dibujar_brujula)
	hud.add_child(_brujula)
	return _brujula


## Dónde cae el objetivo en pantalla, y a qué distancia está.
##
## Devuelve `[hay_objetivo, en_pantalla, punto, metros]`. El caso incómodo es el
## de detrás de la cámara: ahí `unproject_position` devuelve un punto espejado,
## que apuntaría justo al revés. Por eso se comprueba y se invierte a mano.
func _mira() -> Array:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _marcas.is_empty():
		return [false, false, Vector2.ZERO, 0.0]
	var jugador := _jugador()
	var mejor: Node3D = null
	var mejor_d := INF
	for n: Node3D in _marcas.keys():
		if not is_instance_valid(n):
			continue
		var d: float = n.global_position.distance_to(
			jugador.global_position if jugador != null else cam.global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = n
	if mejor == null:
		return [false, false, Vector2.ZERO, 0.0]

	var sitio := mejor.global_position + Vector3.UP * MARCADOR.alto_de(mejor)
	var pantalla := get_viewport().get_visible_rect()
	var detras := cam.is_position_behind(sitio)
	var p := cam.unproject_position(sitio)
	if detras:
		p = pantalla.size * 0.5 + (pantalla.size * 0.5 - p)
	var dentro: bool = not detras and pantalla.grow(-8.0).has_point(p)
	return [true, dentro, p, mejor_d]


func _jugador() -> Node3D:
	if _game != null and "active_index" in _game and "party" in _game:
		var party: Array = _game.get("party")
		var i: int = _game.get("active_index")
		if i >= 0 and i < party.size() and is_instance_valid(party[i]):
			return party[i]
	return get_tree().get_first_node_in_group("player") as Node3D


func _pintar_brujula() -> void:
	var b := _brujula_lista()
	if b != null:
		b.queue_redraw()


func _dibujar_brujula() -> void:
	var m := _mira()
	if not bool(m[0]) or bool(m[1]):
		return                      # sin objetivo, o ya se ve: manda el marcador
	var b := _brujula
	var centro: Vector2 = b.size * 0.5
	var hacia: Vector2 = (m[2] as Vector2) - centro
	if hacia.length() < 1.0:
		return
	hacia = hacia.normalized()
	# Se apoya en el borde de una elipse metida hacia dentro, así la flecha
	# nunca queda medio cortada por el canto de la pantalla.
	var radio := Vector2(centro.x - BRUJULA_MARGEN, centro.y - BRUJULA_MARGEN)
	var sitio := centro + Vector2(hacia.x * radio.x, hacia.y * radio.y)

	var ang := hacia.angle()
	var punta := sitio + Vector2.RIGHT.rotated(ang) * 22.0
	var ala1 := sitio + Vector2.RIGHT.rotated(ang + 2.5) * 16.0
	var ala2 := sitio + Vector2.RIGHT.rotated(ang - 2.5) * 16.0
	b.draw_colored_polygon(PackedVector2Array([punta, ala1, sitio, ala2]), ORO)

	var texto := "%d m" % int(m[3])
	var fuente := ThemeDB.fallback_font
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	b.draw_string(fuente, sitio - Vector2(ancho * 0.5, -32.0), texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ORO)
