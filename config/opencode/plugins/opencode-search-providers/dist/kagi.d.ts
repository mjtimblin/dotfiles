import { type RequestContext, type SearchResult } from "./http.js";
/** The token in a Kagi session link such as `https://kagi.com/search?token=...`. */
export declare function kagiSessionToken(value: string): string | undefined;
/** A session token as typed, or the token from a session link; `undefined` when empty or the link has none. */
export declare function normalizeKagiSessionToken(value: string): string | undefined;
/** An absolute date from a Kagi result, `Oct 4, 2026`, as an ISO timestamp. */
export declare function parseKagiDate(value: string): string | undefined;
/** Whether a 200 answer is Kagi's signed-out search page rather than results. */
export declare function kagiLooksUnauthenticated(html: string): boolean;
/**
 * Reads results from Kagi's HTML search page. It looks for the same elements
 * Kagi's own markup uses: normal `.search-result` blocks and `.sr-group`
 * groups, each with a title link, a description and an optional date.
 */
export declare function parseKagiHtml(html: string): SearchResult[];
/** Search with an API key, which answers JSON. */
export declare function kagiApiSearch(query: string, apiKey: string, context: RequestContext): Promise<SearchResult[]>;
/** Search with a browser session token, which answers Kagi's HTML search page. */
export declare function kagiSessionSearch(query: string, sessionToken: string, context: RequestContext): Promise<SearchResult[]>;
/**
 * Searches Kagi with whichever credential it was given: an API key, a session
 * token, or a session link. A plain value is tried as an API key first, then
 * as a session token when Kagi rejects it, so the same field serves both.
 */
export declare function kagiSearch(query: string, secret: string, context: RequestContext): Promise<SearchResult[]>;
