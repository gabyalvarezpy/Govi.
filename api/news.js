const FEEDS = [
  { source: "BBC Mundo", category: "Mundo", url: "https://feeds.bbci.co.uk/mundo/rss.xml" },
  { source: "DW Español", category: "Mundo", url: "https://rss.dw.com/xml/rss-es-all" },
  { source: "El País", category: "España", url: "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada" },
  { source: "CNN en Español", category: "Mundo", url: "https://news.google.com/rss/search?q=when:2d+site:cnnespanol.cnn.com&hl=es-419&gl=US&ceid=US:es-419" },
  { source: "Reuters", category: "Mundo", url: "https://news.google.com/rss/search?q=when:2d+site:reuters.com&hl=es&gl=ES&ceid=ES:es" },
  { source: "Associated Press", category: "Mundo", url: "https://news.google.com/rss/search?q=when:2d+site:apnews.com&hl=es-419&gl=US&ceid=US:es-419" },
  { source: "Europa Press", category: "España", url: "https://www.europapress.es/rss/rss.aspx" }
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
  const re = new RegExp("<(?:[\\w.-]+:)?" + name + "(?:\s[^>]*)?>([\s\S]*?)<\/(?:[\\w.-]+:)?" + name + "\s*>", "i");
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
    const date = dateRaw ? new Date(dateRaw) : new Date();
    if (!title || !/^https?:\/\//i.test(link)) return null;
    return { title, description: description.slice(0, 260), url: link, image: itemImage(block), source: feed.source, category: feed.category, publishedAt: Number.isNaN(date.getTime()) ? null : date.toISOString() };
  }).filter(Boolean);
}
module.exports = async function handler(req, res) {
  res.setHeader("Cache-Control", "s-maxage=600, stale-while-revalidate=1800");
  res.setHeader("Access-Control-Allow-Origin", "*");
  if (req.method !== "GET") { res.status(405).json({ error: "Método no permitido" }); return; }
  const results = await Promise.all(FEEDS.map(async feed => {
    try {
      const response = await fetch(feed.url, { headers: { "User-Agent": "GOVI-News/1.0 (+https://govi-97ft.vercel.app)" }, signal: AbortSignal.timeout(9000) });
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
  const articles = [...unique.values()].sort((a, b) => new Date(b.publishedAt || 0) - new Date(a.publishedAt || 0)).slice(0, 80);
  res.status(200).json({ articles, updatedAt: new Date().toISOString(), sources: FEEDS.map(f => f.source), count: articles.length });
};
