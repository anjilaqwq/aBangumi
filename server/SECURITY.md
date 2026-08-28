# Security notes — aBangumi Auth BFF

## Threat model

The BFF's job is to keep the OAuth **client secret** and the user's
**access/refresh tokens** off the device and out of any URL. The app only ever
receives an opaque, revocable **session token**.

- **Backend HTTPS callback.** Bangumi redirects the browser to
  `${PUBLIC_BASE_URL}/auth/bangumi/callback`, never to the `abangumi://` custom
  scheme. This prevents a malicious app on the same device from stealing the
  `code`/redirect.
- **Custom-scheme ticket theft.** The `abangumi://` callback redirect carries
  only `ticket`+`state` — values that are inherently browser-visible. A
  malicious app that registers `abangumi://` can read them but still cannot
  claim the session: `/claim` additionally requires an app-held, ≥256-bit
  `verifier` whose SHA-256 must match the challenge bound to the `state` at
  `/start`. The verifier never appears in any URL, deep link, or server log.
- **No PKCE is used** because Bangumi's OAuth (authorization-code + rotating
  refresh token) does not support it; the `client_secret` is therefore required
  on both `authorization_code` and `refresh_token` grants and is only ever sent
  server-to-server. The claim verifier above provides the equivalent
  device-possession proof for the custom-scheme hop.

## What is protected

- **State** — 256-bit `crypto.randomBytes`, TTL ≤ 5 min, consumed exactly once
  before the code exchange. Replay of a callback fails closed. Bound to the
  client's verifier **challenge** (SHA-256 hex), never the verifier itself.
- **Verifier/challenge** — the app generates a ≥256-bit verifier in secure
  storage; the BFF stores only `SHA-256(verifier)`. Challenge comparison is
  `crypto.timingSafeEqual`.
- **Ticket** — 256-bit, TTL ≤ 60 s. Claim **peeks** the ticket, verifies both
  `state` (timing-safe) and `SHA-256(verifier)` against the bound challenge
  (timing-safe), and **only then** consumes it. A wrong/missing verifier never
  burns the ticket, so an intercepted `ticket`+`state` cannot DoS the rightful
  app.
- **Session** — 256-bit opaque token, stored server-side with the rotating
  refresh token. Two independent lifetimes:
  - `accessExpiresAt` — when the Bangumi access token needs refresh; the proxy
    refreshes proactively within a 60 s window (or on 401), never deleting the
    session just because the access token expired.
  - `sessionExpiresAt` — the opaque app session (default 30 days); `getSession`
    only deletes on this boundary.
  - Concurrent refreshes per session are serialized by an in-memory promise
    lock (stampede prevention), and the rotated refresh token is written
    atomically inside that lock.
- **Tokens never in URLs/logs** — the callback redirect carries only
  `ticket` + `state`. Logging records only `METHOD` + `path` (no query string),
  never bodies, headers, codes, verifiers, challenges, or tokens.
- **Secret comparisons** — `crypto.timingSafeEqual` for challenge/state;
  constant-time iteration for Map lookups of random tokens
  (`constantTimeMapGet/Delete`).

## Hardening already applied

- Bounded request bodies (`BODY_LIMIT_BYTES`, default 1 MiB) → 413 on overflow.
- Explicit allowed methods per route → 405 otherwise.
- No permissive CORS: cross-origin reads are only enabled when `CORS_ORIGIN` is
  explicitly set.
- Security headers on every response (`X-Content-Type-Options`, `X-Frame-Options`,
  `Referrer-Policy`, `Cross-Origin-Opener-Policy`).
- `Cache-Control: no-store` on all auth responses (and proxied API responses).
- The OAuth callback failure paths return a minimal generic HTML page (no echoed
  codes/state/errors).
- `PUBLIC_BASE_URL` must be `https://` (http allowed only for localhost).
- The proxy only ever forwards to the fixed host `https://api.bgm.tv`; it never
  honors a client-supplied host and drops `Authorization`/`Host`/hop-by-hop
  headers.

## Production recommendations

1. **Persistent, shared storage.** `MemoryStore` is single-instance and
   non-durable: a restart logs everyone out. Use Redis (with TTL keys) or a
   database for `state`, `session`, and `ticket` so multiple replicas and
   restarts work. The store interface (`MemoryStore`) is the seam to replace.
2. **TLS everywhere.** Terminate TLS at a reverse proxy; keep
   `PUBLIC_BASE_URL` as the `https://` public origin.
3. **Rate limiting** on `/auth/bangumi/start` and `/auth/bangumi/claim` to slow
   token-grabbing/ticket-brute-force.
4. **Secret management.** Inject `BANGUMI_CLIENT_SECRET` from a secret manager
   or environment, never from source control or build artifacts.
5. **Rotation.** Rotating refresh tokens invalidate the previous refresh token
   on each refresh; store the newest one and consider revoking sessions on
   logout by deleting them server-side (already done).
6. **No sensitive logs.** Keep the structured logger at `method`+`path`+`status`;
   do not add headers, bodies, or query strings.
