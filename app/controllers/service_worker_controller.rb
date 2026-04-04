class ServiceWorkerController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def show
    respond_to do |format|
      format.js do
        response.headers["Content-Type"] = "application/javascript; charset=utf-8"
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
        // Only handle GET requests
        if (event.request.method !== 'GET') {
          return;
        }

        // Only handle http/https requests
        const url = new URL(event.request.url);
        if (url.protocol !== 'http:' && url.protocol !== 'https:') {
          return;
        }

        // Skip API requests
        if (url.pathname.startsWith('/api/') || url.pathname.endsWith('.json')) {
          return;
        }

        // Skip service worker requests
        if (url.pathname.includes('/service-worker')) {
          return;
        }

        event.respondWith(
          fetch(event.request)
            .then((networkResponse) => {
              // Cache successful HTML page responses
              if (networkResponse && networkResponse.status === 200) {
                const responseClone = networkResponse.clone();
                caches.open(CACHE_NAME).then((cache) => {
                  cache.put(event.request, responseClone);
                });
              }
              return networkResponse;
            })
            .catch(() => {
              // Network failed - try to return from cache
              return caches.match(event.request).then((cachedResponse) => {
                if (cachedResponse) {
                  return cachedResponse;
                }
                // No cache - must return something, let browser handle it
                // Return a simple error response that won't break things
                return new Response('Network error - offline', {
                  status: 503,
                  statusText: 'Service Unavailable',
                  headers: { 'Content-Type': 'text/plain' }
                });
              });
            })
        );
      });
    JS
  end
end
