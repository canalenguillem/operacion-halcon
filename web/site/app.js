// Rellena versión, tamaños y huellas desde downloads/manifest.json (lo genera tools/export.sh).
fetch("downloads/manifest.json").then(function (r) { return r.json(); }).then(function (m) {
  var mb = function (n) { return Math.round(n / 1e6) + " MB"; };
  document.getElementById("version").textContent = "Versión " + m.version;
  ["windows", "linux"].forEach(function (os) {
    var a = document.getElementById("dl-" + os);
    a.href = "downloads/" + m[os].file;
    a.querySelector("small").textContent = mb(m[os].size);
  });
  document.getElementById("sha").textContent = "SHA-256 · Windows: " + m.windows.sha256 + " · Linux: " + m.linux.sha256;
}).catch(function () {});
