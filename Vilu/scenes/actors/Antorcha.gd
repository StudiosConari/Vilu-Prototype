extends Node3D

## Antorcha que ilumina de verdad.
##
## Se cuelga sobre el nodo raíz de la instancia del .glb. El modelo trae la
## llama en la textura pero no emitía nada, así que las antorchas de la mina
## eran adorno y los rincones quedaban planos.
##
## La luz se coloca SOLA en lo alto del modelo, midiendo su caja envolvente, en
## vez de a una altura escrita a mano: las veinte antorchas de la mina están
## puestas a escalas distintas, y una altura fija quedaría metida en el muro en
## unas y flotando en otras.

@export_group("Luz")
@export var color := Color(1.0, 0.62, 0.25)
## Radio que alcanza a iluminar, en metros.
@export_range(0.5, 25.0, 0.1) var alcance := 7.0
@export_range(0.0, 8.0, 0.05) var energia := 3.3

@export_group("Colocación")
## Dónde va la luz dentro de la altura del modelo. 1 = justo en la punta.
@export_range(0.0, 1.5, 0.01) var altura_relativa := 0.92
## Corrección fina, en METROS de mundo (se compensa la escala del nodo).
@export var desplazamiento := Vector3.ZERO

@export_group("Parpadeo")
@export var parpadea := true
## Cuánto sube y baja la energía, en tanto por uno.
@export_range(0.0, 0.6, 0.01) var vaiven := 0.18
@export_range(0.1, 20.0, 0.1) var velocidad := 6.0

@export_group("Coste")
## Las sombras de una luz puntual se dibujan en seis direcciones. Con veinte
## antorchas eso cuesta más que todo el resto de la mina junta, y el bulto de la
## luz se lee igual sin ellas. Encendelas de a una si alguna lo pide.
@export var sombras := false

var _luz: OmniLight3D = null
var _fase := 0.0


func _ready() -> void:
	_luz = OmniLight3D.new()
	_luz.light_color = color
	_luz.omni_range = alcance
	_luz.light_energy = energia
	_luz.shadow_enabled = sombras
	# Atenuación algo más suave que la de fábrica: con 1.0 la luz muere de golpe
	# y la antorcha se lee como una mancha en vez de como un foco en la pared.
	_luz.omni_attenuation = 0.8
	add_child(_luz)
	_luz.position = _punto_de_llama()

	if parpadea:
		# Fase al azar por antorcha: si arrancaran todas juntas, las veinte
		# latirían al unísono y se vería como un fallo de la pantalla, no como
		# fuego.
		_fase = randf() * TAU
	set_process(parpadea)


## Punto donde va la llama, en el espacio local de este nodo.
func _punto_de_llama() -> Vector3:
	var f := global_transform.basis.get_scale()
	var arreglo := Vector3(
		desplazamiento.x / maxf(f.x, 0.001),
		desplazamiento.y / maxf(f.y, 0.001),
		desplazamiento.z / maxf(f.z, 0.001))

	var mi := _malla(self)
	if mi == null:
		return Vector3(0.0, 1.0, 0.0) + arreglo
	var caja := mi.get_aabb()
	var centro := caja.position + caja.size * 0.5
	var p := Vector3(centro.x, caja.position.y + caja.size.y * altura_relativa, centro.z)
	# La malla puede venir con su propia transformación dentro del .glb.
	return mi.transform * p + arreglo


func _malla(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n as MeshInstance3D
	for c in n.get_children():
		var hondo := _malla(c)
		if hondo != null:
			return hondo
	return null


func _process(delta: float) -> void:
	_fase += delta * velocidad
	# Dos senos de periodo inconmensurable: uno solo se oye como un latido
	# regular, y el fuego no late a compás.
	var f := sin(_fase) * 0.6 + sin(_fase * 2.37 + 1.3) * 0.4
	_luz.light_energy = energia * (1.0 + f * vaiven)
