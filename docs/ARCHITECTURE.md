# Arquitectura — Operación Halcón

Documento provisional (M0). Describe el prototipo tal como está; los cambios previstos están en `docs/ROADMAP.md`.

## Escena

`main.tscn` es un único `Node3D` con `scripts/main.gd`. Todo lo demás se crea por código en `_ready`:

```
Main (Node3D)                    scripts/main.gd
├── WorldEnvironment, DirectionalLight3D
├── suelo (WorldBoundaryShape3D + PlaneMesh), árboles (MultiMesh), colinas (sólidas)
├── ciudad, base aérea, aeródromo de destino   cajas de scripts/build.gd
├── Player (CharacterBody3D)     scripts/player.gd
├── Car × 5 (CharacterBody3D)    scripts/car.gd      grupo "vehicles"
├── Jet × 2 (CharacterBody3D)    scripts/jet.gd      grupo "vehicles"
├── Soldier × 18                 scripts/soldier.gd  grupo "soldiers"
├── Missile (Node3D, se crean al disparar)  scripts/missile.gd
├── Camera3D
└── CanvasLayer → Hud (Control)  scripts/hud.gd (incluye el minimapa)
```

- El norte es **-Z** y el frente de todos los actores también.
- `scripts/build.gd`: ayudas estáticas para crear mallas primitivas, materiales (con caché) y colisiones.

## Quién hace qué

- **`main.gd`** construye el mundo, lleva el estado de la misión (`stage`, `wanted`, `base_alert`, `game_over`), entrar y salir de vehículos, las baterías de misiles, la cámara (orbital a pie y en coche; de persecución en el caza) y los efectos (trazadoras, explosiones, bengalas). Se ejecuta después de los actores (`process_physics_priority = 10`) para que la cámara vea posiciones ya actualizadas.
- **Actores**: cada uno lee el input directamente y recibe una referencia `main` sin tipo. Todos los que reciben daño tienen `hurt(d)`. Los vehículos comparten por convención `is_jet`, `driver`, `dead`, `hp`, `speed`, `enter_range`, `can_exit()`.
- **`hud.gd`** lee el estado de `main` cada fotograma.

## Mundo (metros)

| Qué | Dónde |
|---|---|
| Ciudad y salida del jugador | x ±200, z de -240 a 340; jugador en (0, 262) |
| Carretera principal | x = 0, de z = 340 a z = -700 |
| Base aérea | x de -350 a 350, z de -1300 a -700; puerta en (0, -700) |
| Pista | z = -1200, de x = -330 a 330; cazas en (160, -1130) y (250, -1130) mirando al norte |
| Aeródromo de destino | (6000, 5000) |

## Capas de física

Todo está en la capa 1 por ahora. Los rayos (disparos, línea de visión, cámara) excluyen a quien los lanza.

## Deuda del prototipo (se paga por hitos)

- Sin tipado estático completo (`main` es `Variant` en los actores).
- Acciones del InputMap creadas por código en `main.gd`, no en `project.godot`.
- Números de ajuste como constantes o literales, no `@export` ni `.tres`.
- Lógica de misión, alarma y guiado del misil mezclada con los nodos; sin tests.
- Ayudas de prueba (`--test-jet`, `--shot`…) dentro de `main.gd`.
