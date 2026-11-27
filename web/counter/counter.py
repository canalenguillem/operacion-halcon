"""Contador de descargas de Operación Halcón.

GET /api/download/<linux|windows|macos>  cuenta la descarga y la entrega (nginx sirve el archivo con X-Accel-Redirect)
GET /api/stats                           totales por sistema, en JSON

Solo guarda números: sistema, versión y cuántas descargas. Sin IP, sin cookies, sin datos personales.
"""
import json
import os
import re
import sqlite3
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SYSTEMS = ("windows", "macos", "linux")
MANIFEST = Path(os.environ.get("MANIFEST", "/downloads/manifest.json"))
DB_PATH = os.environ.get("DB_PATH", "/data/counter.sqlite3")
SAFE_FILE = re.compile(r"^[A-Za-z0-9._-]+$")


class Counter:
    """Descargas por sistema y versión, en SQLite."""

    def __init__(self, path: str) -> None:
        self._lock = threading.Lock()
        self._db = sqlite3.connect(path, check_same_thread=False)
        self._db.execute(
            "CREATE TABLE IF NOT EXISTS downloads (system TEXT, version TEXT, count INTEGER NOT NULL, PRIMARY KEY (system, version))"
        )
        self._db.commit()

    def close(self) -> None:
        """Cierra la base de datos (en Windows no se puede borrar el archivo si sigue abierto)."""
        with self._lock:
            self._db.close()

    def add(self, system: str, version: str) -> None:
        with self._lock:
            self._db.execute(
                "INSERT INTO downloads VALUES (?, ?, 1) ON CONFLICT (system, version) DO UPDATE SET count = count + 1",
                (system, version),
            )
            self._db.commit()

    def totals(self) -> dict[str, int]:
        with self._lock:
            rows = self._db.execute("SELECT system, SUM(count) FROM downloads GROUP BY system").fetchall()
        out = {s: 0 for s in SYSTEMS}
        out.update({s: n for s, n in rows if s in out})
        return out

    def by_version(self) -> list[dict]:
        with self._lock:
            rows = self._db.execute("SELECT version, system, count FROM downloads ORDER BY version DESC, system").fetchall()
        return [{"version": v, "system": s, "count": n} for v, s, n in rows]


def starts_at_zero(range_header: str | None) -> bool:
    """Una descarga reanudada (Range que no empieza en 0) no cuenta otra vez."""
    if not range_header:
        return True
    m = re.match(r"^bytes=(\d*)-", range_header.strip())
    return bool(m) and m.group(1) in ("", "0")


def read_manifest() -> dict:
    try:
        return json.loads(MANIFEST.read_text())
    except (OSError, ValueError):
        return {}


def make_handler(counter: Counter) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args) -> None:  # sin registro de peticiones (no se guardan IP)
            pass

        def _json(self, code: int, body: dict) -> None:
            data = json.dumps(body).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self) -> None:
            path = self.path.split("?", 1)[0]
            if path == "/api/stats":
                self._json(200, {"totals": counter.totals(), "by_version": counter.by_version()})
                return
            m = re.match(r"^/api/download/([a-z]+)$", path)
            entry = read_manifest().get(m.group(1)) if m and m.group(1) in SYSTEMS else None
            if not isinstance(entry, dict) or not SAFE_FILE.match(str(entry.get("file", ""))):
                self._json(404, {"error": "no encontrado"})
                return
            if starts_at_zero(self.headers.get("Range")):
                counter.add(m.group(1), str(read_manifest().get("version", "")))
            self.send_response(200)
            self.send_header("X-Accel-Redirect", "/downloads-files/" + entry["file"])
            self.send_header("Content-Disposition", 'attachment; filename="%s"' % entry["file"])
            self.send_header("Content-Length", "0")
            self.end_headers()

    return Handler


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8000), make_handler(Counter(DB_PATH))).serve_forever()
