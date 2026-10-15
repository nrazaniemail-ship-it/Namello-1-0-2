import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const server = await readFile(new URL('../backend/server.mjs', import.meta.url), 'utf8');

test('backend defines NODE_ENV before selecting the default authentication mode', () => {
  const nodeEnv = server.indexOf("const NODE_ENV = String(env.NODE_ENV || 'development');");
  const authMode = server.indexOf("const AUTH_MODE = String(env.NAMELLO_AUTH_MODE || (NODE_ENV === 'production' ? 'google' : 'local')).trim().toLowerCase();");
  assert.notEqual(nodeEnv, -1, 'NODE_ENV declaration must exist');
  assert.notEqual(authMode, -1, 'AUTH_MODE declaration must exist');
  assert.ok(nodeEnv < authMode, 'NODE_ENV must be initialized before AUTH_MODE references it');
});

test('production backend defaults to Google auth and rejects local/demo mode', () => {
  assert.match(server, /env\.NAMELLO_AUTH_MODE\s*\|\|\s*\(NODE_ENV === 'production' \? 'google' : 'local'\)/);
  assert.match(server, /AUTH_MODE !== 'google' && NODE_ENV === 'production'/);
});
