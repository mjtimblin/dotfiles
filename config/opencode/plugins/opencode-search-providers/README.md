# opencode-search-providers

[![npm](https://img.shields.io/npm/v/%40openchamber%2Fopencode-search-providers?style=flat&labelColor=100F0F&color=24837B)](https://www.npmjs.com/package/@openchamber/opencode-search-providers)
[![Discord](https://img.shields.io/badge/Discord-join.svg?style=flat&labelColor=100F0F&color=8B7EC8&logo=discord&logoColor=FFFCF0)](https://discord.gg/ZYRSdnwwKA)
[![License](https://img.shields.io/badge/license-MIT-black?style=flat&labelColor=100F0F&color=EC8B49)](LICENSE)

More search providers for the `websearch` tool built into [OpenCode](https://opencode.ai) 2.x: your own SearXNG server, Brave Search, Kagi, Perplexity Search, Linkup and Serper.

They sit next to the providers OpenCode ships (Exa, Tavily, Parallel, Firecrawl, TinyFish). The agent keeps using the same `websearch` tool, so there's no MCP server to run and no extra tool for the model to learn.

## Providers

| Provider | What you need | Free tier, October 2026 |
|---|---|---|
| SearXNG | The URL of a SearXNG server with the JSON format on | Free, you run the server |
| Brave Search | An API key from [api-dashboard.search.brave.com](https://api-dashboard.search.brave.com) | $5 of credit each month, about 1,000 searches |
| Kagi | An API key from [kagi.com/api/keys](https://kagi.com/api/keys), or a session token | None, $12 per 1,000 searches |
| Perplexity Search | An API key from [console.perplexity.ai](https://console.perplexity.ai) | None, $5 per 1,000 searches |
| Linkup | An API key from [app.linkup.so](https://app.linkup.so) | $20 of credit each month for work email accounts |
| Serper | An API key from [serper.dev](https://serper.dev) | 2,500 searches once |

Serper returns Google results. Kagi and Brave use their own indexes. Prices change, so check the provider's page before you rely on a number here.

A provider shows up in OpenCode only after you give it a key, a session token or a server URL. OpenCode's default choice, "any available provider", picks from every provider it knows and stays with the one it picked, so a provider without a key would fail your searches.

## Install

```bash
opencode plugin add @openchamber/opencode-search-providers
```

Or add it to `~/.config/opencode/opencode.json` yourself:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["@openchamber/opencode-search-providers"]
}
```

In [OpenChamber](https://github.com/openchamber/openchamber), install it from the Integrations page.

## Connect a provider

**In OpenChamber:** open Settings → Web search. Every provider from this plugin has a row under API keys. Paste the key, the session token for Kagi, or the server URL for SearXNG, and the provider joins the search provider choices above.

**In OpenCode:** run `/connect` and pick the provider, or set its environment variable before you start OpenCode:

| Provider | Environment variable |
|---|---|
| SearXNG | `SEARXNG_URL`, for example `http://localhost:8888` |
| Brave Search | `BRAVE_API_KEY` |
| Kagi | `KAGI_API_KEY` or `KAGI_SESSION_TOKEN` |
| Perplexity Search | `PERPLEXITY_SEARCH_API_KEY` |
| Linkup | `LINKUP_API_KEY` |
| Serper | `SERPER_API_KEY` |

Perplexity Search reads its own variable on purpose. `PERPLEXITY_API_KEY` is usually set for Perplexity's models, and reading it would turn on search billed to that key without you asking.

Then pick the provider, or keep "any available provider":

```json
{
  "websearch": { "provider": "brave" }
}
```

The ids are `searxng`, `brave`, `kagi`, `perplexity-search`, `linkup` and `serper`.

## SearXNG

SearXNG answers JSON only when the server allows it. Add `json` to `search.formats` in its `settings.yml` and restart it:

```yaml
search:
  formats:
    - html
    - json
```

Most public instances keep JSON off, so this is meant for a server you run. If the server has the limiter on, requests from OpenCode can be blocked like any other bot. Turn the limiter off, or allow the address OpenCode runs on.

Want DuckDuckGo, Google or Bing results? Turn those engines on in your SearXNG server. DuckDuckGo has no official search API, and this plugin doesn't scrape it.

## Kagi

Kagi accepts either an API key or a browser session token. Paste either one into Kagi's field, or set `KAGI_API_KEY` or `KAGI_SESSION_TOKEN`.

A session token comes from a signed-in kagi.com session, and a session link such as `https://kagi.com/search?token=...` works too: the plugin takes the `token` parameter out of it. The same rules are used by [kagi-cli](https://github.com/mjtimblin/docker-kagi-cli), which documents the token.

An API key is sent as a bearer token to `https://kagi.com/api/v1/search`, which answers JSON. A session token searches `https://kagi.com/html/search` with the token in the `kagi_session` cookie, and the plugin reads the results from the HTML page. When the value is not a session link, the plugin tries it as an API key first and retries it as a session token if Kagi rejects it, so an existing key keeps working unchanged.

Session tokens expire with the browser session that made them. If Kagi rejects the token, sign in again and copy a fresh one.

## How it works

Each provider is an OpenCode integration with the same id. OpenCode keeps the key with its other credentials, and the plugin reads it on every search, so a replaced key works from the next search on. When you save or remove a key, the plugin adds or drops the provider without a restart.

A search sends the query and nothing else to the provider you picked, and returns up to 8 results with up to 2,000 characters of text each.

The integrations carry `metadata: { websearch: true }`. OpenChamber uses it to list them under Web search before they are connected and to keep them out of the model providers. Another plugin that adds web search providers can set the same marker.

## Development

```bash
bun install
bun test
bun run build
```

To load your checkout in OpenCode, put its absolute path in `plugins`:

```json
{
  "plugins": ["/absolute/path/to/opencode-search-providers"]
}
```

## License

MIT
