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

const wait = (window, milliseconds = 25) => new Promise((resolve) => {
  window.setTimeout(resolve, milliseconds);
});

async function createPlayableGame() {
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

  window.Math.random = () => 0.99;
  window.HTMLMediaElement.prototype.load = () => {};
  window.HTMLMediaElement.prototype.pause = () => {};
  window.HTMLMediaElement.prototype.play = () => Promise.resolve();
  window.navigator.vibrate = () => true;
  window.eval(game);
  window.document.dispatchEvent(new window.Event('DOMContentLoaded'));
  await wait(window, 1400);

  const document = window.document;
  document.getElementById('splashEnter').click();
  await wait(window, 280);
  document.getElementById('freePlayBtnV95').click();
  await wait(window);
  [...document.querySelectorAll('button')]
    .find((button) => button.textContent.trim() === 'London')
    .click();
  document.getElementById('playWelcomeBtn').click();
  await wait(window);

  assert.equal(document.getElementById('splash').style.display, 'none');
  assert.equal(document.body.classList.contains('v85-game-entered'), true);
  assert.equal(document.getElementById('modal').open, false);

  return { document, dom, errors, window };
}

function modalTitle(document) {
  return document.getElementById('modalTitle').textContent.trim();
}

async function closeModal(window, document) {
  const close = document.getElementById('modalCloseBtn');
  assert.ok(close, `close button missing from ${modalTitle(document)}`);
  close.click();
  await wait(window);
  assert.equal(document.getElementById('modal').open, false);
}

test('every main action button opens its intended screen and closes cleanly', async () => {
  const { document, dom, errors, window } = await createPlayableGame();
  const routes = [
    ['buyBtn', 'Buy'],
    ['sellBtn', 'Sell'],
    ['dumpBtn', 'Storage'],
    ['bankBtn', 'Finances'],
    ['travelBtn', 'Travel & Shipping'],
    ['shopBtn', 'Black Market'],
    ['hustleBtn', 'Hustle'],
    ['contactsBtn', 'Contacts'],
    ['menuBtn', 'Menu']
  ];

  for (const [id, title] of routes) {
    const button = document.getElementById(id);
    assert.ok(button, `${id} is missing`);
    assert.equal(button.disabled, false, `${id} is disabled`);
    button.click();
    await wait(window);
    assert.equal(modalTitle(document), title, `${id} opened the wrong screen`);
    await closeModal(window, document);
  }

  assert.deepEqual(errors, []);
  dom.window.close();
});

test('buy quantity and sell-all controls complete a round trip', async () => {
  const { document, dom, errors, window } = await createPlayableGame();
  const drug = window.drugs[0][0];
  window.s.cash = 100000;
  window.s.prices[drug] = 100;
  window.s.supply[drug] = 20;
  window.draw();

  document.getElementById('buyBtn').click();
  await wait(window);
  document.querySelector(`[data-plus="buy|${drug}"]`).click();
  assert.equal(window.qtyInput('buy', drug).value, '1');
  document.querySelector(`[data-buydrug="${drug}"]`).click();
  await wait(window);
  assert.equal(window.s.inv[drug], 1);
  assert.equal(window.s.cash, 99900);

  await closeModal(window, document);
  document.getElementById('sellBtn').click();
  await wait(window);
  document.querySelector(`[data-sellpocketall="${drug}"]`).click();
  await wait(window);
  assert.equal(window.s.inv[drug], 0);
  assert.equal(window.s.cash, 100000);
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('finance buttons deposit, withdraw, borrow and repay', async () => {
  const { document, dom, errors, window } = await createPlayableGame();
  window.s.cash = 1000;
  window.s.bank = 100;
  window.draw();

  document.getElementById('bankBtn').click();
  await wait(window);
  document.getElementById('amount').value = '200';
  document.getElementById('deposit').click();
  await wait(window);
  assert.equal(window.s.cash, 800);
  assert.equal(window.s.bank, 300);

  document.getElementById('amount').value = '50';
  document.getElementById('withdraw').click();
  await wait(window);
  assert.equal(window.s.cash, 850);
  assert.equal(window.s.bank, 250);

  document.querySelector('[data-loan]').click();
  await wait(window);
  document.getElementById('borrowMaxLoan').click();
  const borrowed = Number(document.getElementById('loanAmount').value);
  document.getElementById('confirmLoan').click();
  await wait(window);
  assert.equal(window.s.loans.length, 1);
  assert.equal(window.s.cash, 850 + borrowed);

  document.getElementById('bankBtn').click();
  await wait(window);
  document.querySelector('[data-payloan]').click();
  await wait(window);
  assert.equal(window.s.loans.length, 0);
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('storage controls move drugs and weapons in both directions', async () => {
  const { document, dom, errors, window } = await createPlayableGame();
  const drug = window.drugs[0][0];
  const weapon = window.weapons[0].name;
  const city = window.places[window.s.city][0];
  window.s.inv[drug] = 2;
  window.s.weapons = [weapon];
  window.draw();

  document.getElementById('dumpBtn').click();
  await wait(window);
  document.querySelector('[data-storedrug]').click();
  await wait(window);
  assert.equal(window.s.inv[drug], 0);
  assert.equal(window.s.vaults[city][drug], 2);

  document.querySelector('[data-takedrug]').click();
  await wait(window);
  assert.equal(window.s.inv[drug], 2);
  assert.equal(window.s.vaults[city][drug], 0);

  document.querySelector('[data-storeweapon]').click();
  await wait(window);
  assert.equal(window.s.weapons.length, 0);
  assert.equal(window.s.weaponVaults[city][weapon], 1);

  document.querySelector('[data-takeweapon]').click();
  await wait(window);
  assert.equal(window.s.weapons[0], weapon);
  assert.equal(window.s.weaponVaults[city][weapon], 0);
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('black market, hospital, hustle and contacts controls respond', async () => {
  const { document, dom, errors, window } = await createPlayableGame();
  window.s.cash = 1000000;
  window.s.health = 50;
  window.draw();

  document.getElementById('shopBtn').click();
  await wait(window);
  document.querySelector('[data-shop]').click();
  await wait(window);
  assert.equal(window.s.owned.length, 1);

  document.getElementById('shopBtn').click();
  await wait(window);
  document.querySelector('[data-weapon]').click();
  await wait(window);
  assert.equal(window.s.weapons.length, 1);

  document.getElementById('shopBtn').click();
  await wait(window);
  document.querySelector('[data-hospital]').click();
  await wait(window);
  assert.ok(window.s.health > 50);

  document.getElementById('shopBtn').click();
  await wait(window);
  document.querySelector('[data-burner-phone]').click();
  await wait(window);
  assert.equal(window.s.v38.burnerPhones, 1);

  document.getElementById('contactsBtn').click();
  await wait(window);
  assert.ok(document.getElementById('useBurnerPhone'));

  await closeModal(window, document);
  const cashBefore = window.s.cash;
  document.getElementById('hustleBtn').click();
  await wait(window);
  document.querySelector('[data-informant-v66],[data-informant]').click();
  await wait(window);
  assert.ok(window.s.cash < cashBefore);
  assert.equal(window.s.stats.informants, 1);
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('travel, shipping, stay and continue controls preserve navigation', async () => {
  const { document, dom, errors, window } = await createPlayableGame();
  const drug = window.drugs[0][0];
  window.s.cash = 100000;
  window.s.inv[drug] = 2;
  window.draw();

  document.getElementById('travelBtn').click();
  await wait(window);
  assert.equal(document.querySelectorAll('[data-city]').length, 14);
  document.getElementById('shippingModeBtn').click();
  await wait(window);
  assert.ok(document.getElementById('exportStockBtn'));
  assert.ok(document.getElementById('importStockBtn'));

  document.getElementById('exportStockBtn').click();
  await wait(window);
  const destination = [...document.querySelectorAll('[data-shipdest]')]
    .find((button) => Number(button.dataset.shipdest) !== window.s.city);
  assert.ok(destination);
  const destinationIndex = Number(destination.dataset.shipdest);
  destination.click();
  document.querySelector('[data-exportdrug-v41]').click();
  await wait(window);
  assert.equal(window.s.shipments.length, 1);
  assert.equal(window.s.inv[drug], 0);

  await closeModal(window, document);
  window.s.city = destinationIndex;
  window.draw();
  document.getElementById('travelBtn').click();
  await wait(window);
  document.getElementById('shippingModeBtn').click();
  await wait(window);
  document.getElementById('importStockBtn').click();
  await wait(window);
  document.querySelector('[data-importship]').click();
  await wait(window);
  const city = window.places[destinationIndex][0];
  assert.equal(window.s.shipments.length, 0);
  assert.equal(window.s.vaults[city][drug], 2);

  await closeModal(window, document);
  const dayBeforeStay = window.s.day;
  document.getElementById('stayBtn').click();
  await wait(window);
  assert.equal(window.s.day, dayBeforeStay + 1);
  assert.equal(modalTitle(document), 'Stay Here');
  document.getElementById('continueEvent').click();
  await wait(window);
  assert.equal(document.getElementById('modal').open, false);
  assert.deepEqual(errors, []);

  dom.window.close();
});

test('menu settings, instructions, stats and new-game controls route correctly', async () => {
  const { document, dom, errors, window } = await createPlayableGame();

  document.getElementById('menuBtn').click();
  await wait(window);
  assert.ok(document.getElementById('avatarMaleV95'));
  assert.ok(document.getElementById('avatarFemaleV95'));
  document.getElementById('avatarFemaleV95').click();
  await wait(window);
  assert.equal(window.s.avatar, 'female');
  document.getElementById('playerNameInput').value = 'Button Tester';
  document.getElementById('savePlayerNameBtn').click();
  await wait(window);
  assert.equal(window.s.playerName, 'Button Tester');

  const soundText = document.getElementById('soundToggleBtn').textContent;
  document.getElementById('soundToggleBtn').click();
  await wait(window);
  assert.notEqual(document.getElementById('soundToggleBtn').textContent, soundText);

  const musicText = document.getElementById('musicToggleBtn').textContent;
  document.getElementById('musicToggleBtn').click();
  await wait(window);
  assert.notEqual(document.getElementById('musicToggleBtn').textContent, musicText);

  document.getElementById('instructionsBtn').click();
  await wait(window);
  assert.equal(modalTitle(document), 'Instructions');
  document.getElementById('backFromInstructionsV49').click();
  await wait(window);
  assert.equal(modalTitle(document), 'Menu');

  document.getElementById('statsBtn').click();
  await wait(window);
  assert.equal(modalTitle(document), 'Stats');
  document.getElementById('backMenuBtn').click();
  await wait(window);
  assert.equal(modalTitle(document), 'Menu');

  document.getElementById('menuNewGameBtn').click();
  await wait(window);
  assert.equal(modalTitle(document), 'New Game');
  document.getElementById('cancelNewGame').click();
  await wait(window);
  assert.equal(modalTitle(document), 'Menu');
  assert.deepEqual(errors, []);

  dom.window.close();
});
