extends Node3D

## La fauna que puebla el mapa FUERA de las zonas.
##
## Pumas y guanacos que van a lo suyo por el descampado: caminan un trecho, se
## paran, hacen algo —el puma se sienta, olfatea, aúlla— y siguen. No atacan ni
## reaccionan al jugador; son paisaje que se mueve.
##
## Se quedan LEJOS DE LAS ZONAS a propósito. Cada zona tiene su radio declarado
## en WorldRoot, y el mundo entre ellas estaba vacío: son esos huecos los que
## esto llena. Un puma paseándose por el poblado o metido en la quebrada del
## Yastay estorbaría a escenas que ya están contadas.
##
## No son cuerpos físicos: se mueven cambiando su posición y se apoyan en el
## suelo con un rayo, igual que el guanaco compañero. Para animales que sólo
## deambulan, un CharacterBody3D por cabeza es caro y no aporta.

## Qué especies salen, cuántas, y con qué se mueven.
##
## `gestos` son los clips de parada: al detenerse elige uno al azar. Si el
## modelo no tiene alguno, simplemente no sale.
const ESPECIES := [
	{
		"nombre": "puma",
		"escena": "res://models/personaje/puma.glb",
		"cuantos": 3,
		"quieto": "Idle",
		"andar": "Walk",
		"gestos": ["Sit", "Howl", "Bark", "Sneak", "Idle"],
		"paso": 1.9,
		# Los pumas son solitarios: cada uno con su territorio, y grande.
		"radio_de_paseo": 34.0,
		"juntos": 1,
	},
	{
		"nombre": "guanaco",
		"escena": "res://models/personaje/guanaco.glb",
		"cuantos": 4,
		"quieto": "Idle",
		"andar": "Walk",
		"gestos": ["Idle"],
		"paso": 1.2,
		"radio_de_paseo": 18.0,
		# Los guanacos andan en tropilla: cada punto de aparición trae tres.
		"juntos": 3,
	},
]

## Cuánto se agrandan respecto de su tamaño real.
##
## Al doble: un puma de 75 cm y un guanaco de 1,60 son fieles a la medida pero
## en el descampado no se leen — quedan como manchitas contra un mapa de
## cuatrocientos metros. Esto es tamaño de juego, no de documental.
##
## Sólo afecta a la fauna suelta: los guanacos de la quebrada del Yastay y el
## compañero de Benjamín tienen su propio tamaño y no se tocan desde acá.
@export var tamano := 2.0

## Margen que se le suma al radio de cada zona. Ninguno aparece ni pasea dentro.
@export var margen_de_zona := 14.0
## Dentro de qué rectángulo se reparten si NO pusiste marcadores, en metros
## desde el centro del mapa.
##
## Ajustado a la franja habitada: con el rectángulo entero se iban a doscientos
## metros, donde no pasa nadie nunca. Esto los deja en las explanadas que rodean
## el camino entre zonas.
@export var mitad_del_mapa := Vector2(110.0, 170.0)

## Nodos que marcan DÓNDE queres la fauna. Cualquier Node3D del mundo cuyo
## nombre empiece así es un punto de aparición, y alrededor de él se reparten.
##
## Es la vía para colocarlos a mano: dejás un Marker3D en la explanada que te
## guste y ahí salen, en vez de confiar en el reparto al azar.
const MARCADOR := "FaunaSpawn"
## Radio alrededor de cada marcador dentro del cual pueden aparecer.
@export var radio_del_marcador := 22.0
## Cuánto se para entre trecho y trecho, en segundos.
@export var espera_minima := 2.5
@export var espera_maxima := 7.0
## Por encima de esta altura ya no es pampa, es cerro.
##
## El primer intento los repartía por las paredes rocosas que rodean el mapa: el
## rayo encontraba suelo a veinte, cuarenta y cincuenta metros de altura y los
## dejaba ahí, invisibles y fuera de alcance. Lo jugable está a ras.
@export var altura_maxima := 10.0

## Cuán llano tiene que ser el suelo para que valga, como coseno de la
## pendiente. 0.85 son unos 32°: un puma trepa laderas, pero si se admite
## cualquier inclinación terminan todos colgados de un acantilado.
@export var llaneza_minima := 0.85

## Desde qué altura se busca el suelo al colocarlos.
const DESDE_ARRIBA := 200.0
## Cuántos sitios se prueban antes de rendirse con un animal.
const INTENTOS := 40

## Las zonas prohibidas, como [centro, radio]. Las pone WorldRoot al crearnos.
var zonas: Array = []

var _bichos: Array = []


func _ready() -> void:
	if zonas.is_empty():
		push_warning("FaunaSalvaje: sin zonas declaradas; podrían aparecer dentro de una")
	var puestos := 0
	for esp in ESPECIES:
		puestos += _poblar(esp)
	if puestos > 0:
		print("[fauna] %d animales sueltos por el mapa" % puestos)


func _poblar(esp: Dictionary) -> int:
	var escena: PackedScene = load(String(esp["escena"])) as PackedScene
	if escena == null:
		push_warning("FaunaSalvaje: no encuentro %s" % esp["escena"])
		return 0
	var puestos := 0
	for i in int(esp["cuantos"]):
		var casa := _sitio_libre()
		if casa == Vector3.INF:
			continue
		# Los que andan en grupo salen juntos, repartidos alrededor del punto.
		for j in maxi(int(esp.get("juntos", 1)), 1):
			var donde := casa
			if j > 0:
				# Los compañeros de tropilla TAMBIÉN se comprueban contra las
				# zonas. Antes sólo se validaba el punto central, y como salen
				# hasta cinco metros alrededor, alguno acababa metido dentro del
				# margen de una zona.
				var a := randf() * TAU
				var cerca := casa + Vector3(cos(a), 0.0, sin(a)) * (2.0 + randf() * 3.0)
				if not _lejos_de_las_zonas(cerca):
					continue
				donde = _al_suelo(cerca)
				if donde == Vector3.INF:
					continue
			var n: Node3D = escena.instantiate()
			add_child(n)
			# La escala se multiplica sobre la que trae el modelo, no se fija: el
			# .glb ya viene con la suya y pisarla los dejaría a todos del mismo
			# tamaño, puma y guanaco por igual.
			n.scale = n.scale * maxf(tamano, 0.01)
			n.global_position = donde
			n.rotation.y = randf() * TAU
			_bichos.append({
				"nodo": n,
				"casa": casa,
				"meta": donde,
				"espera": randf() * float(espera_maxima),
				"esp": esp,
			})
			puestos += 1
	return puestos


func _process(delta: float) -> void:
	for b in _bichos:
		var n: Node3D = b["nodo"]
		if not is_instance_valid(n):
			continue
		if b["espera"] > 0.0:
			b["espera"] = float(b["espera"]) - delta
			if b["espera"] <= 0.0:
				b["meta"] = _otro_sitio(b)
				_clip(n, String(b["esp"]["andar"]), true)
			continue
		_andar(b, delta)


func _andar(b: Dictionary, delta: float) -> void:
	var n: Node3D = b["nodo"]
	var d: Vector3 = b["meta"] - n.global_position
	d.y = 0.0
	if d.length() < 0.35:
		# Llegó: se para, hace algo y se queda un rato.
		b["espera"] = randf_range(espera_minima, espera_maxima)
		var gestos: Array = b["esp"]["gestos"]
		_clip(n, String(gestos[randi() % gestos.size()]), true)
		return
	var paso: float = float(b["esp"]["paso"]) * delta
	var siguiente := n.global_position + d.normalized() * paso
	# Al andar se usa el apoyo NO exigente: el sitio ya se validó al elegirlo, y
	# volver a pedir pampa llana en cada paso los dejaría flotando en cuanto
	# pisaran un desnivel.
	var suelo := _apoyar(siguiente)
	n.global_position = suelo if suelo != Vector3.INF else siguiente
	# El frente de estos modelos es +Z: medido del hueso de la cadera al de la
	# cabeza, da (0.00, 1.00) en los tres.
	n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), minf(delta * 4.0, 1.0))


## Otro punto al que ir, dentro de su territorio y fuera de las zonas.
func _otro_sitio(b: Dictionary) -> Vector3:
	var casa: Vector3 = b["casa"]
	var radio: float = float(b["esp"]["radio_de_paseo"])
	for i in INTENTOS:
		var a := randf() * TAU
		var r := sqrt(randf()) * radio      # repartido por área, no apelotonado en el centro
		var p := casa + Vector3(cos(a), 0.0, sin(a)) * r
		if not _lejos_de_las_zonas(p):
			continue
		var suelo := _al_suelo(p)
		if suelo != Vector3.INF:
			return suelo
	return b["nodo"].global_position


## Un sitio de partida: sobre pampa llana y fuera de toda zona.
##
## Si hay marcadores puestos a mano, sale alrededor de uno de ellos. Si no, se
## reparte por la franja habitada del mapa.
func _sitio_libre() -> Vector3:
	var marcas := _marcadores()
	for i in INTENTOS:
		var p: Vector3
		if marcas.is_empty():
			p = Vector3(randf_range(-mitad_del_mapa.x, mitad_del_mapa.x), 0.0,
				randf_range(-mitad_del_mapa.y, mitad_del_mapa.y))
		else:
			var centro: Vector3 = marcas[randi() % marcas.size()].global_position
			var a := randf() * TAU
			var r := sqrt(randf()) * radio_del_marcador
			p = centro + Vector3(cos(a), 0.0, sin(a)) * r
		if not _lejos_de_las_zonas(p):
			continue
		var suelo := _al_suelo(p)
		if suelo != Vector3.INF:
			return suelo
	return Vector3.INF


## Los marcadores puestos a mano, si los hay. Se buscan en TODO el mundo, no
## entre nuestros hijos: van colocados en la escena, donde quieras.
func _marcadores() -> Array:
	var raiz := get_parent()
	if raiz == null:
		return []
	var r: Array = []
	_recoger_marcadores(raiz, r)
	return r


func _recoger_marcadores(n: Node, r: Array) -> void:
	for h in n.get_children():
		if h is Node3D and String(h.name).begins_with(MARCADOR):
			r.append(h)
		_recoger_marcadores(h, r)


func _lejos_de_las_zonas(p: Vector3) -> bool:
	for z in zonas:
		var centro: Vector3 = z[0]
		var radio: float = float(z[1]) + margen_de_zona
		if Vector2(p.x - centro.x, p.z - centro.z).length() < radio:
			return false
	return true


## Baja el punto hasta el terreno. INF si ahí no hay suelo donde puedan estar.
func _al_suelo(p: Vector3) -> Vector3:
	return _buscar_suelo(p, true)


## Igual, pero sin exigir que sea pampa llana: sirve para seguir el terreno
## mientras caminan, donde ya se sabe que el sitio elegido era bueno.
func _apoyar(p: Vector3) -> Vector3:
	return _buscar_suelo(p, false)


func _buscar_suelo(p: Vector3, exigente: bool) -> Vector3:
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return Vector3.INF
	var desde := Vector3(p.x, DESDE_ARRIBA, p.z)
	var q := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * (DESDE_ARRIBA * 2.0))
	q.collision_mask = 1
	var r := esp.intersect_ray(q)
	if r.is_empty():
		return Vector3.INF
	if exigente:
		var punto: Vector3 = r["position"]
		if punto.y > altura_maxima:
			return Vector3.INF          # es cerro, no pampa
		var normal: Vector3 = r.get("normal", Vector3.UP)
		if normal.y < llaneza_minima:
			return Vector3.INF          # ladera: ahí no pastan ni pasean
	return r["position"]


func _clip(n: Node3D, nombre: String, en_bucle: bool) -> void:
	var ap := _animador(n)
	if ap == null or not ap.has_animation(nombre):
		return
	var a := ap.get_animation(nombre)
	a.loop_mode = Animation.LOOP_LINEAR if en_bucle else Animation.LOOP_NONE
	if ap.assigned_animation != nombre or not ap.is_playing():
		ap.play(nombre)


func _animador(n: Node) -> AnimationPlayer:
	for h in n.get_children():
		if h is AnimationPlayer:
			return h
		var x := _animador(h)
		if x != null:
			return x
	return null
