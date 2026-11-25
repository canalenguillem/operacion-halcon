extends Control

var main
var obj: Label
var info: Label
var hint: Label
var flash_l: Label
var big_l: Label
var sub_l: Label
var warn: Label
var map: MiniMap
var flash_t := 0.0


class MiniMap extends Control:
	var main

	func _draw() -> void:
		var s := size
		var c := s / 2.0
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
		var me: Vector3 = main.target_pos()
		var reach := 160.0
		if main.vehicle:
			reach = 3500.0 if main.vehicle.is_jet else 400.0
		var k := c.x / reach
		var f := func(p: Vector3) -> Vector2: return c + Vector2(p.x - me.x, p.z - me.z) * k

		var bmin: Vector2 = main.BASE_MIN
		var bmax: Vector2 = main.BASE_MAX
		var a: Vector2 = f.call(Vector3(bmin.x, 0, bmin.y))
		var b: Vector2 = f.call(Vector3(bmax.x, 0, bmax.y))
		draw_rect(Rect2(a, b - a), Color(1, 0.3, 0.3, 0.22))
		draw_rect(Rect2(a, b - a), Color(1, 0.3, 0.3, 0.8), false, 1.5)
		draw_line(f.call(Vector3(0, 0, 340)), f.call(Vector3(0, 0, -700)), Color(0.6, 0.6, 0.6, 0.8), maxf(2.0, 14.0 * k))

		for v in get_tree().get_nodes_in_group("vehicles"):
			if not v.dead and v != main.vehicle:
				draw_circle(f.call(v.global_position), 3.5, Color(0.3, 0.8, 1.0))
		for so in get_tree().get_nodes_in_group("soldiers"):
			if not so.dead:
				draw_circle(f.call(so.global_position), 2.5, Color(1, 0.2, 0.2))
		for sam in main.sams:
			var sp: Vector2 = f.call(sam.pos)
			draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.4, 0.1))
		for m in main.missiles:
			if is_instance_valid(m):
				draw_circle(f.call(m.global_position), 3.0, Color(1, 0.9, 0.2))

		var o: Vector2 = f.call(main.objective_pos())
		o = o.clamp(Vector2(7, 7), s - Vector2(7, 7))
		draw_circle(o, 6.0, Color(0, 0, 0))
		draw_circle(o, 4.5, Color(1, 0.9, 0.2))

		var yaw: float = main.heading()
		var d := Vector2(-sin(yaw), -cos(yaw))
		draw_colored_polygon(PackedVector2Array([c + d * 9.0, c + d.rotated(2.5) * 7.0, c + d.rotated(-2.5) * 7.0]), Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.6), false, 2.0)


func _label(font_size: int, color: Color, h: int, v: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj = _label(24, Color(1, 0.9, 0.35), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	obj.offset_top = 14
	flash_l = _label(22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	flash_l.offset_top = 52
	warn = _label(34, Color(1, 0.2, 0.15), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	warn.offset_top = 110
	info = _label(20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM)
	info.offset_left = 215
	info.offset_bottom = -18
	hint = _label(18, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	hint.offset_bottom = -64
	big_l = _label(64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	sub_l = _label(24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	sub_l.offset_top = 130
	map = MiniMap.new()
	map.main = main
	map.clip_contents = true
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	map.offset_left = 16
	map.offset_right = 196
	map.offset_top = -196
	map.offset_bottom = -16
	add_child(map)


func flash(text: String) -> void:
	flash_l.text = text
	flash_t = 4.0


func big(text: String, sub: String, color: Color) -> void:
	big_l.text = text
	big_l.add_theme_color_override("font_color", color)
	sub_l.text = sub


func _process(dt: float) -> void:
	flash_t -= dt
	flash_l.visible = flash_t > 0.0
	obj.text = main.objective_text()
	var v = main.vehicle
	var hp: int = ceili(main.player.health)
	if v == null:
		info.text = "Salud %d" % hp
	elif v.is_jet:
		info.text = "Caza %d%%    %d km/h    Alt %d m    Potencia %d%%    Bengalas %d" % [ceili(v.hp), int(v.speed * 3.6), int(v.altitude()), int(v.throttle * 100.0), v.flares]
	else:
		info.text = "Salud %d    Coche %d%%    %d km/h" % [hp, ceili(v.hp), int(absf(v.speed) * 3.6)]

	var h := ""
	if not main.game_over:
		if v == null:
			if main.nearby_vehicle() != null:
				h = "[E] Subir"
			elif main.elapsed < 12.0:
				h = "WASD moverse · Ratón cámara · Clic disparar · Shift correr · E subir a vehículos"
		elif v.is_jet:
			if v.grounded:
				h = "Shift: potencia · Ctrl: frenar · A/D: girar · S: despegar a más de 200 km/h"
			else:
				h = "S/W: subir/bajar morro · A/D: alabeo · Shift/Ctrl: potencia · F: bengalas"
		elif main.elapsed < 40.0:
			h = "W/S acelerar/marcha atrás · A/D girar · Espacio freno · E bajar"
	hint.text = h

	var md: float = main.nearest_missile()
	warn.visible = md < 1e8 and fmod(main.elapsed, 0.4) < 0.25
	if md < 1e8:
		warn.text = "¡MISIL!  %d m  —  F: bengalas" % int(md)
	queue_redraw()
	map.queue_redraw()


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.42
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, color)


func _draw() -> void:
	var s := size
	for i in 5:
		var lit: bool = (4 - i) < main.wanted
		var blink: bool = lit and main.wanted >= 4 and fmod(main.elapsed, 0.8) < 0.4
		var colr := Color(0, 0, 0, 0.45)
		if lit:
			colr = Color(1, 1, 1) if blink else Color(1, 0.85, 0.1)
		_star(Vector2(s.x - 36 - i * 34, 38), 15.0, colr)
	if main.vehicle == null and not main.game_over:
		var c := s / 2.0
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * 5.0, c + d * 12.0, Color(1, 1, 1, 0.85), 2.0)
	# health bar above the minimap
	var hpf: float = main.player.health / 100.0
	draw_rect(Rect2(16, s.y - 214, 180, 10), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(16, s.y - 214, 180 * hpf, 10), Color(0.3, 0.9, 0.3) if hpf > 0.35 else Color(0.95, 0.25, 0.2))
