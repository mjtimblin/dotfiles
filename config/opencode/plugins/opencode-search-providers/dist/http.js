/** Results per search; the built-in providers return about as many. */
export const MAX_RESULTS = 8;
/** Characters of page text kept per result, so one long page cannot fill the context. */
export const MAX_CONTENT_CHARS = 2000;
const TIMEOUT_MS = 25_000;
const ERROR_BODY_CHARS = 300;
export class ProviderRequestError extends Error {
    status;
    constructor(message, status) {
        super(message);
        this.status = status;
        this.name = "ProviderRequestError";
    }
}
/**
 * Sends one request and returns the parsed JSON body. A non-2xx answer becomes
 * an error that names the provider and says what usually causes that status,
 * because the agent shows the message to the user as is.
 */
export async function requestJson(context, provider, url, init) {
    const response = await request(context, provider, url, init, "application/json");
    try {
        return await response.json();
    }
    catch {
        throw new ProviderRequestError(`${provider} answered with something that is not JSON.`);
    }
}
/** Sends one request and returns the body as text, for providers that answer HTML. */
export async function requestHtml(context, provider, url, init) {
    const response = await request(context, provider, url, init, "text/html");
    return { url: response.url, text: await response.text() };
}
async function request(context, provider, url, init, accept) {
    const signal = AbortSignal.any([context.signal, AbortSignal.timeout(TIMEOUT_MS)]);
    let response;
    try {
        response = await context.fetch(url, {
            ...init,
            signal,
            headers: { Accept: accept, ...init.headers },
        });
    }
    catch (error) {
        if (context.signal.aborted)
            throw error;
        if (signal.aborted)
            throw new ProviderRequestError(`${provider} did not answer within ${TIMEOUT_MS / 1000} seconds.`);
        throw new ProviderRequestError(`Could not reach ${provider}: ${error instanceof Error ? error.message : String(error)}`);
    }
    if (!response.ok) {
        const body = (await response.text().catch(() => "")).trim().slice(0, ERROR_BODY_CHARS);
        const message = [`${provider} answered HTTP ${response.status}.`, statusHint(response.status), body ? `Response: ${body}` : ""]
            .filter(Boolean)
            .join(" ");
        throw new ProviderRequestError(message, response.status);
    }
    return response;
}
function statusHint(status) {
    if (status === 401 || status === 403)
        return "The API key was rejected or lacks access to this API.";
    if (status === 402)
        return "The account has no credits left.";
    if (status === 429)
        return "The rate limit or the plan's quota is used up.";
    if (status >= 500)
        return "The service had an internal error; try again later.";
    return "";
}
/** Reads `value` as an object, or `undefined` when it is anything else. */
export function asRecord(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value) ? value : undefined;
}
export function asArray(value) {
    return Array.isArray(value) ? value : [];
}
export function asString(value) {
    return typeof value === "string" && value.trim() !== "" ? value : undefined;
}
const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", "#39": "'", nbsp: " " };
/** Decodes the entities that show up in search snippets and HTML result pages. */
export function decodeEntities(value) {
    return value
        .replace(/&#(x?)([0-9a-f]+);/gi, (_, hex, code) => {
        const point = Number.parseInt(code, hex ? 16 : 10);
        return Number.isFinite(point) && point >= 0 && point <= 0x10ffff ? String.fromCodePoint(point) : "";
    })
        .replace(/&(amp|lt|gt|quot|apos|nbsp);/g, (_, name) => ENTITIES[name] ?? "");
}
/** Plain text from a snippet that may carry highlight tags and entities, cut to the content limit. */
export function cleanText(value) {
    const text = asString(value);
    if (!text)
        return undefined;
    const plain = decodeEntities(text.replace(/<[^>]+>/g, "")).trim();
    if (!plain)
        return undefined;
    return plain.length > MAX_CONTENT_CHARS ? `${plain.slice(0, MAX_CONTENT_CHARS).trimEnd()}…` : plain;
}
/** Milliseconds since the epoch for a date string, or `undefined` when it does not parse. */
export function parseTime(value) {
    const text = asString(value);
    if (!text)
        return undefined;
    const time = Date.parse(text);
    return Number.isFinite(time) ? time : undefined;
}
/** One result in OpenCode's shape, or `undefined` when it has no http(s) URL. */
export function toResult(input) {
    const url = asString(input.url);
    if (!url || !/^https?:\/\//i.test(url))
        return undefined;
    const title = cleanText(input.title);
    const content = cleanText(input.content);
    const published = parseTime(input.published);
    return {
        url,
        ...(title ? { title } : {}),
        ...(content ? { content } : {}),
        time: published === undefined ? {} : { published },
    };
}
export function collect(items, map) {
    const results = [];
    for (const item of items) {
        const record = asRecord(item);
        const result = record ? map(record) : undefined;
        if (result)
            results.push(result);
        if (results.length === MAX_RESULTS)
            break;
    }
    return results;
}
