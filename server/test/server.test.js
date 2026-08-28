import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createApp } from '../src/server.js';
import { MemoryStore } from '../src/store.js';
import { randomToken, sha256Hex } from '../src/random.js';

const CONFIG = {
  port: 0,
  clientId: 'bgm69386a8765324f840',
  clientSecret: 'test-secret-not-real',
  publicBaseUrl: 'https://auth.example.com',
  appCallbackUri: 'abangumi://oauth/callback',
  corsOrigin: '',
  stateTtlMs: 5 * 60 * 1000,
  ticketTtlMs: 60 * 1000,
  sessionTtlMs: 30 * 24 * 60 * 60 * 1000,
  bodyLimitBytes: 1024 * 1024,
};

// A fixed, valid 32-byte verifier and its SHA-256 challenge. Used across the
// flow so tests can assert the challenge/verifier binding deterministically.
const VERIFIER = Buffer.alloc(32, 7).toString('base64url');
const CHALLENGE = sha256Hex(VERIFIER);

/**
 * A fake Bangumi backend. Never touches the network — it only intercepts the
 * two fixed hosts the BFF is allowed to call.
 */
function makeFakeBangumi() {
  const calls = { token: [], api: [] };
  const fetchImpl = async (url, init) => {
    const u = String(url);
    if (u === 'https://bgm.tv/oauth/access_token') {
      calls.token.push(init);
      const params = new URLSearchParams(init.body);
      const grant = params.get('grant_type');
      if (grant === 'authorization_code') {
        return jsonResponse(200, {
          access_token: 'test-access',
          refresh_token: 'test-refresh',
          expires_in: 604800,
          token_type: 'Bearer',
          user_id: 123,
        });
      }
      if (grant === 'refresh_token') {
        return jsonResponse(200, {
          access_token: 'refreshed-access',
          refresh_token: 'refreshed-refresh',
          expires_in: 604800,
        });
      }
      return jsonResponse(400, { error: 'unsupported_grant_type' });
    }
    if (u.startsWith('https://api.bgm.tv/')) {
      const auth = String(init.headers.authorization ?? '');
      calls.api.push({ url: u, method: init.method, auth, body: init.body });
      if (auth === 'Bearer stale-access') {
        return jsonResponse(401, { error: 'unauthorized' });
      }
      return jsonResponse(200, {
        ok: true,
        path: new URL(u).pathname,
        auth,
        method: init.method,
      });
    }
    throw new Error(`unexpected upstream url: ${u}`);
  };
  return { fetchImpl, calls };
}

function jsonResponse(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

async function startServer(overrides = {}, fake = makeFakeBangumi()) {
  const config = { ...CONFIG, ...overrides };
  const store = new MemoryStore({
    stateTtlMs: config.stateTtlMs,
    ticketTtlMs: config.ticketTtlMs,
    sessionTtlMs: config.sessionTtlMs,
  });
  const app = createApp({ config, store, fetchImpl: fake.fetchImpl });
  const server = createServer(app);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const { port } = server.address();
  return { base: `http://127.0.0.1:${port}`, server, store, config, fake };
}

/**
 * Drive start -> callback, returning the deep-link ticket+state but NOT yet
 * claiming, so tests can exercise claim (and its failure modes) independently.
 */
async function oauthToRedirect(ctx, { verifier = VERIFIER, code = 'code-abc' } = {}) {
  const start = await fetch(`${ctx.base}/auth/bangumi/start`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ verifier_challenge: sha256Hex(verifier) }),
  });
  assert.equal(start.status, 200);
  const { authorization_url: authUrl, state } = await start.json();

  const cb = await fetch(
    `${ctx.base}/auth/bangumi/callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state)}`,
    { redirect: 'manual' },
  );
  assert.equal(cb.status, 302);
  const location = cb.headers.get('location');
  assert.ok(location.startsWith('abangumi://oauth/callback?'));
  const loc = new URL(location);
  const ticket = loc.searchParams.get('ticket');
  const echoState = loc.searchParams.get('state');
  assert.ok(ticket);
  assert.equal(echoState, state);
  return { state, ticket, authUrl, location };
}

async function claim(ctx, ticket, state, verifier) {
  const resp = await fetch(`${ctx.base}/auth/bangumi/claim`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ticket, state, verifier }),
  });
  return resp;
}

let ctx;
before(async () => {
  ctx = await startServer();
});
after(() => ctx.server.close());

test('health endpoint', async () => {
  const resp = await fetch(`${ctx.base}/health`);
  assert.equal(resp.status, 200);
  assert.deepEqual(await resp.json(), { status: 'ok' });
});

test('start requires a valid SHA-256 verifier challenge', async () => {
  const missing = await fetch(`${ctx.base}/auth/bangumi/start`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{}',
  });
  assert.equal(missing.status, 400);
  assert.deepEqual(await missing.json(), { error: 'invalid_challenge' });

  const bad = await fetch(`${ctx.base}/auth/bangumi/start`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ verifier_challenge: 'not-hex' }),
  });
  assert.equal(bad.status, 400);
});

test('start builds a correct authorize URL with a cryptographically random state', async () => {
  const resp = await fetch(`${ctx.base}/auth/bangumi/start`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ verifier_challenge: CHALLENGE }),
  });
  assert.equal(resp.status, 200);
  const body = await resp.json();
  assert.equal(typeof body.state, 'string');
  assert.ok(body.state.length >= 43);

  const parsed = new URL(body.authorization_url);
  assert.equal(parsed.origin, 'https://bgm.tv');
  assert.equal(parsed.pathname, '/oauth/authorize');
  assert.equal(parsed.searchParams.get('client_id'), CONFIG.clientId);
  assert.equal(parsed.searchParams.get('response_type'), 'code');
  assert.equal(parsed.searchParams.get('redirect_uri'), `${CONFIG.publicBaseUrl}/auth/bangumi/callback`);
  assert.equal(parsed.searchParams.get('state'), body.state);
});

test('full flow: start -> callback -> claim, with no tokens or verifier in the redirect', async () => {
  const { state, ticket, location } = await oauthToRedirect(ctx);

  const resp = await claim(ctx, ticket, state, VERIFIER);
  assert.equal(resp.status, 200);
  const claimed = await resp.json();
  assert.ok(claimed.session_token.length >= 43);
  assert.ok(!Number.isNaN(Date.parse(claimed.expires_at)));

  // No access/refresh token and no verifier/challenge may appear in the URL.
  assert.ok(!/test-access|test-refresh/.test(location), 'tokens must never appear in redirect');
  assert.ok(!location.includes(VERIFIER), 'verifier must never appear in redirect');
  assert.ok(!location.includes(CHALLENGE), 'challenge must never appear in redirect');

  // The BFF exchanged the code with client_secret.
  const exchange = ctx.fake.calls.token.find((c) => new URLSearchParams(c.body).get('grant_type') === 'authorization_code');
  assert.ok(exchange);
  const exchangeParams = new URLSearchParams(exchange.body);
  assert.equal(exchangeParams.get('client_secret'), 'test-secret-not-real');
  assert.equal(exchangeParams.get('code'), 'code-abc');

  // Claim returns the opaque session expiry (30d), not the access expiry.
  const session = ctx.store.getSession(claimed.session_token);
  assert.equal(claimed.expires_at, new Date(session.sessionExpiresAt).toISOString());
});

test('intercepted ticket+state WITHOUT verifier cannot claim (and does not burn the ticket)', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);

  // Attacker who registered abangumi:// has ticket+state but no verifier.
  const noVerifier = await fetch(`${ctx.base}/auth/bangumi/claim`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ticket, state }),
  });
  assert.equal(noVerifier.status, 400);
  assert.deepEqual(await noVerifier.json(), { error: 'missing_params' });

  // The rightful app (which holds the verifier) can still claim it.
  const ok = await claim(ctx, ticket, state, VERIFIER);
  assert.equal(ok.status, 200);
});

test('intercepted ticket+state with a WRONG verifier cannot claim (and does not burn the ticket)', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);
  const wrongVerifier = Buffer.alloc(32, 9).toString('base64url');

  const bad = await claim(ctx, ticket, state, wrongVerifier);
  assert.equal(bad.status, 400);
  assert.deepEqual(await bad.json(), { error: 'invalid_ticket' });

  const ok = await claim(ctx, ticket, state, VERIFIER);
  assert.equal(ok.status, 200, 'legitimate app can still claim after a wrong-verifier attempt');
});

test('claim with a malformed verifier is rejected without consuming the ticket', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);

  const bad = await claim(ctx, ticket, state, '!!!not-base64url!!!');
  assert.equal(bad.status, 400);
  assert.deepEqual(await bad.json(), { error: 'invalid_verifier' });

  const ok = await claim(ctx, ticket, state, VERIFIER);
  assert.equal(ok.status, 200);
});

test('claim with a mismatched state is rejected without consuming the ticket', async () => {
  const { ticket } = await oauthToRedirect(ctx);
  const bad = await claim(ctx, ticket, 'wrong-state', VERIFIER);
  assert.equal(bad.status, 400);
  assert.deepEqual(await bad.json(), { error: 'invalid_ticket' });
});

test('state is consumed exactly once (callback replay fails)', async () => {
  const start = await fetch(`${ctx.base}/auth/bangumi/start`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ verifier_challenge: CHALLENGE }),
  });
  const { state } = await start.json();
  const url = `${ctx.base}/auth/bangumi/callback?code=x&state=${encodeURIComponent(state)}`;
  const first = await fetch(url, { redirect: 'manual' });
  assert.equal(first.status, 302);
  const replay = await fetch(url, { redirect: 'manual' });
  assert.equal(replay.status, 400);
  assert.match(replay.headers.get('content-type'), /text\/html/);
});

test('ticket is consumed exactly once (claim replay fails after success)', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);
  assert.equal((await claim(ctx, ticket, state, VERIFIER)).status, 200);
  assert.equal((await claim(ctx, ticket, state, VERIFIER)).status, 400);
});

test('concurrent claims allow exactly one successful ticket consumer', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);
  const responses = await Promise.all([
    claim(ctx, ticket, state, VERIFIER),
    claim(ctx, ticket, state, VERIFIER),
  ]);
  assert.deepEqual(
    responses.map((response) => response.status).sort(),
    [200, 400],
  );
});

test('callback failure returns a minimal HTML page, never JSON', async () => {
  const resp = await fetch(`${ctx.base}/auth/bangumi/callback?error=access_denied`);
  assert.equal(resp.status, 400);
  assert.match(resp.headers.get('content-type'), /text\/html/);
  const body = await resp.text();
  assert.ok(!body.includes('access_denied'), 'must not echo the error');
  assert.equal(resp.headers.get('cache-control'), 'no-store');
});

test('proxy forwards to api.bgm.tv with the access token and preserves path/method/body', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);
  const claimed = await (await claim(ctx, ticket, state, VERIFIER)).json();

  const resp = await fetch(`${ctx.base}/api/bangumi/v0/me`, {
    method: 'GET',
    headers: { authorization: `Bearer ${claimed.session_token}` },
  });
  assert.equal(resp.status, 200);
  const json = await resp.json();
  assert.equal(json.path, '/v0/me');
  assert.equal(json.auth, 'Bearer test-access');

  const upstream = ctx.fake.calls.api.at(-1);
  assert.equal(upstream.method, 'GET');
  assert.equal(upstream.url, 'https://api.bgm.tv/v0/me');
});

test('proxy allows the /calendar route', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);
  const claimed = await (await claim(ctx, ticket, state, VERIFIER)).json();

  const resp = await fetch(`${ctx.base}/api/bangumi/calendar`, {
    headers: { authorization: `Bearer ${claimed.session_token}` },
  });
  assert.equal(resp.status, 200);
  const upstream = ctx.fake.calls.api.at(-1);
  assert.equal(upstream.url, 'https://api.bgm.tv/calendar');
});

test('proxy preserves method and body upstream', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);
  const claimed = await (await claim(ctx, ticket, state, VERIFIER)).json();

  await fetch(`${ctx.base}/api/bangumi/v0/users/-/collections/42`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${claimed.session_token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ type: 2 }),
  });
  const upstream = ctx.fake.calls.api.at(-1);
  assert.equal(upstream.method, 'POST');
  assert.equal(upstream.url, 'https://api.bgm.tv/v0/users/-/collections/42');
  assert.equal(Buffer.from(upstream.body).toString(), JSON.stringify({ type: 2 }));
});

test('proxy transparently refreshes on 401, includes redirect_uri, retries once, rotates token', async () => {
  const sessionToken = ctx.store.createSession({
    accessToken: 'stale-access',
    refreshToken: 'test-refresh',
    expiresInSeconds: 604800, // far future => no proactive refresh; only 401 path
  });
  const beforeApi = ctx.fake.calls.api.length;
  const beforeToken = ctx.fake.calls.token.length;

  const resp = await fetch(`${ctx.base}/api/bangumi/v0/me`, {
    headers: { authorization: `Bearer ${sessionToken}` },
  });
  assert.equal(resp.status, 200);
  const json = await resp.json();
  assert.equal(json.auth, 'Bearer refreshed-access');

  assert.equal(ctx.fake.calls.api.length, beforeApi + 2, 'one 401 + one retry');
  assert.equal(ctx.fake.calls.token.length, beforeToken + 1, 'exactly one refresh');
  const refreshCall = ctx.fake.calls.token.at(-1);
  const params = new URLSearchParams(refreshCall.body);
  assert.equal(params.get('grant_type'), 'refresh_token');
  assert.equal(params.get('refresh_token'), 'test-refresh');
  assert.equal(params.get('client_secret'), 'test-secret-not-real');
  assert.equal(params.get('redirect_uri'), `${CONFIG.publicBaseUrl}/auth/bangumi/callback`);

  // Rotating refresh token is persisted for the next refresh.
  assert.equal(ctx.store.getSession(sessionToken).refreshToken, 'refreshed-refresh');
});

test('proxy proactively refreshes when access token is about to expire (no 401 round-trip)', async () => {
  const sessionToken = ctx.store.createSession({
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    expiresInSeconds: 30, // within the 60s refresh window
  });
  const beforeApi = ctx.fake.calls.api.length;
  const beforeToken = ctx.fake.calls.token.length;

  const resp = await fetch(`${ctx.base}/api/bangumi/v0/me`, {
    headers: { authorization: `Bearer ${sessionToken}` },
  });
  assert.equal(resp.status, 200);
  const json = await resp.json();
  assert.equal(json.auth, 'Bearer refreshed-access');

  assert.equal(ctx.fake.calls.api.length, beforeApi + 1, 'a single (already-fresh) upstream call');
  assert.equal(ctx.fake.calls.token.length, beforeToken + 1, 'exactly one proactive refresh');
});

test('concurrent requests for the same session trigger exactly one refresh', async () => {
  const sessionToken = ctx.store.createSession({
    accessToken: 'stale-access',
    refreshToken: 'test-refresh',
    expiresInSeconds: 604800,
  });
  const beforeToken = ctx.fake.calls.token.length;

  const [a, b] = await Promise.all([
    fetch(`${ctx.base}/api/bangumi/v0/me`, { headers: { authorization: `Bearer ${sessionToken}` } }),
    fetch(`${ctx.base}/api/bangumi/v0/me`, { headers: { authorization: `Bearer ${sessionToken}` } }),
  ]);
  assert.equal(a.status, 200);
  assert.equal(b.status, 200);
  assert.equal(ctx.fake.calls.token.length, beforeToken + 1, 'stampede prevented');
});

test('a delayed stale 401 reuses the token refreshed by another request', async () => {
  let staleCalls = 0;
  let releaseDelayed401;
  const refreshed = new Promise((resolve) => {
    releaseDelayed401 = resolve;
  });
  const calls = { token: 0 };
  const fetchImpl = async (url, init) => {
    const u = String(url);
    if (u === 'https://bgm.tv/oauth/access_token') {
      calls.token += 1;
      releaseDelayed401();
      return jsonResponse(200, {
        access_token: 'new-access',
        refresh_token: 'new-refresh',
        expires_in: 604800,
      });
    }
    if (u.startsWith('https://api.bgm.tv/')) {
      if (init.headers.authorization === 'Bearer stale-delayed') {
        staleCalls += 1;
        if (staleCalls === 2) await refreshed;
        return jsonResponse(401, { error: 'unauthorized' });
      }
      return jsonResponse(200, { auth: init.headers.authorization });
    }
    throw new Error(`unexpected upstream url: ${u}`);
  };
  const local = await startServer({}, { fetchImpl, calls: { token: [], api: [] } });
  try {
    const sessionToken = local.store.createSession({
      accessToken: 'stale-delayed',
      refreshToken: 'old-refresh',
      expiresInSeconds: 604800,
    });
    const headers = { authorization: `Bearer ${sessionToken}` };
    const [a, b] = await Promise.all([
      fetch(`${local.base}/api/bangumi/v0/me`, { headers }),
      fetch(`${local.base}/api/bangumi/v0/me`, { headers }),
    ]);
    assert.equal(a.status, 200);
    assert.equal(b.status, 200);
    assert.equal(calls.token, 1, 'the delayed stale 401 must not rotate twice');
    assert.equal(local.store.getSession(sessionToken).accessToken, 'new-access');
  } finally {
    local.server.close();
  }
});

test('failed refresh deletes the session', async () => {
  // Dedicated server whose fake fails refresh (revoked refresh token).
  const failing = {
    token: [],
    api: [],
  };
  const failFetch = async (url, init) => {
    const u = String(url);
    if (u === 'https://bgm.tv/oauth/access_token') {
      failing.token.push(init);
      return jsonResponse(400, { error: 'invalid_grant' });
    }
    if (u.startsWith('https://api.bgm.tv/')) {
      failing.api.push(init);
      return jsonResponse(401, { error: 'unauthorized' });
    }
    throw new Error(`unexpected upstream url: ${u}`);
  };
  const srv = await startServer({}, { fetchImpl: failFetch, calls: failing });
  try {
    const sessionToken = srv.store.createSession({
      accessToken: 'stale-access',
      refreshToken: 'revoked-refresh',
      expiresInSeconds: 604800, // no proactive refresh; only 401 path
    });
    const resp = await fetch(`${srv.base}/api/bangumi/v0/me`, {
      headers: { authorization: `Bearer ${sessionToken}` },
    });
    assert.equal(resp.status, 401);
    const json = await resp.json();
    assert.equal(json.error, 'session_expired');
    assert.equal(srv.store.getSession(sessionToken), null);
  } finally {
    srv.server.close();
  }
});

test('proxy requires a valid app session', async () => {
  const resp = await fetch(`${ctx.base}/api/bangumi/v0/me`);
  assert.equal(resp.status, 401);
  assert.deepEqual(await resp.json(), { error: 'unauthorized' });
});

test('logout deletes the server session', async () => {
  const { state, ticket } = await oauthToRedirect(ctx);
  const claimed = await (await claim(ctx, ticket, state, VERIFIER)).json();

  const out = await fetch(`${ctx.base}/auth/logout`, {
    method: 'POST',
    headers: { authorization: `Bearer ${claimed.session_token}` },
  });
  assert.equal(out.status, 204);

  const afterResp = await fetch(`${ctx.base}/api/bangumi/v0/me`, {
    headers: { authorization: `Bearer ${claimed.session_token}` },
  });
  assert.equal(afterResp.status, 401);
});

test('security headers and Cache-Control no-store are present', async () => {
  const resp = await fetch(`${ctx.base}/health`);
  assert.equal(resp.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(resp.headers.get('x-frame-options'), 'DENY');
  assert.equal(resp.headers.get('referrer-policy'), 'no-referrer');
  assert.equal(resp.headers.get('cache-control'), 'no-store');
});

test('auth responses are not cached', async () => {
  const start = await fetch(`${ctx.base}/auth/bangumi/start`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ verifier_challenge: CHALLENGE }),
  });
  assert.equal(start.headers.get('cache-control'), 'no-store');
});

test('method not allowed', async () => {
  const resp = await fetch(`${ctx.base}/auth/bangumi/start`);
  assert.equal(resp.status, 405);
  assert.equal(resp.headers.get('allow'), 'POST');
});

test('unknown route is 404', async () => {
  const resp = await fetch(`${ctx.base}/nope`);
  assert.equal(resp.status, 404);
});

test('bounded body is enforced', async () => {
  const small = await startServer({ bodyLimitBytes: 64 });
  try {
    const resp = await fetch(`${small.base}/auth/bangumi/start`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ pad: 'x'.repeat(200) }),
    });
    assert.equal(resp.status, 413);
  } finally {
    small.server.close();
  }
});

test('no permissive CORS unless configured', async () => {
  const resp = await fetch(`${ctx.base}/health`);
  assert.equal(resp.headers.get('access-control-allow-origin'), null);
});

test('configured CORS origin is honored', async () => {
  const cors = await startServer({ corsOrigin: 'https://app.example.com' });
  try {
    const resp = await fetch(`${cors.base}/health`);
    assert.equal(resp.headers.get('access-control-allow-origin'), 'https://app.example.com');
  } finally {
    cors.server.close();
  }
});

test('randomToken is still exported for unrelated callers', async () => {
  assert.ok(randomToken().length >= 43);
});
