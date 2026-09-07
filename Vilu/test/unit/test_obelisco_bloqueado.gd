extends GutTest

## Que el primer obelisco de la mina exija romper la barricada de tablones.
##
## El fallo: la zona de interacción del obelisco mide 2,5 m de radio y no sabe
## nada de lo que haya en medio. Bastaba con arrimarse por el otro lado de los
## tablones y pulsar [E]: la barricada quedaba de adorno y el tramo se saltaba
## entero.

const OBELISCO := preload("res://scenes/actors/Obelisco.gd")
const DESTRUCTIBLE := preload("res://scenes/actors/Destructible.gd")


## Un tablón que se puede declarar roto o entero.
class TablonFalso extends Node3D:
	var roto := false

	func esta_roto() -> bool:
		return roto


func _obelisco(tablones: Array) -> Node3D:
	var o := Node3D.new()
	o.set_script(OBELISCO)
	add_child_autofree(o)
	var rutas: Array[NodePath] = []
	for t: Node3D in tablones:
		o.add_child(t)
		rutas.append(NodePath(t.name))
	o.set("requiere", rutas)
	return o


func _tablon(nombre: String, roto := false) -> TablonFalso:
	var t := TablonFalso.new()
	t.name = nombre
	t.roto = roto
	return t


func test_con_los_tablones_en_pie_no_se_enciende() -> void:
	var o := _obelisco([_tablon("Tablon1"), _tablon("Tablon2")])
	assert_true(bool(o.call("esta_bloqueado")), "la barricada lo tapa")
	o.call("_on_interacted", null)
	assert_false(bool(o.get("_activado")), "pulsar [E] no lo enciende")


func test_con_uno_solo_roto_sigue_bloqueado() -> void:
	# Son dos tablones, uno encima del otro: romper el de abajo no abre el paso.
	var o := _obelisco([_tablon("Tablon1", true), _tablon("Tablon2")])
	assert_true(bool(o.call("esta_bloqueado")), "queda el de arriba")


func test_rotos_los_dos_se_enciende() -> void:
	var o := _obelisco([_tablon("Tablon1", true), _tablon("Tablon2", true)])
	assert_false(bool(o.call("esta_bloqueado")), "el paso quedó abierto")
	o.call("_on_interacted", null)
	assert_true(bool(o.get("_activado")), "y ahora sí se enciende")


func test_lo_que_ya_no_esta_no_bloquea() -> void:
	# Un destructible que se rompió y se liberó deja su ruta apuntando a nada.
	# Eso cuenta como hecho, no como obstáculo eterno.
	var o := _obelisco([_tablon("Tablon1")])
	o.set("requiere", [NodePath("NoExiste")] as Array[NodePath])
	assert_false(bool(o.call("esta_bloqueado")), "lo que ya no está no tapa nada")


func test_un_obelisco_sin_requisitos_se_enciende_igual() -> void:
	# El segundo de la mina no tiene barricada: esto no puede haberle cambiado
	# nada.
	var o := _obelisco([])
	assert_false(bool(o.call("esta_bloqueado")), "sin requisitos no hay bloqueo")
	o.call("_on_interacted", null)
	assert_true(bool(o.get("_activado")), "se enciende como siempre")


func test_activar_a_mano_ignora_la_barricada() -> void:
	# La mina llama `activar()` para dejarlos encendidos al volver para el duelo.
	# Encontrarte las barreras otra vez de pie sería deshacerte el trabajo, así
	# que ese camino NO comprueba el requisito.
	var o := _obelisco([_tablon("Tablon1"), _tablon("Tablon2")])
	o.call("activar", false)
	assert_true(bool(o.get("_activado")), "la restauración del duelo pasa igual")


func test_la_mina_tiene_el_primer_obelisco_atado_a_sus_tablones() -> void:
	# El guardián de la escena: la lógica puede estar perfecta y no servir de
	# nada si nadie rellenó `requiere` en Mina.tscn.
	var esc := load("res://scenes/regions/Mina.tscn") as PackedScene
	var st := esc.get_state()
	var atado: Array = []
	for i in st.get_node_count():
		if String(st.get_node_name(i)) != "obelisko1":
			continue
		for j in st.get_node_property_count(i):
			if String(st.get_node_property_name(i, j)) == "requiere":
				atado = st.get_node_property_value(i, j)
	assert_eq(atado.size(), 2, "los dos tablones que lo tapan están declarados")
