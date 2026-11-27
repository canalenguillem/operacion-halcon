"""Diseño del mapa: genera la ciudad como datos y planos para revisarla.

Uso (desde la raíz del proyecto):  python tools/map/layout.py

Salidas:
  data/map/city.json          lo que lee Godot (barrios, calles como grafo, agua, colinas, zonas, lugares)
  docs/map/plano.png          plano de toda la región
  docs/map/plano_ciudad.png   plano ampliado de la ciudad

Coordenadas en metros como en Godot: x hacia el este, z hacia el SUR (el norte es -z).
Los nombres son provisionales: el nombre de la ciudad aún no está decidido.

Cómo se construye la red de calles:
  1. Cada barrio aporta polilíneas con su propio patrón (tela de araña en el casco viejo,
     rejillas giradas, curvas de nivel en la colina, callejuelas torcidas en los barrios bajos).
  2. Las avenidas y autovías (arterias) unen los barrios y cruzan el río por los puentes.
  3. Se calculan todos los cruces entre polilíneas («noding») y se limpia el grafo:
     se funden cruces muy cercanos, se quitan los cabos sueltos cortos, las calles que caen
     en el agua o dentro de zonas sin calles, y se queda solo la parte conectada.
"""

from __future__ import annotations

import json
import math
import random
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_JSON = ROOT / "data" / "map" / "city.json"
OUT_PNG = ROOT / "docs" / "map" / "plano.png"
OUT_PNG_CITY = ROOT / "docs" / "map" / "plano_ciudad.png"

# Anchura de calzada (m) por tipo de vía; las aceras van aparte.
ROAD_WIDTH = {"autovia": 18.0, "avenida": 18.0, "calle": 11.0, "muelle": 10.0, "callejon": 7.0}
PRIORITY = {"autovia": 5, "avenida": 4, "calle": 3, "muelle": 2, "callejon": 1}
SIDEWALK = 3.0

rng = random.Random(23)

Vec = tuple[float, float]

# ================================================================== elementos fijos del mundo

RIVER = [(-960, -1260), (-800, -700), (-580, -150), (-480, 300), (-440, 700), (-425, 1140)]
RIVER_WIDTH = 48.0

# La isla. La costa sur de la ciudad (playa y puerto) es fija; el resto lleva ruido para que sea irregular.
COAST_FIXED = [(-1500, 1110), (-420, 1110), (620, 1100), (640, 1160), (1400, 1160)]
COAST_FREE = [(1750, 1020), (2300, 1000), (2900, 920), (3300, 620), (3420, 200), (3330, -300), (2850, -620),
              (1900, -820), (1000, -1180), (420, -1520), (-250, -1640), (-850, -1520), (-1350, -1220),
              (-1820, -820), (-2120, -220), (-2100, 480), (-1880, 1000)]
# Islotes: el del aeródromo clandestino (destino de la misión) y uno militar con una batería de misiles.
ISLETS = [{"id": "aerodromo", "center": [6000.0, 5000.0], "radius": 480.0},
          {"id": "islote_militar", "center": [3700.0, 3100.0], "radius": 260.0}]


def make_coast() -> list[Vec]:
    """Costa de la isla: los tramos libres se subdividen y se ondulan con ruido suave."""
    pts: list[Vec] = list(COAST_FIXED)
    free = [COAST_FIXED[-1]] + COAST_FREE + [COAST_FIXED[0]]
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    walked = 0.0
    for a, b in zip(free, free[1:]):
        n = max(1, int(dist(a, b) // 90))
        nx, nz = -(b[1] - a[1]) / dist(a, b), (b[0] - a[0]) / dist(a, b)
        for i in range(1, n + 1):
            t = i / n
            p = lerp(a, b, t)
            walked += dist(a, b) / n
            last = b == free[-1] and i == n
            if last:
                continue
            amp = 55 * math.sin(walked / 260 + ph1) + 30 * math.sin(walked / 97 + ph2)
            pts.append((p[0] + nx * amp, p[1] + nz * amp))
    return pts


COAST: list[Vec] = []  # se calcula en main() (necesita las funciones de geometría)
BEACH = [(-405, 1052), (620, 1048), (620, 1100), (-420, 1110)]
PIERS = [
    [(770, 1150), (830, 1150), (830, 1330), (770, 1330)],
    [(970, 1150), (1030, 1150), (1030, 1330), (970, 1330)],
    [(1170, 1150), (1230, 1150), (1230, 1330), (1170, 1330)],
    [(-1230, 1105), (-1200, 1105), (-1200, 1210), (-1230, 1210)],  # puerto deportivo
    [(-1130, 1105), (-1100, 1105), (-1100, 1210), (-1130, 1210)],
]

OLD_TOWN_CENTER: Vec = (-30.0, 380.0)
RONDA_R = 300.0
HILL_CENTER: Vec = (-1180.0, -170.0)
HILLS = [{"id": "colinas", "center": list(HILL_CENTER), "radius": 640.0, "height": 105.0}]

BASE = [(-350, -1300), (350, -1300), (350, -700), (-350, -700)]
GATE: Vec = (0.0, -700.0)
DEST: Vec = (6000.0, 5000.0)

RUNWAY = [(1650, 125), (2950, 125), (2950, 175), (1650, 175)]
TAXIWAY = [(1700, 215), (2900, 215), (2900, 235), (1700, 235)]
APRON = [(1850, 240), (2450, 240), (2450, 330), (1850, 330)]
TERMINAL = [(1880, 335), (2380, 335), (2380, 395), (1880, 395)]
PARKING = [(1900, 500), (2300, 500), (2300, 580), (1900, 580)]
PLAYER_START: Vec = (2100.0, 470.0)

# Zonas donde no puede pasar ninguna calle (parques, recintos…).
NO_ROADS = {
    "estadio": [(470, -300), (680, -300), (680, -140), (470, -140)],
    "cementerio": [(-610, -420), (-440, -420), (-440, -290), (-610, -290)],
    "parque": [(110, -70), (290, -70), (290, 60), (110, 60)],
    "golf": [(-1500, 230), (-940, 230), (-900, 420), (-1500, 420)],
    "aeropuerto": [(1600, 90), (3000, 90), (3000, 400), (1600, 400)],
    "base_aerea": BASE,
}

# ================================================================== geometría


def lerp(a: Vec, b: Vec, t: float) -> Vec:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def dist(a: Vec, b: Vec) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def polar(c: Vec, angle_deg: float, r: float, rz: float | None = None) -> Vec:
    a = math.radians(angle_deg)
    return (c[0] + math.cos(a) * r, c[1] + math.sin(a) * (r if rz is None else rz))


def point_in_poly(p: Vec, poly: list[Vec]) -> bool:
    x, z = p
    inside = False
    n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z):
            xi = x1 + (z - z1) * (x2 - x1) / (z2 - z1)
            if x < xi:
                inside = not inside
    return inside


def seg_point_dist(p: Vec, a: Vec, b: Vec) -> float:
    dx, dz = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dz * dz
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / l2))
    return dist(p, (a[0] + dx * t, a[1] + dz * t))


def seg_intersection(p1: Vec, p2: Vec, q1: Vec, q2: Vec, tol: float = 3.0):
    """Cruce de dos segmentos (con tolerancia en metros en los extremos). Devuelve (t, u) o None."""
    rx, rz = p2[0] - p1[0], p2[1] - p1[1]
    sx, sz = q2[0] - q1[0], q2[1] - q1[1]
    den = rx * sz - rz * sx
    if abs(den) < 1e-9:
        return None
    qpx, qpz = q1[0] - p1[0], q1[1] - p1[1]
    t = (qpx * sz - qpz * sx) / den
    u = (qpx * rz - qpz * rx) / den
    lp, lq = math.hypot(rx, rz), math.hypot(sx, sz)
    tt, tu = tol / max(lp, 1e-6), tol / max(lq, 1e-6)
    if -tt <= t <= 1 + tt and -tu <= u <= 1 + tu:
        return max(0.0, min(1.0, t)), max(0.0, min(1.0, u))
    return None


def crosses_line(a: Vec, b: Vec, line: list[Vec]) -> bool:
    return any(seg_intersection(a, b, p, q, 0.0) is not None for p, q in zip(line, line[1:]))


def wobble(points: list[Vec], amount: float) -> list[Vec]:
    """Desplaza al azar los puntos interiores de una polilínea (calles que no son rectas)."""
    out = [points[0]]
    for p in points[1:-1]:
        out.append((p[0] + rng.uniform(-amount, amount), p[1] + rng.uniform(-amount, amount)))
    out.append(points[-1])
    return out


def subdivide(points: list[Vec], step: float) -> list[Vec]:
    out = [points[0]]
    for a, b in zip(points, points[1:]):
        n = max(1, int(dist(a, b) // step))
        for i in range(1, n + 1):
            out.append(lerp(a, b, i / n))
    return out


# ================================================================== polilíneas de partida

# Cada polilínea: puntos, tipo, origen (barrio), si sus extremos son fondos de saco a conservar
# y si puede cruzar el río (solo los puentes).
polylines: list[dict] = []


def add(points: list[Vec], kind: str, source: str, keep_ends: bool = False, bridge: bool = False) -> None:
    polylines.append({"pts": [(float(x), float(z)) for x, z in points], "kind": kind,
                      "source": source, "keep_ends": keep_ends, "bridge": bridge})


def ronda_point(angle: float) -> Vec:
    return polar(OLD_TOWN_CENTER, angle, RONDA_R + ronda_noise[int(round(angle)) % 360])


ronda_noise = [0.0] * 360
_phase = rng.uniform(0, 6.28)
for _a in range(360):
    ronda_noise[_a] = 14.0 * math.sin(math.radians(_a) * 3 + _phase) + 6.0 * math.sin(math.radians(_a) * 7)


def build_old_town() -> None:
    """Casco viejo: plaza de la catedral, dos anillos torcidos, calles radiales y la Ronda."""
    c = OLD_TOWN_CENTER
    add([ronda_point(a) for a in range(0, 361, 6)], "avenida", "casco")
    add([polar(c, a, 58) for a in range(0, 361, 20)], "calle", "casco")  # plaza de la catedral
    for r, kind in ((135, "calle"), (220, "callejon")):
        pts = [polar(c, a, r + rng.uniform(-14, 14)) for a in range(0, 360, 15)]
        add(pts + [pts[0]], kind, "casco")
    angles = [a + rng.uniform(-9, 9) for a in range(0, 360, 26)]
    for a in angles:
        start = 58 if rng.random() < 0.6 else 135
        pts = [polar(c, a + rng.uniform(-6, 6), r) for r in (start, (start + 220) / 2, 220, 262, RONDA_R + 26)]
        add(wobble(pts, 9), "callejon", "casco")
    for _ in range(9):  # callejuelas que cruzan en diagonal entre anillos
        a = rng.uniform(0, 360)
        add(wobble([polar(c, a, 135), polar(c, a + rng.uniform(12, 22), 178), polar(c, a + rng.uniform(25, 40), 220)], 8),
            "callejon", "casco")


def clip_line_to_poly(p0: Vec, d: Vec, poly: list[Vec]) -> list[tuple[float, float]]:
    """Tramos [t0, t1] de la recta p0 + t·d que quedan dentro del polígono."""
    ts: list[float] = []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        ex, ez = b[0] - a[0], b[1] - a[1]
        den = d[0] * ez - d[1] * ex
        if abs(den) < 1e-9:
            continue
        apx, apz = a[0] - p0[0], a[1] - p0[1]
        t = (apx * ez - apz * ex) / den
        u = (apx * d[1] - apz * d[0]) / den
        if 0 <= u < 1:
            ts.append(t)
    ts.sort()
    return [(ts[i], ts[i + 1]) for i in range(0, len(ts) - 1, 2)]


def minus_circle(p0: Vec, d: Vec, t0: float, t1: float, c: Vec, r: float) -> list[tuple[float, float]]:
    fx, fz = p0[0] - c[0], p0[1] - c[1]
    b = fx * d[0] + fz * d[1]
    cc = fx * fx + fz * fz - r * r
    disc = b * b - cc
    if disc <= 0:
        return [(t0, t1)]
    s = math.sqrt(disc)
    c0, c1 = -b - s, -b + s
    out = []
    if c0 > t0:
        out.append((t0, min(t1, c0)))
    if c1 < t1:
        out.append((max(t0, c1), t1))
    return [(a, b) for a, b in out if b > a]


def grid(source: str, poly: list[Vec], angle: float, sx: float, sz: float, kind: str = "calle",
         avenue_every: int = 0, line_jitter: float = 0.0, angle_jitter: float = 0.0,
         wobble_m: float = 0.0, overshoot: float = 24.0) -> None:
    """Rejilla girada `angle` grados recortada al polígono (y fuera de la Ronda del casco viejo)."""
    for fam, spacing in ((0, sx), (1, sz)):
        a = math.radians(angle + (90 if fam else 0))
        d = (math.cos(a), math.sin(a))
        nrm = (-d[1], d[0])
        projs = [p[0] * nrm[0] + p[1] * nrm[1] for p in poly]
        k0, k1 = math.floor(min(projs) / spacing), math.ceil(max(projs) / spacing)
        for k in range(k0, k1 + 1):
            off = k * spacing + rng.uniform(-line_jitter, line_jitter)
            aj = math.radians(rng.uniform(-angle_jitter, angle_jitter))
            dd = (d[0] * math.cos(aj) - d[1] * math.sin(aj), d[0] * math.sin(aj) + d[1] * math.cos(aj))
            p0 = (nrm[0] * off, nrm[1] * off)
            for t0, t1 in clip_line_to_poly(p0, dd, poly):
                for u0, u1 in minus_circle(p0, dd, t0, t1, OLD_TOWN_CENTER, RONDA_R - 24):
                    if u1 - u0 < 40:
                        continue
                    a_pt = (p0[0] + dd[0] * u0, p0[1] + dd[1] * u0)
                    b_pt = (p0[0] + dd[0] * u1, p0[1] + dd[1] * u1)
                    mid = lerp(a_pt, b_pt, 0.5)
                    if _hugs_boundary(mid, dd, poly):
                        continue
                    ext0 = overshoot if u0 == t0 else 0.0
                    ext1 = overshoot if u1 == t1 else 0.0
                    a_pt = (a_pt[0] - dd[0] * ext0, a_pt[1] - dd[1] * ext0)
                    b_pt = (b_pt[0] + dd[0] * ext1, b_pt[1] + dd[1] * ext1)
                    kd = "avenida" if avenue_every and k % avenue_every == 0 else kind
                    pts = subdivide([a_pt, b_pt], 70) if wobble_m else [a_pt, b_pt]
                    add(wobble(pts, wobble_m) if wobble_m else pts, kd, source)


def _hugs_boundary(mid: Vec, d: Vec, poly: list[Vec]) -> bool:
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        el = dist(a, b)
        e = ((b[0] - a[0]) / el, (b[1] - a[1]) / el)
        if abs(d[0] * e[1] - d[1] * e[0]) < 0.17 and seg_point_dist(mid, a, b) < 28:
            return True
    return False


def outline(poly: list[Vec], edges: list[int], kind: str, source: str) -> None:
    n = len(poly)
    for i in edges:
        add([poly[i], poly[(i + 1) % n]], kind, source)


def build_hill() -> None:
    """Colina rica: curvas de nivel serpenteantes, subidas en zigzag y fondos de saco con mansiones."""
    c = HILL_CENTER
    rings = [(150, 125, 0, 360), (290, 245, 15, 330), (430, 360, -160, 160)]
    ring_pts = []
    for rx, rz, a0, a1 in rings:
        pts = [polar(c, a, rx + rng.uniform(-12, 12), rz + rng.uniform(-12, 12)) for a in range(a0, a1 + 1, 10)]
        ring_pts.append((rx, rz))
        add(pts, "calle", "colina")
    for a, (i, j) in [(35, (2, 1)), (165, (2, 1)), (250, (2, 1)), (110, (1, 0)), (300, (1, 0))]:
        (rx1, rz1), (rx2, rz2) = ring_pts[i], ring_pts[j]
        pts = []
        for n in range(9):
            t = n / 8
            pts.append(polar(c, a + 16 * math.sin(t * 2 * math.pi), rx1 + (rx2 - rx1) * t, rz1 + (rz2 - rz1) * t))
        add(pts, "calle", "colina")  # subida en S (curvas de herradura)
    add([polar(c, 20, 150, 125), polar(c, 60, 70, 60), c], "calle", "colina", keep_ends=True)  # subida al mirador
    for _ in range(16):  # fondos de saco con mansiones
        ring = rng.choice([1, 2])
        rx, rz = ring_pts[ring]
        a = rng.uniform(-150, 150) if ring == 2 else rng.uniform(20, 320)
        out = rng.choice([-1, 1])
        bend = rng.uniform(-8, 8)
        add([polar(c, a, rx, rz), polar(c, a + bend * 0.5, rx + out * 30, rz + out * 27),
             polar(c, a + bend, rx + out * 55, rz + out * 50)], "calle", "colina", keep_ends=True)


def build_districts() -> None:
    # Ensanche: rejilla regular al norte del casco viejo.
    ens = [(-650, -430), (720, -430), (720, 160), (-470, 160)]
    grid("ensanche", ens, 0, 110, 110, avenue_every=4)
    outline(ens, [0, 1], "calle", "ensanche")
    # Distrito financiero: rejilla girada, manzanas pequeñas y avenidas.
    fin = [(150, 160), (1000, 160), (1000, 700), (150, 700)]
    grid("financiero", fin, 28, 85, 85, avenue_every=3)
    outline(fin, [1, 2], "calle", "financiero")
    # Polígono: parcelas enormes.
    pol = [(720, -430), (1400, -430), (1400, 160), (720, 160)]
    grid("poligono", pol, 0, 170, 150)
    outline(pol, [0, 1, 2], "calle", "poligono")
    # Puerto: rejilla ligeramente girada y muelles.
    port = [(1000, 160), (1400, 160), (1400, 1150), (620, 1150), (620, 700), (1000, 700)]
    grid("puerto", port, -12, 150, 115)
    outline(port, [1], "calle", "puerto")
    for p in PIERS[:3]:
        cx = (p[0][0] + p[1][0]) / 2
        add([(cx, 1120), (cx, 1320)], "muelle", "puerto", keep_ends=True)
    # La Milla (casino, hoteles y ocio) entre el casco viejo y la playa: manzanas alargadas.
    milla = [(-410, 700), (620, 700), (620, 1052), (-410, 1060)]
    grid("milla", milla, 3, 135, 80)
    # Los Bajos (este, entre el río y el casco) y (oeste, al otro lado del río): callejuelas torcidas.
    bajos_e = [(-470, 160), (-200, 160), (-200, 700), (-410, 700)]
    grid("bajos", bajos_e, 8, 75, 70, kind="callejon", line_jitter=10, angle_jitter=5, wobble_m=7)
    bajos_o = [(-1100, 450), (-505, 450), (-480, 700), (-468, 1070), (-1100, 1070)]
    grid("bajos", bajos_o, -9, 70, 65, kind="callejon", line_jitter=12, angle_jitter=7, wobble_m=8)
    outline(bajos_o, [0, 3], "calle", "bajos")
    # Aeropuerto civil: acceso y bucle de la terminal.
    add([(1800, 430), (2380, 430), (2420, 470), (2380, 510), (2380, 590), (1840, 590), (1840, 470), (1800, 430)], "avenida", "aeropuerto")
    add([(2380, 430), (2600, 430), (2700, 380)], "calle", "aeropuerto", keep_ends=True)  # hangares
    build_hill()


def build_arterials() -> None:
    rp = ronda_point
    # Autovía de circunvalación: aeropuerto → norte (cruce con la carretera de la base) → colina → costa oeste.
    add([(1800, 430), (1560, 330), (1470, -150), (1150, -540), (500, -590), (0, -590), (-500, -610), (-900, -640),
         (-1350, -560), (-1700, -300), (-1820, 150), (-1700, 650), (-1450, 980), (-1150, 1075), (-800, 1078),
         (-470, 1078), (-380, 1047)], "autovia", "autovia", bridge=True)
    # Paseo marítimo y avenida de La Milla.
    add([(-380, 1047), (100, 1046), (620, 1043), (720, 1110), (1300, 1115)], "avenida", "paseo")
    add([(-410, 885), (100, 880), (620, 875), (1000, 870), (1400, 880)], "avenida", "milla")
    # Gran Vía: del casco viejo al norte, a la autovía y a la puerta de la base.
    add([rp(270), (-30, -430), (-30, -590), (-10, -650), GATE], "avenida", "granvia")
    # Avenida del Aeropuerto (este).
    add([rp(355), (700, 345), (1000, 335), (1560, 330)], "avenida", "aeropuerto_av")
    # Radiales del casco viejo.
    add([rp(45), (500, 800), (700, 875)], "avenida", "radial")                       # sureste → Milla y puerto
    add([rp(90), (-30, 885), (-30, 1046)], "avenida", "radial")                      # sur → playa
    add([rp(135), (-330, 690), (-470, 800), (-700, 870)], "avenida", "radial", bridge=True)  # suroeste → Los Bajos
    add([rp(180), (-410, 360), (-560, 330), (-700, 250), polar(HILL_CENTER, 40, 430, 360)], "avenida", "radial", bridge=True)  # oeste → colina
    add([rp(225), (-430, -30), (-640, -170), polar(HILL_CENTER, -12, 430, 360)], "avenida", "radial", bridge=True)  # noroeste → colina
    add([rp(315), (450, -60), (720, -200), (1150, -300)], "avenida", "radial")      # noreste → polígono
    add([polar(HILL_CENTER, -90, 430, 360), (-1180, -570)], "calle", "colina", bridge=False)  # colina → autovía
    # Puentes de los barrios bajos.
    add([(-330, 560), (-470, 560), (-560, 560)], "calle", "bajos", bridge=True)
    add([(-300, 965), (-470, 970), (-560, 975)], "calle", "bajos", bridge=True)
    add([(-500, -250), (-660, -260), polar(HILL_CENTER, -25, 430, 360)], "calle", "ensanche", bridge=True)


RAILWAY = [(3000, -320), (1500, -360), (1100, -380), (700, -380), (310, -380)]

DISTRICTS = [
    {"id": "casco", "name": "Casco Viejo", "style": "casco_antiguo", "label": (-30, 210), "color": (222, 196, 160),
     "poly": [polar(OLD_TOWN_CENTER, a, RONDA_R + 10) for a in range(0, 360, 15)]},
    {"id": "ensanche", "name": "Ensanche", "style": "bloques", "label": (-200, -340), "color": (214, 206, 190),
     "poly": [(-650, -430), (720, -430), (720, 160), (-470, 160)]},
    {"id": "financiero", "name": "Distrito Financiero", "style": "rascacielos", "label": (640, 560), "color": (190, 198, 220),
     "poly": [(150, 160), (1000, 160), (1000, 700), (150, 700)]},
    {"id": "milla", "name": "La Milla", "style": "ocio", "label": (330, 760), "color": (230, 190, 214),
     "poly": [(-410, 700), (620, 700), (620, 1052), (-410, 1060)]},
    {"id": "bajos", "name": "Los Bajos", "style": "chabolas", "label": (-800, 780), "color": (196, 170, 140),
     "poly": [(-1100, 450), (-505, 450), (-480, 700), (-468, 1070), (-1100, 1070)]},
    {"id": "bajos_este", "name": "Los Bajos", "style": "chabolas", "label": None, "color": (196, 170, 140),
     "poly": [(-470, 160), (-200, 160), (-200, 700), (-410, 700)]},
    {"id": "poligono", "name": "Polígono", "style": "naves", "label": (1060, -100), "color": (196, 192, 180),
     "poly": [(720, -430), (1400, -430), (1400, 160), (720, 160)]},
    {"id": "puerto", "name": "Puerto", "style": "muelles", "label": (1200, 820), "color": (180, 192, 200),
     "poly": [(1000, 160), (1400, 160), (1400, 1150), (620, 1150), (620, 700), (1000, 700)]},
    {"id": "colinas", "name": "Las Colinas", "style": "mansiones", "label": (-1180, -620 + 40), "color": (170, 205, 150),
     "poly": [polar(HILL_CENTER, a, 520, 440) for a in range(0, 360, 15)]},
    {"id": "aeropuerto", "name": "Aeropuerto", "style": "aeropuerto", "label": (2300, 650), "color": (205, 205, 200),
     "poly": [(1600, 60), (3050, 60), (3050, 700), (1600, 700)]},
]

POIS = [
    ("aeropuerto", "Aeropuerto (inicio)", (2100, 470)),
    ("casino", "Casino", (200, 965)),
    ("hoteles", "Hoteles de La Milla", (470, 965)),
    ("club", "Club nocturno", (-180, 965)),
    ("playa", "Playa", (100, 1080)),
    ("banco", "Banco central", (560, 430)),
    ("joyeria", "Joyería", (60, 300)),
    ("catedral", "Catedral y plaza mayor", OLD_TOWN_CENTER),
    ("comisaria", "Comisaría central", (300, -180)),
    ("hospital", "Hospital", (-300, -250)),
    ("armeria", "Armería", (-330, 470)),
    ("pintura", "Taller de pintura", (900, -220)),
    ("desguace", "Desguace", (1270, 40)),
    ("contenedores", "Terminal de contenedores", (1100, 1040)),
    ("estacion", "Estación de tren", (310, -380)),
    ("estadio", "Estadio", (575, -220)),
    ("centro_comercial", "Centro comercial", (880, 420)),
    ("mirador", "Mirador y mansiones", HILL_CENTER),
    ("golf", "Club de golf", (-1200, 330)),
    ("puerto_deportivo", "Puerto deportivo (yates)", (-1165, 1085)),
    ("motel", "Motel", (-760, 640)),
    ("moteros", "Bar de moteros", (-920, 960)),
    ("mercado", "Mercado", (-30, 580)),
    ("cementerio", "Cementerio", (-525, -355)),
    ("parque", "Parque", (200, -5)),
    ("gasolinera", "Gasolinera", (60, -520)),
    ("base", "Base aérea (misión del caza)", (250, -820)),
]

# ================================================================== noding y limpieza del grafo


class Graph:
    def __init__(self) -> None:
        self.pos: list[Vec] = []
        self.edges: dict[tuple[int, int], dict] = {}
        self.keep: set[int] = set()
        self._cell: dict[tuple[int, int], list[int]] = defaultdict(list)

    def node(self, p: Vec, snap: float = 4.0) -> int:
        cx, cz = int(p[0] // 20), int(p[1] // 20)
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for i in self._cell[(cx + dx, cz + dz)]:
                    if dist(self.pos[i], p) < snap:
                        return i
        self.pos.append(p)
        self._cell[(cx, cz)].append(len(self.pos) - 1)
        return len(self.pos) - 1

    def add_edge(self, a: int, b: int, kind: str, source: str, bridge: bool) -> None:
        if a == b:
            return
        key = (min(a, b), max(a, b))
        old = self.edges.get(key)
        if old is None or PRIORITY[kind] > PRIORITY[old["kind"]]:
            self.edges[key] = {"kind": kind, "source": source, "bridge_ok": bridge or (old or {}).get("bridge_ok", False)}

    def adjacency(self) -> dict[int, set[int]]:
        adj: dict[int, set[int]] = defaultdict(set)
        for a, b in self.edges:
            adj[a].add(b)
            adj[b].add(a)
        return adj


def build_graph() -> Graph:
    segs = []
    for pl in polylines:
        pts = pl["pts"]
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            if dist(a, b) > 0.5:
                segs.append({"a": a, "b": b, "pl": pl, "ts": [0.0, 1.0],
                             "first": i == 0, "last": i == len(pts) - 2})
    # cruces (con una rejilla espacial para no comparar todos con todos)
    buckets: dict[tuple[int, int], list[int]] = defaultdict(list)
    for i, s in enumerate(segs):
        x0, x1 = sorted((s["a"][0], s["b"][0]))
        z0, z1 = sorted((s["a"][1], s["b"][1]))
        for cx in range(int(x0 // 100) - 1, int(x1 // 100) + 1):
            for cz in range(int(z0 // 100) - 1, int(z1 // 100) + 1):
                buckets[(cx, cz)].append(i)
    seen = set()
    for idx in buckets.values():
        for ii in range(len(idx)):
            for jj in range(ii + 1, len(idx)):
                i, j = idx[ii], idx[jj]
                if (i, j) in seen:
                    continue
                seen.add((i, j))
                s, r = segs[i], segs[j]
                if s["pl"] is r["pl"] and abs(i - j) == 1:
                    continue
                hit = seg_intersection(s["a"], s["b"], r["a"], r["b"])
                if hit:
                    s["ts"].append(hit[0])
                    r["ts"].append(hit[1])
    g = Graph()
    for s in segs:
        ts = sorted(set(round(t, 6) for t in s["ts"]))
        ids = [g.node(lerp(s["a"], s["b"], t)) for t in ts]
        pl = s["pl"]
        if pl["keep_ends"]:
            if s["first"]:
                g.keep.add(ids[0])
            if s["last"]:
                g.keep.add(ids[-1])
        for a, b in zip(ids, ids[1:]):
            g.add_edge(a, b, pl["kind"], pl["source"], pl["bridge"])
    return g


def contract_short(g: Graph, min_len: float) -> None:
    parent = list(range(len(g.pos)))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for (a, b) in list(g.edges):
        if dist(g.pos[a], g.pos[b]) < min_len:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[rb] = ra
    groups: dict[int, list[int]] = defaultdict(list)
    for i in range(len(g.pos)):
        groups[find(i)].append(i)
    for root, members in groups.items():
        if len(members) > 1:
            xs = sum(g.pos[m][0] for m in members) / len(members)
            zs = sum(g.pos[m][1] for m in members) / len(members)
            g.pos[root] = (xs, zs)
            if any(m in g.keep for m in members):
                g.keep.add(root)
    old = g.edges
    g.edges = {}
    for (a, b), e in old.items():
        g.add_edge(find(a), find(b), e["kind"], e["source"], e["bridge_ok"])


def prune_stubs(g: Graph, max_len: float) -> None:
    while True:
        adj = g.adjacency()
        removed = False
        for (a, b) in list(g.edges):
            for end, other in ((a, b), (b, a)):
                if len(adj[end]) == 1 and end not in g.keep and dist(g.pos[a], g.pos[b]) < max_len:
                    g.edges.pop((a, b), None)
                    removed = True
                    break
        if not removed:
            return


def remove_bad_edges(g: Graph) -> None:
    for key in list(g.edges):
        a, b = g.pos[key[0]], g.pos[key[1]]
        e = g.edges[key]
        mid = lerp(a, b, 0.5)
        crosses_river = crosses_line(a, b, RIVER)
        e["bridge"] = crosses_river
        bad = crosses_river and not e["bridge_ok"]
        bad = bad or (not point_in_poly(mid, COAST) and e["kind"] != "muelle" and not any(point_in_poly(mid, p) for p in PIERS))
        for zone_id, zone in NO_ROADS.items():
            if e["source"] in ("aeropuerto", "aeropuerto_av", "autovia") and zone_id == "aeropuerto":
                continue
            if e["source"] == "granvia" and zone_id == "base_aerea":
                continue
            if point_in_poly(mid, zone) or point_in_poly(a, zone) and point_in_poly(b, zone):
                bad = True
        if any(crosses_line(a, b, r + [r[0]]) for r in (RUNWAY, TAXIWAY)):
            bad = True
        if bad:
            del g.edges[key]


def drop_random(g: Graph, source: str, chance: float) -> None:
    """Quita algunos tramos de un barrio (callejones cortados), sin dejar cruces aislados."""
    adj = g.adjacency()
    for key in list(g.edges):
        e = g.edges[key]
        a, b = key
        if e["source"] == source and rng.random() < chance and len(adj[a]) > 2 and len(adj[b]) > 2:
            del g.edges[key]
            adj[a].discard(b)
            adj[b].discard(a)


def largest_component(g: Graph) -> None:
    adj = g.adjacency()
    best: set[int] = set()
    seen: set[int] = set()
    for start in adj:
        if start in seen:
            continue
        comp = {start}
        stack = [start]
        while stack:
            n = stack.pop()
            for m in adj[n]:
                if m not in comp:
                    comp.add(m)
                    stack.append(m)
        seen |= comp
        if len(comp) > len(best):
            best = comp
    g.edges = {k: e for k, e in g.edges.items() if k[0] in best and k[1] in best}


def compact(g: Graph) -> tuple[list[list[float]], list[dict]]:
    used = sorted({i for k in g.edges for i in k})
    remap = {old: new for new, old in enumerate(used)}
    nodes = [[round(g.pos[i][0], 1), round(g.pos[i][1], 1)] for i in used]
    roads = [{"a": remap[a], "b": remap[b], "type": e["kind"], "district": e["source"], "bridge": e["bridge"]}
             for (a, b), e in sorted(g.edges.items())]
    return nodes, roads


# ================================================================== edificios

# Por estilo de barrio: (ancho, fondo, alto, retranqueo, hueco entre edificios, tipo).
# El ancho va a lo largo de la calle y el fondo hacia dentro de la manzana.
BUILDING_STYLES = {
    "casco_antiguo": ((7, 13), (10, 15), (8, 15), 0.3, 0.0, "casa"),
    "bloques": ((16, 28), (14, 20), (14, 26), 0.5, 1.0, "bloque"),
    "rascacielos": ((20, 32), (20, 30), (35, 130), 2.0, 5.0, "torre"),
    "ocio": ((22, 38), (18, 28), (14, 45), 3.0, 4.0, "hotel"),
    "chabolas": ((5, 9), (5, 8), (2.8, 4.5), 0.5, 0.8, "chabola"),
    "naves": ((30, 60), (25, 45), (8, 14), 8.0, 8.0, "nave"),
    "muelles": ((30, 55), (20, 35), (9, 14), 6.0, 10.0, "nave"),
    "mansiones": ((16, 24), (12, 18), (6, 8), 12.0, 22.0, "mansion"),
    "campo": ((9, 13), (8, 11), (5, 7), 14.0, 200.0, "casa_campo"),
}
FINANCIAL_CORE: Vec = (560.0, 430.0)

# Edificios singulares: (id, tipo, ancho, fondo, cerca de).
LANDMARKS = [
    ("catedral", "catedral", 26, 44, OLD_TOWN_CENTER),
    ("casino", "casino", 56, 40, (200, 965)),
    ("hotel_1", "hotel_alto", 34, 26, (470, 965)),
    ("hotel_2", "hotel_alto", 30, 24, (-180, 965)),
    ("hospital", "hospital", 60, 34, (-300, -250)),
    ("comisaria", "comisaria", 40, 28, (300, -180)),
    ("banco", "banco", 34, 34, (560, 430)),
    ("estacion", "estacion", 70, 24, (310, -395)),
    ("centro_comercial", "centro_comercial", 52, 40, (880, 420)),
    ("motel", "motel", 46, 14, (-760, 640)),
    ("gasolinera", "gasolinera", 30, 20, (60, -520)),
    ("mercado", "mercado", 40, 30, (-30, 580)),
    ("grua_1", "grua", 30, 16, (760, 1135)),
    ("grua_2", "grua", 30, 16, (900, 1138)),
    ("grua_3", "grua", 30, 16, (1100, 1140)),
    ("grua_4", "grua", 30, 16, (1290, 1140)),
]


def rect_corners(c: Vec, yaw_dir: Vec, w: float, d: float) -> list[Vec]:
    ux, uz = yaw_dir
    vx, vz = -uz, ux
    hw, hd = w / 2, d / 2
    return [(c[0] + ux * sx * hw + vx * sz * hd, c[1] + uz * sx * hw + vz * sz * hd)
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def rects_overlap(a: list[Vec], b: list[Vec]) -> bool:
    for poly in (a, b):
        for i in range(4):
            p, q = poly[i], poly[(i + 1) % 4]
            ax, az = -(q[1] - p[1]), q[0] - p[0]
            pa = [x * ax + z * az for x, z in a]
            pb = [x * ax + z * az for x, z in b]
            if max(pa) < min(pb) or max(pb) < min(pa):
                return False
    return True


def river_polygon() -> list[Vec]:
    left, right = [], []
    half = RIVER_WIDTH / 2 + 4
    for i, p in enumerate(RIVER):
        prev, nxt = RIVER[max(i - 1, 0)], RIVER[min(i + 1, len(RIVER) - 1)]
        dx, dz = nxt[0] - prev[0], nxt[1] - prev[1]
        ln = math.hypot(dx, dz)
        nx, nz = -dz / ln, dx / ln
        left.append((p[0] + nx * half, p[1] + nz * half))
        right.append((p[0] - nx * half, p[1] - nz * half))
    return left + right[::-1]


class Placer:
    """Coloca rectángulos sin pisar calles, agua, zonas reservadas ni otros edificios."""

    def __init__(self, nodes, roads) -> None:
        self.nodes = nodes
        self.roads = roads
        self.road_cells: dict[tuple[int, int], list[int]] = defaultdict(list)
        for i, r in enumerate(roads):
            a, b = nodes[r["a"]], nodes[r["b"]]
            n = max(1, int(dist(a, b) // 25))
            for s in range(n + 1):
                p = lerp(a, b, s / n)
                cell = (int(p[0] // 50), int(p[1] // 50))
                if i not in self.road_cells[cell]:
                    self.road_cells[cell].append(i)
        self.placed: dict[tuple[int, int], list[list[Vec]]] = defaultdict(list)
        self.river = river_polygon()

    def clearance(self, p: Vec) -> float:
        best = 1e9
        cx, cz = int(p[0] // 50), int(p[1] // 50)
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for i in self.road_cells.get((cx + dx, cz + dz), ()):
                    r = self.roads[i]
                    d = seg_point_dist(p, self.nodes[r["a"]], self.nodes[r["b"]]) - ROAD_WIDTH[r["type"]] / 2 - SIDEWALK
                    best = min(best, d)
        return best

    def free(self, corners: list[Vec], margin: float = 0.3) -> bool:
        pts = corners + [lerp(corners[i], corners[(i + 1) % 4], 0.5) for i in range(4)] + [lerp(corners[0], corners[2], 0.5)]
        for p in pts:
            if self.clearance(p) < margin:
                return False
            if not point_in_poly(p, COAST) or point_in_poly(p, self.river) or point_in_poly(p, BEACH):
                return False
            if any(point_in_poly(p, z) for z in NO_ROADS.values()):
                return False
        for i in range(4):  # que ningún lado cruce una calle (rectángulos grandes)
            a, b = corners[i], corners[(i + 1) % 4]
            cx, cz = int(a[0] // 50), int(a[1] // 50)
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for k in self.road_cells.get((cx + dx, cz + dz), ()):
                        r = self.roads[k]
                        if seg_intersection(a, b, self.nodes[r["a"]], self.nodes[r["b"]], 0.0):
                            return False
        c = lerp(corners[0], corners[2], 0.5)
        cell = (int(c[0] // 60), int(c[1] // 60))
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for other in self.placed.get((cell[0] + dx, cell[1] + dz), ()):
                    if rects_overlap(corners, other):
                        return False
        return True

    def take(self, corners: list[Vec]) -> None:
        c = lerp(corners[0], corners[2], 0.5)
        self.placed[(int(c[0] // 60), int(c[1] // 60))].append(corners)


def style_at(p: Vec) -> str | None:
    for d in DISTRICTS:
        if point_in_poly(p, d["poly"]):
            return d["style"]
    return None


def place_landmarks(pl: Placer) -> list[dict]:
    """Edificios singulares: busca en espiral el primer hueco libre cerca de su sitio."""
    out = []
    for lid, kind, w, d, near in LANDMARKS:
        done = False
        for ring in range(0, 16):
            steps = max(1, ring * 6)
            for k in range(steps):
                a = 2 * math.pi * k / steps
                c = (near[0] + math.cos(a) * ring * 8, near[1] + math.sin(a) * ring * 8)
                for yaw in (0.0, math.pi / 2, math.radians(28), math.radians(-12)):
                    u = (math.cos(yaw), math.sin(yaw))
                    corners = rect_corners(c, u, w, d)
                    if pl.free(corners, 0.5):
                        pl.take(corners)
                        out.append({"id": lid, "kind": kind, "x": round(c[0], 1), "z": round(c[1], 1),
                                    "yaw": round(-yaw, 4), "w": w, "d": d})  # yaw de Godot
                        done = True
                        break
                if done:
                    break
            if done:
                break
        if not done:
            print(f"AVISO: no cabe el edificio singular {lid}")
    return out


def place_buildings(pl: Placer) -> list[list]:
    """Edificios a lo largo de cada calle, a ambos lados, con las medidas de su barrio."""
    out = []
    order = sorted(range(len(pl.roads)), key=lambda i: -PRIORITY[pl.roads[i]["type"]])
    for i in order:
        r = pl.roads[i]
        if r["type"] in ("autovia", "muelle") or r["bridge"]:
            continue
        a, b = pl.nodes[r["a"]], pl.nodes[r["b"]]
        length = dist(a, b)
        if length < 20:
            continue
        u = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        n = (-u[1], u[0])
        half = ROAD_WIDTH[r["type"]] / 2 + SIDEWALK
        for side in (1, -1):
            t = 6.0
            while t < length - 6.0:
                probe = (a[0] + u[0] * t + n[0] * side * (half + 6), a[1] + u[1] * t + n[1] * side * (half + 6))
                style = style_at(probe)
                if style is None and point_in_poly(probe, COAST) and rng.random() < 0.02:
                    style = "campo"
                if style not in BUILDING_STYLES:
                    t += 10
                    continue
                (w0, w1), (d0, d1), (h0, h1), setback, gap, kind = BUILDING_STYLES[style]
                w, d = rng.uniform(w0, w1), rng.uniform(d0, d1)
                h = rng.uniform(h0, h1)
                if style == "rascacielos":
                    k = max(0.0, 1.0 - dist(probe, FINANCIAL_CORE) / 450)
                    h = h0 + (h1 - h0) * k * rng.uniform(0.55, 1.0)
                if style == "chabolas" and rng.random() < 0.12:
                    w, d, h, kind = rng.uniform(14, 20), rng.uniform(12, 16), rng.uniform(10, 18), "bloque_pobre"
                if style == "naves" and rng.random() < 0.3:
                    kind = "almacen"
                if t + w > length - 4:
                    break
                off = half + setback + d / 2
                c = (a[0] + u[0] * (t + w / 2) + n[0] * side * off, a[1] + u[1] * (t + w / 2) + n[1] * side * off)
                corners = rect_corners(c, u, w, d)
                if pl.free(corners):
                    pl.take(corners)
                    # yaw: el eje local X va a lo largo de la calle y la fachada (-Z local) mira a la calle
                    face = (-n[0] * side, -n[1] * side)
                    yaw = math.atan2(-face[0], -face[1])
                    out.append([round(c[0], 1), round(c[1], 1), round(yaw, 3), round(w, 1), round(d, 1), round(h, 1),
                                kind, rng.randrange(100)])
                    t += w + gap
                else:
                    t += 3.0
    return out


# ================================================================== salida


def to_list(poly):
    return [[float(x), float(z)] for x, z in poly]


def infill_slums(pl: Placer, tries: int) -> list[list]:
    """Chabolas también dentro de las manzanas de Los Bajos (no solo mirando a la calle)."""
    out = []
    polys = [d["poly"] for d in DISTRICTS if d["style"] == "chabolas"]
    for _ in range(tries):
        poly = rng.choice(polys)
        xs = [p[0] for p in poly]
        zs = [p[1] for p in poly]
        c = (rng.uniform(min(xs), max(xs)), rng.uniform(min(zs), max(zs)))
        if not point_in_poly(c, poly):
            continue
        w, d, h = rng.uniform(5, 9), rng.uniform(5, 8), rng.uniform(2.8, 4.2)
        yaw = math.radians(rng.choice((-9, 8)) + rng.uniform(-6, 6))
        corners = rect_corners(c, (math.cos(yaw), math.sin(yaw)), w, d)
        if pl.free(corners, 1.0):
            pl.take(corners)
            out.append([round(c[0], 1), round(c[1], 1), round(-yaw, 3), round(w, 1), round(d, 1), round(h, 1),
                        "chabola", rng.randrange(100)])
    return out


def place_containers(pl: Placer) -> list[list]:
    """Pilas de contenedores en los patios libres del puerto: [x, z, yaw, pisos, variante]."""
    out = []
    yaw = math.radians(-12)
    u = (math.cos(yaw), math.sin(yaw))
    v = (-u[1], u[0])
    port = next(d["poly"] for d in DISTRICTS if d["id"] == "puerto")
    for i in range(-40, 40):
        for j in range(-80, 80):
            c = (1000 + u[0] * i * 14.0 + v[0] * j * 3.4, 950 + u[1] * i * 14.0 + v[1] * j * 3.4)
            if c[1] < 760 or not point_in_poly(c, port):
                continue
            corners = rect_corners(c, u, 12.6, 2.9)
            if pl.free(corners, 1.5):
                pl.take(corners)
                out.append([round(c[0], 1), round(c[1], 1), round(-yaw, 3), rng.choice((1, 2, 2, 3, 3, 4)), rng.randrange(100)])
    return out


def write_json(nodes, roads, buildings, landmarks, containers) -> None:
    data = {
        "version": 2,
        "note": "Generado por tools/map/layout.py; no editar a mano.",
        "road_width": ROAD_WIDTH,
        "sidewalk": SIDEWALK,
        "player_start": [PLAYER_START[0], PLAYER_START[1]],
        "nodes": nodes,
        "roads": roads,
        "river": {"line": to_list(RIVER), "width": RIVER_WIDTH},
        "island": to_list(COAST),
        "islets": ISLETS,
        "beach": to_list(BEACH),
        "piers": [to_list(p) for p in PIERS],
        "hills": HILLS,
        "railway": to_list(RAILWAY),
        "districts": [{"id": d["id"], "name": d["name"], "style": d["style"], "poly": to_list(d["poly"])} for d in DISTRICTS],
        "zones": {k: to_list(v) for k, v in NO_ROADS.items()},
        "airport": {"runway": to_list(RUNWAY), "taxiway": to_list(TAXIWAY), "apron": to_list(APRON),
                    "terminal": to_list(TERMINAL), "parking": to_list(PARKING)},
        "pois": [{"id": i, "name": n, "pos": [float(p[0]), float(p[1])]} for i, n, p in POIS],
        "landmarks": landmarks,
        "buildings_format": ["x", "z", "yaw", "ancho", "fondo", "alto", "tipo", "variante"],
        "buildings": buildings,
        "containers_format": ["x", "z", "yaw", "pisos", "variante"],
        "containers": containers,
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")


BUILDINGS: list[list] = []
CONTAINERS: list[list] = []
LANDMARK_LIST: list[dict] = []


def render(path: Path, nodes, roads, x0: float, x1: float, z0: float, z1: float, k: float, title: str) -> None:
    from PIL import Image, ImageDraw, ImageFont

    margin = 18
    legend_w = 330
    w = int((x1 - x0) * k) + margin * 2
    h = max(int((z1 - z0) * k) + margin * 2, 900)

    def P(x: float, z: float) -> tuple[float, float]:
        return (margin + (x - x0) * k, margin + (z - z0) * k)

    def font(size: int, bold: bool = False):
        for name in (["arialbd.ttf", "DejaVuSans-Bold.ttf"] if bold else ["arial.ttf", "DejaVuSans.ttf"]):
            try:
                return ImageFont.truetype(name, size)
            except OSError:
                continue
        return ImageFont.load_default()

    img = Image.new("RGB", (w, h), (92, 150, 200))
    d = ImageDraw.Draw(img)
    d.polygon([P(x, z) for x, z in COAST], fill=(214, 204, 160))  # arena de la orilla
    shore = [(x + (0 if z > 1090 else 0), z) for x, z in COAST]
    d.line([P(x, z) for x, z in shore + [shore[0]]], fill=(214, 204, 160), width=max(3, int(18 * k)))
    d.polygon([P(x, z) for x, z in COAST], fill=(178, 198, 142))
    d.line([P(x, z) for x, z in COAST + [COAST[0]]], fill=(222, 210, 165), width=max(2, int(12 * k)))
    # relieve de la colina (anillos más oscuros)
    hc = HILLS[0]
    for i in range(8, 0, -1):
        r = hc["radius"] * i / 8
        shade = 178 - (8 - i) * 7
        d.ellipse([P(hc["center"][0] - r, hc["center"][1] - r * 0.85), P(hc["center"][0] + r, hc["center"][1] + r * 0.85)],
                  fill=(shade - 20, shade, shade - 45))
    for dist_ in DISTRICTS:
        if dist_["id"] != "colinas":
            d.polygon([P(x, z) for x, z in dist_["poly"]], fill=dist_["color"])
    zone_col = {"estadio": (150, 190, 120), "cementerio": (150, 165, 140), "parque": (120, 172, 100), "golf": (110, 180, 95),
                "aeropuerto": (200, 200, 196), "base_aerea": (150, 150, 150)}
    for zid, poly in NO_ROADS.items():
        d.polygon([P(x, z) for x, z in poly], fill=zone_col[zid])
    d.ellipse([P(445 + 0, -275), P(705, -165)], outline=(240, 240, 240), width=2)  # pista del estadio
    d.rectangle([P(-330, -1220), P(330, -1180)], fill=(60, 60, 66))
    for hx in (160, 250):
        d.rectangle([P(hx - 35, -1068), P(hx + 35, -1032)], fill=(110, 116, 110))
    for poly, col in ((RUNWAY, (55, 55, 60)), (TAXIWAY, (90, 90, 95)), (APRON, (150, 150, 150)), (TERMINAL, (90, 110, 140)),
                      (PARKING, (120, 120, 120))):
        d.polygon([P(x, z) for x, z in poly], fill=col)
    d.polygon([P(x, z) for x, z in BEACH], fill=(236, 216, 160))
    for p in PIERS:
        d.polygon([P(x, z) for x, z in p], fill=(170, 170, 160))
    d.line([P(x, z) for x, z in RIVER], fill=(92, 150, 200), width=max(2, int(RIVER_WIDTH * k)), joint="curve")
    # vía del tren (discontinua)
    for a, b in zip(RAILWAY, RAILWAY[1:]):
        n = int(dist(a, b) // 30)
        for i in range(0, n, 2):
            d.line([P(*lerp(a, b, i / n)), P(*lerp(a, b, (i + 1) / n))], fill=(90, 70, 60), width=max(2, int(5 * k)))

    order = ["callejon", "muelle", "calle", "avenida", "autovia"]
    for pass_ in (0, 1):
        for kind in order:
            for r in roads:
                if r["type"] != kind:
                    continue
                a, b = P(*nodes[r["a"]]), P(*nodes[r["b"]])
                if pass_ == 0:
                    width = (ROAD_WIDTH[kind] + 2 * SIDEWALK) * k
                    d.line([a, b], fill=(150, 105, 65) if r["bridge"] else (190, 190, 184), width=max(2, int(width) + 2))
                else:
                    col = {"autovia": (236, 160, 55), "avenida": (252, 248, 236)}.get(kind, (240, 240, 234))
                    d.line([a, b], fill=col, width=max(1, int(ROAD_WIDTH[kind] * k)))

    for b in BUILDINGS:  # yaw de Godot: el eje X local apunta a (cos yaw, -sin yaw)
        cs = rect_corners((b[0], b[1]), (math.cos(b[2]), -math.sin(b[2])), b[3], b[4])
        shade = max(60, 150 - int(b[5]))
        d.polygon([P(x, z) for x, z in cs], fill=(shade, shade - 6, shade - 12))
    for c in CONTAINERS:
        cs = rect_corners((c[0], c[1]), (math.cos(c[2]), -math.sin(c[2])), 12.2, 2.5)
        d.polygon([P(x, z) for x, z in cs], fill=(150, 80, 60))
    for lm in LANDMARK_LIST:
        cs = rect_corners((lm["x"], lm["z"]), (math.cos(lm["yaw"]), -math.sin(lm["yaw"])), lm["w"], lm["d"])
        d.polygon([P(x, z) for x, z in cs], fill=(150, 40, 40))
    f_dist = font(int(13 + 14 * min(1.0, k / 0.5)), True)
    for dist_ in DISTRICTS:
        if not dist_["label"]:
            continue
        cx, cz = P(*dist_["label"])
        text = dist_["name"].upper()
        tw = d.textlength(text, font=f_dist)
        for ox, oz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            d.text((cx - tw / 2 + ox, cz - 10 + oz), text, font=f_dist, fill=(255, 255, 255))
        d.text((cx - tw / 2, cz - 10), text, font=f_dist, fill=(45, 45, 60))
    f_small = font(13, True)
    for text, (x, z) in [("BASE AÉREA", (0, -1000)), ("MAR", (900, 1300)), ("MAR", (-1000, -1700)), ("RÍO", (-700, -560)), ("vía del tren", (1900, -395))]:
        if x0 < x < x1 and z0 < z < z1:
            cx, cz = P(x, z)
            tw = d.textlength(text, font=f_small)
            d.text((cx - tw / 2, cz - 7), text, font=f_small, fill=(30, 30, 40))

    f_poi = font(11, True)
    for i, (_, _, pos) in enumerate(POIS, start=1):
        if not (x0 < pos[0] < x1 and z0 < pos[1] < z1):
            continue
        cx, cz = P(*pos)
        r = 9
        d.ellipse([cx - r, cz - r, cx + r, cz + r], fill=(205, 40, 40) if i == 1 else (35, 55, 120), outline=(255, 255, 255), width=2)
        t = str(i)
        tw = d.textlength(t, font=f_poi)
        d.text((cx - tw / 2, cz - 6), t, font=f_poi, fill=(255, 255, 255))

    if x1 > 3000:
        cx, cz = P(2700, 1330)
        d.text((cx, cz), "→ isla del aeródromo clandestino\n   (8,7 km al SE)", font=font(14, True), fill=(255, 255, 255))
    sx, sz = margin + 20, h - margin - 30
    d.rectangle([sx, sz, sx + 500 * k, sz + 6], fill=(30, 30, 30))
    d.text((sx, sz + 9), "500 m", font=font(13), fill=(30, 30, 30))
    nx, nz = w - margin - 30, margin + 40
    d.polygon([(nx, nz - 28), (nx - 10, nz), (nx + 10, nz)], fill=(30, 30, 30))
    d.text((nx - 5, nz + 4), "N", font=font(16, True), fill=(30, 30, 30))

    full = Image.new("RGB", (w + legend_w, h), (234, 230, 218))
    full.paste(img, (0, 0))
    img = full
    d = ImageDraw.Draw(img)
    lx = w + 16
    d.text((lx, 18), title, font=font(21, True), fill=(30, 30, 40))
    d.text((lx, 46), "Ciudad: nombre por decidir", font=font(13), fill=(80, 80, 90))
    y = 76
    f_leg = font(13)
    for i, (_, name, _) in enumerate(POIS, start=1):
        d.ellipse([lx, y, lx + 17, y + 17], fill=(205, 40, 40) if i == 1 else (35, 55, 120))
        t = str(i)
        tw = d.textlength(t, font=f_poi)
        d.text((lx + 8.5 - tw / 2, y + 2), t, font=f_poi, fill=(255, 255, 255))
        d.text((lx + 25, y + 1), name, font=f_leg, fill=(30, 30, 40))
        y += 21
    y += 10
    for label, col in [("Autovía", (236, 160, 55)), ("Avenida", (252, 248, 236)), ("Calle / callejón", (240, 240, 234)),
                       ("Puente", (150, 105, 65)), ("Agua", (92, 150, 200)), ("Parque / golf", (115, 176, 98))]:
        d.rectangle([lx, y + 3, lx + 30, y + 14], fill=col, outline=(120, 120, 120))
        d.text((lx + 40, y + 1), label, font=f_leg, fill=(30, 30, 40))
        y += 20
    y += 8
    total = sum(math.dist(nodes[r["a"]], nodes[r["b"]]) for r in roads)
    for s in [f"Calles: {total / 1000:.1f} km, {len(nodes)} cruces",
              f"Puentes: {sum(1 for r in roads if r['bridge'])} tramos"]:
        d.text((lx, y), s, font=f_leg, fill=(30, 30, 40))
        y += 19
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def main() -> None:
    COAST.extend(make_coast())
    build_old_town()
    build_districts()
    build_arterials()
    g = build_graph()
    contract_short(g, 14.0)
    prune_stubs(g, 40.0)
    remove_bad_edges(g)
    prune_stubs(g, 40.0)
    drop_random(g, "bajos", 0.16)
    drop_random(g, "casco", 0.08)
    prune_stubs(g, 40.0)
    largest_component(g)
    nodes, roads = compact(g)
    pl = Placer(nodes, roads)
    landmarks = place_landmarks(pl)
    buildings = place_buildings(pl)
    buildings += infill_slums(pl, 6000)
    containers = place_containers(pl)
    write_json(nodes, roads, buildings, landmarks, containers)
    CONTAINERS.extend(containers)
    BUILDINGS.extend(buildings)
    LANDMARK_LIST.extend(landmarks)
    render(OUT_PNG, nodes, roads, -2350, 3600, -1850, 1450, 0.28, "Plano provisional")
    render(OUT_PNG_CITY, nodes, roads, -1900, 1500, -720, 1260, 0.5, "Plano de la ciudad")
    print(f"{len(nodes)} cruces, {len(roads)} tramos, {sum(1 for r in roads if r['bridge'])} tramos de puente, "
          f"{len(buildings)} edificios, {len(landmarks)} singulares, {len(containers)} pilas de contenedores")


if __name__ == "__main__":
    main()
