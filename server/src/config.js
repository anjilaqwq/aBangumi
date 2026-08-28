// Environment configuration for the aBangumi auth BFF.
//
// Nothing here ever contains a real secret; the client secret is read from the
// environment at runtime and never logged, cached to disk, or echoed back.

const MS_MINUTE = 60 * 1000;
const MS_HOUR = 60 * MS_MINUTE;
const MS_DAY = 24 * MS_HOUR;

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1', '[::1]']);

/**
 * Build a config object from the environment.
 * @param {NodeJS.ProcessEnv} [env]
 * @returns {import('./types.js').Config}
 */
export function loadConfig(env = process.env) {
  const config = {
    port: intFromEnv(env, 'PORT', 8787),
    clientId: (env.BANGUMI_CLIENT_ID ?? '').trim(),
    clientSecret: env.BANGUMI_CLIENT_SECRET ?? '',
    publicBaseUrl: (env.PUBLIC_BASE_URL ?? '').trim().replace(/\/+$/, ''),
    appCallbackUri: (env.APP_CALLBACK_URI ?? 'abangumi://oauth/callback').trim(),
    corsOrigin: (env.CORS_ORIGIN ?? '').trim(),
    stateTtlMs: intFromEnv(env, 'STATE_TTL_MS', 5 * MS_MINUTE),
    ticketTtlMs: intFromEnv(env, 'TICKET_TTL_MS', 60 * 1000),
    sessionTtlMs: intFromEnv(env, 'SESSION_TTL_MS', 30 * MS_DAY),
    bodyLimitBytes: intFromEnv(env, 'BODY_LIMIT_BYTES', 1024 * 1024),
  };
  validateConfig(config);
  return config;
}

function intFromEnv(env, name, fallback) {
  const raw = env[name];
  if (raw === undefined || raw === '') return fallback;
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) {
    throw new Error(`${name} must be a positive number, got: ${raw}`);
  }
  return Math.floor(n);
}

/**
 * Validate a config object, throwing on unsafe/insufficient values.
 * @param {import('./types.js').Config} config
 */
export function validateConfig(config) {
  if (!config.clientId) {
    throw new Error('BANGUMI_CLIENT_ID is required');
  }
  if (!config.clientSecret) {
    throw new Error('BANGUMI_CLIENT_SECRET is required (use an empty value only in .env.example)');
  }

  let parsed;
  try {
    parsed = new URL(config.publicBaseUrl);
  } catch {
    throw new Error('PUBLIC_BASE_URL must be an absolute URL');
  }

  const isLocal = LOCAL_HOSTS.has(parsed.hostname.toLowerCase());
  if (parsed.protocol !== 'https:' && !isLocal) {
    throw new Error(
      'PUBLIC_BASE_URL must use https:// (http is only allowed for localhost/127.0.0.1)',
    );
  }

  if (!config.appCallbackUri.startsWith('abangumi://')) {
    throw new Error('APP_CALLBACK_URI must use the abangumi:// custom scheme');
  }

  if (config.stateTtlMs > 5 * MS_MINUTE) {
    throw new Error('STATE_TTL_MS must not exceed 5 minutes');
  }
  if (config.ticketTtlMs > 60 * 1000) {
    throw new Error('TICKET_TTL_MS must not exceed 60 seconds');
  }
  if (config.bodyLimitBytes < 1024 || config.bodyLimitBytes > 8 * 1024 * 1024) {
    throw new Error('BODY_LIMIT_BYTES must be between 1024 and 8388608');
  }

  return config;
}

/** Bangumi OAuth callback URL (must be registered in the developer console). */
export function bangumiRedirectUri(config) {
  return `${config.publicBaseUrl}/auth/bangumi/callback`;
}
