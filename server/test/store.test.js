import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MemoryStore } from '../src/store.js';

const CHALLENGE = 'a'.repeat(64);

test('state is created with a bound challenge and consumed exactly once', () => {
  const store = new MemoryStore({ stateTtlMs: 5000 });
  const state = store.createState(CHALLENGE);
  assert.deepEqual(store.consumeState(state), { challenge: CHALLENGE });
  assert.equal(store.consumeState(state), null, 'state must be one-time');
});

test('state expires after TTL', () => {
  let now = 0;
  const store = new MemoryStore({ now: () => now, stateTtlMs: 1000 });
  const state = store.createState(CHALLENGE);
  now = 1001;
  assert.equal(store.consumeState(state), null);
});

test('ticket links session+state+challenge and is peekable before consume', () => {
  const store = new MemoryStore({ ticketTtlMs: 5000 });
  const sessionToken = store.createSession({ accessToken: 'a', refreshToken: 'r', expiresInSeconds: 100 });
  const ticket = store.createTicket(sessionToken, 'the-state', CHALLENGE);

  const peek = store.peekTicket(ticket);
  assert.deepEqual(peek, { sessionToken, state: 'the-state', challenge: CHALLENGE });

  // peek does NOT consume
  assert.deepEqual(store.peekTicket(ticket), peek);

  const consumed = store.consumeTicket(ticket);
  assert.deepEqual(consumed, { sessionToken, state: 'the-state', challenge: CHALLENGE });
  assert.equal(store.peekTicket(ticket), null, 'ticket must be one-time after consume');
  assert.equal(store.consumeTicket(ticket), null);
});

test('ticket expires after TTL (peek and consume both fail)', () => {
  let now = 0;
  const store = new MemoryStore({ now: () => now, ticketTtlMs: 1000 });
  const sessionToken = store.createSession({ accessToken: 'a', refreshToken: 'r' });
  const ticket = store.createTicket(sessionToken, 's', CHALLENGE);
  now = 1001;
  assert.equal(store.peekTicket(ticket), null);
  assert.equal(store.consumeTicket(ticket), null);
});

test('session lifetime is independent of access-token lifetime', () => {
  let now = 1_000_000;
  const store = new MemoryStore({ now: () => now, sessionTtlMs: 30 * 24 * 60 * 60 * 1000 });
  const token = store.createSession({
    accessToken: 'acc',
    refreshToken: 'ref',
    expiresInSeconds: 10, // access token expires in 10s
  });
  const s = store.getSession(token);
  assert.equal(s.accessExpiresAt, now + 10_000);
  assert.equal(s.sessionExpiresAt, now + 30 * 24 * 60 * 60 * 1000);

  // Access token has long expired, but the session must NOT be deleted.
  now = now + 11_000;
  const afterAccessExpiry = store.getSession(token);
  assert.ok(afterAccessExpiry, 'session survives access-token expiry');
  assert.equal(afterAccessExpiry.accessToken, 'acc');

  // Only when the session TTL passes does getSession delete it.
  now = 1_000_000 + 31 * 24 * 60 * 60 * 1000;
  assert.equal(store.getSession(token), null);
});

test('updateSession rotates tokens and resets access expiry but keeps session expiry', () => {
  let now = 1_000_000;
  const store = new MemoryStore({ now: () => now, sessionTtlMs: 30 * 24 * 60 * 60 * 1000 });
  const token = store.createSession({ accessToken: 'acc', refreshToken: 'ref', expiresInSeconds: 10 });
  const originalSessionExpiresAt = store.getSession(token).sessionExpiresAt;

  now = 1_000_000 + 5_000;
  assert.equal(store.updateSession(token, { accessToken: 'acc2', refreshToken: 'ref2', accessExpiresInSeconds: 20 }), true);

  const s = store.getSession(token);
  assert.equal(s.accessToken, 'acc2');
  assert.equal(s.refreshToken, 'ref2');
  assert.equal(s.accessExpiresAt, 1_005_000 + 20_000);
  assert.equal(s.sessionExpiresAt, originalSessionExpiresAt, 'session expiry must not move on refresh');
});

test('unknown updateSession returns false', () => {
  const store = new MemoryStore({});
  assert.equal(store.updateSession('nope', { accessToken: 'x', accessExpiresInSeconds: 10 }), false);
});

test('refreshSession dedupes concurrent runs per session', async () => {
  const store = new MemoryStore({});
  let runs = 0;
  const run = async () => {
    runs += 1;
    await new Promise((r) => setTimeout(r, 10));
    return 'done';
  };
  const [a, b, c] = await Promise.all([
    store.refreshSession('s', run),
    store.refreshSession('s', run),
    store.refreshSession('s', run),
  ]);
  assert.equal(runs, 1, 'three concurrent calls collapse to one run');
  assert.deepEqual([a, b, c], ['done', 'done', 'done']);

  // Lock released: a subsequent refresh runs again.
  await store.refreshSession('s', run);
  assert.equal(runs, 2);
});

test('refreshSession releases the lock on failure', async () => {
  const store = new MemoryStore({});
  let runs = 0;
  const failing = async () => {
    runs += 1;
    throw new Error('boom');
  };
  await assert.rejects(() => store.refreshSession('s', failing));
  await assert.rejects(() => store.refreshSession('s', failing));
  assert.equal(runs, 2, 'lock is released after a failed run');
});

test('deleteSession works', () => {
  const store = new MemoryStore({});
  const token = store.createSession({ accessToken: 'a', refreshToken: 'r' });
  assert.equal(store.deleteSession(token), true);
  assert.equal(store.getSession(token), null);
  assert.equal(store.deleteSession(token), false);
});

test('cleanup removes expired entries without a live timer', () => {
  let now = 0;
  const store = new MemoryStore({ now: () => now, stateTtlMs: 100, ticketTtlMs: 100, sessionTtlMs: 100 });
  store.createState(CHALLENGE);
  const s = store.createSession({ accessToken: 'a', refreshToken: 'r' });
  store.createTicket(s, 'x', CHALLENGE);
  assert.equal(store.cleanup(), 0);
  now = 1000;
  assert.equal(store.cleanup(), 3);
  assert.equal(store.cleanup(), 0);
});
