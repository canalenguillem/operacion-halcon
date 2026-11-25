#!/usr/bin/env bash
# Genera los ejecutables de Linux y Windows (x86_64) y la app de macOS (universal, sin firmar),
# sus paquetes y build/manifest.json.
# Requiere las plantillas de exportación de la misma versión de Godot.
# Uso: ./tools/export.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
NAME=operacion-halcon
CONTROLS="Controles: WASD mover, ratón cámara, clic disparar, Shift correr, Espacio saltar, E subir y bajar de vehículos.
Caza: W acelera y despega solo; en vuelo S sube el morro y W lo baja, A/D giran, F bengalas. Esc pausa, R reiniciar."
rm -rf build && mkdir -p "build/$NAME-linux" "build/$NAME-windows"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

export_one() {  # preset, archivo de salida
	"$GODOT" --headless --path . --export-release "$1" "$2" 2>&1 | grep -E "ERROR|error" | grep -v "still in use" && { echo "❌ la exportación de $1 falló"; exit 1; } || true
	[ -f "$2" ] || { echo "❌ no se generó $2 (¿faltan las plantillas de exportación?)"; exit 1; }
}

export_one Linux "build/$NAME-linux/$NAME.x86_64"
chmod +x "build/$NAME-linux/$NAME.x86_64"
cat > "build/$NAME-linux/LEEME.txt" <<TXT
Operación Halcón — Linux (64 bits)

Cómo jugar:
  1. Descomprime esta carpeta donde quieras.
  2. Abre una terminal en ella y ejecuta:   ./$NAME.x86_64
     (si no arranca: chmod +x $NAME.x86_64)

$CONTROLS

Requisitos: una tarjeta gráfica con Vulkan (recomendado) u OpenGL 3.3. No hace falta instalar nada.
TXT
tar -C build -czf "build/$NAME-linux.tar.gz" "$NAME-linux"

export_one Windows "build/$NAME-windows/Operacion-Halcon.exe"
find "build/$NAME-windows" -type f ! -name 'Operacion-Halcon.exe' -delete
cat > "build/$NAME-windows/LEEME.txt" <<TXT
Operación Halcón — Windows (64 bits)

Cómo jugar:
  1. Extrae el .zip: clic derecho -> "Extraer todo..." (no lo ejecutes desde dentro del zip).
  2. Abre la carpeta y haz doble clic en Operacion-Halcon.exe.

Si Windows muestra "Windows protegió su equipo" (SmartScreen):
  Pulsa "Más información" y luego "Ejecutar de todas formas".
  Sale porque el programa no tiene firma digital de pago; es normal en juegos hechos por aficionados.

$CONTROLS

Requisitos: Windows 10 u 11 (64 bits) y una tarjeta gráfica con Vulkan (recomendado) u OpenGL 3.3.
TXT
(cd build && python3 -m zipfile -c "$NAME-windows.zip" "$NAME-windows")

# macOS: Godot genera un .zip con la .app; se le añade el LEEME conservando los permisos de ejecución
mkdir -p "build/$NAME-macos"
export_one macOS "build/$NAME-macos/Operacion-Halcon.zip"
CONTROLS="$CONTROLS" python3 - <<'PY'
import os, zipfile
LEEME = f"""Operación Halcón — macOS (Intel y Apple Silicon)

Cómo jugar:
  1. Descomprime el .zip y arrastra "Operación Halcón" a la carpeta Aplicaciones (o déjala donde quieras).
  2. La primera vez macOS dirá que no puede comprobar que está libre de software malicioso
     (la app no está firmada ni notarizada: es un juego hecho por aficionados).
     Para abrirla:
       - macOS 14 o anterior: clic derecho sobre la app -> "Abrir" -> "Abrir".
       - macOS 15 o posterior: intenta abrirla una vez, ve a Ajustes del Sistema -> Privacidad y seguridad,
         baja hasta el aviso de la app y pulsa "Abrir igualmente".
     Si dice que la app "está dañada", abre la Terminal y ejecuta:
       xattr -dr com.apple.quarantine "/Applications/Operación Halcón.app"

{os.environ["CONTROLS"]}

Requisitos: macOS 10.13 o posterior. No hace falta instalar nada.
"""
with zipfile.ZipFile("build/operacion-halcon-macos/Operacion-Halcon.zip") as zin, \
        zipfile.ZipFile("build/operacion-halcon-macos.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zout:
    for info in zin.infolist():
        zout.writestr(info, zin.read(info), compress_type=zipfile.ZIP_DEFLATED)
    zout.writestr("LEEME-mac.txt", LEEME)
PY

VERSION="$(date +%Y-%m-%d) · $(git rev-parse --short HEAD 2>/dev/null || echo sin-git)"
entry() {  # archivo
	printf '{"file": "%s", "size": %s, "sha256": "%s"}' "$1" "$(stat -c %s "build/$1")" "$(sha256sum "build/$1" | cut -d' ' -f1)"
}
printf '{"version": "%s", "linux": %s, "windows": %s, "macos": %s}\n' "$VERSION" "$(entry "$NAME-linux.tar.gz")" "$(entry "$NAME-windows.zip")" "$(entry "$NAME-macos.zip")" > build/manifest.json
du -h build/*.tar.gz build/*.zip
echo "✅ $VERSION"
