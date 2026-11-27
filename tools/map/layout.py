"""Diseño del mapa: genera la ciudad como datos y un plano para revisarlo.

Uso (desde la raíz del proyecto):  python tools/map/layout.py

Salidas:
  data/map/city.json   lo que lee Godot (barrios, calles como grafo, agua, lugares)
  docs/map/plano.png   plano 2D para revisar el diseño

Coordenadas en metros como en Godot: x hacia el este, z hacia el SUR (el norte es -z).
Los nombres son provisionales: el nombre de la ciudad aún no está decidido.
"""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_JSON = ROOT / "data" / "map" / "city.json"
OUT_PNG = ROOT / "docs" / "map" / "plano.png"

# Anchura de calzada (m) por tipo de vía. Las aceras van aparte (ver ACERA).
ROAD_WIDTH = {"autovia": 16.0, "avenida": 20.0, "calle": 12.0, "callejon": 7.0, "muelle": 10.0}
ACERA = 3.0

rng = random.Random(11)

# ------------------------------------------------------------------ grafo de calles

nodes: list[list[float]] = []
node_index: dict[tuple[int, int], int] = {}
roads: list[dict] = []


def node(x: float, z: float) -> int:
    key = (round(x), round(z))
    if key not in node_index:
        node_index[key] = len(nodes)
        nodes.append([round(x, 1), round(z, 1)])
    return node_index[key]


def road(a: int, b: int, kind: str) -> None:
    if a == b:
        return
    for r in roads:
        if {r["a"], r["b"]} == {a, b}:
            return
    roads.append({"a": a, "b": b, "type": kind})


def chain(points: list[tuple[float, float]], kind: str) -> None:
    ids = [node(x, z) for x, z in points]
    for a, b in zip(ids, ids[1:]):
        road(a, b, kind)


# --- lado este del río: Ensanche, Centro, Polígono y Puerto (rejilla de 150 m;
#     en el Centro hay calles intermedias cada 75 m)
EAST_X = [-150, 0, 150, 300, 450, 600, 750]
MID_X = [75, 225, 375]
EAST_Z = [-100, 50, 200, 350, 500, 650, 800, 950, 1100]
CENTRO_Z = (200, 800)


def east_kind_vertical(x: float) -> str:
    return "avenida" if x == 0 else "calle"


def east_kind_horizontal(z: float) -> str:
    return "avenida" if z in (500, 1100) else "calle"


# Huecos: plaza mayor, parque y parcelas grandes del polígono (manzanas sin calle intermedia).
SKIP_EDGES = {
    ((225, 350), (225, 500)),  # plaza mayor
    ((375, 650), (375, 800)),  # parque
    ((600, -100), (600, 50)),  # naves grandes del polígono
    ((600, 200), (600, 350)),
    ((450, 50), (600, 50)),
}


def skipped(p: tuple[float, float], q: tuple[float, float]) -> bool:
    return (p, q) in SKIP_EDGES or (q, p) in SKIP_EDGES


for z in EAST_Z:
    row = sorted(EAST_X + ([x for x in MID_X] if CENTRO_Z[0] <= z <= CENTRO_Z[1] else []))
    for x0, x1 in zip(row, row[1:]):
        if not skipped((x0, z), (x1, z)):
            road(node(x0, z), node(x1, z), east_kind_horizontal(z))
for x in EAST_X:
    for z0, z1 in zip(EAST_Z, EAST_Z[1:]):
        if not skipped((x, z0), (x, z1)):
            road(node(x, z0), node(x, z1), east_kind_vertical(x))
for x in MID_X:
    zs = [z for z in EAST_Z if CENTRO_Z[0] <= z <= CENTRO_Z[1]]
    for z0, z1 in zip(zs, zs[1:]):
        if not skipped((x, z0), (x, z1)):
            road(node(x, z0), node(x, z1), "calle")

# Muelles: calles que entran en el agua sobre los espigones.
for x in (300, 600):
    chain([(x, 1100), (x, 1300), (x, 1430)], "muelle")
chain([(0, 1100), (0, 1290)], "muelle")

# --- lado oeste del río: Residencial (rejilla de 100 m) y Barrio Viejo (callejones torcidos)
WEST_X = [-700, -600, -500, -400, -290]
RES_Z = [-100, 0, 100, 200, 300, 400]
for z in RES_Z:
    for x0, x1 in zip(WEST_X, WEST_X[1:]):
        road(node(x0, z), node(x1, z), "calle")
for x in WEST_X:
    for z0, z1 in zip(RES_Z, RES_Z[1:]):
        road(node(x, z0), node(x, z1), "calle")

VIEJO_X = [-700, -620, -540, -460, -380, -290]
VIEJO_Z = [400, 480, 560, 640, 720, 800, 880, 960, 1040, 1120]
viejo: dict[tuple[int, int], int] = {}
for i, z in enumerate(VIEJO_Z):
    for j, x in enumerate(VIEJO_X):
        edge = i in (0, len(VIEJO_Z) - 1) or j in (0, len(VIEJO_X) - 1)
        jx = 0.0 if edge else rng.uniform(-16, 16)
        jz = 0.0 if edge else rng.uniform(-14, 14)
        viejo[(i, j)] = node(x + jx, z + jz)
for i in range(len(VIEJO_Z)):
    for j in range(len(VIEJO_X)):
        a = viejo[(i, j)]
        perimeter_row = i in (0, len(VIEJO_Z) - 1)
        perimeter_col = j in (0, len(VIEJO_X) - 1)
        if j + 1 < len(VIEJO_X) and (perimeter_row or rng.random() > 0.18):
            road(a, viejo[(i, j + 1)], "calle" if perimeter_row or i == 5 else "callejon")
        if i + 1 < len(VIEJO_Z) and (perimeter_col or rng.random() > 0.22):
            road(a, viejo[(i + 1, j)], "calle" if perimeter_col else "callejon")
# Una calle diagonal que cruza el barrio viejo (la «calle Mayor»).
chain([(-700, 1120), (-540, 880), (-380, 640), (-290, 480)], "calle")

# Puentes sobre el río (unen la orilla oeste x=-290 con la este x=-150).
for zw, ze in [(-100, -100), (200, 200), (480, 500), (800, 800), (1120, 1100)]:
    road(node(-290, zw), node(-150, ze), "avenida" if ze in (500, 1100) else "calle")

# Carretera a la base aérea (la puerta está en (0, -700)).
chain([(0, -100), (25, -250), (55, -400), (40, -550), (0, -700)], "autovia")
# Carretera de la costa hacia el oeste (fuera del mapa jugable por ahora).
chain([(-700, 1120), (-860, 1120)], "calle")

# ------------------------------------------------------------------ agua, barrios y lugares

RIVER = [(-430, -1000), (-310, -600), (-225, -220), (-212, 170), (-226, 610), (-218, 990), (-215, 1320)]
RIVER_WIDTH = 46.0

SEA = [(-2000, 1170), (-245, 1170), (-245, 1320), (2000, 1320), (2000, 3000), (-2000, 3000)]
PIERS = [  # espigones (tierra que entra en el mar)
    [(260, 1300), (340, 1300), (340, 1460), (260, 1460)],
    [(560, 1300), (640, 1300), (640, 1460), (560, 1460)],
    [(-30, 1300), (30, 1300), (30, 1320), (-30, 1320)],
]

DISTRICTS = [
    {"id": "residencial", "label": (-480, 345), "name": "Residencial", "style": "casas",
     "poly": [(-760, -160), (-245, -160), (-245, 420), (-760, 420)], "color": (200, 214, 170)},
    {"id": "viejo", "label": (-470, 1090), "name": "Barrio Viejo", "style": "casco_antiguo",
     "poly": [(-760, 420), (-245, 420), (-245, 1170), (-760, 1170)], "color": (222, 196, 160)},
    {"id": "ensanche", "label": (140, 120), "name": "Ensanche", "style": "bloques",
     "poly": [(-190, -160), (460, -160), (460, 200), (-190, 200)], "color": (214, 206, 190)},
    {"id": "centro", "label": (150, 725), "name": "Centro", "style": "rascacielos",
     "poly": [(-190, 200), (460, 200), (460, 830), (-190, 830)], "color": (196, 200, 214)},
    {"id": "poligono", "label": (630, 280), "name": "Polígono", "style": "naves",
     "poly": [(460, -160), (810, -160), (810, 830), (460, 830)], "color": (196, 192, 180)},
    {"id": "puerto", "label": (150, 1225), "name": "Puerto", "style": "muelles",
     "poly": [(-190, 830), (810, 830), (810, 1320), (-190, 1320)], "color": (186, 196, 200)},
]

AREAS = [
    {"id": "plaza_mayor", "kind": "plaza", "poly": [(156, 356), (294, 356), (294, 494), (156, 494)]},
    {"id": "parque", "kind": "parque", "poly": [(306, 656), (444, 656), (444, 794), (306, 794)]},
    {"id": "base_aerea", "kind": "base", "poly": [(-350, -1300), (350, -1300), (350, -700), (-350, -700)]},
]

POIS = [
    {"id": "piso_franco", "name": "Piso franco (inicio)", "pos": (-505, 765)},
    {"id": "plaza_vieja", "name": "Plaza vieja", "pos": (-420, 600)},
    {"id": "hospital", "name": "Hospital", "pos": (-450, 150)},
    {"id": "centro_comercial", "name": "Centro comercial", "pos": (-650, -50)},
    {"id": "comisaria", "name": "Comisaría", "pos": (38, 575)},
    {"id": "armeria", "name": "Armería", "pos": (262, 275)},
    {"id": "plaza_mayor", "name": "Plaza mayor", "pos": (225, 425)},
    {"id": "parque", "name": "Parque", "pos": (375, 725)},
    {"id": "taller", "name": "Taller de coches", "pos": (525, 125)},
    {"id": "desguace", "name": "Desguace", "pos": (680, 420)},
    {"id": "mercado", "name": "Mercado del puerto", "pos": (150, 875)},
    {"id": "faro", "name": "Faro", "pos": (600, 1440)},
    {"id": "gasolinera", "name": "Gasolinera", "pos": (85, -330)},
]

# ------------------------------------------------------------------ geometría auxiliar


def seg_intersect(p1, p2, q1, q2) -> bool:
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    d1, d2 = cross(q1, q2, p1), cross(q1, q2, p2)
    d3, d4 = cross(p1, p2, q1), cross(p1, p2, q2)
    return (d1 * d2 < 0) and (d3 * d4 < 0)


def crosses_river(a, b) -> bool:
    return any(seg_intersect(a, b, r1, r2) for r1, r2 in zip(RIVER, RIVER[1:]))


for r in roads:
    r["bridge"] = crosses_river(nodes[r["a"]], nodes[r["b"]])


def to_list(poly):
    return [[float(x), float(z)] for x, z in poly]


# ------------------------------------------------------------------ JSON para Godot


def write_json() -> None:
    data = {
        "version": 1,
        "note": "Generado por tools/map/layout.py; no editar a mano.",
        "road_width": ROAD_WIDTH,
        "sidewalk": ACERA,
        "nodes": nodes,
        "roads": roads,
        "river": {"line": to_list(RIVER), "width": RIVER_WIDTH},
        "sea": to_list(SEA),
        "piers": [to_list(p) for p in PIERS],
        "districts": [{k: (to_list(v) if k == "poly" else list(v) if k == "label" else v) for k, v in d.items() if k != "color"} for d in DISTRICTS],
        "areas": [{**a, "poly": to_list(a["poly"])} for a in AREAS],
        "pois": [{**p, "pos": [float(p["pos"][0]), float(p["pos"][1])]} for p in POIS],
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")


# ------------------------------------------------------------------ plano PNG


def write_png() -> None:
    from PIL import Image, ImageDraw, ImageFont

    x0, x1, z0, z1 = -900.0, 900.0, -1360.0, 1520.0
    k = 0.42  # píxeles por metro
    margin = 20
    legend_w = 300
    w = int((x1 - x0) * k) + margin * 2
    h = int((z1 - z0) * k) + margin * 2

    def P(x: float, z: float) -> tuple[float, float]:
        return (margin + (x - x0) * k, margin + (z - z0) * k)

    def font(size: int, bold: bool = False):
        for name in (["arialbd.ttf", "DejaVuSans-Bold.ttf"] if bold else ["arial.ttf", "DejaVuSans.ttf"]):
            try:
                return ImageFont.truetype(name, size)
            except OSError:
                continue
        return ImageFont.load_default()

    img = Image.new("RGB", (w + legend_w, h), (232, 228, 214))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, h], fill=(176, 196, 140))  # campo

    for dist in DISTRICTS:
        d.polygon([P(x, z) for x, z in dist["poly"]], fill=dist["color"])
    for a in AREAS:
        col = {"plaza": (236, 226, 196), "parque": (120, 170, 100), "base": (150, 150, 150)}[a["kind"]]
        d.polygon([P(x, z) for x, z in a["poly"]], fill=col)
    # base aérea: pista y hangares
    d.rectangle([P(-330, -1220), P(330, -1180)], fill=(60, 60, 66))
    for hx in (160, 250):
        d.rectangle([P(hx - 35, -1068), P(hx + 35, -1032)], fill=(110, 116, 110))
    d.polygon([P(x, z) for x, z in SEA], fill=(92, 150, 200))
    for p in PIERS:
        d.polygon([P(x, z) for x, z in p], fill=(170, 170, 160))
    d.line([P(x, z) for x, z in RIVER], fill=(92, 150, 200), width=int(RIVER_WIDTH * k), joint="curve")

    # calles: primero el borde (acera), luego la calzada
    order = ["callejon", "calle", "muelle", "avenida", "autovia"]
    for kind in order:
        for r in roads:
            if r["type"] != kind:
                continue
            a, b = P(*nodes[r["a"]]), P(*nodes[r["b"]])
            width = (ROAD_WIDTH[kind] + 2 * ACERA) * k
            d.line([a, b], fill=(150, 110, 70) if r["bridge"] else (205, 205, 200), width=max(2, int(width) + 2))
    for kind in order:
        for r in roads:
            if r["type"] != kind:
                continue
            a, b = P(*nodes[r["a"]]), P(*nodes[r["b"]])
            col = {"autovia": (230, 160, 60), "avenida": (250, 250, 250)}.get(kind, (238, 238, 232))
            d.line([a, b], fill=col, width=max(1, int(ROAD_WIDTH[kind] * k)))

    f_dist = font(20, True)
    for dist in DISTRICTS:
        cx, cz = P(*dist["label"])
        text = dist["name"].upper()
        tw = d.textlength(text, font=f_dist)
        d.text((cx - tw / 2 + 1, cz - 11), text, font=f_dist, fill=(255, 255, 255))
        d.text((cx - tw / 2, cz - 12), text, font=f_dist, fill=(50, 50, 60))

    f_small = font(14, True)
    for text, (x, z) in [("BASE AÉREA", (0, -1000)), ("MAR", (100, 1490)), ("RÍO", (-300, -520)), ("CAMPO", (-650, -600)),
                         ("a la base", (95, -520))]:
        cx, cz = P(x, z)
        tw = d.textlength(text, font=f_small)
        d.text((cx - tw / 2, cz - 7), text, font=f_small, fill=(30, 30, 40))
    cx, cz = P(330, 1478)
    d.text((cx, cz), "→ aeródromo clandestino (8,7 km al SE)", font=font(13), fill=(20, 20, 40))

    f_poi = font(12, True)
    for i, poi in enumerate(POIS, start=1):
        cx, cz = P(*poi["pos"])
        r = 9
        d.ellipse([cx - r, cz - r, cx + r, cz + r], fill=(200, 40, 40) if i == 1 else (40, 60, 120), outline=(255, 255, 255), width=2)
        t = str(i)
        tw = d.textlength(t, font=f_poi)
        d.text((cx - tw / 2, cz - 7), t, font=f_poi, fill=(255, 255, 255))

    # escala y norte
    sx, sz = margin + 20, h - margin - 30
    d.rectangle([sx, sz, sx + 500 * k, sz + 6], fill=(30, 30, 30))
    d.text((sx, sz + 9), "500 m", font=font(13), fill=(30, 30, 30))
    nx, nz = w - margin - 30, margin + 40
    d.polygon([(nx, nz - 28), (nx - 10, nz), (nx + 10, nz)], fill=(30, 30, 30))
    d.text((nx - 5, nz + 4), "N", font=font(16, True), fill=(30, 30, 30))

    # leyenda
    lx = w + 16
    d.text((lx, 20), "Plano provisional", font=font(22, True), fill=(30, 30, 40))
    d.text((lx, 50), "Ciudad: nombre por decidir", font=font(14), fill=(80, 80, 90))
    y = 90
    f_leg = font(14)
    for i, poi in enumerate(POIS, start=1):
        d.ellipse([lx, y, lx + 18, y + 18], fill=(200, 40, 40) if i == 1 else (40, 60, 120))
        t = str(i)
        tw = d.textlength(t, font=f_poi)
        d.text((lx + 9 - tw / 2, y + 2), t, font=f_poi, fill=(255, 255, 255))
        d.text((lx + 26, y + 1), poi["name"], font=f_leg, fill=(30, 30, 40))
        y += 26
    y += 14
    for label, col in [("Autovía", (230, 160, 60)), ("Avenida", (250, 250, 250)), ("Calle / callejón", (238, 238, 232)),
                       ("Puente", (150, 110, 70)), ("Agua", (92, 150, 200)), ("Parque", (120, 170, 100))]:
        d.rectangle([lx, y + 3, lx + 30, y + 15], fill=col, outline=(120, 120, 120))
        d.text((lx + 40, y + 1), label, font=f_leg, fill=(30, 30, 40))
        y += 24
    y += 14
    total = sum(math.dist(nodes[r["a"]], nodes[r["b"]]) for r in roads)
    stats = [
        f"Ciudad: 1,57 × 1,48 km",
        f"Calles: {len(roads)} tramos, {total / 1000:.1f} km",
        f"Cruces: {len(nodes)}",
        f"Puentes: {sum(1 for r in roads if r['bridge'])}",
    ]
    for s in stats:
        d.text((lx, y), s, font=f_leg, fill=(30, 30, 40))
        y += 22

    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT_PNG)


if __name__ == "__main__":
    write_json()
    write_png()
    print(f"{len(nodes)} cruces, {len(roads)} tramos -> {OUT_JSON.relative_to(ROOT)}, {OUT_PNG.relative_to(ROOT)}")
