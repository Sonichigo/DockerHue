// dockerhue gateway: asks every colour service for its hue and paints the result.
const http = require("http");

const SERVICES = (process.env.HUE_SERVICES || "go,python,node").split(",");

async function fetchHue(name) {
  try {
    const res = await fetch(`http://${name}:8080/`, { signal: AbortSignal.timeout(1500) });
    return { name, ok: true, ...(await res.json()) };
  } catch (err) {
    return { name, ok: false, color: "#3a3a3a", lang: name, error: err.message };
  }
}

const page = (hues) => `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>dockerhue</title>
<style>
  body{margin:0;font-family:ui-monospace,Menlo,monospace;background:#0e0f13;color:#eee}
  header{padding:24px 20px 8px}h1{margin:0;font-size:22px}p{margin:6px 0 0;color:#9aa}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;padding:20px}
  .tile{border-radius:14px;padding:18px;min-height:130px;display:flex;flex-direction:column;justify-content:flex-end;color:#111}
  .tile.down{color:#bbb;outline:2px dashed #666}
  .lang{font-size:20px;font-weight:700}.meta{font-size:12px;opacity:.75}
</style></head><body>
<header><h1>dockerhue</h1><p>${hues.filter(h=>h.ok).length}/${hues.length} containers answering · refresh to re-poll</p></header>
<div class="grid">
${hues.map(h => `<div class="tile ${h.ok ? "" : "down"}" style="background:${h.color}">
  <div class="lang">${h.lang}</div>
  <div class="meta">${h.ok ? `${h.color} · ${h.host}` : `down: ${h.error}`}</div></div>`).join("\n")}
</div></body></html>`;

http
  .createServer(async (req, res) => {
    const hues = await Promise.all(SERVICES.map(fetchHue));
    if (req.url === "/api") {
      res.setHeader("Content-Type", "application/json");
      return res.end(JSON.stringify(hues, null, 2));
    }
    res.setHeader("Content-Type", "text/html");
    res.end(page(hues));
  })
  .listen(8080, () => console.log(`web gateway on :8080 -> ${SERVICES.join(", ")}`));
