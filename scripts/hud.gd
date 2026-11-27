class_name Hud
extends Control
## Interfaz de la partida: objetivo, estrellas, salud, indicadores, avisos y minimapa.

var main: Main
var obj: Label
var info: Label
var hint: Label
var flash_l: Label
var big_l: Label
var sub_l: Label
var warn: Label
var map: MiniMap
var flash_t: float = 0.0


class MiniMap extends Control:
	var main: Main
	var map: CityMap = CityMap.get_default()

	## Isla, río y calles alrededor de `me` (coordenadas x, z del mundo).
	func _draw_map(me: Vector2, c: Vector2, k: float, reach: float) -> void:
		var to_px: Callable = func(p: Vector2) -> Vector2: return c + (p - me) * k
		var land := PackedVector2Array()
		for p: Vector2 in map.island:
			land.append(to_px.call(p))
		draw_colored_polygon(land, Color(0.26, 0.32, 0.22, 0.9))
		var river := PackedVector2Array()
		for p: Vector2 in map.river_line:
			river.append(to_px.call(p))
		draw_polyline(river, Color(0.12, 0.25, 0.35), maxf(2.0, map.river_width * k))
		var limit: float = reach * 1.5
		for i: int in map.road_count():
			var a: Vector2 = map.road_start(i)
			var b: Vector2 = map.road_end(i)
			if absf(a.x - me.x) > limit and absf(b.x - me.x) > limit or absf(a.y - me.y) > limit and absf(b.y - me.y) > limit:
				continue
			var col := Color(0.85, 0.85, 0.8, 0.85)
			if map.road_type[i] == "autovia":
				col = Color(0.95, 0.65, 0.25, 0.9)
			draw_line(to_px.call(a), to_px.call(b), col, maxf(1.5, map.width(i) * k))

	func _draw() -> void:
		var s: Vector2 = size
		var c: Vector2 = s / 2.0
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.12, 0.25, 0.35, 0.8))  # mar
		var me: Vector3 = main.target_pos()
		var reach: float = 160.0
		if main.vehicle != null:
			reach = 3500.0 if main.vehicle.is_jet else 400.0
		var k: float = c.x / reach
		var f: Callable = func(p: Vector3) -> Vector2: return c + Vector2(p.x - me.x, p.z - me.z) * k

		_draw_map(Vector2(me.x, me.z), c, k, reach)
		var a: Vector2 = f.call(Vector3(World.BASE_MIN.x, 0, World.BASE_MIN.y))
		var b: Vector2 = f.call(Vector3(World.BASE_MAX.x, 0, World.BASE_MAX.y))
		draw_rect(Rect2(a, b - a), Color(1, 0.3, 0.3, 0.22))
		draw_rect(Rect2(a, b - a), Color(1, 0.3, 0.3, 0.8), false, 1.5)

		for v: Vehicle in main.vehicles():
			if not v.dead and v != main.vehicle:
				var vp: Vector2 = f.call(v.global_position)
				draw_circle(vp, 3.5, Color(0.3, 0.8, 1.0))
		for so: Soldier in main.soldiers:
			if not so.dead:
				var sp: Vector2 = f.call(so.global_position)
				draw_circle(sp, 2.5, Color(1, 0.2, 0.2))
		for sam: Vector3 in main.world.sam_positions:
			var bp: Vector2 = f.call(sam)
			draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.4, 0.1))
		for m: Missile in main.air_defense.missiles:
			if is_instance_valid(m):
				var mp: Vector2 = f.call(m.global_position)
				draw_circle(mp, 3.0, Color(1, 0.9, 0.2))

		var o: Vector2 = f.call(main.halcon.objective_pos())
		o = o.clamp(Vector2(7, 7), s - Vector2(7, 7))
		draw_circle(o, 6.0, Color(0, 0, 0))
		draw_circle(o, 4.5, Color(1, 0.9, 0.2))

		var yaw: float = main.heading()
		var d: Vector2 = Vector2(-sin(yaw), -cos(yaw))
		draw_colored_polygon(PackedVector2Array([c + d * 9.0, c + d.rotated(2.5) * 7.0, c + d.rotated(-2.5) * 7.0]), Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.6), false, 2.0)


func _label(font_size: int, color: Color, h: HorizontalAlignment, v: VerticalAlignment) -> Label:
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


## Mensaje breve bajo el objetivo.
func flash(text: String) -> void:
	flash_l.text = text
	flash_t = 4.0


## Mensaje grande de fin de misión.
func big(text: String, sub: String, color: Color) -> void:
	big_l.text = text
	big_l.add_theme_color_override("font_color", color)
	sub_l.text = sub


func _process(dt: float) -> void:
	flash_t -= dt
	flash_l.visible = flash_t > 0.0
	obj.text = main.halcon.objective_text()
	var hp: int = ceili(main.player.health)
	var jet: Jet = main.vehicle as Jet
	if main.vehicle == null:
		info.text = "Salud %d    Bajas %d" % [hp, main.combat.kills]
	elif jet != null:
		info.text = "Caza %d%%    %d km/h    Alt %d m    Potencia %d%%    Bengalas %d" % [ceili(jet.hp), int(jet.speed * 3.6), int(jet.altitude()), int(jet.throttle * 100.0), jet.flares]
	else:
		info.text = "Salud %d    Coche %d%%    %d km/h" % [hp, ceili(main.vehicle.hp), int(absf(main.vehicle.speed) * 3.6)]
	hint.text = _hint(jet)

	var md: float = main.air_defense.nearest_missile()
	warn.visible = md < 1e8 and fmod(main.elapsed, 0.4) < 0.25
	if md < 1e8:
		warn.text = "¡MISIL!  %d m  —  F: bengalas" % int(md)
	queue_redraw()
	map.queue_redraw()


func _hint(jet: Jet) -> String:
	if main.game_over:
		return ""
	if main.vehicle == null:
		if main.driving.nearby() != null:
			return "[E] Subir"
		if main.elapsed < 12.0:
			return "WASD moverse · Ratón cámara · Clic disparar · Shift correr · E subir a vehículos"
		return ""
	if jet != null:
		if jet.grounded:
			return "W: acelerar (despega solo a 250 km/h) · S: frenar · A/D: girar"
		return "S: subir morro · W: bajar morro · A/D: girar · Shift/Ctrl: potencia · F: bengalas"
	if main.elapsed < 40.0:
		return "W/S acelerar/marcha atrás · A/D girar · Espacio freno · E bajar"
	return ""


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var rr: float = r if i % 2 == 0 else r * 0.42
		var a: float = -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, color)


func _draw() -> void:
	var s: Vector2 = size
	if main.combat.hurt_t > 0.0:  # fogonazo rojo al recibir daño
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0, 0, minf(0.35, main.combat.hurt_t)))
	var wanted: int = main.mission.wanted
	for i: int in 5:
		var lit: bool = (4 - i) < wanted
		var blink: bool = lit and wanted >= MissionState.WANTED_ALERT and fmod(main.elapsed, 0.8) < 0.4
		var colr := Color(0, 0, 0, 0.45)
		if lit:
			colr = Color(1, 1, 1) if blink else Color(1, 0.85, 0.1)
		_star(Vector2(s.x - 36 - i * 34, 38), 15.0, colr)
	if main.vehicle == null and not main.game_over:
		var c: Vector2 = s / 2.0
		for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * 5.0, c + d * 12.0, Color(1, 1, 1, 0.85), 2.0)
		if main.combat.hit_t > 0.0:  # marca de impacto: aspa blanca, roja si lo has abatido
			var hc: Color = Color(1, 0.2, 0.15) if main.combat.hit_kill else Color.WHITE
			for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 6.0, c + d * 15.0, hc, 3.0)
	# barra de salud sobre el minimapa
	var hpf: float = main.player.health / main.player.data.max_health
	draw_rect(Rect2(16, s.y - 214, 180, 10), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(16, s.y - 214, 180 * hpf, 10), Color(0.3, 0.9, 0.3) if hpf > 0.35 else Color(0.95, 0.25, 0.2))
