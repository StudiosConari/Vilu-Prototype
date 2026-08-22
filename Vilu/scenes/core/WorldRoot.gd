@tool
extends Node3D

## Mundo abierto de VILU. Instancia TODAS las zonas al aire libre a la vez,
## cada una desplazada a su lugar en el mapa, y las mantiene vivas.
##
## Los INTERIORES (Mina, Final) NO viven acá: se siguen cargando aparte con
## TravelManager al entrar por su boca, como hace cualquier RPG de mundo
## abierto. Ver Game.gd.
##
## ACTIVACIÓN POR CERCANÍA
##   El problema central al pasar de zonas a mundo abierto es que los guiones
##   arrancaban en _ready(): "la escena cargó" equivalía a "el jugador llegó".
##   Con todo el mundo cargado de entrada eso ya no vale — el Yastay pelearía
##   solo mientras vos estás en La Tirana.
##   Por eso cada zona con guion expone activate()/deactivate(), y este nodo
##   las llama cuando el jugador entra o sale de su radio.
##
## El eje Z es el norte-sur del mapa (−Z = norte, como Chile en el papel).

signal zone_entered(id: String)
signal zone_exited(id: String)

const EXIT_SCENE := preload("res://scenes/actors/ZoneExit.tscn")

## Layout del mapa, con el POBLADO (bar + bruja) como centro y punto de partida:
##
##                        Isluga (norte lejano)
##                            |
##                        Alicanto (norte)
##                            |
##     Cumbre ── Yastay ── POBLADO ── boca de la Mina (este)
##    (norte del                |
##      Yastay)             La Tirana (sur)
##
## `radio` es la distancia desde el centro a la que se considera que el jugador
## "está" en la zona, y con la que se activa su guion.
const ZONAS := [
	{
		"id": "Poblado",
		"escena": "res://scenes/regions/Poblado.tscn",
		"pos": Vector3(0, 0, 0),
		"radio": 36.0,
	},
	{
		"id": "Region1_Tarapaca",
		"escena": "res://scenes/regions/Region1_Tarapaca.tscn",
		"pos": Vector3(0, 0, 105),
		"radio": 34.0,
	},
	{
		"id": "Region2_Alicanto",
		"escena": "res://scenes/regions/Region2_Alicanto.tscn",
		"pos": Vector3(0, 0, -125),
		"radio": 44.0,
	},
	{
		"id": "Isluga",
		"escena": "res://scenes/puzzles/Isluga.tscn",
		"pos": Vector3(0, 0, -235),
		"radio": 32.0,
	},
	{
		"id": "Region2_Yastay",
		"escena": "res://scenes/regions/Region2_Yastay.tscn",
		"pos": Vector3(-145, 0, 0),
		"radio": 34.0,
	},
	{
		"id": "Cumbre",
		"escena": "res://scenes/puzzles/Cumbre.tscn",
		"pos": Vector3(-145, 0, -125),
		"radio": 42.0,
	},
]
# La arena de oleadas (Region2_Volcan) se eliminó: era contenido suelto del
# prototipo anterior, fuera de la ruta narrativa.

## Boca de la Mina: al ESTE del poblado. Es un interior, así que no es una zona
## del mundo — sólo una entrada física con su ZoneExit.
const BOCA_MINA := Vector3(88, 0, 0)

## Caminos que unen las zonas: [desde, hasta, ancho, hueco].
##
## `hueco` son los metros de grieta abierta en el medio del tramo. Es el
## reemplazo de los viejos `require_abilities` de los ZoneExit: en vez de un
## cartel que dice "te faltan las ALAS", hay un vacío que sólo cruza Emilia
## planeando. El gate pasa a ser el terreno.
const CAMINOS := [
	["Poblado", "Region1_Tarapaca", 9.0, 0.0],     # sur
	["Poblado", "Region2_Alicanto", 9.0, 0.0],     # norte
	["Region2_Alicanto", "Isluga", 9.0, 0.0],      # norte lejano
	["Poblado", "Region2_Yastay", 9.0, 0.0],       # oeste
	["Region2_Yastay", "Cumbre", 9.0, 9.0],        # grieta: pide ALAS
]

var _zonas := {}          # id -> Node3D (raíz de la zona, ya desplazada)
var _zona_actual := ""
var _activas := {}        # id -> true si su guion está corriendo


func _ready() -> void:
	# EN EL EDITOR: las zonas se instancian recién al correr el juego, así que
	# World.tscn se vería vacío y esculpir el terreno sería a ciegas. Acá se
	# dibujan sólo siluetas con el nombre de cada zona, para saber dónde va
	# cada cosa mientras se trabaja con Terrain3D.
	# NO se instancian las zonas de verdad: sus _ready() correrían dentro del
	# editor (diálogos, timers, spawns) y eso sería un desastre.
	if Engine.is_editor_hint():
		_previsualizar_zonas()
		return

	add_to_group("world")
	if terreno_csg_de_respaldo:
		_construir_terreno()
	_instanciar_zonas()
	_construir_caminos()
	_construir_boca_mina()


## Previsualización de referencia para trabajar el terreno en el editor.
##
## Instancia las escenas REALES de cada zona. Es seguro porque en Godot los
## scripts sin @tool no corren en el editor: aparece la geometría guardada en
## el .tscn (las plataformas de la Cumbre, las del Isluga) pero ningún _ready()
## se ejecuta, así que no se disparan diálogos, timers ni spawns.
##
## Contrapartida: las zonas que construyen su geometría POR SCRIPT (Poblado,
## Alicanto, Yastay, La Tirana) van a verse vacías, porque su _build_*() sólo
## corre en runtime. Para esas queda la silueta celeste como referencia.
##
## Todo se crea sin `owner`, así que no se guarda dentro de World.tscn.
## Tipo explícito a propósito: con `:= true` más un setter, Godot serializaba
## la propiedad como `null` en el .tscn, y al ser falso no se dibujaba nada.
## Piso plano de CSG que sostiene al jugador mientras Terrain3D no tenga
## terreno esculpido. Apagalo cuando corras tools/generar_terreno.gd: si no,
## en las hondonadas el terreno baja por debajo de esta caja y aparece un
## suelo plano falso asomando.
@export var terreno_csg_de_respaldo: bool = true

## Tipo explícito a propósito: con `:= true` más un setter, Godot serializaba
## la propiedad como `null` en el .tscn, y al ser falso no se dibujaba nada.
@export var mostrar_zonas_en_editor: bool = true:
	set(v):
		mostrar_zonas_en_editor = v
		if Engine.is_editor_hint() and is_inside_tree():
			_previsualizar_zonas()


func _previsualizar_zonas() -> void:
	for hijo in get_children():
		if hijo.name.begins_with("_preview"):
			remove_child(hijo)
			hijo.queue_free()

	var raiz := Node3D.new()
	raiz.name = "_preview"
	add_child(raiz)

	for z in ZONAS:
		var r: float = float(z["radio"])
		var centro: Vector3 = z["pos"]

		# Geometría real de la zona (sin lógica: los scripts están dormidos)
		if mostrar_zonas_en_editor:
			var esc: PackedScene = load(z["escena"])
			if esc != null:
				var inst: Node3D = esc.instantiate()
				inst.name = "_pv_" + str(z["id"])
				raiz.add_child(inst)
				inst.position = centro

		# Silueta del área de activación
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.85, 1.0, 0.18)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var mi := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(r * 2.0, 0.3, r * 2.0)
		mi.mesh = caja
		mi.position = centro + Vector3(0, 0.15, 0)
		mi.set_surface_override_material(0, mat)
		raiz.add_child(mi)

		var lbl := Label3D.new()
		lbl.text = "%s\n%.0f m" % [z["id"], r]
		lbl.font_size = 48
		lbl.pixel_size = 0.05
		lbl.position = centro + Vector3(0, 20, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(0.4, 0.95, 1.0)
		lbl.outline_size = 12
		lbl.outline_modulate = Color(0, 0, 0, 1)
		raiz.add_child(lbl)

	# Boca de la Mina
	var m_lbl := Label3D.new()
	m_lbl.text = "boca de la Mina"
	m_lbl.font_size = 40
	m_lbl.pixel_size = 0.05
	m_lbl.position = BOCA_MINA + Vector3(0, 10, 0)
	m_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	m_lbl.modulate = Color(1.0, 0.75, 0.35)
	m_lbl.outline_size = 12
	m_lbl.outline_modulate = Color(0, 0, 0, 1)
	raiz.add_child(m_lbl)


## Suelo continuo bajo TODO el mapa. Sin esto las zonas quedan como losas
## flotando en el vacío unidas por cintas, que es exactamente como se veía
## antes: se puede caminar por los caminos pero salirse es caer al abismo.
## El terreno está a y=-1.0, justo debajo del piso de las zonas (y=-0.5), así
## que no las tapa: se ven encima, apoyadas.
func _construir_terreno() -> void:
	var suelo := StandardMaterial3D.new()
	suelo.albedo_color = Color(0.40, 0.35, 0.27)

	var t := CSGBox3D.new()
	t.name = "Terreno"
	t.size = Vector3(560.0, 1.0, 640.0)
	# Centro del mapa: promedio aproximado de la extensión de las zonas.
	t.position = Vector3(-30.0, -1.0, -70.0)
	t.use_collision = true
	t.material_override = suelo
	add_child(t)


## Entrada a la Mina, al este del poblado. La Mina es un INTERIOR: no vive en
## el mundo, se carga aparte al cruzar este umbral.
func _construir_boca_mina() -> void:
	var roca := StandardMaterial3D.new()
	roca.albedo_color = Color(0.26, 0.23, 0.20)
	var negro := StandardMaterial3D.new()
	negro.albedo_color = Color(0.04, 0.04, 0.05)

	# Cerro con el socavón
	var cerro := CSGBox3D.new()
	cerro.size = Vector3(20.0, 9.0, 14.0)
	cerro.position = BOCA_MINA + Vector3(6.0, 3.5, 0.0)
	cerro.use_collision = true
	cerro.material_override = roca
	add_child(cerro)

	# Boca oscura (sólo visual, marca dónde entrar)
	var boca := CSGBox3D.new()
	boca.size = Vector3(1.0, 4.0, 5.0)
	boca.position = BOCA_MINA + Vector3(-3.6, 2.0, 0.0)
	boca.material_override = negro
	add_child(boca)

	# Vigas del entable
	for vz: float in [-2.6, 2.6]:
		var viga := CSGBox3D.new()
		viga.size = Vector3(0.6, 4.4, 0.6)
		viga.position = BOCA_MINA + Vector3(-3.8, 2.2, vz)
		viga.material_override = roca
		add_child(viga)
	var dintel := CSGBox3D.new()
	dintel.size = Vector3(0.6, 0.6, 6.0)
	dintel.position = BOCA_MINA + Vector3(-3.8, 4.5, 0.0)
	dintel.material_override = roca
	add_child(dintel)

	var lbl := Label3D.new()
	lbl.text = "Mina"
	lbl.font_size = 24
	lbl.position = BOCA_MINA + Vector3(-3.8, 5.6, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	add_child(lbl)

	var salida := EXIT_SCENE.instantiate()
	add_child(salida)
	salida.position = BOCA_MINA + Vector3(-4.5, 2.0, 0.0)
	salida.target_region = "Mina"
	salida.require_beat = -1
	salida.prompt = "[E] Entrar a la Mina"


## Punto donde reaparece el jugador al salir de la Mina (frente a la boca).
func mine_mouth() -> Vector3:
	return global_position + BOCA_MINA + Vector3(-8.0, 0.5, 0.0)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_revisar_zona_del_jugador()


# ─── Construcción ────────────────────────────────────────────────────────────

func _instanciar_zonas() -> void:
	for z in ZONAS:
		var esc: PackedScene = load(z["escena"])
		if esc == null:
			push_warning("WorldRoot: no se pudo cargar %s" % z["escena"])
			continue
		var inst: Node3D = esc.instantiate()
		inst.name = z["id"]
		add_child(inst)
		inst.position = z["pos"]
		_zonas[z["id"]] = inst
		_activas[z["id"]] = false


## Pistas de tierra entre zonas. Van de BORDE a borde (no de centro a centro,
## que las haría atravesar el piso de cada zona), con un solape de 4 m para que
## no quede una junta abierta por la que se caiga el jugador.
func _construir_caminos() -> void:
	var tierra := StandardMaterial3D.new()
	tierra.albedo_color = Color(0.52, 0.44, 0.33)
	const SOLAPE := 4.0

	for c in CAMINOS:
		var a: Vector3 = _pos_de(c[0])
		var b: Vector3 = _pos_de(c[1])
		if a == Vector3.INF or b == Vector3.INF:
			continue
		var delta := b - a
		delta.y = 0.0
		var dist := delta.length()
		if dist < 1.0:
			continue
		var dir := delta.normalized()

		# Recortar el tramo que queda dentro de cada zona
		var ra: float = _radio_de(c[0]) - SOLAPE
		var rb: float = _radio_de(c[1]) - SOLAPE
		var largo := dist - ra - rb
		if largo <= 1.0:
			continue
		var desde := a + dir * ra
		var ancho := float(c[2])
		var hueco := float(c[3]) if c.size() > 3 else 0.0
		var yaw := atan2(dir.x, dir.z)

		if hueco <= 0.0 or hueco >= largo - 4.0:
			_losa(desde + dir * (largo * 0.5), ancho, largo, yaw, tierra)
			continue

		# Tramo con grieta: dos mitades y el vacío en el medio.
		var tramo := (largo - hueco) * 0.5
		_losa(desde + dir * (tramo * 0.5), ancho, tramo, yaw, tierra)
		_losa(desde + dir * (largo - tramo * 0.5), ancho, tramo, yaw, tierra)
		_cartel_grieta(desde + dir * (tramo - 2.0))


func _losa(centro: Vector3, ancho: float, largo: float, yaw: float, mat: Material) -> void:
	var b := CSGBox3D.new()
	b.size = Vector3(ancho, 0.4, largo)
	b.position = Vector3(centro.x, -0.45, centro.z)
	b.rotation.y = yaw
	b.use_collision = true
	b.material_override = mat
	add_child(b)


func _cartel_grieta(pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text = "El camino se corta.\nEmilia puede planear: saltá y mantené [Espacio]"
	lbl.font_size = 18
	lbl.position = pos + Vector3(0.0, 2.2, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.82, 0.45)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	add_child(lbl)


func _radio_de(id: String) -> float:
	for z in ZONAS:
		if z["id"] == id:
			return float(z["radio"])
	return 0.0


func _pos_de(id: String) -> Vector3:
	for z in ZONAS:
		if z["id"] == id:
			return z["pos"]
	return Vector3.INF


# ─── Activación por cercanía ────────────────────────────────────────────────

func _jugador_activo() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if "active" in p and p.active:
			return p
	var arr := get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null


func _revisar_zona_del_jugador() -> void:
	var p: Node3D = _jugador_activo()
	if p == null:
		return
	var pos: Vector3 = p.global_position

	for z in ZONAS:
		var id: String = z["id"]
		var centro: Vector3 = z["pos"]
		var d := Vector2(pos.x - centro.x, pos.z - centro.z).length()
		var dentro := d <= float(z["radio"])

		if dentro and not _activas[id]:
			_activar(id)
		elif not dentro and _activas[id]:
			_desactivar(id)


func _activar(id: String) -> void:
	_activas[id] = true
	_zona_actual = id
	var n: Node = _zonas.get(id)
	if n and n.has_method("activate"):
		n.activate()
	zone_entered.emit(id)


func _desactivar(id: String) -> void:
	_activas[id] = false
	if _zona_actual == id:
		_zona_actual = ""
	var n: Node = _zonas.get(id)
	if n and n.has_method("deactivate"):
		n.deactivate()
	zone_exited.emit(id)


# ─── API pública ────────────────────────────────────────────────────────────

## Zona en la que está parado el jugador ("" si está en el camino entre dos).
func current_zone() -> String:
	return _zona_actual


func zone_node(id: String) -> Node3D:
	return _zonas.get(id)


## Posición MUNDIAL del spawn de una zona. Busca el marcador pedido y cae a
## PlayerSpawn. Devuelve Vector3.INF si la zona no existe.
func spawn_point(id: String, marcador := "PlayerSpawn") -> Vector3:
	var n: Node3D = _zonas.get(id)
	if n == null:
		return Vector3.INF
	var m := n.get_node_or_null(marcador) as Node3D
	if m == null:
		m = n.get_node_or_null("PlayerSpawn") as Node3D
	if m == null:
		return n.global_position
	return m.global_position


func has_zone(id: String) -> bool:
	return _zonas.has(id)
