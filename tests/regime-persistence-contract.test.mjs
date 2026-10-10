import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const js = fs.readFileSync('index_scripts/16.js','utf8');

test('1.0.13 regime persistence/change/rolling helpers exist', () => {
  for (const name of ['nmStrOhlcRegimePersistence','nmStrOhlcChangeDetection','nmStrRollingEdge']) {
    assert.match(js, new RegExp(`function ${name}\\(`));
  }
});

test('1.0.13 engine exposes persistence, change detection and rolling edge', () => {
  assert.match(js, /out\.regime\s*=\s*\{[^}]*persistence:\s*ohlcPersistence[^}]*changes:\s*ohlcChanges[^}]*rolling:\s*ohlcRolling/s);
  assert.match(js, /const rollingWindow = Math\.max\(10, Math\.min\(30/);
});

test('1.0.33 version contract', () => {
  const v = JSON.parse(fs.readFileSync('version.json','utf8'));
  assert.equal(v.version, '1.0.33');
  assert.equal(v.versionCode, 34);
  assert.match(js, /NM_VERSION_NAME = "1\.0\.33"/);
  assert.match(js, /NM_VERSION_CODE = 34/);
});
