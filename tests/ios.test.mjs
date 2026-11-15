import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { JSDOM, VirtualConsole } from 'jsdom';
import { nativeGameSource, nativeHTML } from '../scripts/prepare-ios.mjs';

const game = nativeGameSource(fs.readFileSync(new URL('../game.js', import.meta.url), 'utf8'));
const html = nativeHTML(fs.readFileSync(new URL('../ios/game-shell.html.template', import.meta.url), 'utf8'));
const wait = (window, ms) => new Promise(resolve => window.setTimeout(resolve, ms));

test('native package excludes web preview unlock and uses local resource paths', () => {
  assert.doesNotMatch(game, /UNLOCK WEB PREVIEW|unlockWebPreviewV95|window\.noirNativePurchase/);
  assert.doesNotMatch(html, /rel="manifest"|\?v=/);
  assert.match(html, /src="game.js"/);
  assert.match(game, /state\.allCitiesUnlocked=window\.__NOIR_IOS_ENTITLED===true/);
});

test('native bridge stays locked until verified entitlement and recovers on revocation', async () => {
  const errors = [];
  const logs = new VirtualConsole();
  logs.on('jsdomError', e => errors.push(e.message));
  const dom = new JSDOM(html, { url: 'https://native.test/', runScripts: 'outside-only', pretendToBeVisual: true, virtualConsole: logs });
  const { window } = dom;
  try {
    window.HTMLMediaElement.prototype.load = () => {};
    window.HTMLMediaElement.prototype.pause = () => {};
    window.HTMLMediaElement.prototype.play = () => Promise.resolve();
    const requests = [];
    window.webkit = { messageHandlers: { noirPurchase: { postMessage: data => requests.push(data) } } };
    window.__NOIR_IOS_ENTITLED = false;
    window.eval(game);
    window.document.dispatchEvent(new window.Event('DOMContentLoaded'));
    await wait(window, 1400);
    window.document.getElementById('splashEnter').click();
    await wait(window, 280);
    window.document.getElementById('unlockAllCitiesBtnV95').click();
    assert.equal(requests[0].productId, 'games.redhead.noirmarket.unlockallcities');
    assert.equal(window.s.allCitiesUnlocked, false);
    assert.equal(window.document.getElementById('unlockWebPreviewV95'), null);
    // Even a forged/stale save flag is not an iOS entitlement.
    window.s.allCitiesUnlocked = true;
    window.draw();
    assert.equal(window.s.allCitiesUnlocked, false);
    // Simulate the payload from verified native StoreKit transactions.
    window.__NOIR_IOS_ENTITLED = true;
    window.NOIR_MARKET_UNLOCK_ALL_CITIES();
    await wait(window, 25);
    assert.equal(window.document.querySelectorAll('[data-start-city-v95]').length, 14);
    window.document.getElementById('playWelcomeBtn').click();
    await wait(window, 25);
    assert.equal(window.s.accessMode, 'full');
    assert.equal(window.document.getElementById('modal').open, false);
    window.__NOIR_IOS_ENTITLED = false;
    window.NOIR_MARKET_RESTORE_UNLOCK(false);
    assert.equal(window.s.allCitiesUnlocked, false);
    assert.equal(window.s.accessMode, 'free');
    assert.deepEqual(errors, []);
  } finally { dom.window.close(); }
});

test('native bridge failure does not offer a free full-game unlock', async () => {
  const dom = new JSDOM(html, { url: 'https://native.test/', runScripts: 'outside-only', pretendToBeVisual: true, virtualConsole: new VirtualConsole() });
  const { window } = dom;
  try {
    window.HTMLMediaElement.prototype.load = () => {};
    window.eval(game);
    window.document.dispatchEvent(new window.Event('DOMContentLoaded'));
    await wait(window, 20);
    window.showWelcome();
    await wait(window, 20);
    window.document.getElementById('unlockAllCitiesBtnV95').click();
    assert.equal(window.document.getElementById('modalTitle').textContent, 'Purchase unavailable');
    assert.equal(window.s.allCitiesUnlocked, false);
    assert.equal(window.document.getElementById('unlockWebPreviewV95'), null);
  } finally { dom.window.close(); }
});
