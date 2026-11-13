const FEEDS = [
  { source: "ABC Color", category: "Paraguay", url: "https://www.abc.com.py/arc/outboundfeeds/rss/nacionales/" },
  { source: "ABC Color · Política", category: "Paraguay", url: "https://www.abc.com.py/arc/outboundfeeds/rss/politica/" },
  { source: "ABC Color · Mundo", category: "Mundo", url: "https://www.abc.com.py/arc/outboundfeeds/rss/mundo/" },
  { source: "Última Hora", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:ultimahora.com&hl=es&gl=PY&ceid=PY:es" },
  { source: "La Nación", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:lanacion.com.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "IP Paraguay", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:ip.gov.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "RTVE", category: "España", url: "https://news.google.com/rss/search?q=when:1d+site:rtve.es&hl=es&gl=ES&ceid=ES:es" },
  { source: "El País", category: "España", url: "https://news.google.com/rss/search?q=when:1d+site:elpais.com&hl=es&gl=ES&ceid=ES:es" },
  { source: "Agencia EFE", category: "España", url: "https://news.google.com/rss/search?q=when:1d+site:efe.com&hl=es&gl=ES&ceid=ES:es" },
  { source: "La Vanguardia", category: "España", url: "https://news.google.com/rss/search?q=when:1d+site:lavanguardia.com&hl=es&gl=ES&ceid=ES:es" },
  { source: "Telefuturo", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:telefuturo.com.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "C9N", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:c9n.com.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "SNT", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:snt.com.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "NPY", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:npy.com.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "Trece", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:trece.com.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "GEN", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:gen.com.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "Unicanal", category: "Paraguay", url: "https://news.google.com/rss/search?q=when:1d+site:unicanal.com.py&hl=es&gl=PY&ceid=PY:es" },
  { source: "BBC Mundo", category: "Mundo", url: "https://feeds.bbci.co.uk/mundo/rss.xml" },
  { source: "DW Español", category: "Mundo", url: "https://rss.dw.com/xml/rss-es-all" },
  { source: "Reuters", category: "Mundo", url: "https://news.google.com/rss/search?q=when:1d+site:reuters.com&hl=es&gl=ES&ceid=ES:es" },
  { source: "Associated Press", category: "Mundo", url: "https://news.google.com/rss/search?q=when:1d+site:apnews.com&hl=es-419&gl=US&ceid=US:es-419" },
  { source: "CNN en Español", category: "Mundo", url: "https://news.google.com/rss/search?q=when:1d+site:cnnespanol.cnn.com&hl=es-419&gl=US&ceid=US:es-419" },
  { source: "Actualidad mundial", category: "Mundo", url: "https://news.google.com/rss/search?q=when:1d+noticias+internacionales&hl=es&gl=ES&ceid=ES:es" }
];

function decode(value) {
  return String(value || "")
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/<[^>]*>/g, " ")
    .replace(/&amp;/g, "&").replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">").replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([\da-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/\s+/g, " ").trim();
}
function tag(xml, name) {
  const re = new RegExp("<(?:[\\w.-]+:)?" + name + "(?:\\s[^>]*)?>([\\s\\S]*?)<\\/(?:[\\w.-]+:)?" + name + "\\s*>", "i");
  const m = xml.match(re); return m ? m[1] : "";
}
function itemImage(xml) {
  const candidates = [
    xml.match(/<(?:media:)?(?:thumbnail|content)\b[^>]*url=["']([^"']+)["']/i),
    xml.match(/<enclosure\b[^>]*url=["']([^"']+)["']/i),
    xml.match(/<img[^>]+src=["']([^"']+)["']/i)
  ];
  return candidates.find(Boolean)?.[1] || "";
}
function parseFeed(xml, feed) {
  const blocks = xml.match(/<item\b[\s\S]*?<\/item>/gi) || xml.match(/<entry\b[\s\S]*?<\/entry>/gi) || [];
  return blocks.map(block => {
    const title = decode(tag(block, "title"));
    let link = tag(block, "link");
    if (!link) link = (block.match(/<link[^>]+href=["']([^"']+)["']/i) || [])[1] || "";
    link = decode(link);
    const description = decode(tag(block, "description") || tag(block, "summary") || tag(block, "content"));
    const dateRaw = decode(tag(block, "pubDate") || tag(block, "published") || tag(block, "updated"));
    const date = dateRaw ? new Date(dateRaw) : null;
    if (!title || !/^https?:\/\//i.test(link)) return null;
    return { title, description: description.slice(0, 260), url: link, image: itemImage(block), source: feed.source, category: feed.category, publishedAt: !date || Number.isNaN(date.getTime()) ? null : date.toISOString() };
  }).filter(Boolean);
}
module.exports = async function handler(req, res) {
  const forceRefresh = Boolean(req.query && req.query.refresh);
  res.setHeader("Cache-Control", forceRefresh ? "no-store, no-cache, must-revalidate, proxy-revalidate" : "s-maxage=60, stale-while-revalidate=300");
  res.setHeader("Access-Control-Allow-Origin", "*");
  if (req.method !== "GET") { res.status(405).json({ error: "Método no permitido" }); return; }
  const results = await Promise.all(FEEDS.map(async feed => {
    try {
      const response = await fetch(feed.url, { cache: "no-store", headers: { "User-Agent": "GOVI-News/1.0 (+https://govi-97ft.vercel.app)", "Cache-Control": "no-cache" }, signal: AbortSignal.timeout(4500) });
      if (!response.ok) throw new Error("HTTP " + response.status);
      const xml = await response.text();
      return parseFeed(xml, feed);
    } catch (error) {
      console.warn("GOVI Noticias: fuente no disponible", feed.source, error.message);
      return [];
    }
  }));
  const unique = new Map();
  results.flat().forEach(article => {
    const key = article.url.split("?")[0];
    if (!unique.has(key)) unique.set(key, article);
  });
  const priority = { Paraguay: 0, España: 1, Mundo: 2 };
  const sorted = [...unique.values()].sort((a, b) =>
    (priority[a.category] ?? 9) - (priority[b.category] ?? 9) ||
    new Date(b.publishedAt || 0) - new Date(a.publishedAt || 0)
  );
  // Reservar espacio para las tres regiones evita que Paraguay ocupe los 60 resultados.
  const articles = [];
  const selected = new Set();
  for (const category of ["Paraguay", "España", "Mundo"]) {
    sorted.filter(article => article.category === category).slice(0, 20).forEach(article => {
      articles.push(article);
      selected.add(article.url.split("?")[0]);
    });
  }
  // Si alguna región aporta menos de 20 noticias, completar con las siguientes disponibles.
  sorted.forEach(article => {
    const key = article.url.split("?")[0];
    if (articles.length < 60 && !selected.has(key)) {
      articles.push(article);
      selected.add(key);
    }
  });
  articles.sort((a, b) =>
    (priority[a.category] ?? 9) - (priority[b.category] ?? 9) ||
    new Date(b.publishedAt || 0) - new Date(a.publishedAt || 0)
  );
  res.status(200).json({ articles, updatedAt: new Date().toISOString(), sources: FEEDS.map(f => f.source), count: articles.length });
};
