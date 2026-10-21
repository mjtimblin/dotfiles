import { asArray, asRecord, collect, MAX_RESULTS, ProviderRequestError, requestJson, toResult, } from "./http.js";
import { kagiSearch, kagiSessionSearch } from "./kagi.js";
const jsonBody = (body) => ({
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
});
const bearer = (apiKey) => ({ Authorization: `Bearer ${apiKey}` });
/** `https://searx.example.org`, with or without a trailing slash or `/search`, to its search endpoint. */
export function searxngSearchUrl(serverUrl) {
    let base;
    try {
        base = new URL(serverUrl.trim());
    }
    catch {
        throw new ProviderRequestError(`The SearXNG address "${serverUrl}" is not a valid URL.`);
    }
    if (base.protocol !== "http:" && base.protocol !== "https:") {
        throw new ProviderRequestError(`The SearXNG address must start with http:// or https://.`);
    }
    const path = base.pathname.replace(/\/+$/, "").replace(/\/search$/, "");
    return new URL(`${path}/search`, base.origin);
}
export const searxng = {
    id: "searxng",
    name: "SearXNG",
    access: "server",
    env: "SEARXNG_URL",
    async search(query, serverUrl, context) {
        const url = searxngSearchUrl(serverUrl);
        url.searchParams.set("q", query);
        url.searchParams.set("format", "json");
        let body;
        try {
            body = await requestJson(context, "SearXNG", url.toString(), { method: "GET" });
        }
        catch (error) {
            // SearXNG answers 403 when the JSON format is not enabled on the server.
            if (error instanceof ProviderRequestError && error.status === 403) {
                throw new ProviderRequestError('SearXNG refused the JSON format. Add "json" to search.formats in the server\'s settings.yml, then restart it.', 403);
            }
            throw error;
        }
        return collect(asArray(asRecord(body)?.results), (item) => toResult({ url: item.url, title: item.title, content: item.content, published: item.publishedDate }));
    },
};
export const brave = {
    id: "brave",
    name: "Brave Search",
    access: "key",
    env: "BRAVE_API_KEY",
    async search(query, apiKey, context) {
        const url = new URL("https://api.search.brave.com/res/v1/web/search");
        url.searchParams.set("q", query);
        url.searchParams.set("count", String(MAX_RESULTS));
        url.searchParams.set("text_decorations", "false");
        const body = await requestJson(context, "Brave Search", url.toString(), {
            method: "GET",
            headers: { "X-Subscription-Token": apiKey },
        });
        return collect(asArray(asRecord(asRecord(body)?.web)?.results), (item) => toResult({ url: item.url, title: item.title, content: item.description, published: item.page_age }));
    },
};
export const kagi = {
    id: "kagi",
    name: "Kagi",
    access: "key",
    env: "KAGI_API_KEY",
    sessionEnv: "KAGI_SESSION_TOKEN",
    search: kagiSearch,
    sessionSearch: kagiSessionSearch,
};
export const perplexity = {
    // `perplexity` is OpenCode's id for Perplexity's models, and
    // PERPLEXITY_API_KEY is usually set for them: reading it would turn search
    // on and bill it to that key without the user asking.
    id: "perplexity-search",
    name: "Perplexity Search",
    access: "key",
    env: "PERPLEXITY_SEARCH_API_KEY",
    async search(query, apiKey, context) {
        const body = await requestJson(context, "Perplexity Search", "https://api.perplexity.ai/search", {
            ...jsonBody({ query, max_results: MAX_RESULTS }),
            headers: { "Content-Type": "application/json", ...bearer(apiKey) },
        });
        return collect(asArray(asRecord(body)?.results), (item) => toResult({ url: item.url, title: item.title, content: item.snippet, published: item.date ?? item.last_updated }));
    },
};
export const linkup = {
    id: "linkup",
    name: "Linkup",
    access: "key",
    env: "LINKUP_API_KEY",
    async search(query, apiKey, context) {
        const body = await requestJson(context, "Linkup", "https://api.linkup.so/v1/search", {
            ...jsonBody({ q: query, depth: "fast", outputType: "searchResults", maxResults: MAX_RESULTS }),
            headers: { "Content-Type": "application/json", ...bearer(apiKey) },
        });
        return collect(asArray(asRecord(body)?.results), (item) => item.type === "text" ? toResult({ url: item.url, title: item.name, content: item.content }) : undefined);
    },
};
export const serper = {
    id: "serper",
    name: "Serper",
    access: "key",
    env: "SERPER_API_KEY",
    async search(query, apiKey, context) {
        const body = await requestJson(context, "Serper", "https://google.serper.dev/search", {
            ...jsonBody({ q: query, num: MAX_RESULTS }),
            headers: { "Content-Type": "application/json", "X-API-KEY": apiKey },
        });
        return collect(asArray(asRecord(body)?.organic), (item) => toResult({ url: item.link, title: item.title, content: item.snippet, published: item.date }));
    },
};
export const PROVIDERS = [searxng, brave, kagi, perplexity, linkup, serper];
