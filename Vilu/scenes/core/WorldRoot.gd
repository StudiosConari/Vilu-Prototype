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
const PISO_BALDOSAS := preload("res://scenes/core/PisoBaldosas.gd")
const TOON_SKIN := preload("res://scenes/core/ToonSkin.gd")
const PARADA_DE_BUS := preload("res://scenes/actors/ParadaDeBus.gd")
const TRAMPA_DEL_ORO := preload("res://scenes/actors/TrampaDelOro.gd")

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
## Todo el layout está corrido +55 en Z respecto del original, para liberar
## espacio al NORTE y poder esculpir ahí el volcán del Isluga.
##
## LA CUMBRE ES LA EXCEPCIÓN: se queda en z=-125 porque su cráter de 20 m ya
## está esculpido en el terreno, en coordenadas fijas del mundo. Moverla lo
## dejaría desalineado y habría que rehacerlo.
	{
		"id": "Poblado",
		"inline": true,
		"escena": "",
		"pos": Vector3(0, 0, 55),
		"radio": 36.0,
	},
	{
		"id": "Tarapaca",
		"inline": true,
		"escena": "",
		"pos": Vector3(0, 0, 160),
		"radio": 34.0,
	},
	{
		"id": "Alicanto",
		"inline": true,
		"escena": "",
		"pos": Vector3(0, 0, -70),
		"radio": 44.0,
	},
	# El Isluga NO está acá a propósito. Dejó de ser una zona del mundo abierto:
	# ahora es un interior con puerta, y se entra por el monumento de la subida.
	# Si volviera al registro, `has_zone("Isluga")` daría true y el selector del
	# título dejaría de cargarlo, porque Game sólo entra al interior cuando la
	# zona NO existe en el mundo.
	{
		"id": "Yastay",
		"inline": true,
		"escena": "",
		"pos": Vector3(-145, 0, 55),
		"radio": 34.0,
	},
	# La CUMBRE tampoco está acá. Se renombró a Ojos del Salado y, como el
	# Isluga, dejó de ser una zona del mundo: ahora es un interior al que se
	# entra por la puerta del monumento de su subida. Ver INTERIORES en Game.gd.
]
# La arena de oleadas (Region2_Volcan) se eliminó: era contenido suelto del
# prototipo anterior, fuera de la ruta narrativa.

## Boca de la Mina: al ESTE del poblado. Es un interior, así que no es una zona
## del mundo — sólo una entrada física con su ZoneExit.
## Sigue al Poblado en el corrimiento de +55 en Z.
const BOCA_MINA := Vector3(88, 0, 55)

## Desde la boca hasta donde se reaparece al salir. Lo bastante lejos como para
## quedar fuera del disparador de entrada: si no, salir de la Mina te dejaría
## dentro del área que te vuelve a ofrecer entrar.
##
## Va hacia el OESTE porque la boca mira al poblado: los arbustos y las raíces
## que la flanquean están puestos simétricos respecto de su eje, todos con x
## menor que ella. Antes esto era (0, -1.3, -8) —ocho metros hacia el norte—,
## que con el modelo de entrada nuevo, que está girado, caía de costado y justo
## por el borde del acantilado: se salía de la mina al mar.
##
## Esto es sólo el respaldo. Si hay un marcador en el grupo "salida_mina" manda
## ése, y así la salida se arrastra a mano sin tocar código ni depender de hacia
## dónde quede mirando el modelo el día de mañana.
const SALIR_DE_LA_MINA := Vector3(-8.0, 0.4, 0.0)

## Caminos que unen las zonas: [desde, hasta, ancho, hueco].
##
## `hueco` son los metros de grieta abierta en el medio del tramo. Es el
## reemplazo de los viejos `require_abilities` de los ZoneExit: en vez de un
## cartel que dice "te faltan las ALAS", hay un vacío que sólo cruza Emilia
## planeando. El gate pasa a ser el terreno.
const CAMINOS := [
	["Poblado", "Tarapaca", 9.0, 0.0],     # sur
	["Poblado", "Alicanto", 9.0, 0.0],     # norte
	# Alicanto -> Isluga: QUITADO. Ese tramo terminaba dentro del cráter, y como
	# ahí el terreno está esculpido hacia abajo, las baldosas quedaban flotando
	# sobre la lava. El acceso al volcán son ahora las plataformas puestas a
	# mano, no un camino empedrado. Para recuperarlo:
	#   ["Alicanto", "Isluga", 9.0, 0.0],
	["Poblado", "Yastay", 9.0, 0.0],       # oeste
	# El tramo Yastay->Cumbre se fue con ella: la Cumbre ya no es zona del mundo.
]

var _zonas := {}          # id -> Node3D (raíz de la zona, ya desplazada)
var _zona_actual := ""
var _activas := {}        # id -> true si su guion está corriendo
## Zonas del catálogo que este mundo NO tiene. Se junta y se informa una vez.
var _ausentes: Array = []


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

	# MODO EDICIÓN DE TERRENO: no se construye nada encima del terreno, para
	# poder esculpirlo sin que props, muros ni empedrados tapen la vista.
	# El juego queda sin contenido mientras esté activo: es un interruptor de
	# trabajo, no un estado final.
	if modo_edicion_terreno:
		print("[mundo] MODO EDICIÓN DE TERRENO: sin zonas, caminos ni props.")
		return

	if terreno_csg_de_respaldo:
		_construir_terreno()
	_instanciar_zonas()
	if construir_caminos:
		_construir_caminos()
	_construir_boca_mina()
	_construir_paradas_de_bus()
	_construir_trampa_del_oro()
	if sombreado_toon:
		# Al final de todo: hay que vestir lo que ya está construido.
		var n: int = TOON_SKIN.new().aplicar(self)
		print("[mundo] materiales toon: %d" % n)


## Piso plano de CSG de emergencia. Queda APAGADO: ahora el suelo lo pone
## Terrain3D, y esta caja se superponía con él produciendo el parpadeo de
## z-fighting. Encendelo sólo si te quedás sin terreno y necesitás algo que
## sostenga al jugador.
@export var terreno_csg_de_respaldo: bool = false

## Empedra los CUATRO caminos entre zonas al arrancar el juego (ver CAMINOS).
##
## Queda APAGADO: las rutas están puestas a mano en World.tscn, como el resto
## del decorado, y éstos se generaban encima. Sólo corrían al jugar, así que en
## el editor no se veían: aparecían recién al probar, y no había forma de
## moverlos ni de borrarlos desde el árbol.
##
## OJO SI LO VOLVÉS A ENCENDER: el tramo Yastay→Cumbre no es un camino más. Se
## genera con una GRIETA de 9 m en el medio, con su cartel, y esa grieta ES la
## puerta que exige las ALAS. Con los caminos apagados esa puerta no existe, y
## el paso a la Cumbre queda librado a lo que haya en el terreno: si querés
## conservar el gate, hay que rehacerlo a mano.
@export var construir_caminos: bool = false

## MODO EDICIÓN DE TERRENO. Con esto encendido no se construye NADA sobre el
## terreno al correr el juego: ni zonas, ni muros, ni caminos, ni props.
##
## Queda APAGADO por defecto para que el juego y los tests sigan funcionando.
## Encendelo desde el inspector del nodo World cuando quieras correr el juego
## y ver sólo el terreno.
##
## Ojo: para esculpir en el EDITOR no hace falta tocarlo — ahí las zonas, los
## muros y los props no se construyen nunca, porque sus scripts no son @tool.
## Lo que sí tapa la vista en el editor es `mostrar_zonas_en_editor`.
@export var modo_edicion_terreno: bool = false


## Convierte los materiales del mundo al sombreado toon escalonado, para que
## casas y props no queden con luz PBR suave al lado del terreno cel-shaded.
@export var sombreado_toon: bool = true

## Dibuja en el editor la ayuda de referencia: la silueta celeste del radio de
## activación de cada zona, su cartel con nombre y metros, el cartel de la boca
## de la mina y la geometría de las zonas que no viven dentro de World.tscn.
##
## Apagalo y NO SE DIBUJA NADA DE ESO — que es lo que querés cuando estás
## esculpiendo el terreno o acomodando props y las siluetas te tapan la vista.
##
## Tipo explícito a propósito: con `:= true` más un setter, Godot serializaba
## la propiedad como `null` en el .tscn, y al ser falso no se dibujaba nada.
@export var mostrar_zonas_en_editor: bool = true:
	set(v):
		mostrar_zonas_en_editor = v
		if Engine.is_editor_hint() and is_inside_tree():
			_previsualizar_zonas()


## Marcalo para volver a leer las escenas de las zonas. Se apaga solo: es un
## botón, no un ajuste.
##
## La previsualización se arma UNA vez, al abrir World.tscn, instanciando una
## copia de cada escena de zona. Si editás y guardás Isluga.tscn con World.tscn
## abierta, acá se sigue viendo la versión vieja: son dos copias distintas y
## Godot no refresca las que crea un script —sólo las que están instanciadas de
## verdad en el .tscn, y éstas no lo están a propósito, para no engordar el
## archivo con geometría que es sólo de referencia—.
##
## Antes había que cerrar World.tscn y volver a abrirla.
@export var refrescar_zonas: bool = false:
	set(v):
		refrescar_zonas = false          # vuelve solo a su sitio
		if v and Engine.is_editor_hint() and is_inside_tree():
			_previsualizar_zonas()


## Previsualización de referencia para trabajar en el editor.
##
## Instancia las escenas REALES de cada zona. Es seguro porque en Godot los
## scripts sin @tool no corren en el editor: aparece la geometría guardada en
## el .tscn (las plataformas de la Cumbre, las del Isluga) pero ningún _ready()
## se ejecuta, así que no se disparan diálogos, timers ni spawns.
##
## Contrapartida: las zonas que construyen su geometría POR SCRIPT (Poblado,
## Alicanto, Yastay, La Tirana) se ven vacías, porque su _build_*() sólo corre
## en runtime. Para esas queda la silueta celeste como referencia.
##
## Todo se crea sin `owner`, así que no se guarda dentro de World.tscn.
func _previsualizar_zonas() -> void:
	for hijo in get_children():
		if hijo.name.begins_with("_preview"):
			remove_child(hijo)
			hijo.queue_free()

	# Apagado: se limpia y no se dibuja nada más.
	#
	# Antes este interruptor no apagaba casi nada. Sólo se consultaba al
	# instanciar las escenas de las zonas y al dibujar el bulto de la boca de la
	# mina, así que las siluetas celestes y sus carteles seguían tapando el mapa
	# aunque estuviera en false — que es justamente lo que uno quiere esconder
	# cuando lo apaga.
	if not mostrar_zonas_en_editor:
		return

	var raiz := Node3D.new()
	raiz.name = "_preview"
	add_child(raiz)

	for z in ZONAS:
		var r: float = float(z["radio"])
		var centro: Vector3 = _pos_de_zona(z)

		# Geometría real de la zona (sin lógica: los scripts están dormidos).
		# Las que viven dentro de World.tscn no se previsualizan: ya están ahí.
		if not z.get("inline", false):
			# Sin caché: si la escena de la zona se acaba de guardar, `load` a
			# secas puede devolver la copia que el editor tenía en memoria y el
			# refresco no serviría de nada. Esto sólo corre en el editor, así que
			# releer el archivo no le cuesta al juego.
			var esc: PackedScene = ResourceLoader.load(
				z["escena"], "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
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

	# Boca de la Mina: el bulto real, igual que las zonas, para poder esculpir
	# el terreno alrededor sabiendo dónde queda el socavón.
	# Igual que arriba: con el modelo puesto no hace falta el bulto de CSG. Y si
	# este mundo no tiene Mina, tampoco hay nada que previsualizar.
	if not _hay_mina():
		return
	if _nodo_boca() == null:
		_geometria_boca_mina(raiz)

	var m_lbl := Label3D.new()
	m_lbl.text = "boca de la Mina"
	m_lbl.font_size = 40
	m_lbl.pixel_size = 0.05
	m_lbl.position = _pos_boca() + Vector3(0, 12, 0)
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
## El nodo que hace de boca, si la escena trae uno.
##
## Se busca por GRUPO y no por nombre ni por ruta: el modelo se puede renombrar
## o mover de sitio en el editor y esto sigue encontrándolo.
func _nodo_boca() -> Node3D:
	var n := get_tree().get_first_node_in_group("boca_mina")
	return n as Node3D if n is Node3D else null


## Dónde está la boca, en coordenadas de este nodo.
##
## Si la escena trae un modelo de entrada, manda ése; si no, la constante de
## siempre. Así el greybox sigue sirviendo en un mundo sin el modelo puesto.
func _pos_boca() -> Vector3:
	var n := _nodo_boca()
	return to_local(n.global_position) if n != null else BOCA_MINA


## Si este mundo tiene la Mina.
##
## Igual que con ZONAS, el catálogo es de TODO el juego pero el mapa está
## partido en dos mundos, y la Mina es de Tarapacá. Sin esta comprobación
## Atacama montaba igual el cerro de greybox de la boca —con su cartel y su
## disparador de "[E] Entrar a la Mina"— plantado en medio del desierto, al
## lado de la quebrada del Yastay y a la vista de todos.
##
## Vale cualquiera de las dos señas: el modelo de la entrada en su grupo, o el
## nodo "Mina" del que cuelga. Con el greybox no había ninguna de las dos, y por
## eso se construía en los dos mundos.
func _hay_mina() -> bool:
	return _nodo_boca() != null or get_node_or_null("Mina") != null


func _construir_boca_mina() -> void:
	if not _hay_mina():
		return
	var modelo := _nodo_boca()
	# El bulto de CSG sólo se arma si NO hay modelo. Estaba para marcar el sitio
	# mientras la boca era un greybox; con la entrada de madera puesta sería un
	# cerro gris de más, y encima en otro lugar.
	if modelo == null:
		_geometria_boca_mina(self)

	var salida := EXIT_SCENE.instantiate()
	add_child(salida)
	salida.target_region = "Mina"
	salida.require_beat = -1
	salida.prompt = "[E] Entrar a la Mina"
	if modelo != null:
		# Centrada en el modelo y generosa: no se sabe hacia dónde mira, y como
		# pide [E] no hay riesgo de entrar sin querer.
		salida.position = _pos_boca() + Vector3(0.0, 2.5, 0.0)
		salida.tamano = Vector3(9.0, 6.0, 9.0)
	else:
		salida.position = BOCA_MINA + Vector3(-4.5, 2.0, 0.0)


## Monta la trampa del oro de la quebrada del Alicanto, si sus dos piezas están
## puestas en la escena.
##
## Se buscan por nombre en TODO el árbol, no por ruta: los dos modelos quedaron
## colgando dentro del área de la persona herida, y una ruta fija se rompería en
## cuanto se los reacomode. Si falta alguno, no se monta nada y se avisa.
func _construir_trampa_del_oro() -> void:
	var puente := _buscar_por_prefijo(self, "puente_derrumbable")
	var camino := _buscar_por_prefijo(self, "camino_derrumbable")
	if puente == null or camino == null:
		return
	var trampa := Node3D.new()
	trampa.name = "TrampaDelOro"
	trampa.set_script(TRAMPA_DEL_ORO)
	trampa.puente = puente
	trampa.camino = camino
	add_child(trampa)
	print("[mundo] trampa del oro: %s arma, %s se derrumba" % [puente.name, camino.name])


func _buscar_por_prefijo(n: Node, prefijo: String) -> Node3D:
	if n is Node3D and n.name.begins_with(prefijo):
		return n
	for c in n.get_children():
		var r := _buscar_por_prefijo(c, prefijo)
		if r != null:
			return r
	return null


## Margen alrededor del bus desde el que ya se puede subir, en metros.
const MARGEN_PARADA := 2.5


## Cuelga una parada de bus de cada autobús de la escena.
##
## Se hace en ejecución y no a mano en el .tscn para que los dos mundos —este y
## el otro— funcionen igual sin tocar ninguna de las dos escenas: alcanza con
## que el nodo del bus se llame "bus...".
##
## El área se ajusta al TAMAÑO REAL del modelo más el margen, en vez de ser una
## esfera fija: el bus mide más de nueve metros de largo, y una esfera centrada
## o no llega a las puntas o te deja subir desde el techo de al lado.
func _construir_paradas_de_bus() -> void:
	var etiqueta := "la otra región"
	var juego := get_tree().get_first_node_in_group("game")
	if juego != null and juego.has_method("nombre_del_otro_mundo"):
		var n: String = juego.nombre_del_otro_mundo()
		if n != "":
			etiqueta = n

	var n_paradas := 0
	for hijo in _buscar_buses():
		var caja := _caja_de(hijo)
		if caja.size == Vector3.ZERO:
			continue

		var area := Area3D.new()
		area.set_script(PARADA_DE_BUS)
		area.name = "Parada_" + hijo.name
		area.bus = hijo.name
		area.prompt = "[E] Viajar a %s" % etiqueta
		add_child(area)
		area.global_position = caja.position + caja.size * 0.5

		var cs := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = caja.size + Vector3.ONE * (MARGEN_PARADA * 2.0)
		cs.shape = forma
		area.add_child(cs)
		n_paradas += 1

	if n_paradas > 0:
		print("[mundo] paradas de bus: %d — viajan a %s" % [n_paradas, etiqueta])


## Todos los autobuses de la escena, estén colgados donde estén.
##
## Se recorre el árbol ENTERO y no sólo los hijos de la raíz. En World.tscn los
## buses cuelgan de arriba, pero en WorldAtacama.tscn se agruparon dentro de un
## nodo "Terminal de Buses": mirando sólo el primer nivel, esa región se quedaba
## sin una sola parada, o sea sin viaje de vuelta.
##
## Al dar con uno no se sigue bajando: las piezas de dentro del modelo no son
## paradas, y basta con que alguna empiece por "bus" para duplicarla.
func _buscar_buses(desde: Node = self) -> Array:
	var encontrados: Array = []
	for hijo in desde.get_children():
		if hijo is Node3D and String(hijo.name).begins_with("bus"):
			encontrados.append(hijo)
			continue
		encontrados.append_array(_buscar_buses(hijo))
	return encontrados


## Caja envolvente de un nodo, en coordenadas de mundo.
func _caja_de(n: Node) -> AABB:
	var caja := AABB()
	var primero := true
	for m in _mallas_de(n):
		var a: AABB = m.global_transform * m.mesh.get_aabb()
		if primero:
			caja = a
			primero = false
		else:
			caja = caja.merge(a)
	return caja


func _mallas_de(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mallas_de(c))
	return out


## Sólo el bulto visible de la boca: cerro, socavón, entable y cartel.
##
## Va aparte del ZoneExit para poder dibujarla también en el editor. Antes la
## boca entera se construía sólo al correr el juego, así que en el editor no
## había nada que ver donde va la Mina: se esculpía el terreno a ciegas ahí.
## El ZoneExit no se previsualiza a propósito — es lógica, no paisaje.
func _geometria_boca_mina(padre: Node3D) -> void:
	# Colores claros a propósito: con el sombreado toon y su rampa de luz, un
	# gris oscuro se convierte en una mancha negra sin forma legible.
	var roca := StandardMaterial3D.new()
	roca.albedo_color = Color(0.62, 0.46, 0.34)
	var negro := StandardMaterial3D.new()
	negro.albedo_color = Color(0.16, 0.12, 0.14)

	# Cerro con el socavón
	var cerro := CSGBox3D.new()
	cerro.size = Vector3(20.0, 9.0, 14.0)
	cerro.position = BOCA_MINA + Vector3(6.0, 3.5, 0.0)
	cerro.use_collision = true
	cerro.material_override = roca
	padre.add_child(cerro)

	# Boca oscura (sólo visual, marca dónde entrar)
	var boca := CSGBox3D.new()
	boca.size = Vector3(1.0, 4.0, 5.0)
	boca.position = BOCA_MINA + Vector3(-3.6, 2.0, 0.0)
	boca.material_override = negro
	padre.add_child(boca)

	# Vigas del entable
	for vz: float in [-2.6, 2.6]:
		var viga := CSGBox3D.new()
		viga.size = Vector3(0.6, 4.4, 0.6)
		viga.position = BOCA_MINA + Vector3(-3.8, 2.2, vz)
		viga.material_override = roca
		padre.add_child(viga)
	var dintel := CSGBox3D.new()
	dintel.size = Vector3(0.6, 0.6, 6.0)
	dintel.position = BOCA_MINA + Vector3(-3.8, 4.5, 0.0)
	dintel.material_override = roca
	padre.add_child(dintel)

	var lbl := Label3D.new()
	lbl.text = "Mina"
	lbl.font_size = 24
	lbl.position = BOCA_MINA + Vector3(-3.8, 5.6, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	padre.add_child(lbl)


## Punto donde reaparece el jugador al salir de la Mina (frente a la boca).
func mine_mouth() -> Vector3:
	# Marcador puesto a mano: manda siempre. Poné un Marker3D donde quieras que
	# la party aparezca al salir y metelo en el grupo "salida_mina".
	var m := get_tree().get_first_node_in_group("salida_mina") as Node3D
	if m != null:
		return m.global_position
	return to_global(_pos_boca() + SALIR_DE_LA_MINA)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_revisar_zona_del_jugador()


# ─── Construcción ────────────────────────────────────────────────────────────

## Dónde está una zona, en coordenadas de este nodo.
##
## Si la zona vive DENTRO de World.tscn manda el nodo real, no el número del
## registro: así se la puede arrastrar en el editor y el radio de activación,
## los caminos y las siluetas la siguen. El número queda de respaldo para las
## que se sigan instanciando, como la Cumbre.
func _pos_de_zona(z: Dictionary) -> Vector3:
	var n := get_node_or_null(NodePath(z["id"])) as Node3D
	if n == null:
		return z["pos"]
	# La zona puede decir dónde está su centro DE VERDAD. El nodo marca dónde se
	# empezó a construir, que no tiene por qué ser el medio: el del Yastay está
	# al pie del puente y su quebrada queda 23 m al este, así que medir desde el
	# nodo hacía que la zona llegara hasta el poblado.
	#
	# Va en coordenadas de mundo, igual que `position` acá: la raíz del mundo
	# está en el origen, así que local y global coinciden para sus hijos.
	var propio: Variant = n.get("centro_de_zona")
	if propio is Vector3 and propio != Vector3.ZERO:
		return propio
	return n.position


## El radio con que se activa una zona.
##
## El del catálogo dice cuánto OCUPA la zona en el mapa —de ahí salen las pistas
## de tierra que la unen con sus vecinas—, pero cuándo empieza su guion es otra
## cosa, y la zona puede fijarlo por su cuenta.
func _radio_de_activacion(z: Dictionary) -> float:
	var n := get_node_or_null(NodePath(z["id"])) as Node3D
	if n != null:
		var propio: Variant = n.get("radio_de_zona")
		if propio is float and propio > 0.0:
			return propio
	return float(z["radio"])


func _instanciar_zonas() -> void:
	_ausentes.clear()
	for z in ZONAS:
		# Zona construida a mano dentro de World.tscn: ya está en el árbol y
		# sólo hay que registrarla. Instanciar además su escena pondría una
		# copia encima, y como el nombre ya está tomado Godot le cambiaría el
		# suyo por algo tipo "@Node3D@179".
		if z.get("inline", false):
			var ya := get_node_or_null(NodePath(z["id"])) as Node3D
			if ya == null:
				# NO es un aviso: ZONAS es el catálogo de TODAS las zonas del
				# juego y hay dos mundos que se reparten unas y otras. Que
				# Tarapacá no esté en Atacama, o Yastay en Tarapacá, es lo
				# normal desde que se partió el mapa. Antes esto gritaba una
				# advertencia por cada zona ausente en cada arranque.
				_ausentes.append(str(z["id"]))
				continue
			_zonas[z["id"]] = ya
			_activas[z["id"]] = false
			continue
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

	print("[mundo] zonas de este mapa: %s" % ", ".join(PackedStringArray(_zonas.keys())))
	if not _ausentes.is_empty():
		print("[mundo] del catálogo, en este mapa no están: %s" % ", ".join(PackedStringArray(_ausentes)))


## Pistas de tierra entre zonas. Van de BORDE a borde (no de centro a centro,
## que las haría atravesar el piso de cada zona), con un solape de 4 m para que
## no quede una junta abierta por la que se caiga el jugador.
func _construir_caminos() -> void:
	const SOLAPE := 4.0
	var piso := Node3D.new()
	piso.name = "Caminos"
	piso.set_script(PISO_BALDOSAS)
	add_child(piso)

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

		if hueco <= 0.0 or hueco >= largo - 4.0:
			piso.camino(desde, desde + dir * largo, ancho)
			continue

		# Tramo con grieta: dos mitades empedradas y el vacío en el medio.
		var tramo := (largo - hueco) * 0.5
		piso.camino(desde, desde + dir * tramo, ancho)
		piso.camino(desde + dir * (largo - tramo), desde + dir * largo, ancho)
		_cartel_grieta(desde + dir * (tramo - 2.0))

	var n: int = piso.construir()
	if n > 0:
		print("[mundo] baldosas de camino: %d" % n)


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
			return _pos_de_zona(z)
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
	var gana := zona_en(p.global_position)

	for z in ZONAS:
		var id: String = z["id"]

		# Zona declarada en ZONAS pero nunca registrada: pasa cuando al nodo de
		# World.tscn le cambian el nombre y deja de coincidir con su "id".
		# _instanciar_zonas ya avisó por consola al arrancar; acá se saltea,
		# porque indexar _activas[id] rompería el _process en CADA cuadro.
		if not _activas.has(id):
			continue

		if id == gana and not _activas[id]:
			_activar(id)
		elif id != gana and _activas[id]:
			_desactivar(id)


## En qué zona está ese punto, o "" si está en el camino entre dos.
##
## Estar en una zona es EXCLUSIVO: cuando dos se pisan gana la más metida, o sea
## aquella de cuyo radio ocupa la fracción menor. Se mide en fracción y no en
## metros para que una zona chica no pierda siempre contra una grande que
## empieza más lejos.
##
## Antes se activaban TODAS las que contuvieran al jugador, y eso vale mientras
## las zonas no se toquen. En Atacama sí se tocan: el Poblado y la quebrada del
## Yastay tienen los centros a 39 m con radios de 36 y 34, así que desde el bar
## ya contabas como "dentro" del Yastay y la escena del encuentro arrancaba
## sola, a media región de distancia. Poblado y Alicanto se pisan igual.
func zona_en(pos: Vector3) -> String:
	var gana := ""
	var mejor := INF
	for z in ZONAS:
		var id: String = z["id"]
		if not _activas.has(id):
			continue
		var r: float = _radio_de_activacion(z)
		if r <= 0.0:
			continue
		var centro: Vector3 = _pos_de_zona(z)
		# En planta: las zonas se reparten el mapa, no la altura.
		var d := Vector2(pos.x - centro.x, pos.z - centro.z).length()
		var metido := d / r
		if metido <= 1.0 and metido < mejor:
			mejor = metido
			gana = id
	return gana


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
	var m := n.find_child(marcador, true, false) as Node3D
	if m == null:
		m = n.find_child("PlayerSpawn", true, false) as Node3D
	if m == null:
		return n.global_position
	return m.global_position


func has_zone(id: String) -> bool:
	return _zonas.has(id)
