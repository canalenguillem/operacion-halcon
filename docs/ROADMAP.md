# Roadmap — Operación Halcón

Hito actual: **M1**. M0 es el prototipo completo que se hizo de una vez; a partir de aquí se revisa por fases, cada una validada jugando.

Regla: no empezar un hito hasta que el anterior pase `./tools/check.sh` y el humano haya validado lo que hay que probar jugando.

## M0 — Esqueleto y prototipo
- [x] Proyecto Godot 4.7, escena única y mundo generado por código
- [x] Prototipo de toda la misión: a pie, coche, base con soldados, caza, misiles, victoria y derrota
- [x] HUD: objetivo, estrellas, salud, minimapa, aviso de misil
- [x] `CLAUDE.md`, `docs/GDD.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`
- [x] `./tools/check.sh` en verde (carga, arranque y despegue automático)
- [x] Repositorio git y primer commit

## M1 — A pie: moverse, cámara y disparar
- [x] `Player` con movimiento, sprint, salto y regeneración (prototipo)
- [x] Cámara orbital con colisión y mira (prototipo)
- [x] Pistola con trazadora (prototipo)
- [ ] Acciones del InputMap en `project.godot`
- [ ] Tipado estático en `player.gd` y en lo que toca de `main.gd`; ajustes como `@export`
- [ ] GUT instalado y primer test
- [ ] **Humano:** ¿se mueve y apunta bien? Velocidad andando/corriendo, sensibilidad del ratón, distancia de la cámara, cadencia de la pistola

## M2 — Coche
- [x] Coche arcade: acelerar, frenar, girar, daño por choque, explosión (prototipo)
- [x] Subir y bajar con E; la cámara se recoloca detrás al conducir (prototipo)
- [ ] Tipado y `@export` en `car.gd`
- [ ] **Humano:** ¿se conduce bien? Velocidad máxima, giro, freno; ¿se llega a la base sin aburrirse (≈30 s)?

## M3 — La base y los soldados
- [x] Recinto con valla, puerta con barrera, hangares, torre y barracones (prototipo)
- [x] Soldados: alerta, persecución, disparo con línea de visión, atropello (prototipo)
- [x] Alarma y estrellas (prototipo)
- [ ] `MissionState` y `WantedLevel` como lógica pura con tests
- [ ] Capas de física definidas en ARCHITECTURE
- [ ] **Humano:** ¿se puede llegar al caza? ¿demasiado fácil o difícil? ¿se entiende por qué te disparan?

## M4 — El caza
- [x] Rodaje, despegue, vuelo arcade, pérdida, aterrizaje y choque (prototipo)
- [x] Cámara de persecución e indicadores de velocidad, altura y potencia (prototipo)
- [ ] Tipado y `@export` en `jet.gd`
- [ ] **Humano:** ¿se despega a la primera? ¿se entiende Shift para acelerar? ¿el giro y el morro responden bien?

## M5 — Misiles y huida
- [x] Baterías, misiles guiados, bengalas, aviso en pantalla (prototipo)
- [x] Victoria al llegar al aeródromo; pantalla con tiempo y bajas (prototipo)
- [ ] Guiado del misil como lógica pura con tests
- [ ] **Humano:** ¿se puede sobrevivir? ¿bastan las bengalas? ¿el viaje de 60 s se hace largo?

## M6 — Menús
- [ ] Menú principal, pausa, pantalla de controles y opciones (volumen, sensibilidad, dificultad)
- [ ] Récord de tiempo guardado
- [ ] **Humano:** recorrer todos los menús

## M7 — Pulido
- [ ] Sonido (motor, disparos, explosiones, alarma, aviso de misil) y música
- [ ] Efectos: humo, partículas, sacudida de cámara
- [ ] Arte CC0 o mejor modelado con primitivas
- [ ] **Humano:** ver y escuchar

## Por decidir
- Policía y tráfico en la ciudad, más misiones, armas en el caza, modo online (skill `juego-online`).
