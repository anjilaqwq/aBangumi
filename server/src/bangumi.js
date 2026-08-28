// Bangumi (bgm.tv) OAuth + API client. Only talks to the two fixed hosts
// https://bgm.tv and https://api.bgm.tv — never an arbitrary host.
import { bangumiRedirectUri } from './config.js';

export const BANGUMI_AUTHORIZE_URL = 'https://bgm.tv/oauth/authorize';
export const BANGUMI_TOKEN_URL = 'https://bgm.tv/oauth/access_token';
export const BANGUMI_API_ORIGIN = 'https://api.bgm.tv';

/** Refresh the access token proactively when it expires within this window. */
export const REFRESH_WINDOW_MS = 60 * 1000;

const UPSTREAM_USER_AGENT = 'aBangumi/1.1.0 (https://github.com/anjilaqwq/aBangumi)';

/** Hop-by-hop / connection headers we must not forward upstream. */
const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'host',
  'content-length',
  'authorization',
  'cookie',
]);

/**
 * Build the Bangumi authorize URL. redirect_uri and state are percent-encoded
 * by URLSearchParams automatically.
 * @param {{ clientId: string, redirectUri: string, state: string }} p
 */
export function buildAuthorizationUrl({ clientId, redirectUri, state }) {
  const url = new URL(BANGUMI_AUTHORIZE_URL);
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('state', state);
  return url.toString();
}

async function postToken(fetchImpl, params) {
  const body = new URLSearchParams(params);
  const resp = await fetchImpl(BANGUMI_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': UPSTREAM_USER_AGENT,
    },
    body: body.toString(),
  });

  const text = await resp.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    /* non-JSON error body */
  }

  if (!resp.ok) {
    const err = new Error(`Bangumi token request failed (HTTP ${resp.status})`);
    err.status = resp.status;
    err.detail = json;
    throw err;
  }
  if (!json || typeof json.access_token !== 'string' || !json.access_token) {
    const err = new Error('Bangumi token response missing access_token');
    err.status = 502;
    throw err;
  }
  return json;
}

/**
 * Exchange an authorization code for tokens. Requires the client secret.
 * @param {{ clientId: string, clientSecret: string, code: string, redirectUri: string, fetchImpl?: typeof fetch }} p
 */
export function exchangeCode({ clientId, clientSecret, code, redirectUri, fetchImpl = fetch }) {
  return postToken(fetchImpl, {
    grant_type: 'authorization_code',
    client_id: clientId,
    client_secret: clientSecret,
    code,
    redirect_uri: redirectUri,
  });
}

/**
 * Refresh with a rotating refresh token. Requires the client secret and, per
 * the Bangumi OAuth protocol, the same `redirect_uri` used in the original
 * authorization request (the BFF's HTTPS callback).
 * @param {{ clientId: string, clientSecret: string, refreshToken: string, redirectUri: string, fetchImpl?: typeof fetch }} p
 */
export function refreshTokens({ clientId, clientSecret, refreshToken, redirectUri, fetchImpl = fetch }) {
  return postToken(fetchImpl, {
    grant_type: 'refresh_token',
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    redirect_uri: redirectUri,
  });
}

/**
 * Pick the client request headers we forward upstream. We never forward the
 * app's Authorization, Host, or connection-level headers.
 * @param {Record<string, string | string[] | undefined>} headers
 */
function forwardHeaders(headers) {
  const out = {};
  for (const [name, value] of Object.entries(headers ?? {})) {
    const lower = name.toLowerCase();
    if (HOP_BY_HOP.has(lower)) continue;
    if (value === undefined) continue;
    out[lower] = Array.isArray(value) ? value.join(', ') : value;
  }
  if (!out['user-agent']) out['user-agent'] = UPSTREAM_USER_AGENT;
  return out;
}

/**
 * Proxy one request to api.bgm.tv using the session's current access token.
 *
 * Refresh policy:
 * - proactively refresh when the access token expires within
 *   `REFRESH_WINDOW_MS` (avoids a doomed 401 round-trip);
 * - otherwise, refresh on a 401 and retry exactly once.
 *
 * Concurrent requests for the same session share a single refresh via
 * `store.refreshSession` (stampede prevention), and a rotating refresh token is
 * persisted atomically by `store.updateSession` inside that lock.
 *
 * Returns a Fetch Response; the caller copies status/headers/body back to the
 * app verbatim.
 *
 * @param {object} p
 * @param {import('./types.js').Config} p.config
 * @param {import('./store.js').MemoryStore} p.store
 * @param {string} p.sessionToken
 * @param {string} p.method
 * @param {string} p.path   upstream path+query, starting with "/" (e.g. "/v0/me")
 * @param {Record<string, string | string[] | undefined>} p.headers
 * @param {Buffer | null} p.body
 * @param {typeof fetch} [p.fetchImpl]
 */
export async function proxyToBangumi({
  config,
  store,
  sessionToken,
  method,
  path,
  headers,
  body,
  fetchImpl = fetch,
}) {
  const session = store.getSession(sessionToken);
  if (!session) {
    return jsonResponse(401, { error: 'invalid_session', message: 'App session not found or expired' });
  }

  // Path must stay rooted at api.bgm.tv; reject anything that could escape.
  const upstream = new URL(BANGUMI_API_ORIGIN + normalizeUpstreamPath(path));
  const redirectUri = bangumiRedirectUri(config);

  const refresh = (failedAccessToken) =>
    store.refreshSession(sessionToken, async () => {
      const s = store.getSession(sessionToken);
      if (!s) throw new Error('session disappeared during refresh');
      // A delayed 401 may arrive after another request already refreshed the
      // rotating token. Reuse that newer session instead of rotating twice.
      if (failedAccessToken && s.accessToken !== failedAccessToken) return s;
      const refreshed = await refreshTokens({
        clientId: config.clientId,
        clientSecret: config.clientSecret,
        refreshToken: s.refreshToken,
        redirectUri,
        fetchImpl,
      });
      store.updateSession(sessionToken, {
        accessToken: refreshed.access_token,
        refreshToken: refreshed.refresh_token,
        accessExpiresInSeconds: refreshed.expires_in,
      });
      return store.getSession(sessionToken);
    });

  const doFetch = (accessToken) =>
    fetchImpl(upstream, {
      method,
      headers: {
        ...forwardHeaders(headers),
        authorization: `Bearer ${accessToken}`,
      },
      body,
      redirect: 'follow',
    });

  let current = session;
  if (needsRefresh(current, store.now())) {
    try {
      current = await refresh(current.accessToken);
    } catch {
      store.deleteSession(sessionToken);
      return jsonResponse(401, {
        error: 'session_expired',
        message: 'Session refresh failed; please re-authenticate',
      });
    }
  }
  if (!current) {
    return jsonResponse(401, { error: 'invalid_session', message: 'App session not found or expired' });
  }

  let resp = await doFetch(current.accessToken);

  if (resp.status === 401) {
    try {
      current = await refresh(current.accessToken);
      resp = await doFetch(current.accessToken);
    } catch {
      // Refresh failed: the session's refresh token is gone/revoked/expired.
      store.deleteSession(sessionToken);
      return jsonResponse(401, {
        error: 'session_expired',
        message: 'Session refresh failed; please re-authenticate',
      });
    }
  }

  return resp;
}

function needsRefresh(session, now) {
  return session.accessExpiresAt > 0 && session.accessExpiresAt <= now + REFRESH_WINDOW_MS;
}

function normalizeUpstreamPath(path) {
  if (typeof path !== 'string' || path.length === 0 || !path.startsWith('/')) {
    throw new Error('upstream path must start with "/"');
  }
  return path;
}

function jsonResponse(status, obj) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}
