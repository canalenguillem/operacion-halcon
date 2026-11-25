# GDD — Operación Halcón

## Concepto

Acción 3D en tercera persona con una sola misión de unos 5 minutos: robar un coche en la ciudad, entrar por la fuerza en una base aérea, robar un caza y escapar volando de las baterías de misiles hasta un aeródromo clandestino. La idea sale de un vídeo de una misión parecida; el juego es original (mundo, nombres y arte propios).

## Pilares

1. **Tres formas de moverse en una misión.** A pie, en coche y en caza; cada una se controla bien en 10 segundos.
2. **Tensión creciente.** Ciudad tranquila → alarma en la base → huida con misiles.
3. **Se entiende sin leer.** Un objetivo en pantalla, un haz de luz que lo marca y un minimapa.

## Bucle principal

```
Empezar → Robar coche → Llegar a la base → Robar caza → Despegar y huir → Resultado (tiempo, bajas) → Reintentar
```

## Fases de la misión

| Fase | Objetivo | Termina cuando |
|---|---|---|
| `GET_CAR` | Consigue un coche | Subes a un coche (o entras a pie en la base) |
| `GO_BASE` | Conduce hasta la base aérea | Entras en el recinto |
| `GET_JET` | Entra en la base y roba un caza | Subes a un caza. Si se destruyen los dos: misión fallida |
| `ESCAPE` | Despega y huye al aeródromo clandestino | Pasas a menos de 220 m del aeródromo (8,7 km) |

Se pierde si el jugador muere, si el caza que pilota se destruye o si no quedan cazas.

## Reglas

- **Nivel de búsqueda** (0-5 estrellas): 1 al robar un coche, 4 al ser detectado en la base, 5 al robar el caza. Por ahora solo se muestra; en la ciudad no hay policía.
- **Alarma de la base:** salta al entrar en el recinto, al acercarse a menos de 45 m de un soldado o al disparar cerca. Con la alarma, todos los soldados a menos de 500 m te persiguen y disparan.
- **Jugador:** 100 de salud; se regenera tras 6 s sin recibir daño. Pistola: 25 de daño, 4,5 disparos/s, con ayuda de puntería (3° alrededor de la mira) y marca de impacto (aspa blanca; roja si lo abates).
- **Soldados** (18): 40 de salud, disparan cada 1-1,8 s hasta 95 m, con más puntería de cerca. Hacen 5 de daño a pie, 2 al coche y 1,2 al caza. Se les puede atropellar.
- **Coche:** 144 km/h, 100 de resistencia; los choques fuertes lo dañan y al explotar expulsa al conductor con 40 de daño.
- **Caza:** 540 km/h, 100 de resistencia. En tierra W acelera y despega solo a 250 km/h; si sigues con W pulsada al despegar, no baja el morro hasta que la sueltas. Por debajo de 200 km/h en el aire entra en pérdida. Chocar contra algo en vuelo lo destruye; tocar suelo plano con poco ángulo es aterrizar.
- **Misiles:** 5 baterías (3 en la base, 2 en la ruta). Disparan al caza a más de 25 m de altura y entre 250 y 2600 m, cada 8-12 s, con 2 misiles en el aire como máximo. Misil: 666 km/h, giro limitado (se le puede esquivar girando fuerte), 34 de daño. **Bengalas** (12): cada una despista con un 75 % a los misiles cercanos.

## Controles

| Modo | Teclas |
|---|---|
| A pie | WASD mover · ratón cámara · clic disparar · Shift correr · Espacio saltar · E subir |
| Coche | W/S acelerar/marcha atrás · A/D girar · Espacio freno · E bajar |
| Caza en tierra | W acelerar · S frenar · A/D girar · despega solo a 250 km/h (o con S desde 200 km/h) · E bajar (parado) |
| Caza en vuelo | S/W subir/bajar morro · A/D alabeo · Shift/Ctrl potencia · F bengalas |
| General | R reiniciar · Esc soltar el ratón |

## Por decidir (se ajusta jugando)

- Sensación del movimiento a pie, del coche y del vuelo.
- Dificultad de soldados y misiles.
- ¿Policía en la ciudad? ¿Tráfico y peatones? ¿Cañón o misiles en el caza? ¿Hay que aterrizar para ganar?
- ¿Más misiones? ¿Modo online (skill `juego-online`)?
