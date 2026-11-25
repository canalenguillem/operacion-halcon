# Arquitectura — Operación Halcón

Describe el juego tal como está; los cambios previstos están en `docs/ROADMAP.md`.

## Escena

`main.tscn` es un único `Node3D` con `scripts/main.gd` (`Main`). Todo lo demás se crea por código:

```
Main (Node3D)                    une mundo, actores, misión, cámara y efectos
├── World (Node3D)               cielo, suelo, árboles, colinas, ciudad, base, aeródromo, haz del objetivo
├── Sfx (Node)                   efectos, bucles y música
├── Player (CharacterBody3D)
├── Car × 5 (Vehicle)
├── Jet × 2 (Vehicle)
├── Soldier × 18 (CharacterBody3D)
├── Missile (Node3D)             se crean al disparar una batería
├── Camera3D
├── CanvasLayer → Hud (Control)  incluye el minimapa (`Hud.MiniMap`)
└── CanvasLayer (capa 10) → Menu (Control)  menú principal, pausa, controles y opciones
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
| Misil y baterías | `Missile` (y `Main._update_sams`) | `MissileLogic` | `MissileData` → `data/missile.tres` |
| Misión | `Main` | `MissionState` | constantes en `MissionState` |
| Mundo | `World` | funciones estáticas de `World` (`in_base`, `dest_distance`, `clear_spot`) | constantes en `World` |

- `Vehicle` (`scripts/vehicle.gd`) es la base de coche y caza: `is_jet`, `driver`, `dead`, `hp`, `speed`, `enter_range`, `can_exit()`, `hurt()`, `controlled()` y `resolve_bumps()` (atropellos y choques).
- `Build` (`scripts/build.gd`): ayudas estáticas para crear mallas primitivas, materiales (con caché) y colisiones. `Build.extrude` hace un prisma a partir de un polígono convexo (alas, derivas, perfil del coche, tejados) y `Build.windows_mat` es el material de fachada con ventanas (textura generada, triplanar en coordenadas del mundo, una ventana cada 3 m).
- `Humanoid` (`scripts/humanoid.gd`): muñeco articulado del jugador y de los soldados. `animate(velocidad, dt, apuntando)` balancea piernas y brazos; el ángulo sale de `Humanoid.swing` (con tests).

## Misión

`MissionState` (`RefCounted`) lleva la fase (`Stage`: `GET_CAR → GO_BASE → GET_JET → ESCAPE → WON`), las estrellas (`wanted`), la alarma (`base_alert`) y el final (`over`). `Main` le llama `step(...)` cada fotograma de física con hechos ya calculados (¿vas en vehículo?, ¿en caza?, ¿dentro de la base?, cazas que quedan, distancia al aeródromo) y escucha sus señales (`alert_raised`, `jet_stolen`, `failed(reason)`, `completed`) para mostrar los mensajes. Los actores avisan con `main.mission.raise_alert()` y `main.mission.fail(...)`.

## Quién llama a quién

- **Señales hacia arriba:** `MissionState` → `Main` → `Hud`.
- **Llamadas hacia abajo:** `Main` crea los actores y les pasa `main`. Los actores piden a `Main` efectos y consultas (`explosion`, `tracer`, `drop_flares`, `target_node`, `hurt_target`, `eject`). Es un acoplamiento aceptado mientras haya una sola escena.
- `Main` se ejecuta después de los actores (`process_physics_priority = 10`) para que la cámara vea posiciones ya actualizadas. La cámara es orbital a pie y en coche, y de persecución en el caza.
- `Hud` lee el estado de `Main` cada fotograma.

## Menús y opciones

- `Menu` (`scripts/menu.gd`) tiene `process_mode = ALWAYS` y es quien pone y quita la pausa del árbol: `open(MAIN | PAUSE)` pausa y suelta el ratón; `close()` reanuda y lo captura. Avisa a `Main` con señales (`play_pressed`, `restart_pressed`, `main_menu_pressed`). La pantalla de controles sale de `Menu.CONTROLS` y lee las teclas del InputMap.
- `Main` abre el menú principal al arrancar, salvo al reiniciar (`Main.skip_menu`, estático), con argumentos de desarrollo o si `show_menu` es false (tests). Esc durante la partida abre la pausa.
- `Settings` (`scripts/settings.gd`, estático) guarda en `user://settings.cfg` la sensibilidad (`mouse_scale`), la dificultad y el mejor tiempo. La dificultad multiplica el daño de los soldados (`Main.hurt_target`) y la recarga de las baterías (`Main._update_sams`).

## Sonido y efectos

- `Sfx` (`scripts/sfx.gd`, `process_mode = ALWAYS`) carga `assets/audio/sfx/*.ogg` y la música. Tres formas de sonar: `play` (sin posición), `play_at` (en un punto del mundo) y `set_loop` (motores, alarma, aviso de misil). `Main._update_audio` ajusta los bucles cada fotograma; en pausa se detienen solos. Buses `SFX` y `Music` creados por código; `Sfx.apply_volume` aplica los volúmenes de `Settings`.
- Sacudida de cámara: `Main.shake` (lógica en `CameraLogic`) mueve `Camera3D.h_offset`/`v_offset`. La suman las explosiones (según radio y distancia) y el daño al jugador.
- `Main.explosion(pos, radio)`: bola de fuego y humo siempre; con radio ≥ 3 añade sonido, metralla y sacudida.
- `Vehicle.update_smoke` echa humo por debajo del 40 % de resistencia. `Hud` pinta un fogonazo rojo mientras `Main.hurt_t` > 0.

## Input

Acciones en `project.godot`: `forward`, `back`, `left`, `right`, `sprint`, `jump`, `shoot`, `interact`, `flare`, `throttle_up`, `throttle_down`, `restart`. En el caza en tierra, `forward`/`back` son el acelerador; en vuelo, el morro.

## Capas de física (`Layers`)

| Bit | Nombre | Quién está |
|---|---|---|
| 1 | `WORLD` | suelo, edificios, valla, colinas |
| 2 | `PLAYER` | jugador |
| 4 | `VEHICLES` | coches y cazas |
| 8 | `SOLDIERS` | soldados |

Por ahora todos colisionan con todos (`Layers.ALL`). Los rayos (disparos, línea de visión, cámara) excluyen a quien los lanza. Los árboles no tienen colisión.

## Mundo (metros)

| Qué | Dónde |
|---|---|
| Ciudad y salida del jugador | x ±200, z de -240 a 340; jugador en (0, 262) |
| Carretera principal | x = 0, de z = 340 a z = -700 |
| Base aérea | x de -350 a 350, z de -1300 a -700; puerta en (0, -700) |
| Pista | z = -1200, de x = -330 a 330; cazas en (160, -1130) y (250, -1130) mirando al norte |
| Baterías | 3 en la base, 2 en la ruta (`World.BASE_SAMS`, `World.ROUTE_SAMS`) |
| Aeródromo de destino | (6000, 5000) |

## Tests

- Lógica pura: un `tests/test_*_logic.gd` por clase, más `test_mission_state.gd`, `test_world.gd` y `test_humanoid.gd`.
- Integración: `tests/test_shooting.gd` carga `main.tscn` (con `show_menu = false`) y dispara de verdad a los soldados.
- `./tools/check.sh` además arranca el menú, la misión y la pausa, y comprueba que el caza despega solo con W.

## Publicación

- `./tools/export.sh` genera en `build/` los paquetes de Linux (`.tar.gz`) y Windows (`.zip`) y `manifest.json` (versión, tamaños y SHA-256).
- `web/` es una web estática (portada, controles, instrucciones y descargas) servida por un único contenedor nginx: sin cuentas, sin bases de datos, sin cookies. `app.js` lee `downloads/manifest.json`.
- `./web/deploy.sh` copia los paquetes a `web/site/downloads/` y sincroniza con `servidor:/srv/operacion-halcon-web` (compose `halcon`, puerto 8080, subred 172.30.60.0/24). El dominio `halcon.enguillem.es` y el HTTPS los gestiona el humano en su proxy.
- El juego usa Forward+ (Vulkan); en equipos sin Vulkan Godot cae a OpenGL 3.3.

## Deuda

- Ayudas de desarrollo (`--test-jet`, `--shot`, `--yaw`…) dentro de `main.gd`.
- Medidas de los modelos (cajas, colores) como literales en cada actor.
