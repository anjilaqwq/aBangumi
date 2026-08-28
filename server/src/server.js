// HTTP request handler (router) for the aBangumi auth BFF.
//
// Endpoints:
//   GET  /health
//   POST /auth/bangumi/start
//   GET  /auth/bangumi/callback
//   POST /auth/bangumi/claim
//   POST /auth/logout
//   *    /api/bangumi/*   (app-session-authenticated proxy to api.bgm.tv)
import {
  buildAuthorizationUrl,
  exchangeCode,
  proxyToBangumi,
} from './bangumi.js';
import { bangumiRedirectUri } from './config.js';
import {
  readBody,
  sendEmpty,
  sendHtml,
  sendJson,
  sendRedirect,
  sendUpstream,
} from './http.js';
import { isValidChallenge, isValidVerifier, sha256Hex, timingSafeEqualStr } from './random.js';

const PROXY_METHODS = new Set(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);

// Minimal, safe denial page shown in the browser when the OAuth callback fails.
// Deliberately generic: it must never echo codes, states, tokens, or errors.
const DENIAL_HTML =
  '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">' +
  '<meta name="viewport" content="width=device-width, initial-scale=1">' +
  '<title>授权失败</title></head><body style="font-family:system-ui,sans-serif;' +
  'background:#fafaf7;color:#1a1a18;padding:40px;text-align:center">' +
  '<h1 style="font-weight:400">登录未完成</h1>' +
  '<p>授权已中止或失效，请返回应用重新登录。你可以关闭此页面。</p>' +
  '</body></html>';

/**
 * Create a Node http request listener.
 * @param {{ config: import('./types.js').Config, store: import('./store.js').MemoryStore, fetchImpl?: typeof fetch, log?: (msg: string) => void }} deps
 * @returns {(req: import('node:http').IncomingMessage, res: import('node:http').ServerResponse) => void}
 */
export function createApp({ config, store, fetchImpl = fetch, log = () => {} }) {
  const corsOrigin = config.corsOrigin || '';

  return async (req, res) => {
    try {
      await handle(req, res);
    } catch (err) {
      const status = err && typeof err.status === 'number' ? err.status : 500;
      if (status >= 500) {
        // Never log bodies, tokens, or query strings — only the failure class.
        log(`error status=${status} message=${err instanceof Error ? err.message : 'unknown'}`);
      }
      if (!res.headersSent) {
        sendJson(res, status, { error: status >= 500 ? 'internal_error' : 'bad_request' }, { corsOrigin });
      } else {
        res.end();
      }
    }
  };

  /**
   * @param {import('node:http').IncomingMessage} req
   * @param {import('node:http').ServerResponse} res
   */
  async function handle(req, res) {
    const url = new URL(req.url, 'http://internal');
    const { pathname, search } = url;

    // ----- CORS preflight (only when an origin is configured) -----
    if (corsOrigin && req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': corsOrigin,
        'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type',
        'Access-Control-Max-Age': '86400',
        Vary: 'Origin',
      });
      res.end();
      return;
    }

    if (req.method === 'GET' && pathname === '/health') {
      return sendJson(res, 200, { status: 'ok' }, { corsOrigin });
    }

    if (pathname === '/auth/bangumi/start') {
      if (req.method !== 'POST') return methodNotAllowed(res, ['POST']);
      return start(req, res);
    }

    if (pathname === '/auth/bangumi/callback') {
      if (req.method !== 'GET') return methodNotAllowed(res, ['GET']);
      return callback(req, res, url);
    }

    if (pathname === '/auth/bangumi/claim') {
      if (req.method !== 'POST') return methodNotAllowed(res, ['POST']);
      return claim(req, res);
    }

    if (pathname === '/auth/logout') {
      if (req.method !== 'POST') return methodNotAllowed(res, ['POST']);
      return logout(req, res);
    }

    if (pathname.startsWith('/api/bangumi/')) {
      if (!PROXY_METHODS.has(req.method)) {
        return methodNotAllowed(res, [...PROXY_METHODS]);
      }
      return proxy(req, res, pathname, search);
    }

    return sendJson(res, 404, { error: 'not_found' }, { corsOrigin });
  }

  async function start(req, res) {
    const body = await readJsonBody(req, res, config.bodyLimitBytes);
    if (body === null) return; // error already sent

    // The app sends only the SHA-256 challenge of its claim verifier. The
    // verifier itself never reaches the server, any URL, or any log.
    const challenge = typeof body.verifier_challenge === 'string' ? body.verifier_challenge : '';
    if (!isValidChallenge(challenge)) {
      return sendJson(res, 400, { error: 'invalid_challenge' }, { corsOrigin });
    }

    const state = store.createState(challenge);
    const redirectUri = bangumiRedirectUri(config);
    const authorizationUrl = buildAuthorizationUrl({
      clientId: config.clientId,
      redirectUri,
      state,
    });

    return sendJson(
      res,
      200,
      { authorization_url: authorizationUrl, state },
      { corsOrigin },
    );
  }

  async function callback(req, res, url) {
    const code = url.searchParams.get('code');
    const state = url.searchParams.get('state');
    const error = url.searchParams.get('error');

    // This endpoint is hit by the user's browser after Bangumi redirects back.
    // Every failure path returns a minimal, generic HTML page — never JSON with
    // codes/state/error details.
    if (error) {
      return sendHtml(res, 400, DENIAL_HTML);
    }
    if (!code || !state) {
      return sendHtml(res, 400, DENIAL_HTML);
    }

    // Consume the state exactly once, before doing any work, so a replay is
    // impossible even if the code exchange fails. Returns the bound challenge.
    const consumed = store.consumeState(state);
    if (!consumed) {
      return sendHtml(res, 400, DENIAL_HTML);
    }

    let tokens;
    try {
      tokens = await exchangeCode({
        clientId: config.clientId,
        clientSecret: config.clientSecret,
        code,
        redirectUri: bangumiRedirectUri(config),
        fetchImpl,
      });
    } catch (err) {
      return sendHtml(res, err.status === 502 ? 502 : 400, DENIAL_HTML);
    }

    const sessionToken = store.createSession({
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
      expiresInSeconds: tokens.expires_in,
    });
    const ticket = store.createTicket(sessionToken, state, consumed.challenge);

    // The redirect carries only a short-lived one-time ticket and the state;
    // access/refresh tokens and the verifier never leave the server in a URL.
    const qs = new URLSearchParams({ ticket, state });
    return sendRedirect(res, `${config.appCallbackUri}?${qs.toString()}`);
  }

  async function claim(req, res) {
    const body = await readJsonBody(req, res, config.bodyLimitBytes);
    if (body === null) return;

    const ticket = typeof body.ticket === 'string' ? body.ticket : '';
    const state = typeof body.state === 'string' ? body.state : '';
    const verifier = typeof body.verifier === 'string' ? body.verifier : '';
    if (!ticket || !state || !verifier) {
      return sendJson(res, 400, { error: 'missing_params' }, { corsOrigin });
    }
    if (!isValidVerifier(verifier)) {
      return sendJson(res, 400, { error: 'invalid_verifier' }, { corsOrigin });
    }

    // Peek (do NOT consume) the ticket. A wrong/missing verifier must never
    // burn the legitimate app's ticket, so an intercepted `ticket`+`state`
    // alone cannot deny the real app its one claim.
    const entry = store.peekTicket(ticket);
    if (!entry) {
      return sendJson(res, 400, { error: 'invalid_ticket' }, { corsOrigin });
    }

    const stateOk = timingSafeEqualStr(entry.state, state);
    const challengeOk = timingSafeEqualStr(sha256Hex(verifier), entry.challenge);
    if (!stateOk || !challengeOk) {
      return sendJson(res, 400, { error: 'invalid_ticket' }, { corsOrigin });
    }

    // Consume and return the linkage atomically; a concurrent claimant must fail.
    const consumed = store.consumeTicketIfMatches(ticket, state, sha256Hex(verifier));
    if (!consumed) {
      return sendJson(res, 400, { error: 'invalid_ticket' }, { corsOrigin });
    }

    const session = store.getSession(consumed.sessionToken);
    if (!session) {
      return sendJson(res, 401, { error: 'invalid_session' }, { corsOrigin });
    }

    return sendJson(
      res,
      200,
      {
        session_token: consumed.sessionToken,
        // Opaque app-session expiry (independent of the Bangumi access-token
        // lifetime, which is refreshed transparently by the proxy).
        expires_at: new Date(session.sessionExpiresAt).toISOString(),
      },
      { corsOrigin },
    );
  }

  async function logout(req, res) {
    const sessionToken = bearerToken(req);
    if (!sessionToken) {
      return sendJson(res, 401, { error: 'unauthorized' }, { corsOrigin });
    }
    store.deleteSession(sessionToken);
    return sendEmpty(res, 204, { corsOrigin });
  }

  async function proxy(req, res, pathname, search) {
    const sessionToken = bearerToken(req);
    if (!sessionToken) {
      return sendJson(res, 401, { error: 'unauthorized' }, { corsOrigin });
    }

    const body = req.method === 'GET' || req.method === 'DELETE'
      ? null
      : await readBody(req, config.bodyLimitBytes).catch((err) => {
          if (err && err.status === 413) {
            sendJson(res, 413, { error: 'payload_too_large' }, { corsOrigin });
          }
          throw err;
        });

    // /api/bangumi/v0/me?foo=1  ->  /v0/me?foo=1
    const upstreamPath = pathname.slice('/api/bangumi'.length) + (search ?? '');

    const upstream = await proxyToBangumi({
      config,
      store,
      sessionToken,
      method: req.method,
      path: upstreamPath,
      headers: req.headers,
      body,
      fetchImpl,
    });

    return sendUpstream(res, upstream, { corsOrigin });
  }
}

function methodNotAllowed(res, allow) {
  return sendJson(
    res,
    405,
    { error: 'method_not_allowed' },
    { extraHeaders: { Allow: allow.join(', ') } },
  );
}

function bearerToken(req) {
  const header = req.headers.authorization;
  if (typeof header !== 'string') return null;
  const m = /^Bearer\s+([A-Za-z0-9_-]+)$/.exec(header.trim());
  return m ? m[1] : null;
}

/**
 * Read and JSON-parse a bounded request body. On error an appropriate response
 * is sent and null is returned.
 */
async function readJsonBody(req, res, limit) {
  let raw;
  try {
    raw = await readBody(req, limit);
  } catch (err) {
    if (err && err.status === 413) {
      sendJson(res, 413, { error: 'payload_too_large' });
    } else {
      sendJson(res, 400, { error: 'bad_request' });
    }
    return null;
  }

  if (raw.length === 0) return {};
  try {
    const parsed = JSON.parse(raw.toString('utf8'));
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      sendJson(res, 400, { error: 'bad_request' });
      return null;
    }
    return parsed;
  } catch {
    sendJson(res, 400, { error: 'bad_request' });
    return null;
  }
}
