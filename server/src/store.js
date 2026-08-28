// In-memory storage for pending states, opaque app sessions, and one-time
// tickets. This is a single-instance, non-durable store: restarting the BFF
// invalidates every pending state, session, and ticket. For production with
// more than one replica, replace this with Redis or a database (see SECURITY.md).
import {
  constantTimeMapDelete,
  constantTimeMapGet,
  randomToken,
  timingSafeEqualStr,
} from './random.js';

const MS_DAY = 24 * 60 * 60 * 1000;

export class MemoryStore {
  /**
   * @param {{ now?: () => number, stateTtlMs?: number, ticketTtlMs?: number, sessionTtlMs?: number }} [opts]
   */
  constructor(opts = {}) {
    this._now = opts.now ?? (() => Date.now());
    this.stateTtlMs = opts.stateTtlMs ?? 5 * 60 * 1000;
    this.ticketTtlMs = opts.ticketTtlMs ?? 60 * 1000;
    // The opaque app session is independent of the Bangumi access-token
    // lifetime: it survives many access-token refreshes and only expires after
    // this long without a successful refresh.
    this.sessionTtlMs = opts.sessionTtlMs ?? 30 * MS_DAY;

    /** @type {Map<string, { challenge: string, expiresAt: number }>} */
    this.states = new Map();
    /** @type {Map<string, import('./types.js').Session>} */
    this.sessions = new Map();
    /** @type {Map<string, { sessionToken: string, state: string, challenge: string, expiresAt: number }>} */
    this.tickets = new Map();
    /** @type {Map<string, Promise<unknown>>} per-session refresh locks */
    this.refreshLocks = new Map();
  }

  /** Current time source (injectable for tests). */
  now() {
    return this._now();
  }

  // ----- pending state -----

  /**
   * Create a pending state bound to a client verifier challenge.
   * @param {string} challenge SHA-256 hex of the client's claim verifier.
   * @returns {string} the random state
   */
  createState(challenge) {
    const state = randomToken();
    this.states.set(state, { challenge, expiresAt: this._now() + this.stateTtlMs });
    return state;
  }

  /**
   * Consume a state exactly once. Returns its bound challenge, or null when
   * missing/expired. Consuming on a failed code exchange is deliberate: the
   * state may never be reused.
   * @param {string} state
   * @returns {{ challenge: string } | null}
   */
  consumeState(state) {
    const entry = constantTimeMapDelete(this.states, state);
    if (!entry) return null;
    if (entry.expiresAt <= this._now()) return null;
    return { challenge: entry.challenge };
  }

  // ----- app sessions -----

  /**
   * Create an opaque session and store its Bangumi tokens server-side. The
   * session lifetime is independent of the access-token lifetime.
   * @param {{ accessToken: string, refreshToken: string, expiresInSeconds?: number }} tokens
   * @returns {string} the opaque session token handed to the app
   */
  createSession({ accessToken, refreshToken, expiresInSeconds }) {
    const sessionToken = randomToken();
    const now = this._now();
    this.sessions.set(sessionToken, {
      accessToken,
      refreshToken,
      accessExpiresAt: accessExpiresAt(now, expiresInSeconds),
      sessionExpiresAt: now + this.sessionTtlMs,
      createdAt: now,
    });
    return sessionToken;
  }

  /**
   * Look up a session. It is deleted only when the *session* has expired —
   * never merely because the Bangumi access token has expired (that is handled
   * by a transparent refresh, not a logout).
   * @param {string} sessionToken
   * @returns {import('./types.js').Session | null}
   */
  getSession(sessionToken) {
    const entry = constantTimeMapGet(this.sessions, sessionToken);
    if (!entry) return null;
    if (entry.sessionExpiresAt <= this._now()) {
      this.sessions.delete(sessionToken);
      return null;
    }
    return entry;
  }

  /**
   * Update a session's tokens after a transparent refresh (rotating refresh
   * token). Only the access token, its expiry, and the refresh token change;
   * the session lifetime is untouched.
   * @param {string} sessionToken
   * @param {{ accessToken: string, refreshToken?: string, accessExpiresInSeconds?: number }} tokens
   * @returns {boolean}
   */
  updateSession(sessionToken, { accessToken, refreshToken, accessExpiresInSeconds }) {
    const entry = this.getSession(sessionToken);
    if (!entry) return false;
    entry.accessToken = accessToken;
    if (refreshToken) entry.refreshToken = refreshToken;
    entry.accessExpiresAt = accessExpiresAt(this._now(), accessExpiresInSeconds);
    return true;
  }

  deleteSession(sessionToken) {
    return constantTimeMapDelete(this.sessions, sessionToken) !== undefined;
  }

  // ----- per-session refresh lock -----

  /**
   * Run `run()` at most once concurrently per session. Concurrent callers all
   * await the same in-flight promise (stampede prevention). The lock is always
   * released when `run` settles.
   * @template T
   * @param {string} sessionToken
   * @param {() => Promise<T>} run
   * @returns {Promise<T>}
   */
  refreshSession(sessionToken, run) {
    const inflight = this.refreshLocks.get(sessionToken);
    if (inflight) return inflight;
    const p = (async () => {
      try {
        return await run();
      } finally {
        this.refreshLocks.delete(sessionToken);
      }
    })();
    this.refreshLocks.set(sessionToken, p);
    return p;
  }

  // ----- one-time tickets -----

  /**
   * Create a one-time ticket linking a session to the pending state (and its
   * verifier challenge) so the app can prove it completed the flow.
   * @param {string} sessionToken
   * @param {string} state
   * @param {string} challenge
   * @returns {string} ticket
   */
  createTicket(sessionToken, state, challenge) {
    const ticket = randomToken();
    this.tickets.set(ticket, {
      sessionToken,
      state,
      challenge,
      expiresAt: this._now() + this.ticketTtlMs,
    });
    return ticket;
  }

  /**
   * Peek at a ticket WITHOUT consuming it. Used to verify state + verifier
   * before the (only-on-success) consume step, so a wrong-verifier attempt can
   * never burn the legitimate app's ticket.
   * @param {string} ticket
   * @returns {{ sessionToken: string, state: string, challenge: string } | null}
   */
  peekTicket(ticket) {
    const entry = constantTimeMapGet(this.tickets, ticket);
    if (!entry) return null;
    if (entry.expiresAt <= this._now()) return null;
    return { sessionToken: entry.sessionToken, state: entry.state, challenge: entry.challenge };
  }

  /** Consume a ticket exactly once. Returns its linkage or null. */
  consumeTicket(ticket) {
    const entry = constantTimeMapDelete(this.tickets, ticket);
    if (!entry) return null;
    if (entry.expiresAt <= this._now()) return null;
    return { sessionToken: entry.sessionToken, state: entry.state, challenge: entry.challenge };
  }

  /**
   * Verify and consume a ticket in one synchronous critical section.
   * Mismatched credentials never remove the legitimate app's ticket.
   */
  consumeTicketIfMatches(ticket, state, challenge) {
    const entry = constantTimeMapGet(this.tickets, ticket);
    if (!entry) return null;
    if (entry.expiresAt <= this._now()) {
      constantTimeMapDelete(this.tickets, ticket);
      return null;
    }
    if (!timingSafeEqualStr(entry.state, state) || !timingSafeEqualStr(entry.challenge, challenge)) {
      return null;
    }
    const consumed = constantTimeMapDelete(this.tickets, ticket);
    if (!consumed) return null;
    return {
      sessionToken: consumed.sessionToken,
      state: consumed.state,
      challenge: consumed.challenge,
    };
  }

  // ----- maintenance -----

  /** Remove expired entries. Returns the number removed. */
  cleanup() {
    let removed = 0;
    const now = this._now();
    for (const [key, value] of this.states) {
      if (value.expiresAt <= now) {
        this.states.delete(key);
        removed += 1;
      }
    }
    for (const [key, value] of this.sessions) {
      if (value.sessionExpiresAt <= now) {
        this.sessions.delete(key);
        removed += 1;
      }
    }
    for (const [key, value] of this.tickets) {
      if (value.expiresAt <= now) {
        this.tickets.delete(key);
        removed += 1;
      }
    }
    return removed;
  }

  /**
   * Start periodic cleanup. The returned timer is `.unref()`'d so it never
   * keeps the process (or tests) alive.
   * @param {number} intervalMs
   */
  startCleanup(intervalMs = 60 * 1000) {
    return setInterval(() => this.cleanup(), intervalMs).unref();
  }
}

/**
 * Compute an access-token expiry timestamp. 0 means "unknown" (no proactive
 * refresh); the session lifetime governs expiry in that case.
 * @param {number} now
 * @param {number | undefined} expiresInSeconds
 */
function accessExpiresAt(now, expiresInSeconds) {
  return Number.isFinite(expiresInSeconds) && expiresInSeconds > 0
    ? now + expiresInSeconds * 1000
    : 0;
}
