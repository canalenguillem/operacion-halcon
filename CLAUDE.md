# Operación Halcón (carpeta `mini-gta`, nombre provisional)

Juego de acción **3D en tercera persona** de una sola misión: robar un coche, colarse en una base aérea, robar un caza y huir de los misiles hasta un aeródromo clandestino. Juego original: la idea de la misión viene de un vídeo, pero no se copian nombre, personajes, mapa ni arte de ningún juego existente.

> **Estado:** M0–M7 hechos y validados jugando, salvo el arte nuevo de M7 (primitivas mejoradas), pendiente de que el humano lo mire. Lo siguiente está sin decidir. Ver `docs/ROADMAP.md`.

## Stack

- **Godot 4.7.x stable**. Prohibidas las APIs de Godot 3.
- **GDScript con tipado estático** en todo. `project.godot` trata `untyped_declaration` como error: sin tipo no compila.
- **3D**, Forward+. Resolución base 1280×720, `stretch/mode = canvas_items`, `stretch/aspect = expand`.
- Arte 100 % propio, sin packs externos: primitivas por código (`scripts/build.gd`) y modelos/texturas hechos por Claude con las herramientas del equipo (Blender 4.2 por script, GIMP, Python). Audio en `assets/audio/` (ver `docs/CREDITS.md`).
- Tests con **GUT 9.x** en `addons/gut`.
- Plataforma: escritorio (se desarrolla en Linux y en Windows). En Windows: `GODOT=/c/Users/Toni/Godot/Godot_v4.7.2-stable_win64_console.exe ./tools/check.sh` desde Git Bash.

## Documentación (léela antes de cualquier tarea grande)

- `docs/GDD.md`: qué es el juego (diseño, reglas, números).
- `docs/ARCHITECTURE.md`: cómo está construido.
- `docs/ROADMAP.md`: hitos. **Trabaja solo en el hito actual** y marca las casillas al terminarlas.

## Comandos

```bash
./tools/check.sh                                        # verificación completa (importa, carga todo, arranca la misión, tests)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --path .                                          # jugar (necesita pantalla)
godot --path . -- --play                                # jugar sin pasar por el menú
godot --path . -- --at=150,0.2,-1110 --yaw=90           # empezar a pie en esa posición (x,y,z); --yaw gira la cámara (grados)
godot --path . -- --test-jet                            # empezar volando
godot --path . -- --test-takeoff                        # despegue automático (imprime el estado cada segundo)
godot --path . -- --menu | --pause | --controls | --options | --map   # abrir directamente esa pantalla
godot --path . -- --shot=/ruta/captura.png              # se combina con los anteriores: captura a los 2,5 s y sale
godot --path . -- --fps                                 # imprime fps y llamadas de dibujo cada segundo
godot --path . -- --hour=22 --cine=250,500,700,220      # hora del día y vista aérea girando (x,z,radio,altura)
./tools/export.sh                                       # ejecutables de Linux, Windows y macOS en build/ (necesita las plantillas de exportación)
./web/deploy.sh                                         # publica la web y las descargas en el servidor de web/.deploy.env (antes: ./tools/export.sh)
```

## Estructura

```
project.godot
main.tscn          # un Node3D con scripts/main.gd; todo lo demás se crea por código
scripts/           # main (raíz) y sistemas: camera_rig, driving, combat, effects, air_defense, halcon_mission, gps, game_audio, dev_tools
                   # interfaz: ui_style, hud, radar, map_draw, map_screen, road_router, loading_screen
                   # world, city_map (datos de la isla), terrain (relieve), city_builder, buildings_builder, street_furniture, hud, menu, settings, sfx, camera_logic, build, humanoid, layers, mission_state, vehicle
                   # y por actor: <actor>.gd, <actor>_logic.gd, <actor>_data.gd (player, car, jet, soldier, missile)
data/              # player.tres, car.tres, jet.tres, soldier.tres, missile.tres, day_night.tres; map/city.json (generado)
shaders/           # facade.gdshader (fachadas con ventanas que se encienden de noche)
assets/audio/      # sfx/*.ogg, music/mission.ogg
tests/             # test_*.gd (GUT)
docs/
tools/             # check.sh, load_all.gd, export.sh; map/layout.py (genera el mapa: python tools/map/layout.py)
web/               # web de descargas: site/, counter/ (contador), nginx.conf, docker-compose.yml, deploy.sh
```

## Convenciones

Las mismas que `../mini-futbol-kit` y `../mini-bolidos-kit`:

- Archivos, funciones y variables en `snake_case`; `class_name` y nodos en `PascalCase`.
- **Señales hacia arriba, llamadas hacia abajo.**
- **Los datos no van en el código.** Los valores de ajuste son `@export` o Resources `.tres`.
- El input va siempre por acciones del InputMap, nunca por teclas directas.
- Cada actor tiene tres piezas: nodo (`car.gd`), lógica pura con tests GUT (`car_logic.gd`) y datos (`car_data.gd` + `data/car.tres`). Ver ARCHITECTURE.
- Comentarios y mensajes de commit en español; identificadores en inglés.
- Al editar `.tscn`/`.tres` como texto: no inventes `uid`, no toques `.godot/` ni `.import`.

## Flujo de trabajo

1. Lee el hito actual en `docs/ROADMAP.md`.
2. Avanza en pasos pequeños y ejecuta `./tools/check.sh` tras cada uno.
3. Lo que solo se puede juzgar jugando (sensación de control, vuelo, dificultad) **no lo des por bueno tú**. Deja al humano una lista corta de qué probar y qué valores ajustar.
4. No empieces un hito hasta que el humano haya validado el anterior.
5. Commits pequeños con mensajes descriptivos.
