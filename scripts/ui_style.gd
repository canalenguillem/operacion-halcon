class_name UiStyle
extends RefCounted
## Estilo común de la interfaz: colores, fuentes, tema de los menús e iconos dibujados por código.
## Todo es propio: las fuentes son variaciones (negrita, cursiva) de la fuente que trae Godot.

const ACCENT: Color = Color(1.0, 0.78, 0.22)
const TEXT: Color = Color(0.97, 0.96, 0.93)
const MUTED: Color = Color(0.7, 0.72, 0.76)
const PANEL: Color = Color(0.04, 0.05, 0.07, 0.78)
const HEALTH: Color = Color(0.36, 0.84, 0.36)
const ARMOR: Color = Color(0.35, 0.6, 1.0)
const DANGER: Color = Color(0.95, 0.24, 0.2)
const ROUTE: Color = Color(0.78, 0.38, 1.0)
const WIN: Color = Color(0.45, 1.0, 0.55)

## Colores del mapa (radar y mapa grande).
const MAP_SEA: Color = Color(0.1, 0.2, 0.3)
const MAP_LAND: Color = Color(0.24, 0.3, 0.21)
const MAP_ROAD: Color = Color(0.82, 0.82, 0.78)
const MAP_HIGHWAY: Color = Color(0.95, 0.66, 0.26)
const MAP_DISTRICT: Dictionary = {
	"casco_antiguo": Color(0.42, 0.36, 0.3),
	"bloques": Color(0.34, 0.34, 0.33),
	"rascacielos": Color(0.3, 0.33, 0.4),
	"ocio": Color(0.42, 0.28, 0.38),
	"chabolas": Color(0.36, 0.3, 0.24),
	"naves": Color(0.32, 0.32, 0.3),
	"muelles": Color(0.28, 0.32, 0.36),
	"mansiones": Color(0.28, 0.38, 0.24),
	"aeropuerto": Color(0.33, 0.34, 0.34),
}

## Icono de cada lugar en el mapa: [letra, color]. Los que no están no salen en el radar.
const POI_ICONS: Dictionary = {
	"aeropuerto": ["✈", Color(0.55, 0.75, 1.0)],
	"casino": ["$", Color(1.0, 0.8, 0.2)],
	"hoteles": ["H", Color(0.9, 0.5, 0.9)],
	"club": ["N", Color(1.0, 0.35, 0.7)],
	"banco": ["B", Color(0.35, 0.85, 0.45)],
	"joyeria": ["J", Color(0.6, 0.95, 1.0)],
	"comisaria": ["P", Color(0.35, 0.55, 1.0)],
	"hospital": ["+", Color(0.95, 0.25, 0.25)],
	"armeria": ["A", Color(0.95, 0.55, 0.2)],
	"pintura": ["T", Color(0.9, 0.9, 0.3)],
	"desguace": ["D", Color(0.7, 0.6, 0.5)],
	"estacion": ["E", Color(0.8, 0.8, 0.85)],
	"estadio": ["O", Color(0.6, 0.9, 0.5)],
	"centro_comercial": ["C", Color(0.95, 0.6, 0.6)],
	"puerto_deportivo": ["Y", Color(0.5, 0.85, 1.0)],
	"motel": ["M", Color(1.0, 0.4, 0.65)],
	"moteros": ["B", Color(0.75, 0.55, 0.35)],
	"gasolinera": ["G", Color(0.9, 0.3, 0.2)],
	"base": ["★", Color(0.95, 0.3, 0.3)],
}

static var _title: FontVariation
static var _body: FontVariation
static var _theme: Theme


## Fuente de títulos y cifras grandes: negrita gruesa y en cursiva.
static func title_font() -> Font:
	if _title == null:
		_title = FontVariation.new()
		_title.base_font = ThemeDB.fallback_font
		_title.variation_embolden = 1.1
		_title.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)
		_title.spacing_glyph = 1
	return _title


## Fuente del resto del texto: algo más gruesa que la normal.
static func body_font() -> Font:
	if _body == null:
		_body = FontVariation.new()
		_body.base_font = ThemeDB.fallback_font
		_body.variation_embolden = 0.45
	return _body


## Texto con contorno. `align` respecto a `pos` (izquierda, centro o derecha).
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, font: Font = null, outline: int = 6) -> void:
	var f: Font = font if font != null else body_font()
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	if outline > 0:
		ci.draw_string_outline(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, color.a * 0.85))
	ci.draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_width(s: String, size: int, font: Font = null) -> float:
	var f: Font = font if font != null else body_font()
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Panel oscuro con una franja de color a la izquierda.
static func panel(ci: CanvasItem, r: Rect2, accent: Color = ACCENT) -> void:
	ci.draw_rect(r, PANEL)
	ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), accent)


## Barra de progreso con fondo.
static func bar(ci: CanvasItem, r: Rect2, value: float, color: Color) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(value, 0.0, 1.0), r.size.y)), color)


static func star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var rr: float = r if i % 2 == 0 else r * 0.42
		var a: float = -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, color)


## Pistola de perfil (cañón hacia la derecha) que cabe en un cuadrado de lado `s`.
static func icon_pistol(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var k: float = s / 10.0
	var o: Vector2 = c - Vector2(5, 5) * k
	ci.draw_rect(Rect2(o + Vector2(1, 2) * k, Vector2(8.5, 2.6) * k), color)  # corredera
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(2, 4.6) * k, o + Vector2(4.6, 4.6) * k,
		o + Vector2(4.0, 9) * k, o + Vector2(1.2, 9) * k]), color)  # empuñadura
	ci.draw_arc(o + Vector2(5.2, 5.2) * k, 1.1 * k, 0.0, PI, 6, color, 0.8 * k)  # guardamonte


static func icon_car(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var k: float = s / 10.0
	var o: Vector2 = c - Vector2(5, 5) * k
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0.5, 7) * k, o + Vector2(0.5, 5) * k, o + Vector2(2.5, 4.4) * k,
		o + Vector2(3.8, 2.4) * k, o + Vector2(7, 2.4) * k, o + Vector2(8.4, 4.4) * k, o + Vector2(9.5, 5) * k, o + Vector2(9.5, 7) * k]), color)
	for x: float in [2.6, 7.4]:
		ci.draw_circle(o + Vector2(x, 7.3) * k, 1.2 * k, Color(0.08, 0.08, 0.08))


## Flecha del jugador apuntando hacia `dir` (vector unitario en pantalla).
static func arrow(ci: CanvasItem, c: Vector2, dir: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array([c + dir * s, c + dir.rotated(2.5) * s * 0.8, c - dir * s * 0.35, c + dir.rotated(-2.5) * s * 0.8])
	ci.draw_colored_polygon(pts, Color(0, 0, 0))
	var inner := PackedVector2Array()
	for p: Vector2 in pts:
		inner.append(c + (p - c) * 0.72)
	ci.draw_colored_polygon(inner, color)


## Icono redondo de un lugar (letra sobre color).
static func poi_icon(ci: CanvasItem, c: Vector2, id: String, r: float) -> void:
	var info: Array = POI_ICONS.get(id, ["·", MUTED]) as Array
	ci.draw_circle(c, r + 1.5, Color(0, 0, 0, 0.85))
	ci.draw_circle(c, r, info[1] as Color)
	var glyph: String = str(info[0])
	if glyph == "✈":
		icon_plane(ci, c, r * 1.5, Color(0.05, 0.05, 0.05))
	elif glyph == "★":
		star(ci, c, r * 0.8, Color(0.05, 0.05, 0.05))
	else:
		var size: int = int(r * 1.5)
		text(ci, c + Vector2(0, size * 0.36), glyph, size, Color(0.05, 0.05, 0.05), HORIZONTAL_ALIGNMENT_CENTER, null, 0)


## Avión visto desde arriba (morro hacia arriba).
static func icon_plane(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var k: float = s / 10.0
	ci.draw_rect(Rect2(c + Vector2(-0.7, -4.5) * k, Vector2(1.4, 9) * k), color)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4.8, 1) * k, c + Vector2(0, -1.8) * k, c + Vector2(4.8, 1) * k]), color)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 4.6) * k, c + Vector2(0, 3) * k, c + Vector2(2, 4.6) * k]), color)


## Tema de los menús: fuente, botones planos con franja de color al pasar o enfocar.
static func menu_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 20
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.0)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(ACCENT, 0.92)
	hover.border_width_left = 6
	hover.border_color = Color(1, 1, 1)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT.darkened(0.2)
	for st: String in ["normal", "disabled"]:
		t.set_stylebox(st, "Button", normal)
	for st: String in ["hover", "focus", "hover_pressed"]:
		t.set_stylebox(st, "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(0.05, 0.05, 0.05))
	t.set_color("font_focus_color", "Button", Color(0.05, 0.05, 0.05))
	t.set_color("font_pressed_color", "Button", Color(0.05, 0.05, 0.05))
	t.set_color("font_hover_pressed_color", "Button", Color(0.05, 0.05, 0.05))
	t.set_constant("align_to_largest_stylebox", "Button", 1)
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = PANEL
	panel_box.border_width_left = 6
	panel_box.border_color = ACCENT
	t.set_stylebox("panel", "PanelContainer", panel_box)
	t.set_color("font_color", "Label", TEXT)
	var opt := normal.duplicate() as StyleBoxFlat
	opt.bg_color = Color(1, 1, 1, 0.08)
	t.set_stylebox("normal", "OptionButton", opt)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("focus", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_color("font_hover_color", "OptionButton", Color(0.05, 0.05, 0.05))
	t.set_color("font_focus_color", "OptionButton", Color(0.05, 0.05, 0.05))
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.18)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	_theme = t
	return t
