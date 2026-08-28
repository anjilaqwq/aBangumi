// Cryptographically secure random tokens, SHA-256 challenge derivation, and
// constant-time secret comparison.
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

const DEFAULT_BYTES = 32; // 256 bits

/**
 * Generate a URL-safe, cryptographically random token (base64url).
 * @param {number} [bytes] Number of random bytes (>=32 gives >=256 bits).
 * @returns {string}
 */
export function randomToken(bytes = DEFAULT_BYTES) {
  if (!Number.isInteger(bytes) || bytes < 32) {
    throw new Error('randomToken requires at least 32 bytes (256 bits)');
  }
  return randomBytes(bytes).toString('base64url');
}

/**
 * SHA-256 digest of a string, hex-encoded (lowercase). Used to bind a client
 * PKCE-style verifier challenge to a pending state. The verifier itself is
 * never stored or logged — only this one-way challenge.
 * @param {string | Buffer} input
 * @returns {string} 64 lowercase hex characters
 */
export function sha256Hex(input) {
  return createHash('sha256')
    .update(typeof input === 'string' ? Buffer.from(input, 'utf8') : input)
    .digest('hex');
}

/**
 * A challenge must be exactly 64 lowercase hex chars (SHA-256 digest).
 * @param {unknown} challenge
 * @returns {boolean}
 */
export function isValidChallenge(challenge) {
  return typeof challenge === 'string' && /^[0-9a-f]{64}$/.test(challenge);
}

/**
 * A verifier must be canonical base64url encoding of >=32 bytes (256 bits) and
 * bounded in size. Canonicality is enforced by a decode → re-encode round-trip
 * so we never accept junk or padding.
 * @param {unknown} verifier
 * @returns {boolean}
 */
export function isValidVerifier(verifier) {
  if (typeof verifier !== 'string') return false;
  if (verifier.length < 43 || verifier.length > 128) return false;
  if (!/^[A-Za-z0-9_-]+$/.test(verifier)) return false;
  const buf = Buffer.from(verifier, 'base64url');
  if (buf.length < 32 || buf.length > 96) return false;
  return buf.toString('base64url') === verifier;
}

/**
 * Constant-time string comparison. Returns false on length mismatch (which,
 * by necessity, leaks only the length — tokens here are fixed-length).
 * @param {string} a
 * @param {string} b
 * @returns {boolean}
 */
export function timingSafeEqualStr(a, b) {
  const ab = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ab.length !== bb.length) return false;
  return timingSafeEqual(ab, bb);
}

/**
 * Constant-time Map lookup by string key. Iterates every entry so the number
 * of comparisons does not depend on whether the key matches.
 * @template T
 * @param {Map<string, T>} map
 * @param {string} key
 * @returns {T | undefined}
 */
export function constantTimeMapGet(map, key) {
  const k = String(key);
  let found;
  for (const [candidate, value] of map) {
    if (timingSafeEqualStr(candidate, k)) found = value;
  }
  return found;
}

/**
 * Constant-time Map delete by string key (returns the removed value).
 * @template T
 * @param {Map<string, T>} map
 * @param {string} key
 * @returns {T | undefined}
 */
export function constantTimeMapDelete(map, key) {
  const k = String(key);
  let removed;
  for (const [candidate, value] of map) {
    if (timingSafeEqualStr(candidate, k)) {
      removed = value;
      map.delete(candidate);
    }
  }
  return removed;
}
