import type { WebSearch } from "@opencode/plugin";
export type SearchResult = WebSearch.Result;
/** What a provider needs to make its request: injected so tests run without a network. */
export interface RequestContext {
    readonly fetch: typeof fetch;
    readonly signal: AbortSignal;
}
/** Results per search; the built-in providers return about as many. */
export declare const MAX_RESULTS = 8;
/** Characters of page text kept per result, so one long page cannot fill the context. */
export declare const MAX_CONTENT_CHARS = 2000;
export declare class ProviderRequestError extends Error {
    readonly status?: number | undefined;
    constructor(message: string, status?: number | undefined);
}
/**
 * Sends one request and returns the parsed JSON body. A non-2xx answer becomes
 * an error that names the provider and says what usually causes that status,
 * because the agent shows the message to the user as is.
 */
export declare function requestJson(context: RequestContext, provider: string, url: string, init: RequestInit): Promise<unknown>;
/** A page a provider answered, with the address after redirects. */
export interface HtmlResponse {
    readonly url: string;
    readonly text: string;
}
/** Sends one request and returns the body as text, for providers that answer HTML. */
export declare function requestHtml(context: RequestContext, provider: string, url: string, init: RequestInit): Promise<HtmlResponse>;
/** Reads `value` as an object, or `undefined` when it is anything else. */
export declare function asRecord(value: unknown): Record<string, unknown> | undefined;
export declare function asArray(value: unknown): unknown[];
export declare function asString(value: unknown): string | undefined;
/** Decodes the entities that show up in search snippets and HTML result pages. */
export declare function decodeEntities(value: string): string;
/** Plain text from a snippet that may carry highlight tags and entities, cut to the content limit. */
export declare function cleanText(value: unknown): string | undefined;
/** Milliseconds since the epoch for a date string, or `undefined` when it does not parse. */
export declare function parseTime(value: unknown): number | undefined;
/** One result in OpenCode's shape, or `undefined` when it has no http(s) URL. */
export declare function toResult(input: {
    url: unknown;
    title?: unknown;
    content?: unknown;
    published?: unknown;
}): SearchResult | undefined;
export declare function collect(items: unknown[], map: (item: Record<string, unknown>) => SearchResult | undefined): SearchResult[];
