// Rellena versión, tamaños y huellas desde downloads/manifest.json (lo genera tools/export.sh)
// y el número de descargas desde /api/stats.
var SYSTEMS = ["windows", "macos", "linux"];
var sizes = {};
var counts = null;

function render() {
  SYSTEMS.forEach(function (os) {
    var parts = [];
    if (sizes[os]) parts.push(Math.round(sizes[os] / 1e6) + " MB");
    if (counts) parts.push(counts[os] + (counts[os] === 1 ? " descarga" : " descargas"));
    document.querySelector("#dl-" + os + " small").textContent = parts.join(" · ");
  });
}

function loadStats() {
  fetch("api/stats").then(function (r) { return r.json(); }).then(function (s) {
    counts = s.totals;
    render();
  }).catch(function () {});
}

fetch("downloads/manifest.json").then(function (r) { return r.json(); }).then(function (m) {
  document.getElementById("version").textContent = "Versión " + m.version;
  SYSTEMS.forEach(function (os) { sizes[os] = m[os].size; });
  document.getElementById("sha").textContent = "SHA-256 · Windows: " + m.windows.sha256 + " · macOS: " + m.macos.sha256 + " · Linux: " + m.linux.sha256;
  render();
}).catch(function () {});

loadStats();
SYSTEMS.forEach(function (os) {
  document.getElementById("dl-" + os).addEventListener("click", function () { setTimeout(loadStats, 1500); });
});
