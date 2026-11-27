class_name Hud
extends Control
## Interfaz de la partida, dibujada por código con `UiStyle`:
## - arriba a la izquierda, la caja de ayuda (consejos y avisos);
## - arriba a la derecha, estrellas de búsqueda, arma, tiempo y bajas;
## - abajo a la izquierda, el radar (`Radar`) con la salud y el vehículo debajo;
## - abajo a la derecha, el nombre de la zona y el velocímetro (o los instrumentos del caza);
## - abajo en el centro, el objetivo como un subtítulo;
## - en el centro, la mira, la marca de impacto y de dónde te disparan;
## - los mensajes grandes de fin de misión en una franja.

const MARGIN: float = 22.0
## Segundos que se ven el nombre de una zona nueva y un aviso.
const ZONE_TIME: float = 4.5
const FLASH_TIME: float = 4.5

var main: Main
var radar: Radar
var _flash: String = ""
var _flash_t: float = 0.0
var _big: String = ""
var _big_sub: String = ""
var _big_color: Color = Color.WHITE
var _big_t: float = 0.0
var _zone: String = ""
var _zone_t: float = 0.0
var _zone_check: float = 0.0
var _vehicle_name: String = ""
var _last_vehicle: Vehicle = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar = Radar.new()
	radar.main = main
	radar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	radar.position = Vector2(MARGIN, 0)
	add_child(radar)


## Aviso breve en la caja de ayuda.
func flash(text: String) -> void:
	_flash = text
	_flash_t = FLASH_TIME


## Mensaje grande de fin de misión.
func big(text: String, sub: String, color: Color) -> void:
	_big = text
	_big_sub = sub
	_big_color = color
	_big_t = 0.0


func _process(dt: float) -> void:
	_flash_t -= dt
	_zone_t -= dt
	_big_t += dt
	radar.position = Vector2(MARGIN, size.y - MARGIN - 34.0 - Radar.SIZE)
	_zone_check -= dt
	if _zone_check <= 0.0:
		_zone_check = 0.5
		var z: String = _zone_name()
		if z != _zone:
			_zone = z
			_zone_t = ZONE_TIME if z != "" else 0.0
	var v: Vehicle = main.vehicle
	if v != _last_vehicle:
		_last_vehicle = v
		if v != null:
			_vehicle_name = "Caza" if v.is_jet else "Coche"
			_zone_t = maxf(_zone_t, 3.0)
		else:
			_vehicle_name = ""
	queue_redraw()


## Nombre del barrio en el que estás ("" en el campo).
func _zone_name() -> String:
	var p: Vector3 = main.target_pos()
	if World.in_base(p):
		return "Base aérea"
	var map: CityMap = main.world.map
	var id: String = map.district_at(Vector2(p.x, p.z))
	for d: Dictionary in map.districts:
		if d["id"] == id:
			return str(d["name"])
	return ""


func _draw() -> void:
	var s: Vector2 = size
	if main.combat.hurt_t > 0.0:  # fogonazo rojo al recibir daño
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0, 0, minf(0.3, main.combat.hurt_t)))
	_draw_help(s)
	_draw_top_right(s)
	_draw_bars(s)
	_draw_bottom_right(s)
	_draw_objective(s)
	_draw_center(s)
	_draw_missile_warning(s)
	if _big != "":
		_draw_banner(s)


# ---------------------------------------------------------------- caja de ayuda

func _draw_help(_s: Vector2) -> void:
	var lines: Array[String] = []
	if _flash_t > 0.0:
		lines.append(_flash)
	var hint: String = _hint()
	if hint != "":
		lines.append(hint)
	if lines.is_empty():
		return
	var w: float = 380.0
	var font: Font = UiStyle.body_font()
	var y: float = MARGIN
	for line: String in lines:
		var text_h: float = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 16).y
		var r := Rect2(MARGIN, y, w, text_h + 18.0)
		var a: float = clampf(_flash_t, 0.0, 1.0) if line == _flash and line != hint else 1.0
		draw_rect(r, Color(UiStyle.PANEL, UiStyle.PANEL.a * a))
		draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color(UiStyle.ACCENT, a))
		draw_multiline_string(font, r.position + Vector2(16, 24), line, HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 16, -1, Color(UiStyle.TEXT, a))
		y += r.size.y + 6.0


func _hint() -> String:
	if main.game_over:
		return ""
	var v: Vehicle = main.vehicle
	var jet: Jet = v as Jet
	if v == null:
		if main.driving.nearby() != null:
			return "Pulsa %s para subir." % Menu.key_name("interact")
		if main.elapsed < 14.0:
			return "%s para moverte · Ratón para mirar · Clic para disparar · %s para correr · %s: mapa" % [
				Menu.keys_text("forward left back right"), Menu.key_name("sprint"), Menu.key_name("map")]
		return ""
	if jet != null:
		if jet.grounded:
			return "%s: acelerar (despega solo a 250 km/h) · %s: frenar · %s %s: girar" % [Menu.key_name("forward"), Menu.key_name("back"), Menu.key_name("left"), Menu.key_name("right")]
		return "%s: subir el morro · %s: bajarlo · %s %s: girar · %s/%s: potencia · %s: bengalas" % [
			Menu.key_name("back"), Menu.key_name("forward"), Menu.key_name("left"), Menu.key_name("right"),
			Menu.key_name("throttle_up"), Menu.key_name("throttle_down"), Menu.key_name("flare")]
	if main.elapsed < 45.0 and absf(v.speed) < 2.0:
		return "%s %s: acelerar y marcha atrás · %s: freno · %s: bajar" % [Menu.key_name("forward"), Menu.key_name("back"), Menu.key_name("jump"), Menu.key_name("interact")]
	return ""


# ---------------------------------------------------------------- arriba a la derecha

func _draw_top_right(s: Vector2) -> void:
	var right: float = s.x - MARGIN
	var wanted: int = main.mission.wanted
	for i: int in 5:
		var lit: bool = (4 - i) < wanted
		var blink: bool = lit and wanted >= MissionState.WANTED_ALERT and fmod(main.elapsed, 0.8) < 0.4
		var c := Vector2(right - 16.0 - i * 34.0, MARGIN + 16.0)
		UiStyle.star(self, c, 17.5, Color(0, 0, 0, 0.7))
		var col := Color(1, 1, 1, 0.18)
		if lit:
			col = Color.WHITE if blink else UiStyle.ACCENT
		UiStyle.star(self, c, 14.5, col)
	# arma
	var box := Rect2(right - 170.0, MARGIN + 42.0, 170.0, 46.0)
	draw_rect(box, UiStyle.PANEL)
	UiStyle.icon_pistol(self, box.position + Vector2(36, 23), 34.0, UiStyle.TEXT)
	UiStyle.text(self, Vector2(box.end.x - 14.0, box.position.y + 33.0), "∞", 28, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.title_font(), 0)
	# hora del día, tiempo de misión y bajas
	UiStyle.text(self, Vector2(right, MARGIN + 120.0), DayNightLogic.clock(main.day_night.hour), 26, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.title_font())
	var t: String = "Misión %s · Bajas %d" % [Settings.format_time(main.elapsed), main.combat.kills]
	UiStyle.text(self, Vector2(right, MARGIN + 144.0), t, 15, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)


# ---------------------------------------------------------------- salud y vehículo

func _draw_bars(s: Vector2) -> void:
	var x: float = MARGIN
	var y: float = s.y - MARGIN - 26.0
	var w: float = Radar.SIZE
	var hp: float = main.player.health / main.player.data.max_health
	var col: Color = UiStyle.HEALTH if hp > 0.3 else (UiStyle.DANGER if fmod(main.elapsed, 0.6) < 0.35 else UiStyle.DANGER.darkened(0.4))
	UiStyle.bar(self, Rect2(x, y, w, 9), hp, col)
	var v: Vehicle = main.vehicle
	if v != null:
		var max_hp: float = (v as Jet).data.max_hp if v.is_jet else (v as Car).data.max_hp
		UiStyle.bar(self, Rect2(x, y + 13, w, 7), v.hp / max_hp, Color(0.95, 0.6, 0.2))


# ---------------------------------------------------------------- abajo a la derecha

func _draw_bottom_right(s: Vector2) -> void:
	var right: float = s.x - MARGIN
	var y: float = s.y - MARGIN
	var v: Vehicle = main.vehicle
	var jet: Jet = v as Jet
	if jet != null:
		_draw_jet(Vector2(right, y), jet)
		y -= 150.0
	elif v != null:
		var kmh: int = int(absf(v.speed) * 3.6)
		UiStyle.text(self, Vector2(right - 52.0, y - 6.0), str(kmh), 54, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.title_font())
		UiStyle.text(self, Vector2(right, y - 10.0), "km/h", 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		var frac: float = absf(v.speed) / (v as Car).data.max_speed
		UiStyle.bar(self, Rect2(right - 180.0, y - 66.0, 180.0, 6.0), frac, UiStyle.ACCENT)
		y -= 84.0
	if _zone_t > 0.0 and (_zone != "" or _vehicle_name != ""):
		var a: float = clampf(_zone_t, 0.0, 1.0)
		if _vehicle_name != "":
			UiStyle.text(self, Vector2(right, y), _vehicle_name, 18, Color(UiStyle.MUTED, a), HORIZONTAL_ALIGNMENT_RIGHT)
			y -= 26.0
		if _zone != "":
			UiStyle.text(self, Vector2(right, y), _zone, 34, Color(UiStyle.ACCENT, a), HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.title_font(), 7)


func _draw_jet(at: Vector2, jet: Jet) -> void:
	var r := Rect2(at.x - 260.0, at.y - 136.0, 260.0, 136.0)
	UiStyle.panel(self, r, Color(0.45, 0.75, 1.0))
	var x: float = r.position.x + 18.0
	UiStyle.text(self, Vector2(x, r.position.y + 42.0), "%d" % int(jet.speed * 3.6), 34, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.title_font())
	UiStyle.text(self, Vector2(x + 92.0, r.position.y + 40.0), "km/h", 14, UiStyle.MUTED)
	UiStyle.text(self, Vector2(r.end.x - 16.0, r.position.y + 42.0), "%d m" % int(jet.altitude()), 28, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.title_font())
	UiStyle.text(self, Vector2(r.end.x - 16.0, r.position.y + 60.0), "altura", 13, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	UiStyle.text(self, Vector2(x, r.position.y + 84.0), "Potencia", 14, UiStyle.MUTED)
	UiStyle.bar(self, Rect2(x + 78.0, r.position.y + 74.0, 146.0, 10.0), jet.throttle, Color(0.45, 0.75, 1.0))
	UiStyle.text(self, Vector2(x, r.position.y + 116.0), "Bengalas", 14, UiStyle.MUTED)
	for i: int in jet.data.flares:
		var c: Color = UiStyle.ACCENT if i < jet.flares else Color(1, 1, 1, 0.15)
		draw_rect(Rect2(x + 78.0 + i * 12.0, r.position.y + 104.0, 8.0, 14.0), c)


# ---------------------------------------------------------------- objetivo y centro

func _draw_objective(s: Vector2) -> void:
	if main.game_over:
		return
	var text: String = main.halcon.objective_text()
	var size_px: int = 22
	var w: float = UiStyle.text_width(text, size_px) + 40.0
	var r := Rect2(s.x / 2.0 - w / 2.0, s.y - MARGIN - 44.0, w, 40.0)
	draw_rect(r, Color(0, 0, 0, 0.55))
	UiStyle.text(self, Vector2(s.x / 2.0, r.position.y + 28.0), text, size_px, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_center(s: Vector2) -> void:
	var c: Vector2 = s / 2.0
	var combat: Combat = main.combat
	if main.vehicle == null and not main.game_over:
		var moving: float = Vector2(main.player.velocity.x, main.player.velocity.z).length()
		var gap: float = 5.0 + moving * 0.7 + maxf(0.0, 0.25 - combat.shot_t) * 30.0
		for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * gap, c + d * (gap + 8.0), Color(0, 0, 0, 0.6), 4.0)
			draw_line(c + d * gap, c + d * (gap + 8.0), Color(1, 1, 1, 0.92), 2.0)
		draw_circle(c, 1.6, Color(1, 1, 1, 0.9))
		if combat.hit_t > 0.0:  # marca de impacto: aspa blanca, roja si lo has abatido
			var hc: Color = UiStyle.DANGER if combat.hit_kill else Color.WHITE
			for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 6.0, c + d * 15.0, hc, 3.0)
	if combat.hit_from_t > 0.0 and not main.game_over:  # de dónde te disparan
		var me: Vector3 = main.target_pos()
		var rel := Vector2(combat.hit_from.x - me.x, combat.hit_from.z - me.z).rotated(main.camera.yaw)
		if rel.length() > 0.5:
			var ang: float = rel.angle()
			var a: float = clampf(combat.hit_from_t, 0.0, 1.0)
			draw_arc(c, 150.0, ang - 0.32, ang + 0.32, 16, Color(0, 0, 0, 0.5 * a), 12.0)
			draw_arc(c, 150.0, ang - 0.3, ang + 0.3, 16, Color(UiStyle.DANGER, 0.9 * a), 8.0)


func _draw_missile_warning(s: Vector2) -> void:
	var md: float = main.air_defense.nearest_missile()
	if md >= 1e8 or main.game_over:
		return
	var on: bool = fmod(main.elapsed, 0.4) < 0.25
	var r := Rect2(s.x / 2.0 - 190.0, MARGIN + 6.0, 380.0, 64.0)
	draw_rect(r, Color(0.35, 0.0, 0.0, 0.75 if on else 0.5))
	draw_rect(r, UiStyle.DANGER, false, 3.0)
	UiStyle.text(self, Vector2(s.x / 2.0, r.position.y + 34.0), "¡MISIL!  %d m" % int(md), 30, Color.WHITE if on else UiStyle.DANGER, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.title_font())
	UiStyle.text(self, Vector2(s.x / 2.0, r.position.y + 56.0), "%s: bengalas" % Menu.key_name("flare"), 15, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_banner(s: Vector2) -> void:
	var grow: float = clampf(_big_t * 4.0, 0.0, 1.0)
	var h: float = 150.0 * grow
	var y: float = s.y * 0.42 - h / 2.0
	draw_rect(Rect2(0, y, s.x, h), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(0, y, s.x, 3), Color(_big_color, 0.9))
	draw_rect(Rect2(0, y + h - 3.0, s.x, 3), Color(_big_color, 0.9))
	if grow < 1.0:
		return
	UiStyle.text(self, Vector2(s.x / 2.0, y + 86.0), _big, 66, _big_color, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.title_font(), 10)
	UiStyle.text(self, Vector2(s.x / 2.0, y + 126.0), _big_sub, 20, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
