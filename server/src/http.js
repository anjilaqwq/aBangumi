// Small HTTP helpers: bounded body reading, and responses with security headers.

export const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'no-referrer',
  'Cross-Origin-Opener-Policy': 'same-origin',
};

/**
 * Read the request body up to `limit` bytes. Rejects with an error carrying
 * `.status = 413` if the body exceeds the limit.
 * @param {import('node:http').IncomingMessage} req
 * @param {number} limit
 * @returns {Promise<Buffer>}
 */
export function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    let done = false;

    const fail = (err) => {
      if (done) return;
      done = true;
      req.removeListener('data', onData);
      req.removeListener('end', onEnd);
      req.removeListener('error', onError);
      reject(err);
    };

    const onData = (chunk) => {
      total += chunk.length;
      if (total > limit) {
        const err = new Error('Request body too large');
        err.status = 413;
        fail(err);
        req.resume(); // drain
        return;
      }
      chunks.push(chunk);
    };

    const onEnd = () => {
      if (done) return;
      done = true;
      resolve(Buffer.concat(chunks));
    };

    const onError = (err) => {
      fail(err);
    };

    req.on('data', onData);
    req.on('end', onEnd);
    req.on('error', onError);
  });
}

/**
 * Send a JSON response with security + no-store headers.
 * @param {import('node:http').ServerResponse} res
 * @param {number} status
 * @param {unknown} payload
 * @param {{ corsOrigin?: string, extraHeaders?: Record<string, string> }} [opts]
 */
export function sendJson(res, status, payload, opts = {}) {
  const body = Buffer.from(JSON.stringify(payload));
  const headers = {
    ...SECURITY_HEADERS,
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': String(body.length),
    ...(opts.extraHeaders ?? {}),
  };
  applyCors(headers, opts.corsOrigin);
  res.writeHead(status, headers);
  res.end(body);
}

/**
 * Send an empty response with security + no-store headers.
 * @param {import('node:http').ServerResponse} res
 * @param {number} status
 * @param {{ corsOrigin?: string, extraHeaders?: Record<string, string> }} [opts]
 */
export function sendEmpty(res, status, opts = {}) {
  const headers = {
    ...SECURITY_HEADERS,
    'Cache-Control': 'no-store',
    ...(opts.extraHeaders ?? {}),
  };
  applyCors(headers, opts.corsOrigin);
  res.writeHead(status, headers);
  res.end();
}

/**
 * Copy a Fetch response back to the client, preserving status and content-type
 * (plus security headers). The body is passed through verbatim.
 * @param {import('node:http').ServerResponse} res
 * @param {Response} upstream
 * @param {{ corsOrigin?: string }} [opts]
 */
export async function sendUpstream(res, upstream, opts = {}) {
  const headers = { ...SECURITY_HEADERS, 'Cache-Control': 'no-store' };
  const ct = upstream.headers.get('content-type');
  if (ct) headers['Content-Type'] = ct;
  const len = upstream.headers.get('content-length');
  if (len) headers['Content-Length'] = len;
  applyCors(headers, opts.corsOrigin);

  const body = Buffer.from(await upstream.arrayBuffer());
  res.writeHead(upstream.status, headers);
  res.end(body);
}

/**
 * Send a minimal HTML page (used for the browser-facing OAuth callback denial
 * paths). Contains no sensitive details; never cached.
 * @param {import('node:http').ServerResponse} res
 * @param {number} status
 * @param {string} html
 */
export function sendHtml(res, status, html) {
  const body = Buffer.from(html, 'utf8');
  res.writeHead(status, {
    ...SECURITY_HEADERS,
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': String(body.length),
  });
  res.end(body);
}

/**
 * Send a 302 redirect to the app's custom scheme. Security headers are applied
 * and the Location is never cached.
 * @param {import('node:http').ServerResponse} res
 * @param {string} location
 */
export function sendRedirect(res, location) {
  res.writeHead(302, {
    ...SECURITY_HEADERS,
    'Cache-Control': 'no-store',
    Location: location,
  });
  res.end();
}

function applyCors(headers, corsOrigin) {
  if (!corsOrigin) return;
  headers['Access-Control-Allow-Origin'] = corsOrigin;
  headers['Vary'] = 'Origin';
}
