import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parse } from 'acorn';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('release metadata is aligned across the app shell', () => {
  const html = read('ios/game-shell.html.template');
  const manifest = JSON.parse(read('manifest.json'));
  const serviceWorker = read('sw.js');

  assert.match(html, /<title>Noir Market V9\.7<\/title>/);
  assert.match(html, /styles\.css\?v=9\.7\.3/);
  assert.match(html, /game\.js\?v=9\.7\.3/);
  assert.equal(manifest.version, '9.7');
  assert.match(serviceWorker, /registration\.unregister/);
});

test('all packaged assets referenced by the app shell exist', () => {
  const required = [
    'index.html',
    'styles.css',
    'game.js',
    'manifest.json',
    'sw.js',
    'assets/redhead-games-logo.png',
    'assets/game-music.mp3',
    'icon-192.png',
    'icon-512.png',
    'apple-touch-icon.png'
  ];

  for (const file of required) {
    assert.equal(fs.existsSync(path.join(root, file)), true, `${file} is missing`);
  }
});

test('game source parses and contains one active top-level declaration per function', () => {
  const source = read('game.js');
  const program = parse(source, { ecmaVersion: 'latest', sourceType: 'script' });
  const names = program.body
    .filter((node) => node.type === 'FunctionDeclaration' && node.id)
    .map((node) => node.id.name);
  const duplicates = names.filter((name, index) => names.indexOf(name) !== index);

  assert.deepEqual([...new Set(duplicates)], []);
  assert.ok(Buffer.byteLength(source) < 400_000, 'game.js exceeded the 400 KB runtime budget');
});

test('the V9.7 startup uses one bounded settling-snow animation and one game renderer', () => {
  const source = read('game.js');
  const html = read('ios/game-shell.html.template');
  const serviceWorker = read('sw.js');

  assert.match(source, /window\.NOIR_STATIC_VISUALS=true/);
  assert.match(source, /draw=renderGameV93/);
  assert.match(source, /load=loadGameV93/);
  assert.match(source, /window\.__NOIR_NATIVE_TIMEOUT\(revealTitle,1250\)/);
  assert.match(source, /Math\.min\(92,Math\.max\(52,/);
  assert.match(source, /var settled=\[\]/);
  assert.match(source, /particle\.speed=\.72\+depth\*2\.35/);
  assert.match(source, /document\.addEventListener\('noir:splash-exit',stop,false\)/);
  assert.match(source, /prefers-reduced-motion: reduce/);
  assert.match(html, /id="pixelSnowCanvasV97"/);
  assert.match(html, /class="splash-title-v97"[^>]*><span>NOIR<\/span><span>MARKET<\/span>/);
  assert.match(read('styles.css'), /body\.preintro-running #splash\.splash\{[\s\S]*?opacity:1!important/);
  assert.match(read('styles.css'), /\.splash-loader\.clicked-v97 \.splash-loader-fill/);
  assert.match(read('styles.css'), /font-family:Arial,Helvetica,sans-serif/);
  assert.match(read('styles.css'), /#splash \.splash-title-v97 span\{[\s\S]*?color:#fff!important;[\s\S]*?background:none!important/);
  assert.doesNotMatch(html, /splash-static\.jpg|splashStaticImage/);
  assert.doesNotMatch(serviceWorker, /splash-static\.jpg/);
});
