import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildAuthorizationUrl, refreshTokens } from '../src/bangumi.js';

test('buildAuthorizationUrl constructs the exact Bangumi authorize URL', () => {
  const url = buildAuthorizationUrl({
    clientId: 'bgm69386a8765324f840',
    redirectUri: 'https://auth.example.com/auth/bangumi/callback',
    state: 'state-123',
  });

  const parsed = new URL(url);
  assert.equal(parsed.origin, 'https://bgm.tv');
  assert.equal(parsed.pathname, '/oauth/authorize');
  assert.equal(parsed.searchParams.get('client_id'), 'bgm69386a8765324f840');
  assert.equal(parsed.searchParams.get('response_type'), 'code');
  assert.equal(
    parsed.searchParams.get('redirect_uri'),
    'https://auth.example.com/auth/bangumi/callback',
  );
  assert.equal(parsed.searchParams.get('state'), 'state-123');
});

test('buildAuthorizationUrl percent-encodes redirect_uri and state', () => {
  const url = buildAuthorizationUrl({
    clientId: 'id',
    redirectUri: 'https://auth.example.com/auth/bangumi/callback',
    state: 'a b+c/d',
  });
  const rawQuery = url.split('?')[1];
  assert.ok(
    rawQuery.includes('redirect_uri=https%3A%2F%2Fauth.example.com%2Fauth%2Fbangumi%2Fcallback'),
  );
  assert.ok(rawQuery.includes('state=a+b%2Bc%2Fd'));
});

test('refreshTokens sends the exact required form including redirect_uri', async () => {
  let captured;
  const fetchImpl = async (url, init) => {
    captured = { url: String(url), init };
    return new Response(JSON.stringify({ access_token: 'new', refresh_token: 'new-r', expires_in: 3600 }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  await refreshTokens({
    clientId: 'bgm69386a8765324f840',
    clientSecret: 'secret',
    refreshToken: 'old-r',
    redirectUri: 'https://auth.example.com/auth/bangumi/callback',
    fetchImpl,
  });

  assert.equal(captured.url, 'https://bgm.tv/oauth/access_token');
  const params = new URLSearchParams(captured.init.body);
  assert.equal(params.get('grant_type'), 'refresh_token');
  assert.equal(params.get('client_id'), 'bgm69386a8765324f840');
  assert.equal(params.get('client_secret'), 'secret');
  assert.equal(params.get('refresh_token'), 'old-r');
  assert.equal(params.get('redirect_uri'), 'https://auth.example.com/auth/bangumi/callback');
});
