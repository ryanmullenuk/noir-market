import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import { JSDOM } from 'jsdom';

test('public page offers support without loading the game', () => {
  const dom = new JSDOM(fs.readFileSync(new URL('../index.html', import.meta.url), 'utf8'));
  const doc = dom.window.document;
  assert.equal(doc.querySelector('script[src], link[rel="manifest"], #splashEnter'), null);
  for (const page of ['support.html', 'privacy.html']) {
    assert.ok(doc.querySelector(`a[href="${page}"]`));
    assert.ok(fs.existsSync(new URL('../' + page, import.meta.url)));
  }
  dom.window.close();
});

test('retirement clears only game caches, redirects game tabs, and unregisters', async () => {
  const handlers = {}, deleted = [], navigated = [];
  let claimed = false, unregistered = false, pending;
  const scope = 'https://redhead.games/noir-market/';
  const self = {
    addEventListener: (name, handler) => { handlers[name] = handler; },
    skipWaiting() {},
    registration: { scope, unregister: async () => { unregistered = true; } },
    clients: {
      claim: async () => { claimed = true; },
      matchAll: async () => ['', 'index.html', 'support.html', 'privacy.html'].map(page => ({
        url: scope + page, navigate: async url => { navigated.push([page, url]); }
      }))
    }
  };
  vm.runInNewContext(fs.readFileSync(new URL('../sw.js', import.meta.url), 'utf8'), {
    self, URL, caches: {
      keys: async () => ['noir-market-v9.7.3', 'aztlan-isle-v1'],
      delete: async key => { deleted.push(key); }
    }
  });
  handlers.activate({ waitUntil: promise => { pending = promise; } });
  await pending;
  assert.deepEqual(deleted, ['noir-market-v9.7.3']);
  assert.deepEqual(navigated, [['', scope], ['index.html', scope]]);
  assert.ok(claimed && unregistered);
  assert.equal(handlers.fetch, undefined);
});
