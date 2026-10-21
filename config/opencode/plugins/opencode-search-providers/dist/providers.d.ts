import { type RequestContext, type SearchResult } from "./http.js";
/**
 * One search service. `key` providers take an API key; the `server` provider
 * takes the address of a server the user runs. `env` names the environment
 * variable OpenCode also reads the key or address from. `sessionEnv` and
 * `sessionSearch` let a key provider accept a session token as well, from its
 * own environment variable.
 */
export type SearchProvider = {
    readonly id: string;
    readonly name: string;
    readonly access: "key";
    readonly env: string;
    readonly sessionEnv?: string;
    readonly search: (query: string, apiKey: string, context: RequestContext) => Promise<SearchResult[]>;
    readonly sessionSearch?: (query: string, sessionToken: string, context: RequestContext) => Promise<SearchResult[]>;
} | {
    readonly id: string;
    readonly name: string;
    readonly access: "server";
    readonly env: string;
    readonly search: (query: string, serverUrl: string, context: RequestContext) => Promise<SearchResult[]>;
};
/** `https://searx.example.org`, with or without a trailing slash or `/search`, to its search endpoint. */
export declare function searxngSearchUrl(serverUrl: string): URL;
export declare const searxng: SearchProvider;
export declare const brave: SearchProvider;
export declare const kagi: SearchProvider;
export declare const perplexity: SearchProvider;
export declare const linkup: SearchProvider;
export declare const serper: SearchProvider;
export declare const PROVIDERS: readonly SearchProvider[];
