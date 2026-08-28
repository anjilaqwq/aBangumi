# aBangumi Auth BFF

A dependency-light **Node.js (>=20)** backend-for-frontend that implements the
secure Bangumi OAuth flow for the aBangumi Flutter app. It uses only Node.js
built-ins (`node:http`, `node:crypto`, `node:url`, global `fetch`) — **no npm
dependencies, no database**.

The client secret never lives in the app. The BFF owns the OAuth callback so
Bangumi redirects to **this backend over HTTPS**, never to the app's custom
scheme.

## Endpoints

| Method | Path                    | Auth            | Purpose |
| ------ | ----------------------- | --------------- | ------- |
| POST   | `/auth/bangumi/start`   | —               | Body `{ verifier_challenge }` (SHA-256 hex of the app's claim verifier). Creates a pending `state` bound to that challenge; returns `authorization_url` + `state`. |
| GET    | `/auth/bangumi/callback`| —               | Validate/consume `state`, exchange `code` server-side, create an opaque app session + one-time `ticket`, 302 to `abangumi://oauth/callback?ticket=…&state=…`. Failure paths return a minimal generic HTML page. |
| POST   | `/auth/bangumi/claim`   | —               | Body `{ ticket, state, verifier }`. Verifies `state` and `SHA-256(verifier)` against the bound challenge (timing-safe), then consumes the ticket once. Returns `{ session_token, expires_at }`. A wrong/missing verifier does **not** consume the ticket. |
| POST   | `/auth/logout`          | `Bearer <session>` | Delete the server session. |
| `*`    | `/api/bangumi/*`        | `Bearer <session>` | Proxy to `https://api.bgm.tv/*` with the current access token; proactive refresh within 60 s of access-token expiry, otherwise refresh + single retry on 401. Includes `/calendar`. |
| GET    | `/health`               | —               | Liveness probe. |

**No access token, refresh token, client secret, or claim verifier ever appears
in a URL or in the app.** The app only ever holds an opaque session token (and,
transiently, its own claim verifier in secure storage).

## Configuration

See [`.env.example`](./.env.example). Required variables:

- `BANGUMI_CLIENT_ID` — public OAuth app id.
- `BANGUMI_CLIENT_SECRET` — **secret**; never commit it.
- `PUBLIC_BASE_URL` — public `https://` URL of this BFF (must be HTTPS except localhost).

Optional: `APP_CALLBACK_URI` (default `abangumi://oauth/callback`), `PORT`
(default `8787`), `CORS_ORIGIN`, and TTL overrides.

## Run

```bash
cd server
# export BANGUMI_CLIENT_ID=… BANGUMI_CLIENT_SECRET=… PUBLIC_BASE_URL=https://…
npm start
```

## Test

```bash
cd server
npm test   # node --test, no network required
```

## Developer console / callback setup

1. Create an OAuth app at <https://next.bgm.tv/dashboard/apps> (Bangumi
   developer console).
2. Set the **callback / redirect URI** to:

   ```
   ${PUBLIC_BASE_URL}/auth/bangumi/callback
   ```

   e.g. `https://auth.example.com/auth/bangumi/callback`. This is the HTTPS
   URL the browser returns to; the BFF then redirects into the app.
3. Note the **client id** and **client secret**; put them in the BFF
   environment (secret only on the server).

## Notes & limitations

- **Session vs access-token lifetime.** The opaque app session lasts
  `SESSION_TTL_MS` (default **30 days**), independent of the Bangumi access
  token. The BFF transparently refreshes the access token (rotating refresh
  token) before it expires or on a 401, without logging the app out.
- **In-memory storage** means a restart (or deploying a second instance)
  invalidates every pending state, session, and ticket. For production with
  more than one replica, replace `MemoryStore` with Redis or a database — see
  [SECURITY.md](./SECURITY.md).
- The BFF listens over plain HTTP and expects a TLS-terminating reverse proxy
  (nginx/Caddy/Cloudflare) in front of it. `PUBLIC_BASE_URL` must be that
  proxy's `https://` URL.
