extends Node3D
class_name MarcadorDeObjetivo

## La esfera dorada que flota sobre el objetivo de la misión activa.
##
## Se construye entera por código —malla, material y luz— porque tiene que poder
## colgarse de cualquier cosa: de Carmen, de un obelisco, de un guanaco herido o
## de la puerta de una zona, y ninguno de ellos es una escena que se pueda
## editar en común.
##
## Dos decisiones que parecen detalles y no lo son:
##
##   - **Se dibuja POR ENCIMA de todo** (`no_depth_test`). Un marcador tapado
##     por una pared no sirve para nada: justo cuando no ves el objetivo es
##     cuando necesitás saber dónde está.
##   - **Crece con la distancia.** A tamaño fijo, a cuarenta metros son cuatro
##     píxeles. Escalando con la distancia se ve igual de grande desde donde
##     sea, que es lo que hace que sirva de guía y no de adorno.
##
## No se instancia a mano: la crea y la quita [GuiaDeObjetivos].

const ORO := Color(0.96, 0.84, 0.46)

## Lo que sube y baja, y cuánto tarda en dar un ciclo completo.
const VAIVEN := 0.18
const VAIVEN_SEG := 1.6
## A qué distancia tiene el tamaño natural. Más lejos crece; más cerca no
## encoge, para que al llegar no se convierta en una mota.
const DISTANCIA_BASE := 14.0
const ESCALA_MAX := 3.5

## El radio de la bolita, en metros.
##
## Estaba en 0,28 —56 cm de bola— y a la distancia de juego tapaba media cara
## del objetivo. Un marcador tiene que señalar lo que hay debajo, no esconderlo.
const RADIO := 0.14

## Lo que se separa de la coronilla de aquello que marca.
const HOLGURA := 0.6

var _t := 0.0
var _alto := 0.0
var _camara: Camera3D = null


## `alto` es la altura del objeto marcado: la esfera se pone justo encima.
func _init(alto := 1.8) -> void:
	_alto = alto


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ORO
	mat.emission_enabled = true
	mat.emission = ORO
	mat.emission_energy_multiplier = 2.0
	# Por encima de la geometría, y sin proyectar ni recibir sombra: es un
	# elemento de interfaz que resulta que vive en el mundo 3D.
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 8

	# Una esfera y nada más.
	#
	# Antes esto era una punta de flecha con una columna de luz de catorce metros
	# subiendo desde ella. Se veía de lejos, sí, pero partía la pantalla en dos y
	# tapaba el nivel: la guía pesaba más que el juego. Una bolita quieta sobre
	# el objetivo dice lo mismo sin robar el plano, y para lo que queda fuera de
	# cuadro ya está la flecha del borde.
	var bola := SphereMesh.new()
	bola.radius = RADIO
	bola.height = RADIO * 2.0
	bola.radial_segments = 16
	bola.rings = 8
	var esfera := MeshInstance3D.new()
	esfera.mesh = bola
	esfera.material_override = mat
	esfera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(esfera)

	var luz := OmniLight3D.new()
	luz.light_color = ORO
	luz.light_energy = 0.8
	luz.omni_range = 2.0
	luz.shadow_enabled = false

	add_child(luz)

	position.y = _alto + HOLGURA
	# Empieza en un punto cualquiera del vaivén: dos marcadores a la vista
	# subiendo y bajando al unísono se ven como una máquina, no como una guía.
	_t = randf() * VAIVEN_SEG


func _process(delta: float) -> void:
	_t += delta
	position.y = _alto + HOLGURA + sin(_t / VAIVEN_SEG * TAU) * VAIVEN
	_escalar_con_la_distancia()


## Tamaño aparente constante: lejos crece, cerca se queda como está.
func _escalar_con_la_distancia() -> void:
	if _camara == null or not is_instance_valid(_camara):
		_camara = get_viewport().get_camera_3d()
		if _camara == null:
			return
	var d := global_position.distance_to(_camara.global_position)
	scale = Vector3.ONE * clampf(d / DISTANCIA_BASE, 1.0, ESCALA_MAX)


## La altura de un objeto, para saber a qué altura ponerle la esfera.
##
## Se mira la caja que ocupan sus mallas. Un guanaco tumbado mide medio metro y
## una puerta de zona cuatro: con una altura fija, la misma esfera queda dentro
## de la cabeza de uno y a tres metros por encima de la otra.
##
## Se salta a los marcadores que ya estén colgando, y hace falta: una vez puesto,
## el marcador es HIJO de lo que marca. Sin esta salvedad, volver a medir sumaba
## la altura del propio marcador —el objeto "crecía" al señalarlo— y la flecha
## del borde, que usa esta altura para saber si el objetivo está en cuadro,
## terminaba apuntando al cielo dando por hecho que se había salido de la
## pantalla. Con la columna de catorce metros que llevaba antes el error era de
## catorce metros; ya no está, pero el fallo volvería igual.
static func alto_de(nodo: Node3D) -> float:
	var alto := 0.0
	for v in _mallas(nodo):
		var caja := v.get_aabb()
		var arriba: float = (v.global_transform * Vector3(0.0, caja.end.y, 0.0)).y
		alto = maxf(alto, arriba - nodo.global_position.y)
	return alto if alto > 0.2 else 1.8


static func _mallas(n: Node) -> Array[VisualInstance3D]:
	var r: Array[VisualInstance3D] = []
	if n is MarcadorDeObjetivo:
		return r                      # es un marcador puesto: no es el objeto
	if n is VisualInstance3D and not (n is OmniLight3D):
		r.append(n as VisualInstance3D)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r
