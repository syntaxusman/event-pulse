import assert from "node:assert/strict";
import { test } from "node:test";
import { parseScraperProxyPool } from "../src/lib/eventpulse/multilogin-browser.server.ts";

const one = (value) => parseScraperProxyPool(JSON.stringify([value]))[0];

test("scraper proxies: URL format", () => {
  assert.deepEqual(one("http://user:pass@proxy.example:8000"), {
    host: "proxy.example",
    port: 8000,
    type: "http",
    username: "user",
    password: "pass",
  });
  assert.equal(one("socks5://u:p@10.0.0.1:1080").type, "socks5");
  assert.equal(one("socks5h://u:p@10.0.0.1:1080").type, "socks5");
  assert.equal(one("https://u:p@proxy.example:8000/").type, "http");
  assert.deepEqual(one("proxy.example:8000"), { host: "proxy.example", port: 8000, type: "http" });
});

test("scraper proxies: provider host:port:user:pass format", () => {
  assert.deepEqual(one("gb.residential.example:7777:customer-abc_country-gb:se:cret"), {
    host: "gb.residential.example",
    port: 7777,
    type: "http",
    username: "customer-abc_country-gb",
    password: "se:cret",
  });
});

test("scraper proxies: unescaped and escaped special characters in passwords", () => {
  assert.equal(one("http://user:p@ss#w/rd?1@proxy.example:8000").password, "p@ss#w/rd?1");
  assert.equal(one("user:p@ss@proxy.example:8000").password, "p@ss");
  assert.equal(one("http://user:p%40ss@proxy.example:8000").password, "p@ss");
  assert.equal(one("http://user:100%@proxy.example:8000").password, "100%");
});

test("scraper proxies: plain lists and empty values", () => {
  assert.equal(parseScraperProxyPool("a.example:1, b.example:2\nc.example:3").length, 3);
  assert.deepEqual(parseScraperProxyPool("[]"), []);
  assert.deepEqual(parseScraperProxyPool("  "), []);
  assert.deepEqual(parseScraperProxyPool(undefined), []);
});

test("scraper proxies: errors never echo the secret", () => {
  for (const bad of [
    "ftp://u:secretpw@h:1",
    "h:1:secretpw",
    "u:secretpw@host",
    "u:secretpw@h:99999",
  ]) {
    assert.throws(
      () => one(bad),
      (error) => /Scraper proxy #1/.test(error.message) && !error.message.includes("secretpw"),
    );
  }
  assert.throws(() => parseScraperProxyPool("[not json"), /not a valid JSON array/);
});
