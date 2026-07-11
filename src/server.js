// Placeholder app: the smallest thing the pipeline can prove is alive.
// Replace this with your real app — keep a /health endpoint that returns 200.
import { createServer } from "node:http";

const startedAt = new Date().toISOString();

export function createApp() {
  return createServer((req, res) => {
    if (req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", startedAt }));
      return;
    }
    if (req.url === "/") {
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.end("Hello from the startup pipeline template.\n");
      return;
    }
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "not found" }));
  });
}

// Started directly (node src/server.js) — bind and serve.
if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number.parseInt(process.env.PORT ?? "3000", 10);
  createApp().listen(port, () => {
    console.log(`listening on :${port}`);
  });
}
