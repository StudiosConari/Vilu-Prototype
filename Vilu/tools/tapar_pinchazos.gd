extends SceneTree

## Tapa los pinchazos del heightmap: vértices sueltos hundidos muy por debajo
## de TODOS sus vecinos.
##
## CÓMO USARLO  (con el editor de Godot CERRADO, si no se pierde al guardar)
##   Godot.exe --path . --script res://tools/tapar_pinchazos.gd --quit-after 900
##   Poné SIMULAR = true si sólo querés el informe.
##
## QUÉ ES UN PINCHAZO Y QUÉ NO
##   Un acantilado legítimo tiene al menos un vecino igual de bajo: por eso se
##   exige que el vértice esté HONDO metros por debajo del vecino MÁS BAJO. Un
##   borde de meseta nunca cumple eso; un clic suelto del pincel, sí.
##
## Aparecieron al quitar las losas grises de la Cumbre: mientras las cajas los
## tapaban no se veían, pero ahora el terreno es el piso y son agujeros.
##
## El parche sale de la MEDIANA de los vecinos inmediatos (a 1 m, que es el
## paso del heightmap), no de un valor fijo: así calza tanto en la meseta de
## entrada (0 m) como en el piso de lava (-15 m) o en la cima (13 m).
##
## POR QUÉ MEDIANA Y POR QUÉ A 1 m
##   Un primer intento promediaba un anillo de 3 m quedándose con los valores
##   más altos. En un pinchazo pegado al borde del foso ese anillo cae a
##   caballo entre el piso de lava y la meseta, y el promedio lo subía 14 m:
##   en vez de tapar el agujero dejaba una púa saliendo de la lava. Los
##   vecinos a 1 m son los vértices realmente contiguos, y la mediana ignora
##   al vecino contagiado sin dejarse arrastrar por el desnivel de al lado.

## Sólo informa, no escribe.
const SIMULAR := false
## Cuánto más bajo que su vecino más bajo para considerarlo pinchazo, en metros.
const HONDO := 3.0
## Pasadas: tapar un pinchazo puede destapar a su vecino pegado.
const PASADAS := 3


func _init() -> void:
	var w: Node3D = load("res://scenes/core/World.tscn").instantiate()
	root.add_child(w)
	for i in 40:
		await process_frame

	var t = w.get_node_or_null("Terrain3D")
	if t == null:
		push_error("tapar_pinchazos: no encuentro el Terrain3D en World.tscn")
		quit(1)
		return
	var d = t.data

	var total := 0
	for pasada in PASADAS:
		var arreglados := 0
		for z in w.ZONAS:
			arreglados += _revisar(d, z, pasada == 0)
		total += arreglados
		if arreglados == 0:
			break

	print("")
	if total == 0:
		print("tapar_pinchazos: no habia nada que tapar.")
	elif SIMULAR:
		print("tapar_pinchazos: %d vertices a corregir (SIMULAR, no se escribio nada)" % total)
	else:
		d.save_directory(String(t.get("data_directory")))
		print("tapar_pinchazos: %d vertices corregidos y guardados a disco." % total)
	quit()


func _revisar(d, z: Dictionary, informar: bool) -> int:
	var c: Vector3 = z["pos"]
	var lado := int(float(z["radio"]))
	var arreglados := 0
	for ix in range(-lado, lado + 1):
		for iz in range(-lado, lado + 1):
			var p := Vector3(c.x + float(ix), 0.0, c.z + float(iz))
			var h: float = d.get_height(p)
			if is_nan(h):
				continue
			var min_vec := INF
			var roto := false
			for o in [Vector3(2,0,0), Vector3(-2,0,0), Vector3(0,0,2), Vector3(0,0,-2)]:
				var hv: float = d.get_height(p + o)
				if is_nan(hv):
					roto = true
					break
				min_vec = minf(min_vec, hv)
			if roto or h >= min_vec - HONDO:
				continue

			var nivel: float = _nivel_sano(d, p)
			if is_nan(nivel):
				continue
			if informar:
				print("%-22s (%.0f, %.0f)  %.2f -> %.2f" % [String(z["id"]), p.x, p.z, h, nivel])
			if not SIMULAR:
				d.set_height(p, nivel)
			arreglados += 1
	return arreglados


## Altura de referencia: mediana de los 8 vértices contiguos.
func _nivel_sano(d, p: Vector3) -> float:
	var vals: Array[float] = []
	for dx in [-1.0, 0.0, 1.0]:
		for dz in [-1.0, 0.0, 1.0]:
			if dx == 0.0 and dz == 0.0:
				continue
			var hv: float = d.get_height(p + Vector3(dx, 0.0, dz))
			if not is_nan(hv):
				vals.append(hv)
	if vals.is_empty():
		return NAN
	vals.sort()
	var n := vals.size()
	if n % 2 == 1:
		return vals[n / 2]
	return (vals[n / 2 - 1] + vals[n / 2]) * 0.5
