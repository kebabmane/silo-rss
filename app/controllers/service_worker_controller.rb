class ServiceWorkerController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def show
    respond_to do |format|
      format.js do
        response.headers['Content-Type'] = 'application/javascript; charset=utf-8'
        render inline: service_worker_code
      end
    end
  end

  private

  def service_worker_code
    <<~JS
      // Service Worker for Silo Feed Reader
      const CACHE_NAME = 'silo-v1';
      const URLS_TO_CACHE = ['/'];

      // Install event - cache essential files
      self.addEventListener('install', (event) => {
        event.waitUntil(
          caches.open(CACHE_NAME).then((cache) => {
            return cache.addAll(URLS_TO_CACHE).catch(() => {
              // Ignore cache errors during install
            });
          })
        );
        self.skipWaiting();
      });

      // Activate event - clean up old caches
      self.addEventListener('activate', (event) => {
        event.waitUntil(
          caches.keys().then((cacheNames) => {
            return Promise.all(
              cacheNames.map((cacheName) => {
                if (cacheName !== CACHE_NAME) {
                  return caches.delete(cacheName);
                }
              })
            );
          })
        );
        self.clients.claim();
      });

      // Fetch event - network-first strategy
      self.addEventListener('fetch', (event) => {
        if (event.request.method !== 'GET') {
          return;
        }

        // Only cache http/https requests (skip chrome-extension://, etc.)
        const url = new URL(event.request.url);
        if (url.protocol !== 'http:' && url.protocol !== 'https:') {
          return;
        }

        event.respondWith(
          fetch(event.request)
            .then((response) => {
              if (!response || response.status !== 200 || response.type === 'error') {
                return response;
              }

              // Clone the response
              const responseToCache = response.clone();
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(event.request, responseToCache);
              });

              return response;
            })
            .catch(() => {
              // Return cached version if fetch fails
              return caches.match(event.request);
            })
        );
      });
    JS
  end
end
