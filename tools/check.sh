#!/usr/bin/env bash
# Verificación headless del proyecto Godot. Uso: ./tools/check.sh
set -uo pipefail

GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
BAD="Parse Error|SCRIPT ERROR|ERROR:|Failed to load|FAIL"

echo "→ Importando recursos…"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "→ Cargando e instanciando escenas y recursos…"
"$GODOT" --headless --path . -s res://tools/load_all.gd >"$LOG" 2>&1
LOAD_EXIT=$?
if grep -E "$BAD" "$LOG"; then
  echo "❌ Errores al cargar el proyecto (ver arriba)"
  exit 1
fi
if [ "$LOAD_EXIT" -ne 0 ]; then
  cat "$LOG"
  echo "❌ load_all.gd terminó con código $LOAD_EXIT"
  exit 1
fi
tail -n 1 "$LOG"

echo "→ Arrancando el menú, la misión 5 s (a pie), la pausa y 15 s de despegue automático…"
"$GODOT" --headless --path . --fixed-fps 60 --quit-after 120 >"$LOG" 2>&1   # menú principal
"$GODOT" --headless --path . --fixed-fps 60 --quit-after 300 -- --play >>"$LOG" 2>&1
"$GODOT" --headless --path . --fixed-fps 60 --quit-after 120 -- --play --pause >>"$LOG" 2>&1
"$GODOT" --headless --path . --fixed-fps 60 --quit-after 900 -- --test-takeoff >>"$LOG" 2>&1
# Al cerrar con --quit-after, Godot avisa de que la música seguía sonando: no es un fallo del juego.
if grep -v "resources still in use at exit" "$LOG" | grep -E "$BAD"; then
  echo "❌ Errores al ejecutar la misión (ver arriba)"
  exit 1
fi
if ! grep -q "grounded=false" "$LOG"; then
  echo "❌ El caza no ha despegado en la prueba automática"
  exit 1
fi
if ! grep "t=15 " "$LOG" | grep -q "grounded=false.*over=false"; then
  echo "❌ El caza no sigue volando a los 15 s solo con W pulsada"
  exit 1
fi

if [ -d addons/gut ] && [ -d tests ]; then
  echo "→ Ejecutando tests GUT…"
  if ! "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit; then
    echo "❌ Tests fallidos"
    exit 1
  fi
else
  echo "⚠ GUT o tests/ no encontrados: tests omitidos"
fi

if [ -d web/counter ]; then
  echo "→ Pruebas del contador de descargas…"
  (cd web/counter && python3 -m unittest -q) || { echo "❌ Pruebas del contador fallidas"; exit 1; }
fi

echo "✅ Proyecto OK"
