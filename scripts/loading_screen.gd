class_name LoadingScreen
extends CanvasLayer
## Pantalla de carga con un consejo al azar mientras se construye la isla.

const TIPS: Array[String] = [
	"Pulsa {map} para abrir el mapa y marcar un destino: el GPS te lleva por las calles.",
	"El radar gira con la cámara: lo que tienes delante queda siempre arriba.",
	"La flecha amarilla del radar señala tu objetivo aunque esté lejos.",
	"Si te disparan, una marca roja alrededor de la mira te dice desde dónde.",
	"En el caza, las bengalas ({flare}) despistan a los misiles que te persiguen.",
	"La autovía rodea la isla: es la forma más rápida de cruzarla.",
	"Los soldados de la base te ven a 45 m. Entra rápido… o con un coche.",
	"Desde el mirador de Las Colinas se ve toda la ciudad.",
]


func _ready() -> void:
	layer = 50
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(_draw_on.bind(c))
	add_child(c)


func _draw_on(c: Control) -> void:
	var s: Vector2 = c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.035, 0.05))
	c.draw_rect(Rect2(0, 0, 6, s.y), UiStyle.ACCENT)
	UiStyle.text(c, Vector2(70, s.y * 0.42), "OPERACIÓN HALCÓN", 64, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.title_font(), 10)
	UiStyle.text(c, Vector2(72, s.y * 0.42 + 44), "Cargando la isla…", 22, UiStyle.TEXT)
	var tip: String = TIPS[randi() % TIPS.size()].format({"map": Menu.key_name("map"), "flare": Menu.key_name("flare")})
	c.draw_rect(Rect2(70, s.y - 110, s.x - 140, 60), UiStyle.PANEL)
	c.draw_rect(Rect2(70, s.y - 110, 4, 60), UiStyle.ACCENT)
	UiStyle.text(c, Vector2(90, s.y - 74), "Consejo: " + tip, 18, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, null, 0)
