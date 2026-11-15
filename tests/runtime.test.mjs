import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { JSDOM, VirtualConsole } from 'jsdom';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const html = fs.readFileSync(path.join(root, 'ios/game-shell.html.template'), 'utf8')
  .replace('<script src="game.js?v=9.7.3"></script>', '');
const game = fs.readFileSync(path.join(root, 'game.js'), 'utf8');

const wait = (window, milliseconds) => new Promise((resolve) => {
  window.setTimeout(resolve, milliseconds);
});

async function createGame(storage = {}) {
  const errors = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on('jsdomError', (error) => {
    if (!/Not implemented: HTMLMediaElement/.test(error.message)) errors.push(error);
  });

  const dom = new JSDOM(html, {
    url: 'https://redhead.games/index.html',
    runScripts: 'outside-only',
    pretendToBeVisual: true,
    virtualConsole
  });
  const { window } = dom;

  window.HTMLMediaElement.prototype.load = () => {};
  window.HTMLMediaElement.prototype.pause = () => {};
  window.HTMLMediaElement.prototype.play = () => Promise.resolve();
  window.navigator.vibrate = () => true;
  for (const [key, value] of Object.entries(storage)) {
    window.localStorage.setItem(key, value);
  }
  window.eval(game);
  window.document.dispatchEvent(new window.Event('DOMContentLoaded'));
  await wait(window, 1400);

  return { dom, errors, window };
}

test('V9.7 starts once and reaches the playable settled-snow title screen', async () => {
  const { dom, errors, window } = await createGame();

  assert.equal(window.document.title, 'Noir Market V9.7');
  assert.equal(window.NOIR_MARKET_VERSION, '9.7');
  assert.equal(window.document.getElementById('splashLoaderText').textContent, 'ENTER');
  assert.equal(window.document.getElementById('splashEnter').disabled, false);
  assert.equal(window.document.querySelectorAll('#marketTable .row:not(.header)').length, 14);
  assert.equal(window.document.querySelector('.splash-title-v97').textContent, 'NOIRMARKET');
  assert.equal(window.document.querySelectorAll('canvas').length, 1);
  assert.ok(window.document.getElementById('pixelSnowCanvasV97'));
  assert.equal(window.document.getElementById('splashLoaderFill').style.width, '0%');
  assert.equal(window.document.querySelectorAll('.live-dust,.game-dust,#splashStaticImage').length, 0);
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('older saves migrate without losing player progress', async () => {
  const fresh = await createGame();
  const oldState = JSON.parse(JSON.stringify(fresh.window.s));
  oldState.day = 17;
  oldState.cash = 43210;
  oldState.bank = 9876;
  oldState.city = 3;
  oldState.playerName = 'Regression Runner';
  fresh.dom.window.close();

  const { dom, errors, window } = await createGame({
    noir_market_v8_8: JSON.stringify(oldState)
  });

  assert.equal(window.s.day, 17);
  assert.equal(window.s.cash, 43210);
  assert.equal(window.s.bank, 9876);
  assert.equal(window.s.city, 3);
  assert.equal(window.s.playerName, 'Regression Runner');
  assert.ok(window.localStorage.getItem('noir_market_v9_7'));
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('intro, city selection and trade screens remain connected', async () => {
  const { dom, errors, window } = await createGame();
  const document = window.document;

  document.getElementById('splashEnter').click();
  assert.equal(document.getElementById('splashEnter').classList.contains('clicked-v97'), true);
  await wait(window, 280);
  assert.equal(document.getElementById('modalTitle').textContent, 'How to Play');

  document.getElementById('freePlayBtnV95').click();
  await wait(window, 20);
  assert.equal(document.getElementById('modalTitle').textContent, 'Free Play');

  const london = [...document.querySelectorAll('button')]
    .find((button) => button.textContent.trim() === 'London');
  assert.ok(london, 'London starting-city button is missing');
  london.click();

  const play = document.getElementById('playWelcomeBtn');
  assert.equal(play.disabled, false);
  play.click();
  await wait(window, 20);

  assert.equal(document.getElementById('splash').getAttribute('aria-hidden'), 'true');
  assert.equal(document.getElementById('splash').style.display, 'none');
  assert.equal(document.body.classList.contains('v85-game-entered'), true);
  assert.equal(document.body.classList.contains('modal-open'), false);
  assert.equal(document.getElementById('modal').open, false);

  document.getElementById('buyBtn').click();
  await wait(window, 20);
  assert.equal(document.getElementById('modalTitle').textContent, 'Buy');
  assert.equal(document.querySelectorAll('[data-buydrug]').length, 14);

  document.getElementById('modalCloseBtn').click();
  document.getElementById('travelBtn').click();
  await wait(window, 20);
  assert.match(document.getElementById('modalTitle').textContent, /Travel/i);
  assert.equal(document.querySelectorAll('[data-city]').length, 14);
  assert.equal(document.querySelectorAll('.locked-city-v95').length, 11);
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('city stories use ten templates with exactly half true per deck', async () => {
  const { dom, errors, window } = await createGame();

  assert.equal(window.NOIR_NEWS_STORIES_V95.length, 10);
  window.s.v95.storyTruthDeck = [];
  const truthValues = [];
  for (let index = 0; index < 10; index += 1) {
    truthValues.push(window.newRumour().accurate);
  }
  assert.equal(truthValues.filter(Boolean).length, 5);
  assert.match(window.s.rumour.text, /tomorrow/i);
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('unlock route exposes every city and persists the entitlement', async () => {
  const { dom, errors, window } = await createGame();
  const document = window.document;

  document.getElementById('splashEnter').click();
  await wait(window, 280);
  document.getElementById('unlockAllCitiesBtnV95').click();
  await wait(window, 20);
  assert.equal(document.getElementById('modalTitle').textContent, 'Unlock All Cities');

  document.getElementById('unlockWebPreviewV95').click();
  await wait(window, 20);
  assert.equal(window.s.allCitiesUnlocked, true);
  assert.equal(window.s.accessMode, 'full');
  assert.equal(document.querySelectorAll('[data-start-city-v95]').length, 14);

  const edinburgh = [...document.querySelectorAll('[data-start-city-v95]')]
    .find((button) => button.textContent.trim() === 'Edinburgh');
  assert.ok(edinburgh, 'Edinburgh full-game starting-city button is missing');
  edinburgh.click();
  document.getElementById('playWelcomeBtn').click();
  await wait(window, 20);
  assert.equal(document.getElementById('modal').open, false);
  assert.equal(document.body.classList.contains('v85-game-entered'), true);
  assert.equal(document.getElementById('splash').style.display, 'none');

  const saved = JSON.parse(window.localStorage.getItem('noir_market_v9_7'));
  assert.equal(saved.allCitiesUnlocked, true);
  assert.equal(saved.accessMode, 'full');
  assert.deepEqual(errors, []);

  dom.window.close();
});
