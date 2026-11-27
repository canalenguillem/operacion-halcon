"""Pruebas del contador. Uso: python3 -m unittest discover -s web/counter"""
import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

import counter


class CounterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        manifest = Path(self.tmp.name) / "manifest.json"
        manifest.write_text(json.dumps({
            "version": "v1", "linux": {"file": "juego-linux.tar.gz"}, "windows": {"file": "juego-windows.zip"},
            "macos": {"file": "../secreto"},
        }))
        counter.MANIFEST = manifest
        self.counter = counter.Counter(os.path.join(self.tmp.name, "c.sqlite3"))
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), counter.make_handler(self.counter))
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.url = "http://127.0.0.1:%d" % self.server.server_address[1]

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.counter.close()
        self.tmp.cleanup()

    def get(self, path: str, headers: dict | None = None):
        return urllib.request.urlopen(urllib.request.Request(self.url + path, headers=headers or {}))

    def test_descargar_cuenta_y_redirige_al_archivo(self) -> None:
        r = self.get("/api/download/linux")
        self.assertEqual(r.headers["X-Accel-Redirect"], "/downloads-files/juego-linux.tar.gz")
        self.get("/api/download/linux")
        self.get("/api/download/windows")
        stats = json.load(self.get("/api/stats"))
        self.assertEqual(stats["totals"], {"windows": 1, "macos": 0, "linux": 2})
        self.assertIn({"version": "v1", "system": "linux", "count": 2}, stats["by_version"])

    def test_reanudar_una_descarga_no_cuenta(self) -> None:
        self.get("/api/download/linux", {"Range": "bytes=5000-"})
        self.get("/api/download/linux", {"Range": "bytes=0-"})
        self.assertEqual(self.counter.totals()["linux"], 1)

    def test_sistema_desconocido_o_archivo_raro_da_404(self) -> None:
        for path in ("/api/download/amiga", "/api/download/macos", "/api/otra"):
            with self.assertRaises(urllib.error.HTTPError) as e:
                self.get(path)
            self.assertEqual(e.exception.code, 404)
        self.assertEqual(sum(self.counter.totals().values()), 0)

    def test_el_contador_sobrevive_a_un_reinicio(self) -> None:
        self.counter.add("windows", "v1")
        again = counter.Counter(os.path.join(self.tmp.name, "c.sqlite3"))
        self.assertEqual(again.totals()["windows"], 1)
        again.close()


if __name__ == "__main__":
    unittest.main()
