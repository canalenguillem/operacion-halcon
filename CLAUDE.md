# Operación Halcón (carpeta `mini-gta`, nombre provisional)

Juego de acción **3D en tercera persona** de una sola misión: robar un coche, colarse en una base aérea, robar un caza y huir de los misiles hasta un aeródromo clandestino. Juego original: la idea de la misión viene de un vídeo, pero no se copian nombre, personajes, mapa ni arte de ningún juego existente.

> **Estado:** M0 hecho (prototipo jugable de principio a fin, sin validar). Hito actual: **M1**. Ver `docs/ROADMAP.md`.

## Stack

- **Godot 4.7.x stable**. Prohibidas las APIs de Godot 3.
- **GDScript con tipado estático** en todo (el prototipo de M0 aún no lo cumple: se arregla hito a hito, ver ROADMAP).
- **3D**, Forward+. Resolución base 1280×720, `stretch/mode = canvas_items`, `stretch/aspect = expand`.
- Sin assets externos por ahora: todo el mundo se genera con primitivas (`scripts/build.gd`).
- Tests con **GUT 9.x** en `addons/gut` (se añade en M1, copiado de `../mini-futbol-kit`).
- Plataforma: escritorio Linux.

## Documentación (léela antes de cualquier tarea grande)

- `docs/GDD.md`: qué es el juego (diseño, reglas, números).
- `docs/ARCHITECTURE.md`: cómo está construido.
- `docs/ROADMAP.md`: hitos. **Trabaja solo en el hito actual** y marca las casillas al terminarlas.

## Comandos

```bash
./tools/check.sh                                        # verificación completa (importa, carga todo, arranca la misión, tests)
godot --path .                                          # jugar (necesita pantalla)
godot --path . -- --at=150,0.2,-1110                    # empezar a pie en esa posición (x,y,z)
godot --path . -- --test-jet                            # empezar volando
godot --path . -- --test-takeoff                        # despegue automático (imprime el estado cada segundo)
godot --path . -- --shot=/ruta/captura.png              # guarda una captura a los 150 fotogramas y sale
```

## Estructura

```
project.godot
main.tscn          # un Node3D con scripts/main.gd; todo lo demás se crea por código
scripts/           # main, build, player, car, jet, soldier, missile, hud
docs/
tools/             # check.sh, load_all.gd
```

## Convenciones

Las mismas que `../mini-futbol-kit` y `../mini-bolidos-kit`:

- Archivos, funciones y variables en `snake_case`; `class_name` y nodos en `PascalCase`.
- **Señales hacia arriba, llamadas hacia abajo.**
- **Los datos no van en el código.** Los valores de ajuste son `@export` o Resources `.tres`.
- El input va siempre por acciones del InputMap, nunca por teclas directas.
- Lógica pura (estado de la misión, nivel de búsqueda, guiado del misil) separada de los nodos y con tests GUT.
- Comentarios y mensajes de commit en español; identificadores en inglés.
- Al editar `.tscn`/`.tres` como texto: no inventes `uid`, no toques `.godot/` ni `.import`.

## Flujo de trabajo

1. Lee el hito actual en `docs/ROADMAP.md`.
2. Avanza en pasos pequeños y ejecuta `./tools/check.sh` tras cada uno.
3. Lo que solo se puede juzgar jugando (sensación de control, vuelo, dificultad) **no lo des por bueno tú**. Deja al humano una lista corta de qué probar y qué valores ajustar.
4. No empieces un hito hasta que el humano haya validado el anterior.
5. Commits pequeños con mensajes descriptivos.
