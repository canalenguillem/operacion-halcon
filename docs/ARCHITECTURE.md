# Arquitectura — Operación Halcón

Describe el juego tal como está; los cambios previstos están en `docs/ROADMAP.md`.

## Escena

`main.tscn` es un único `Node3D` con `scripts/main.gd` (`Main`). Todo lo demás se crea por código:

```
Main (Node3D)                    raíz: crea todo, reparte el input y llama a los sistemas en orden
├── World (Node3D)               cielo, relieve, ciudad, edificios, farolas, árboles, base, aeródromo, haz del objetivo
├── Sfx (Node)                   efectos, bucles y música
├── Effects (Node3D)             trazadoras, explosiones, bengalas
├── Driving (Node)               subir y bajar de vehículos; `vehicle` es el que conduces
├── Combat (Node)                disparo del jugador, daño recibido, bajas y marcas del HUD
├── AirDefense (Node)            baterías antiaéreas y misiles en vuelo
├── HalconMission (Node)         la misión: objetivo, haz de luz y mensajes de `MissionState`
├── GameAudio (Node)             bucles según el juego (motores, alarma, aviso de misil)
├── DevTools (Node)              argumentos de desarrollo (--play, --at, --shot…)
├── Player (CharacterBody3D)
├── Car × 5 (Vehicle)
├── Jet × 2 (Vehicle)
├── Soldier × 18 (CharacterBody3D)
├── Missile (Node3D)             se crean al disparar una batería
├── CameraRig (Camera3D)         orbital a pie y en coche, persecución en el caza, sacudida
├── Gps (Node)                   ruta por las calles al objetivo o al destino marcado
├── DayNight (Node)              hora del juego: sol, luna, cielo, ventanas y luces de farolas
├── CanvasLayer → Hud (Control)  incluye el radar (`Radar`)
├── CanvasLayer (capa 10) → Menu, MapScreen  menús y mapa a pantalla completa
└── LoadingScreen (CanvasLayer)  solo mientras se construye la isla
```
- El norte es **-Z** y el frente de todos los actores también. Un giro (yaw) positivo gira a la izquierda.
- Tipado estático obligatorio: `project.godot` trata `untyped_declaration` como error, así que `./tools/check.sh` falla si falta un tipo.

## Tres piezas por actor

| Actor | Nodo (aplica) | Lógica pura (decide, con tests) | Datos (`.tres`, se ajustan en el editor) |
|---|---|---|---|
| Jugador | `Player` | `PlayerLogic` | `PlayerData` → `data/player.tres` |
| Coche | `Car` (hereda de `Vehicle`) | `CarLogic` | `CarData` → `data/car.tres` |
| Caza | `Jet` (hereda de `Vehicle`) | `JetLogic` | `JetData` → `data/jet.tres` |
| Soldado | `Soldier` | `SoldierLogic` | `SoldierData` → `data/soldier.tres` |
| Misil y baterías | `Missile` (y `AirDefense`) | `MissileLogic` | `MissileData` → `data/missile.tres` |
| Misión | `HalconMission` | `MissionState` | constantes en `MissionState` |
| Mundo | `World` | funciones estáticas de `World` (`in_base`, `dest_distance`, `clear_spot`) | constantes en `World` |

- `Vehicle` (`scripts/vehicle.gd`) es la base de coche y caza: `is_jet`, `driver`, `dead`, `hp`, `speed`, `enter_range`, `can_exit()`, `hurt()`, `controlled()` y `resolve_bumps()` (atropellos y choques).
- `Build` (`scripts/build.gd`): ayudas estáticas para crear mallas primitivas, materiales (con caché) y colisiones. `Build.extrude` hace un prisma a partir de un polígono convexo (alas, derivas, perfil del coche, tejados) y `Build.windows_mat` es el material de fachada con ventanas (textura generada, triplanar en coordenadas del mundo, una ventana cada 3 m).
- `Humanoid` (`scripts/humanoid.gd`): muñeco articulado del jugador y de los soldados. `animate(velocidad, dt, apuntando)` balancea piernas y brazos; el ángulo sale de `Humanoid.swing` (con tests).

## Misión

`MissionState` (`RefCounted`, en `Main.mission`) lleva la fase (`Stage`: `GET_CAR → GO_BASE → GET_JET → ESCAPE → WON`), las estrellas (`wanted`), la alarma (`base_alert`) y el final (`over`). `HalconMission` le llama `step(...)` cada fotograma de física con hechos ya calculados (¿vas en vehículo?, ¿en caza?, ¿dentro de la base?, cazas que quedan, distancia al aeródromo) y escucha sus señales (`alert_raised`, `jet_stolen`, `failed(reason)`, `completed`) para mostrar los mensajes. Los actores avisan con `main.mission.raise_alert()` y `main.mission.fail(...)`.

## Sistemas y quién llama a quién

`Main` es la raíz de composición: crea el mundo, los sistemas y los actores y no tiene lógica de juego propia. Cada sistema es un nodo hijo con una referencia `main` y un método `tick(...)` que `Main._physics_process` llama en este orden: `combat` → `driving` → `air_defense` (si la partida sigue) → `halcon` → `camera` → `game_audio` → `dev`. Los sistemas no tienen `_physics_process` propio, así el orden es explícito.

| Campo en `Main` | Clase | Qué hace |
|---|---|---|
| `camera` | `CameraRig` | `yaw`/`pitch`, `orbit(relativo)`, `snap_behind(v)`, `add_shake(x)` |
| `driving` | `Driving` | `vehicle`, `nearby()`, `interact()`, `enter(v)`, `exit()`, `eject(daño)` |
| `combat` | `Combat` | `player_shoot()`, `hurt_target(datos)`, `on_player_hurt()`, `kills`, `hit_t`, `hurt_t` |
| `effects` | `Effects` | `tracer`, `explosion(pos, radio)`, `flares` |
| `air_defense` | `AirDefense` | baterías, `missiles`, `drop_flares`, `nearest_missile()` |
| `halcon` | `HalconMission` | `objective_pos()`, `objective_text()`, mensajes de fin |
| `day_night` | `DayNight` | `hour`, `apply()` (lógica en `DayNightLogic`, datos en `data/day_night.tres`) |
| `gps` | `Gps` | `route`, `set_waypoint(p)`, `clear_waypoint()`, `destination()` (usa `RoadRouter`) |
| `game_audio` | `GameAudio` | bucles de sonido |
| `dev` | `DevTools` | ayudas de desarrollo |

`Main` conserva solo consultas comunes: `vehicle` (atajo a `driving.vehicle`), `game_over`, `elapsed`, `vehicles()`, `target_node()`, `target_pos()`, `heading()`, y las listas `player`, `cars`, `jets`, `soldiers`.

- **Señales hacia arriba:** `MissionState` → `HalconMission` → `Hud`.
- **Llamadas hacia abajo:** `Main` crea los actores y les pasa `main`. Los actores piden efectos y consultas al sistema que toca (`main.effects.explosion`, `main.combat.hurt_target`, `main.driving.eject`, `main.air_defense.drop_flares`…). Es un acoplamiento aceptado mientras haya una sola escena.
- `Main` se ejecuta después de los actores (`process_physics_priority = 10`) para que la cámara vea posiciones ya actualizadas.
- `Hud` lee el estado de `Main` y sus sistemas cada fotograma.

## Día y noche

`DayNight` avanza la hora (un día dura `day_minutes` minutos reales; empieza a `start_hour`) y en cada fotograma ajusta el sol (altura y rumbo), la luna, los colores del cielo y de la niebla, la luz ambiente, el brillo y las ventanas encendidas. De noche, un grupo de `OmniLight3D` (`lamp_lights`) se coloca cada 0,5 s en las farolas más cercanas a la cámara (`World.lamp_positions`); el resto de farolas y los neones solo brillan (material sin luz). El HUD muestra la hora. `--hour=21.5` fija la hora para probar.

## Interfaz

- `UiStyle` (`scripts/ui_style.gd`): colores, fuentes propias (variaciones en negrita y cursiva de la fuente de Godot), iconos dibujados por código (estrella, pistola, coche, avión, flecha, lugares) y el tema de los menús. Sin fuentes ni imágenes externas.
- `Hud` lo dibuja todo en `_draw`: caja de ayuda (consejos y avisos con `flash`), estrellas, arma, tiempo y bajas, salud y vehículo bajo el radar, nombre de la zona y velocímetro (o instrumentos del caza), objetivo como subtítulo, mira dinámica, marca de impacto, indicador de por dónde te disparan (`Combat.hit_from`), aviso de misil y franja de fin de misión (`big`).
- `Radar` (`scripts/radar.gd`): círculo recortado con `clip_children`; gira con la cámara y se aleja con la velocidad. `MapDraw` (`scripts/map_draw.gd`) pinta la isla con una transformación mundo → pantalla; lo comparten el radar y `MapScreen`.
- `MapScreen` (`scripts/map_screen.gd`): mapa a pantalla completa (M o desde la pausa; pausa el juego). Arrastrar/WASD mueve, rueda/± acerca, clic marca destino en `Gps`, clic derecho lo quita.
- `RoadRouter` (`scripts/road_router.gd`, tests en `tests/test_road_router.gd`): A* sobre el grafo de calles con coste por tipo de vía. `Gps` recalcula la ruta cada 0,4 s; en el caza no hay ruta y a pie solo si el destino está a más de 250 m.
- `LoadingScreen`: un consejo al azar mientras `Main._ready` construye la isla (espera dos fotogramas para que se vea; los tests, con `show_menu = false`, no la usan).

## Menús y opciones

- `Menu` (`scripts/menu.gd`) tiene `process_mode = ALWAYS` y es quien pone y quita la pausa del árbol: `open(MAIN | PAUSE)` pausa y suelta el ratón; `close()` reanuda y lo captura. Avisa a `Main` con señales (`play_pressed`, `restart_pressed`, `main_menu_pressed`). La pantalla de controles sale de `Menu.CONTROLS` y lee las teclas del InputMap.
- El menú usa el tema de `UiStyle`: columna a la izquierda sobre un degradado; detrás, `CameraRig.cinematic` sobrevuela la ciudad (su `_process` sigue con el juego en pausa).
- Opciones gráficas en `Settings` (`fullscreen`, `vsync`, `shadows`): `Settings.apply_display()` las aplica a la ventana y `World.apply_graphics()` a las sombras del sol (al cambiar, `Menu.options_changed`).
- `Main` abre el menú principal al arrancar, salvo al reiniciar (`Main.skip_menu`, estático), con argumentos de desarrollo o si `show_menu` es false (tests). Esc durante la partida abre la pausa.
- `Settings` (`scripts/settings.gd`, estático) guarda en `user://settings.cfg` la sensibilidad (`mouse_scale`), la dificultad y el mejor tiempo. La dificultad multiplica el daño de los soldados (`Combat.hurt_target`) y la recarga de las baterías (`AirDefense`).

## Sonido y efectos

- `Sfx` (`scripts/sfx.gd`, `process_mode = ALWAYS`) carga `assets/audio/sfx/*.ogg` y la música. Tres formas de sonar: `play` (sin posición), `play_at` (en un punto del mundo) y `set_loop` (motores, alarma, aviso de misil). `GameAudio.tick` ajusta los bucles cada fotograma; en pausa se detienen solos. Buses `SFX` y `Music` creados por código; `Sfx.apply_volume` aplica los volúmenes de `Settings`.
- Sacudida de cámara: `CameraRig.shake` (lógica en `CameraLogic`) mueve `Camera3D.h_offset`/`v_offset`. La suman las explosiones (según radio y distancia) y el daño al jugador.
- `Effects.explosion(pos, radio)`: bola de fuego y humo siempre; con radio ≥ 3 añade sonido, metralla y sacudida.
- `Vehicle.update_smoke` echa humo por debajo del 40 % de resistencia. `Hud` pinta un fogonazo rojo mientras `Combat.hurt_t` > 0.

## Input

Acciones en `project.godot`: `forward`, `back`, `left`, `right`, `sprint`, `jump`, `shoot`, `interact`, `flare`, `throttle_up`, `throttle_down`, `restart`, `map`. En el caza en tierra, `forward`/`back` son el acelerador; en vuelo, el morro.

## Capas de física (`Layers`)

| Bit | Nombre | Quién está |
|---|---|---|
| 1 | `WORLD` | suelo, edificios, valla, colinas |
| 2 | `PLAYER` | jugador |
| 4 | `VEHICLES` | coches y cazas |
| 8 | `SOLDIERS` | soldados |

Por ahora todos colisionan con todos (`Layers.ALL`). Los rayos (disparos, línea de visión, cámara) excluyen a quien los lanza. Los árboles no tienen colisión.

## Mundo (metros)

El mapa es una **isla** descrita como datos en `data/map/city.json`, que genera `tools/map/layout.py` (Python; también dibuja `docs/map/plano.png` y `docs/map/plano_ciudad.png`). No se edita a mano: se cambia el script y se vuelve a generar.

- `CityMap` (`scripts/city_map.gd`, con tests en `tests/test_city_map.gd`): carga el JSON una vez (`CityMap.get_default()`) y responde consultas: `on_land`, `district_at`, `in_zone`, `road_clearance` (con índice espacial), `poi(id)`, `river_polygon()`. Las calles son un grafo: `nodes` (cruces) y `road_a`/`road_b`/`road_type`/`road_bridge`.
- `Terrain` (`scripts/terrain.gd`, tests en `tests/test_terrain.gd`): relieve en una rejilla de 10 m. Colinas en campana (`hill_height`), con las carreteras allanadas como bancales (`ground_height`); la tierra se ensancha 7 m hacia el agua para que la pendiente de la orilla quede fuera de calles y barrios. Malla con colores por vértice (hierba, arena, golf, tierra en laderas) y colisión `HeightMapShape3D`. `surface(p)` es la altura a la que se apoya todo lo demás (0 en el llano).
- `CityBuilder` (`scripts/city_builder.gd`): islotes (llanos, con borde y colisión), agua a y = -1 y fondo a y = -2,2. Todo lo plano (suelo de barrios, aceras, calzadas, cruces, pasos de cebra, marcas, pista del aeropuerto) va en **una sola malla** con colores por vértice, apoyada en el relieve (en la colina las bandas se trocean cada 6 m). Los puentes son cajas con colisión y barandillas, siempre horizontales.
- `BuildingsBuilder` (`scripts/buildings_builder.gd`): los ~2900 edificios de `city.json` (colocados por `layout.py` a lo largo de las calles, con medidas según el barrio) con `MultiMesh`: una llamada de dibujo por pieza (cuerpo con fachada de ventanas, cristal o lisa —`Build.facade_mat`, teñida por instancia—, tejados, máquinas de azotea, neones, piscinas, puertas). Cada edificio tiene su caja de colisión. Los singulares (catedral, casino, hoteles, hospital, comisaría, banco, estación, centro comercial, motel, gasolinera, mercado) son piezas sueltas con rótulos `Label3D`.
- Fachadas: `shaders/facade.gdshader` (textura de ventanas o de muro cortina en coordenadas del mundo, teñida por el color de cada instancia; de noche brillan solo las ventanas encendidas, uniforme `night`). `Build.facade_mat(kind)` da el material compartido y `Build.set_night(x)` lo enciende.
- Puerto: pilas de contenedores (`CityMap.c_*`, colocadas por `layout.py` en los patios libres) y cuatro grúas pórtico (edificios singulares).
- `StreetFurniture` (`scripts/street_furniture.gd`): farolas (cada 32 m; a ambos lados en avenidas) y semáforos en los cruces grandes, con `MultiMesh` y sin colisión por ahora.
- `World` lo orquesta (`terrain`, ciudad, edificios, mobiliario) y añade cielo, árboles (`clear_spot`), nubes, base aérea, baterías y el islote del aeródromo.
- Rendimiento medido con `--fps` (RTX 3050 portátil): 120-145 fps en el centro y volando, menos de 300 llamadas de dibujo.
- El minimapa (`Hud.MiniMap`) pinta la isla, el río y las calles de `CityMap`.

| Qué | Dónde |
|---|---|
| Isla | x de -2300 a 3500, z de -1700 a 1160 (costa sur fija: playa y puerto) |
| Casco viejo (centro) | círculo de 300 m alrededor de (-30, 380) |
| Salida del jugador | aeropuerto civil, (2100, 470); coches en el aparcamiento |
| Base aérea | x de -350 a 350, z de -1300 a -700; puerta en (0, -700), unida a la Gran Vía |
| Pista de la base | z = -1200, de x = -330 a 330; cazas en (160, -1130) y (250, -1130) mirando al norte |
| Baterías | 3 en la base, 2 en la ruta (una en la isla, otra en un islote) |
| Aeródromo de destino | islote en (6000, 5000) |

## Tests

- Lógica pura: un `tests/test_*_logic.gd` por clase, más `test_mission_state.gd`, `test_world.gd`, `test_city_map.gd`, `test_terrain.gd` y `test_humanoid.gd`.
- Integración: `tests/test_shooting.gd` carga `main.tscn` (con `show_menu = false`) y dispara de verdad a los soldados.
- `./tools/check.sh` además arranca el menú, la misión y la pausa, y comprueba que el caza despega solo con W.

## Publicación

- `./tools/export.sh` genera en `build/` los paquetes de Linux (`.tar.gz`), Windows (`.zip`) y macOS (`.zip` con la app universal, sin firmar ni notarizar) y `manifest.json` (versión, tamaños y SHA-256).
- `web/` es una web estática (portada, controles, instrucciones y descargas) servida por nginx: sin cuentas ni cookies. `app.js` lee `downloads/manifest.json` y `/api/stats`.
- Contador de descargas (`web/counter/counter.py`, Python sin dependencias, SQLite en el volumen `counter-data`): los botones van a `/api/download/<windows|macos|linux>`, que suma uno por sistema y versión y entrega el archivo con `X-Accel-Redirect`; `/downloads/` directo da 404. No cuenta las reanudaciones (`Range` que no empieza en 0). Solo guarda números: ni IP ni datos personales. `/api/stats` da los totales y el desglose por versión. Pruebas: `web/counter/test_counter.py` (las lanza `check.sh`).
- `./web/deploy.sh` copia los paquetes a `web/site/downloads/` y sincroniza `web/` con el servidor indicado en `web/.deploy.env` (`HOST` y `DIR`; no se sube al repositorio). El puerto y la subred se fijan en el `.env` de esa carpeta del servidor (`HALCON_PORT`, `HALCON_SUBNET`). El dominio y el HTTPS los gestiona el humano en su proxy.
- El juego usa Forward+ (Vulkan); en equipos sin Vulkan Godot cae a OpenGL 3.3.

## Deuda

- Medidas de los modelos (cajas, colores) como literales en cada actor.
