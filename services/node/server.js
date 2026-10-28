const http = require("http");
const os = require("os");

http
  .createServer((req, res) => {
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ lang: "node", color: "#68A063", host: os.hostname() }));
  })
  .listen(8080, () => console.log("node hue listening on :8080"));
