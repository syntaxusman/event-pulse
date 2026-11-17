// Validates MULTILOGIN_SCRAPER_PROXIES without printing credentials.
// Usage: npm run check:proxies   (reads .env)
import { parseScraperProxyPool } from "../src/lib/eventpulse/multilogin-browser.server.ts";

try {
  const proxies = parseScraperProxyPool(process.env["MULTILOGIN_SCRAPER_PROXIES"]);
  if (proxies.length === 0) {
    console.log("MULTILOGIN_SCRAPER_PROXIES is empty: approved/fallback profiles are used.");
  }
  proxies.forEach((proxy, index) => {
    const host = proxy.host.replace(/^(.{3}).*?(.{0,6})$/, "$1…$2");
    console.log(
      `#${index + 1}: ${proxy.type} ${host}:${proxy.port}` +
        ` user=${proxy.username ? "yes" : "no"} password=${proxy.password ? "yes" : "no"}`,
    );
  });
  console.log(`OK: ${proxies.length} proxies.`);
} catch (error) {
  console.error(`INVALID: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
}
