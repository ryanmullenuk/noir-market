// Retire the browser edition and its offline app cache; preserve saved game data.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith('noir-market-')).map(key => caches.delete(key)));
    await self.clients.claim();
    const scope = new URL(self.registration.scope);
    const clients = await self.clients.matchAll({ type: 'window' });
    await Promise.all(clients.map(function (client) {
      const url = new URL(client.url);
      if (url.origin === scope.origin && (url.pathname === scope.pathname || url.pathname === scope.pathname + 'index.html')) {
        return client.navigate(scope.href).catch(function () {});
      }
    }));
    await self.registration.unregister();
  })());
});
