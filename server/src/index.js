// Entrypoint for the aBangumi auth BFF.
//
//   node src/index.js
//
// The server itself listens over plain HTTP and is intended to sit behind a
// TLS-terminating reverse proxy (nginx/Caddy/Cloudflare). PUBLIC_BASE_URL must
// be the public https:// URL of that proxy.
import { createServer } from 'node:http';
import { loadConfig } from './config.js';
import { createApp } from './server.js';
import { MemoryStore } from './store.js';

function main() {
  let config;
  try {
    config = loadConfig(process.env);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(`[abangumi-bff] configuration error: ${err.message}`);
    process.exit(1);
  }

  const store = new MemoryStore({
    stateTtlMs: config.stateTtlMs,
    ticketTtlMs: config.ticketTtlMs,
    sessionTtlMs: config.sessionTtlMs,
  });
  store.startCleanup();

  const log = (msg) => console.log(`[abangumi-bff] ${msg}`);
  const app = createApp({ config, store, log });

  const server = createServer((req, res) => {
    // Minimal request log: method + path only (no query string, no bodies).
    const url = new URL(req.url, 'http://internal');
    res.on('finish', () => {
      log(`${req.method} ${url.pathname} -> ${res.statusCode}`);
    });
    app(req, res);
  });

  server.listen(config.port, () => {
    log(`listening on :${config.port}`);
  });

  const shutdown = () => {
    log('shutting down');
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 3000).unref();
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main();
