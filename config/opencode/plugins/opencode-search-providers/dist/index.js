import { asString, ProviderRequestError } from "./http.js";
import { PROVIDERS } from "./providers.js";
export { PROVIDERS } from "./providers.js";
/**
 * Marks an integration as the account of a web search provider with the same
 * id. Clients that list integrations (OpenChamber's Settings → Web search) use
 * it to offer the provider before it is connected, when `websearch` does not
 * list it yet, and to keep it out of the model providers.
 */
export const WEBSEARCH_INTEGRATION_METADATA = { websearch: true };
const SERVER_METHOD_ID = "server";
const SERVER_URL_FIELD = "url";
/** The key or server address a credential holds for this provider. */
export function secretOf(provider, credential) {
    if (!credential)
        return undefined;
    if (provider.access === "key")
        return credential.type === "key" ? asString(credential.key)?.trim() : undefined;
    if (credential.type === "external")
        return asString(credential.metadata?.[SERVER_URL_FIELD])?.trim();
    // The environment variable arrives as a key whose value is the address.
    if (credential.type === "key")
        return asString(credential.key)?.trim();
    return undefined;
}
function registerIntegration(editor, provider) {
    editor.update(provider.id, (integration) => {
        integration.name = provider.name;
        Object.assign(integration, { metadata: WEBSEARCH_INTEGRATION_METADATA });
    });
    if (provider.access === "key") {
        editor.method.update({
            integrationID: provider.id,
            method: { type: "key", label: provider.sessionEnv ? "API key or session token" : "API key" },
        });
    }
    else {
        editor.method.update({
            integrationID: provider.id,
            method: {
                id: SERVER_METHOD_ID,
                type: "external",
                label: "Your SearXNG server",
                form: [
                    {
                        key: SERVER_URL_FIELD,
                        type: "string",
                        format: "uri",
                        title: "Server URL",
                        description: "The address of a SearXNG server with the JSON format enabled.",
                        placeholder: "https://searx.example.org",
                        required: true,
                    },
                ],
            },
        });
    }
    const names = provider.access === "key" && provider.sessionEnv ? [provider.env, provider.sessionEnv] : [provider.env];
    editor.method.update({ integrationID: provider.id, method: { type: "env", names } });
}
const RELOAD_EVENTS = new Set(["credential.updated", "credential.switched", "integration.updated"]);
function notConnectedMessage(provider) {
    if (provider.access === "server")
        return `${provider.name} is not connected: add its server URL or set ${provider.env}.`;
    if (provider.sessionEnv) {
        return `${provider.name} is not connected: add its API key or session token, or set ${provider.env} or ${provider.sessionEnv}.`;
    }
    return `${provider.name} is not connected: add its API key or set ${provider.env}.`;
}
export const SearchProvidersPlugin = {
    id: "openchamber.search-providers",
    async setup(ctx) {
        await ctx.integration.transform((editor) => {
            for (const provider of PROVIDERS)
                registerIntegration(editor, provider);
        });
        const secretFor = async (provider) => {
            const connection = await ctx.integration.connection.active(provider.id);
            if (!connection)
                return undefined;
            const value = secretOf(provider, await ctx.integration.connection.resolve(connection));
            if (!value)
                return undefined;
            const session = provider.access === "key" &&
                provider.sessionEnv !== undefined &&
                connection.type === "env" &&
                connection.name === provider.sessionEnv;
            return { value, session };
        };
        const readAvailable = async () => {
            const secrets = await Promise.all(PROVIDERS.map((provider) => secretFor(provider).catch(() => undefined)));
            return new Set(PROVIDERS.filter((_, index) => secrets[index] !== undefined).map((provider) => provider.id));
        };
        let available = await readAvailable();
        await ctx.websearch.transform((editor) => {
            for (const provider of PROVIDERS) {
                if (!available.has(provider.id))
                    continue;
                editor.add({
                    id: provider.id,
                    name: provider.name,
                    async execute(input, { signal }) {
                        // Read on every search, so a replaced key applies to the next one.
                        const secret = await secretFor(provider);
                        if (!secret)
                            throw new ProviderRequestError(notConnectedMessage(provider));
                        if (provider.access === "key" && secret.session && provider.sessionSearch) {
                            return provider.sessionSearch(input.query, secret.value, { fetch, signal });
                        }
                        return provider.search(input.query, secret.value, { fetch, signal });
                    },
                });
            }
        });
        // A key saved or removed later adds or drops its provider. Refreshes run
        // one at a time, so an older read never replaces a newer one.
        let refreshing = Promise.resolve();
        const refresh = () => {
            refreshing = refreshing.then(async () => {
                const next = await readAvailable();
                if (next.size === available.size && [...next].every((id) => available.has(id)))
                    return;
                available = next;
                await ctx.websearch.reload();
            }).catch((error) => {
                console.warn("[opencode-search-providers] could not refresh the providers", error instanceof Error ? error.message : error);
            });
        };
        const controller = new AbortController();
        void (async () => {
            try {
                for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
                    if (RELOAD_EVENTS.has(event.type))
                        refresh();
                }
            }
            catch (error) {
                if (!controller.signal.aborted) {
                    console.warn("[opencode-search-providers] event stream ended", error instanceof Error ? error.message : error);
                }
            }
        })();
        return () => controller.abort();
    },
};
export default SearchProvidersPlugin;
