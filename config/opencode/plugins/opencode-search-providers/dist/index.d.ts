/**
 * Web search providers for OpenCode's built-in `websearch` tool.
 *
 * Every provider is an OpenCode integration, so its key (or, for SearXNG, its
 * server address) is saved where OpenCode keeps credentials and read from an
 * environment variable as well. Kagi also accepts a session token, from
 * KAGI_SESSION_TOKEN or the same field as its API key. A provider joins
 * `websearch` only once it has a key, a token or an address: OpenCode's
 * default "any available provider" choice picks among every registered
 * provider and stays with the one it picked, so a provider without a
 * credential would fail searches for the whole session.
 *
 * Register in opencode.json:
 *   { "plugins": ["@openchamber/opencode-search-providers"] }
 */
import type { Credential, Plugin } from "@opencode/plugin";
import { type SearchProvider } from "./providers.js";
export { PROVIDERS, type SearchProvider } from "./providers.js";
/**
 * Marks an integration as the account of a web search provider with the same
 * id. Clients that list integrations (OpenChamber's Settings → Web search) use
 * it to offer the provider before it is connected, when `websearch` does not
 * list it yet, and to keep it out of the model providers.
 */
export declare const WEBSEARCH_INTEGRATION_METADATA: {
    readonly websearch: true;
};
/** The key or server address a credential holds for this provider. */
export declare function secretOf(provider: SearchProvider, credential: Credential.Value | undefined): string | undefined;
export declare const SearchProvidersPlugin: Plugin.Plugin;
export default SearchProvidersPlugin;
