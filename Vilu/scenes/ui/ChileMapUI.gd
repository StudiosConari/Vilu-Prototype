extends Control

## Mapa de volcanes de Chile — overlay de pantalla completa.
## ESC o clic fuera del panel para cerrar. Clic en un volcán activo para viajar.

# [nombre, región, y_normalizado (0=norte/1=sur), region_id_viaje, beat_mínimo]
const VOLCANOES := [
	["Isluga",          "I Tarapacá",  0.10, "Isluga",  -1],
	["Ojos del Salado", "III Atacama", 0.48, "OjosDelSalado", 7],
]

## Índice del volcán donde se encuentra el jugador ahora (0=Isluga, 1=Salado, …).
## El guardián que abre el mapa lo asigna antes de add_child.
var current_volcano_idx := 0

var _panel      := Rect2()
var _dot_pos    : Array[Vector2] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode   = FOCUS_ALL
	grab_focus()
	queue_redraw()
	# El mapa usa [ESC] para cerrarse. Estando en este grupo, el menú de pausa
	# sabe que no debe abrirse encima con esa misma tecla.
	add_to_group("pantalla_modal")


func _draw() -> void:
	var s  := get_size()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.80))

	var pw := 380.0
	var ph := 560.0
	var px := (s.x - pw) * 0.5
	var py := (s.y - ph) * 0.5
	_panel = Rect2(px, py, pw, ph)

	draw_rect(_panel, Color(0.09, 0.07, 0.05, 0.97))
	draw_rect(_panel, Color(0.60, 0.44, 0.16), false, 2.0)

	var font := ThemeDB.fallback_font

	# Título
	draw_string(font, Vector2(px + 20, py + 36),
		"VOLCANES SAGRADOS DE CHILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.92, 0.80, 0.28))
	draw_line(Vector2(px + 16, py + 46), Vector2(px + pw - 16, py + 46),
		Color(0.55, 0.40, 0.14), 1.0)

	# Silueta simplificada de Chile (polígono estrecho vertical)
	var mx := px + 52.0
	var my := py + 62.0
	var mw := 64.0
	var mh := 430.0

	var pts := PackedVector2Array([
		Vector2(mx + 20, my),
		Vector2(mx + mw, my + 16),
		Vector2(mx + mw - 2,  my + mh * 0.30),
		Vector2(mx + mw - 9,  my + mh * 0.58),
		Vector2(mx + mw - 5,  my + mh * 0.80),
		Vector2(mx + mw - 12, my + mh),
		Vector2(mx + 4,       my + mh),
		Vector2(mx + 8,       my + mh * 0.80),
		Vector2(mx + 5,       my + mh * 0.58),
		Vector2(mx + 10,      my + mh * 0.30),
		Vector2(mx + 13,      my),
	])
	draw_colored_polygon(pts, Color(0.20, 0.16, 0.11))
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.42, 0.32, 0.20), 1.5)

	draw_string(font, Vector2(mx - 2, my - 4),        "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.48, 0.42, 0.30))
	draw_string(font, Vector2(mx - 2, my + mh + 12),  "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.48, 0.42, 0.30))

	# Volcanes
	_dot_pos.clear()
	for i in VOLCANOES.size():
		var v       : Array  = VOLCANOES[i]
		var vname   : String = v[0]
		var vreg    : String = v[1]
		var vy_n    : float  = v[2]
		var beat_min: int    = v[4]

		var active  := beat_min < 0 or GameManager.get_beat() >= beat_min
		var is_here := (i == current_volcano_idx)

		var dot := Vector2(mx + mw * 0.5, my + mh * vy_n)
		_dot_pos.append(dot)

		var col: Color
		if is_here:
			col = Color(0.28, 0.92, 0.42)
		elif active:
			col = Color(0.92, 0.82, 0.22)
		else:
			col = Color(0.26, 0.22, 0.16)

		draw_circle(dot, 8.0, col)
		if active:
			draw_arc(dot, 12.0, 0.0, TAU, 24, col.lightened(0.22), 1.5)

		var lx := mx + mw + 24.0
		draw_line(dot + Vector2(9, 0), Vector2(lx - 4, dot.y), col.darkened(0.3), 1.0)

		var tc := Color(0.88, 0.74, 0.42) if active else Color(0.34, 0.28, 0.22)
		draw_string(font, Vector2(lx, dot.y + 2),  vname, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tc)
		draw_string(font, Vector2(lx, dot.y + 17), vreg,  HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tc.darkened(0.3))

		if is_here:
			draw_string(font, Vector2(lx, dot.y + 30), "← Aquí",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.30, 0.88, 0.42))
		elif active:
			draw_string(font, Vector2(lx, dot.y + 30), "[clic para viajar]",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.68, 0.58, 0.24))
		else:
			draw_string(font, Vector2(lx, dot.y + 30), "Bloqueado",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.34, 0.28, 0.22))

	# Pie
	draw_string(font, Vector2(px + pw * 0.5 - 38, py + ph - 16),
		"[ESC] Cerrar", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.44, 0.38, 0.28))


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _panel.has_point(event.position):
			_close()
			return
		for i in _dot_pos.size():
			if event.position.distance_to(_dot_pos[i]) < 16.0:
				var v       : Array  = VOLCANOES[i]
				var beat_min: int    = v[4]
				var target  : String = v[3]
				var active  := beat_min < 0 or GameManager.get_beat() >= beat_min
				if active and i != current_volcano_idx and target != "":
					_travel_to(target)
				return


func _travel_to(region_id: String) -> void:
	var game := get_tree().current_scene
	_close()
	if game and game.has_method("go_to"):
		game.go_to(region_id, true)   # fast-travel: usar TravelSpawn (junto al guardián)


func _close() -> void:
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()
