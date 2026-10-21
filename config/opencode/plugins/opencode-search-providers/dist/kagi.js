import { asArray, asRecord, cleanText, collect, decodeEntities, MAX_RESULTS, ProviderRequestError, requestHtml, requestJson, toResult, } from "./http.js";
const KAGI_API_URL = "https://kagi.com/api/v1/search";
const KAGI_HTML_URL = "https://kagi.com/html/search";
const USER_AGENT = "opencode-search-providers (+https://github.com/openchamber/opencode-search-providers)";
/**
 * Kagi answers its HTML search page with these phrases when the session token
 * is missing or expired. The search page carries all three together.
 */
const UNAUTHENTICATED_MARKERS = [
    "<title>Kagi Search - A Premium Search Engine</title>",
    "Welcome to Kagi",
    "paid search engine that gives power back to the user",
];
const MONTHS = {
    jan: 0,
    feb: 1,
    mar: 2,
    apr: 3,
    may: 4,
    jun: 5,
    jul: 6,
    aug: 7,
    sep: 8,
    oct: 9,
    nov: 10,
    dec: 11,
};
const VOID_ELEMENTS = new Set([
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr",
]);
/** The token in a Kagi session link such as `https://kagi.com/search?token=...`. */
export function kagiSessionToken(value) {
    const text = value.trim();
    if (!/^https?:\/\//i.test(text))
        return undefined;
    try {
        return new URL(text).searchParams.get("token")?.trim() || undefined;
    }
    catch {
        return undefined;
    }
}
/** A session token as typed, or the token from a session link; `undefined` when empty or the link has none. */
export function normalizeKagiSessionToken(value) {
    const text = value.trim();
    if (!text)
        return undefined;
    if (/^https?:\/\//i.test(text))
        return kagiSessionToken(text);
    return text;
}
/** An absolute date from a Kagi result, `Oct 4, 2026`, as an ISO timestamp. */
export function parseKagiDate(value) {
    const match = /^([A-Za-z]{3,9})\s+(\d{1,2}),\s+(\d{4})$/.exec(value.trim());
    if (!match)
        return undefined;
    const month = MONTHS[match[1].slice(0, 3).toLowerCase()];
    if (month === undefined)
        return undefined;
    const day = Number(match[2]);
    const year = Number(match[3]);
    const date = new Date(Date.UTC(year, month, day));
    if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month || date.getUTCDate() !== day)
        return undefined;
    return date.toISOString();
}
/** Whether a 200 answer is Kagi's signed-out search page rather than results. */
export function kagiLooksUnauthenticated(html) {
    return UNAUTHENTICATED_MARKERS.every((marker) => html.includes(marker));
}
/**
 * Reads results from Kagi's HTML search page. It looks for the same elements
 * Kagi's own markup uses: normal `.search-result` blocks and `.sr-group`
 * groups, each with a title link, a description and an optional date.
 */
export function parseKagiHtml(html) {
    const source = html
        .replace(/<!--[\s\S]*?-->/g, "")
        .replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, "");
    const elements = scanHtml(source);
    const results = [];
    for (const block of elements) {
        if (!block.classes.has("search-result"))
            continue;
        const link = firstByClass(elements, block, "__sri_title_link", "a");
        const result = extractResult(source, elements, block, link);
        if (result)
            results.push(result);
        if (results.length === MAX_RESULTS)
            return results;
    }
    for (const group of elements) {
        if (!group.classes.has("sr-group"))
            continue;
        for (const item of descendants(elements, group)) {
            if (!item.classes.has("__srgi"))
                continue;
            const titleBox = firstByClass(elements, item, "__srgi-title");
            const link = titleBox ? descendants(elements, titleBox).find((element) => element.name === "a") : undefined;
            const result = extractResult(source, elements, item, link);
            if (result)
                results.push(result);
            if (results.length === MAX_RESULTS)
                return results;
        }
    }
    return results;
}
function scanHtml(html) {
    const tagPattern = /<(\/?)([a-zA-Z][\w:-]*)((?:"[^"]*"|'[^']*'|[^'">])*)>/g;
    const open = [];
    const elements = [];
    let match;
    while ((match = tagPattern.exec(html))) {
        const closing = match[1] === "/";
        const name = match[2].toLowerCase();
        const attrText = match[3] ?? "";
        const start = match.index;
        const end = start + match[0].length;
        if (closing) {
            let index = open.length - 1;
            while (index >= 0 && open[index].name !== name)
                index -= 1;
            if (index < 0)
                continue;
            // Close any elements left open inside this one at the closing tag too.
            while (open.length > index) {
                const element = open.pop();
                elements.push({ ...element, closeStart: start, end });
            }
            continue;
        }
        const attrs = parseAttributes(attrText);
        const element = {
            name,
            attrs,
            classes: new Set((attrs.get("class") ?? "").split(/\s+/).filter(Boolean)),
            start,
            openEnd: end,
        };
        if (VOID_ELEMENTS.has(name) || /(?:^|\s)\/\s*$/.test(attrText)) {
            elements.push({ ...element, closeStart: end, end });
        }
        else {
            open.push(element);
        }
    }
    return elements.sort((left, right) => left.start - right.start);
}
function parseAttributes(source) {
    const attrs = new Map();
    const pattern = /([^\s"'<>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;
    let match;
    while ((match = pattern.exec(source))) {
        const value = match[2] ?? match[3] ?? match[4] ?? "";
        attrs.set(match[1].toLowerCase(), decodeEntities(value));
    }
    return attrs;
}
function isInside(element, parent) {
    return element.start >= parent.openEnd && element.end <= parent.closeStart;
}
function descendants(elements, parent) {
    return elements.filter((element) => isInside(element, parent));
}
function firstByClass(elements, parent, className, tag) {
    return elements.find((element) => element.classes.has(className) && (tag === undefined || element.name === tag) && isInside(element, parent));
}
function allByClass(elements, parent, className) {
    return elements.filter((element) => element.classes.has(className) && isInside(element, parent));
}
function plainText(source) {
    return source
        .replace(/<br\s*\/?>/gi, " ")
        .replace(/<[^>]+>/g, "")
        .replace(/\s+/g, " ")
        .trim();
}
/** Text inside `container`, leaving out each element in `skipped`. */
function textOutside(html, container, skipped) {
    let source = "";
    let cursor = container.openEnd;
    for (const element of [...skipped].sort((left, right) => left.start - right.start)) {
        if (element.start < cursor || element.start < container.openEnd || element.end > container.closeStart)
            continue;
        source += html.slice(cursor, element.start);
        source += " ";
        cursor = element.end;
    }
    source += html.slice(cursor, container.closeStart);
    return plainText(source);
}
function extractResult(html, elements, block, titleLink) {
    if (!titleLink)
        return undefined;
    const title = plainText(html.slice(titleLink.openEnd, titleLink.closeStart));
    if (!title)
        return undefined;
    const description = firstByClass(elements, block, "__sri-desc");
    let content;
    let published;
    if (description) {
        const time = firstByClass(elements, description, "__sri-time");
        if (time)
            published = parseKagiDate(plainText(html.slice(time.openEnd, time.closeStart)));
        const skipped = allByClass(elements, description, "summarize-link");
        // A relative date such as "Yesterday" stays in the snippet; an absolute
        // one becomes the published time and is removed from the text.
        if (time && published)
            skipped.push(time);
        content = cleanText(textOutside(html, description, skipped));
    }
    return toResult({ url: titleLink.attrs.get("href"), title, content, published });
}
/** Search with an API key, which answers JSON. */
export async function kagiApiSearch(query, apiKey, context) {
    const body = await requestJson(context, "Kagi", KAGI_API_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({ query, limit: MAX_RESULTS }),
    });
    return collect(asArray(asRecord(asRecord(body)?.data)?.search), (item) => toResult({ url: item.url, title: item.title, content: item.snippet, published: item.time }));
}
/** Search with a browser session token, which answers Kagi's HTML search page. */
export async function kagiSessionSearch(query, sessionToken, context) {
    const token = normalizeKagiSessionToken(sessionToken);
    if (!token) {
        throw new ProviderRequestError("The Kagi session link has no token in it. Paste a session link with a token parameter, or the token itself.");
    }
    const url = new URL(KAGI_HTML_URL);
    url.searchParams.set("q", query);
    let page;
    try {
        page = await requestHtml(context, "Kagi", url.toString(), {
            method: "GET",
            headers: { Cookie: `kagi_session=${token}`, "User-Agent": USER_AGENT },
        });
    }
    catch (error) {
        // A session that Kagi does not accept is answered with 401/403, or with a
        // redirect to its welcome or sign-in page when the request does not follow
        // redirects (a test double, for example).
        if (error instanceof ProviderRequestError &&
            error.status !== undefined &&
            (error.status === 401 || error.status === 403 || (error.status >= 300 && error.status < 400))) {
            throw new ProviderRequestError("Kagi rejected the session token. It may be invalid or expired.", error.status);
        }
        throw error;
    }
    if (signedOutPage(page.url) || kagiLooksUnauthenticated(page.text)) {
        throw new ProviderRequestError("Kagi rejected the session token. It may be invalid or expired.", 401);
    }
    return parseKagiHtml(page.text);
}
/** Kagi sends an invalid or expired session to its welcome or sign-in page. */
function signedOutPage(value) {
    try {
        const path = new URL(value).pathname.replace(/\/+$/, "");
        return path === "/welcome" || path === "/signin" || path === "/login";
    }
    catch {
        return false;
    }
}
function authenticationFailed(error) {
    return (error instanceof ProviderRequestError &&
        (error.status === 401 || error.status === 403 || error.message.includes("not JSON")));
}
/**
 * Searches Kagi with whichever credential it was given: an API key, a session
 * token, or a session link. A plain value is tried as an API key first, then
 * as a session token when Kagi rejects it, so the same field serves both.
 */
export async function kagiSearch(query, secret, context) {
    const linkedToken = kagiSessionToken(secret);
    if (linkedToken)
        return kagiSessionSearch(query, linkedToken, context);
    try {
        return await kagiApiSearch(query, secret, context);
    }
    catch (error) {
        if (!authenticationFailed(error))
            throw error;
        try {
            return await kagiSessionSearch(query, secret, context);
        }
        catch (sessionError) {
            if (!(sessionError instanceof ProviderRequestError))
                throw sessionError;
            throw new ProviderRequestError(`Kagi rejected the credential as an API key and as a session token. API key: ${error.message} Session token: ${sessionError.message}`, sessionError.status ?? (error instanceof ProviderRequestError ? error.status : undefined));
        }
    }
}
