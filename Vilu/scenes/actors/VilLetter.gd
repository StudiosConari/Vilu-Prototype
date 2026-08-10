extends Node3D

## Letra 3D (V, I, L, U) construida con cajas. Yace PLANA sobre el tablero
## (se lee desde la cámara), extruida hacia arriba. Puede ser:
##  · sólida azul (la que el jugador mueve/gira), o
##  · "fantasma" roja translúcida (el objetivo: dónde debería calzar).
## Gira sobre su eje vertical (Y) y se desplaza en la grilla del tablero.

@export var glyph := "I"
@export var is_ghost := false

const BLUE := Color(0.25, 0.45, 0.95)
const BLUE_SEL := Color(0.35, 0.7, 1.0)
const RED := Color(0.9, 0.25, 0.2)

var _mat: StandardMaterial3D
var _selected := false
var _tween: Tween


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	if is_ghost:
		_mat.albedo_color = Color(RED.r, RED.g, RED.b, 0.35)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.emission_enabled = true
		_mat.emission = Color(0.5, 0.1, 0.08)
	else:
		_mat.albedo_color = BLUE
	for spec in _boxes(glyph):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec["size"]
		mi.mesh = bm
		mi.position = spec["pos"]
		if spec.has("rot"):
			mi.rotation.y = spec["rot"]
		mi.material_override = _mat
		add_child(mi)


## Cajas (en espacio local, plano XZ, extruidas en Y) que forman cada letra.
func _boxes(g: String) -> Array:
	match g:
		"I":
			return [{"size": Vector3(0.6, 0.6, 3.2), "pos": Vector3(0, 0.3, 0)}]
		"L":
			return [
				{"size": Vector3(0.6, 0.6, 3.2), "pos": Vector3(-0.8, 0.3, 0)},
				{"size": Vector3(2.2, 0.6, 0.6), "pos": Vector3(0.1, 0.3, 1.3)},
			]
		"U":
			return [
				{"size": Vector3(0.6, 0.6, 2.6), "pos": Vector3(-0.9, 0.3, -0.3)},
				{"size": Vector3(0.6, 0.6, 2.6), "pos": Vector3(0.9, 0.3, -0.3)},
				{"size": Vector3(2.4, 0.6, 0.6), "pos": Vector3(0, 0.3, 1.3)},
			]
		"V":
			# Barras que se juntan ABAJO (+Z, base de la pantalla) y se abren
			# ARRIBA (-Z). Así lee como "V" y no como "Λ".
			return [
				{"size": Vector3(0.6, 0.6, 3.4), "pos": Vector3(-0.55, 0.3, 0), "rot": 0.33},
				{"size": Vector3(0.6, 0.6, 3.4), "pos": Vector3(0.55, 0.3, 0), "rot": -0.33},
			]
	return [{"size": Vector3(0.6, 0.6, 3.2), "pos": Vector3(0, 0.3, 0)}]


func set_selected(on: bool) -> void:
	if is_ghost or on == _selected:
		return
	_selected = on
	if _mat:
		_mat.albedo_color = BLUE_SEL if on else BLUE
		_mat.emission_enabled = on
		if on:
			_mat.emission = Color(0.1, 0.3, 0.6)


## Yaw normalizado a [0, 360).
func yaw_deg() -> float:
	return fposmod(rad_to_deg(rotation.y), 360.0)


## Desplaza (tween corto) a una nueva posición del tablero.
func move_to(pos: Vector3) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "position", pos, 0.12)


## Gira +90° horario (tween corto) sobre el eje vertical.
func rotate_cw() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", rotation.y - deg_to_rad(90.0), 0.15)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
