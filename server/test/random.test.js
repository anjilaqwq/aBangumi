import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  constantTimeMapDelete,
  constantTimeMapGet,
  isValidChallenge,
  isValidVerifier,
  randomToken,
  sha256Hex,
  timingSafeEqualStr,
} from '../src/random.js';

test('randomToken is >= 256 bits and URL-safe', () => {
  const t = randomToken();
  assert.ok(t.length >= 43, '32 bytes base64url should be at least 43 chars');
  assert.match(t, /^[A-Za-z0-9_-]+$/);
});

test('randomToken generates unique values', () => {
  const seen = new Set(Array.from({ length: 1000 }, () => randomToken()));
  assert.equal(seen.size, 1000);
});

test('randomToken rejects < 32 bytes', () => {
  assert.throws(() => randomToken(31));
});

test('timingSafeEqualStr compares equal and unequal values', () => {
  const a = randomToken();
  const b = randomToken();
  assert.equal(timingSafeEqualStr(a, a), true);
  assert.equal(timingSafeEqualStr(a, b), false);
  assert.equal(timingSafeEqualStr(a, a + 'x'), false);
});

test('sha256Hex returns a 64-char lowercase hex digest', () => {
  const h = sha256Hex('hello');
  assert.match(h, /^[0-9a-f]{64}$/);
  assert.equal(sha256Hex('hello'), h, 'deterministic');
  assert.notEqual(sha256Hex('hello'), sha256Hex('world'));
});

test('isValidChallenge accepts only 64 lowercase hex chars', () => {
  assert.equal(isValidChallenge('a'.repeat(64)), true);
  assert.equal(isValidChallenge('A'.repeat(64)), false);
  assert.equal(isValidChallenge('a'.repeat(63)), false);
  assert.equal(isValidChallenge('g'.repeat(64)), false);
  assert.equal(isValidChallenge(null), false);
  assert.equal(isValidChallenge(123), false);
});

test('isValidVerifier enforces canonical base64url of >=32 bytes', () => {
  const good = Buffer.alloc(32, 1).toString('base64url');
  assert.equal(isValidVerifier(good), true, `good=${good}`);

  // <32 bytes
  assert.equal(isValidVerifier(Buffer.alloc(31, 1).toString('base64url')), false);
  // non-base64url chars
  assert.equal(isValidVerifier('a'.repeat(43) + '!'), false);
  // too short a string to encode 32 bytes
  assert.equal(isValidVerifier('abc'), false);
  // padding is not canonical base64url
  assert.equal(isValidVerifier(good + '='), false);
  // non-string
  assert.equal(isValidVerifier(null), false);
  assert.equal(isValidVerifier(12345), false);
});

test('constantTimeMapGet/Delete work and delete consumes once', () => {
  const map = new Map([['k1', 'v1'], ['k2', 'v2']]);
  assert.equal(constantTimeMapGet(map, 'k1'), 'v1');
  assert.equal(constantTimeMapGet(map, 'missing'), undefined);
  assert.equal(constantTimeMapDelete(map, 'k1'), 'v1');
  assert.equal(constantTimeMapDelete(map, 'k1'), undefined);
  assert.equal(map.has('k1'), false);
});
