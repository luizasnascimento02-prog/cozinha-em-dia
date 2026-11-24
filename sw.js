// Service worker: guarda o app no celular para abrir mesmo sem internet.
// Ao mudar qualquer arquivo do app, aumente a VERSAO para todo mundo receber a atualização.
const VERSAO = "cozinha-v1";
const ARQUIVOS = [
  "./", "index.html", "config.js", "manifest.webmanifest", "vendor/supabase.js",
  "icons/icon-192.png", "icons/icon-512.png", "icons/maskable-512.png", "icons/apple-touch-icon.png", "icons/favicon.png",
  "img/abertura.webp", "img/logo.webp", "img/abacate.webp", "img/tomate.webp", "img/feijoada.webp", "img/frango.webp",
  "img/hamburguer.webp", "img/lasanha.webp", "img/macarrao.webp", "img/pizza.webp", "img/sushi.webp"
];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(VERSAO).then(c => c.addAll(ARQUIVOS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys()
    .then(ks => Promise.all(ks.filter(k => k !== VERSAO).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  // Banco de dados (Supabase): sempre pela internet, nunca do cache.
  if (url.hostname.endsWith(".supabase.co") || url.hostname.endsWith(".supabase.in")) return;

  // Fontes do Google: guarda depois da primeira vez.
  if (url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com") {
    e.respondWith(caches.open(VERSAO).then(async c => {
      const hit = await c.match(req);
      if (hit) return hit;
      const res = await fetch(req);
      if (res.ok || res.type === "opaque") c.put(req, res.clone());
      return res;
    }));
    return;
  }

  if (url.origin !== location.origin) return;

  // Página e config: tenta a internet primeiro (pega novidades), senão usa a cópia guardada.
  const ehPagina = req.mode === "navigate";
  if (ehPagina || url.pathname.endsWith("/config.js")) {
    const chave = ehPagina ? "index.html" : "config.js";
    e.respondWith(fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(VERSAO).then(c => c.put(chave, copy)); }
      return res;
    }).catch(() => caches.match(chave)));
    return;
  }

  // Demais arquivos do app: cópia guardada primeiro, atualizando em segundo plano.
  e.respondWith(caches.match(req).then(hit => {
    const net = fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(VERSAO).then(c => c.put(req, copy)); }
      return res;
    }).catch(() => hit);
    return hit || net;
  }));
});
