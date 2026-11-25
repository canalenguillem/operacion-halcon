# Roadmap — Operación Halcón

Hito actual: **M6** (código hecho; falta la validación del humano). M1–M5 hechos y validados por el humano (lo probaron también sus alumnos). M0 es el prototipo completo que se hizo de una vez; a partir de aquí se revisa por fases, cada una validada jugando.

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
- [x] Acciones del InputMap en `project.godot` (incluida `shoot`)
- [x] Tipado estático en `player.gd`; `class_name` en `Main`, `Player` y `Build`; ajustes en `PlayerData` (`data/player.tres`)
- [x] GUT instalado; `PlayerLogic` (lógica pura) con 11 tests
- [x] Ayuda de puntería (`aim_assist_degrees`), marca de impacto y contador de bajas (el humano disparaba y no abatía a nadie)
- [x] **Humano:** se mueve, apunta y dispara bien

## M2 — Coche
- [x] Coche arcade: acelerar, frenar, girar, daño por choque, explosión (prototipo)
- [x] Subir y bajar con E; la cámara se recoloca detrás al conducir (prototipo)
- [x] `Vehicle` (base de coche y caza), `CarData` (`data/car.tres`) y `CarLogic` con tests
- [x] **Humano:** se conduce bien

## M3 — La base y los soldados
- [x] Recinto con valla, puerta con barrera, hangares, torre y barracones (prototipo)
- [x] Soldados: alerta, persecución, disparo con línea de visión, atropello (prototipo)
- [x] Alarma y estrellas (prototipo)
- [x] `MissionState` (fases, estrellas y alarma) como lógica pura con señales y tests; `SoldierData`, `SoldierLogic` con tests
- [x] `World` separado de `Main`, con tests de la geometría
- [x] Test de integración del disparo (`tests/test_shooting.gd`)
- [x] Capas de física (`Layers`) definidas en ARCHITECTURE
- [x] **Humano:** se llega al caza y se abate a los soldados

## M4 — El caza
- [x] Rodaje, despegue, vuelo arcade, pérdida, aterrizaje y choque (prototipo)
- [x] Cámara de persecución e indicadores de velocidad, altura y potencia (prototipo)
- [x] W acelera en tierra y el caza despega solo (el humano no consiguió despegar con Shift + S)
- [x] `JetData` (`data/jet.tres`) y `JetLogic` con tests
- [x] **Humano:** despega con W; giro y morro bien

## M5 — Misiles y huida
- [x] Baterías, misiles guiados, bengalas, aviso en pantalla (prototipo)
- [x] Victoria al llegar al aeródromo; pantalla con tiempo y bajas (prototipo)
- [x] `MissileData` (`data/missile.tres`) y `MissileLogic` (guiado y baterías) con tests
- [x] **Humano:** llega al aeródromo y ve «Misión cumplida»
- [x] **Humano:** dificultad y duración del vuelo bien
- [x] Tipado estático en todo el proyecto; `untyped_declaration` es error

## M6 — Menús
- [x] `Menu`: menú principal, pausa (Esc), controles (leídos del InputMap) y opciones
- [x] Opciones: sensibilidad del ratón y dificultad (daño de los soldados y recarga de las baterías); el volumen llega con el sonido en M7
- [x] `Settings`: opciones y récord de tiempo guardados en `user://settings.cfg`, con tests
- [x] Reiniciar (R o desde la pausa) no vuelve a pasar por el menú principal
- [ ] **Humano:** recorrer todos los menús con ratón y con teclado; pausar en coche y en vuelo; cambiar sensibilidad y dificultad y notar la diferencia; ganar y ver el récord en el menú principal

## M7 — Pulido
- [ ] Sonido (motor, disparos, explosiones, alarma, aviso de misil) y música
- [ ] Efectos: humo, partículas, sacudida de cámara
- [ ] Arte CC0 o mejor modelado con primitivas
- [ ] **Humano:** ver y escuchar

## Por decidir
- Policía y tráfico en la ciudad, más misiones, armas en el caza, modo online (skill `juego-online`).
