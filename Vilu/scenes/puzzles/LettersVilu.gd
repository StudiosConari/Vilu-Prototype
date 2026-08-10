extends Node3D

## Beat 5 — AscensoOjos (rediseño): rompecabezas de letras.
## Las letras V-I-L-U azules (3D) están desordenadas sobre el tablero. Hay que
## hacerlas CALZAR con sus fantasmas ROJOS (posición + rotación correctas).
##  · Te acercás a una letra para SELECCIONARLA (se ilumina).
##  · Cubo rojo DERECHO: cada golpe la gira 90° en sentido horario.
##  · Cubo rojo IZQUIERDO: la mueve un paso en la grilla; la dirección depende
##    de QUÉ CARA golpeás (golpeá el lado que mira hacia donde querés llevarla).
## Cuando las 4 letras calzan con su fantasma, se abre el paso a la siguiente zona.

signal solved

@export var advance_to_beat := 5
@export var grid_step := 3.0
@export var select_radius := 2.8
@export var pos_tol := 0.9
@export var yaw_tol := 12.0
@export var min_x := -9.0
@export var max_x := 9.0
@export var min_z := -3.0
@export var max_z := 3.0

var _letters: Array = []          # VilLetter azules
var _targets := {}                # glyph -> {pos:Vector3, yaw:float}
var _selected: Node3D = null
var _solved := false


func _ready() -> void:
	var lc := get_node_or_null("Letters")
	if lc:
		for l in lc.get_children():
			_letters.append(l)
	var gc := get_node_or_null("Ghosts")
	if gc:
		for g in gc.get_children():
			if "glyph" in g:
				_targets[g.glyph] = {"pos": g.position, "yaw": g.yaw_deg()}
	var right := get_node_or_null("RightCube")
	if right and right.has_signal("struck"):
		right.struck.connect(_on_rotate)
	var left := get_node_or_null("LeftCube")
	if left and left.has_signal("struck"):
		left.struck.connect(_on_move.bind(left))
	_hint("Letras VILU: acercate a una letra para elegirla. Cubo DERECHO = girar horario. Cubo IZQUIERDO = mover (golpeá la cara que mira hacia donde querés llevarla). Calzalas con los fantasmas rojos.")


func _process(_delta: float) -> void:
	_update_selection()


# --- Selección por cercanía al personaje activo (se mantiene la última). ---
func _update_selection() -> void:
	var p := _active_player()
	if p == null:
		return
	var best: Node3D = null
	var best_d := select_radius * select_radius
	for l in _letters:
		if not is_instance_valid(l):
			continue
		var d: float = p.global_position.distance_squared_to(l.global_position)
		if d < best_d:
			best_d = d
			best = l
	if best != null and best != _selected:
		_select(best)


func _select(l: Node3D) -> void:
	if _selected and is_instance_valid(_selected) and _selected.has_method("set_selected"):
		_selected.set_selected(false)
	_selected = l
	if _selected.has_method("set_selected"):
		_selected.set_selected(true)


func _active_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if "active" in p and p.active:
			return p
	var arr := get_tree().get_nodes_in_group("player")
	return arr[0] if not arr.is_empty() else null


# --- Cubos ---
func _on_rotate(_from: Vector3) -> void:
	if _solved or _selected == null:
		return
	if _selected.has_method("rotate_cw"):
		_selected.rotate_cw()
	get_tree().create_timer(0.16).timeout.connect(_check)


func _on_move(from_pos: Vector3, cube: Node3D) -> void:
	if _solved or _selected == null or not is_instance_valid(cube):
		return
	var dir := _face_move(from_pos, cube.global_position)
	var np: Vector3 = _selected.position + dir * grid_step
	np.x = clampf(np.x, min_x, max_x)
	np.z = clampf(np.z, min_z, max_z)
	if _selected.has_method("move_to"):
		_selected.move_to(np)
	else:
		_selected.position = np
	get_tree().create_timer(0.13).timeout.connect(_check)


## Dirección de grilla a partir de la cara golpeada: la letra va hacia el lado
## desde el que golpeás (golpeás la cara este -> se mueve al este/derecha).
func _face_move(from_pos: Vector3, center: Vector3) -> Vector3:
	var d := from_pos - center
	d.y = 0.0
	if absf(d.x) >= absf(d.z):
		return Vector3(signf(d.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(d.z))


# --- Resolución ---
func _check() -> void:
	if _solved:
		return
	for l in _letters:
		if not is_instance_valid(l) or not (l.glyph in _targets):
			return
		var t: Dictionary = _targets[l.glyph]
		var tp: Vector3 = t["pos"]
		if Vector2(l.position.x - tp.x, l.position.z - tp.z).length() > pos_tol:
			return
		var dy: float = absf(fposmod(l.yaw_deg() - float(t["yaw"]) + 180.0, 360.0) - 180.0)
		if dy > yaw_tol:
			return
	_solve()


func _solve() -> void:
	_solved = true
	_hint("¡VILU completado! El paso a la siguiente zona se abre.")
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	solved.emit()


func is_solved() -> bool:
	return _solved


# --- Helpers para tests ---
func letter(glyph: String) -> Node3D:
	for l in _letters:
		if l.glyph == glyph:
			return l
	return null


func place_at_target(glyph: String) -> void:
	var l := letter(glyph)
	if l and glyph in _targets:
		l.position = _targets[glyph]["pos"]
		l.rotation.y = deg_to_rad(_targets[glyph]["yaw"])


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)
