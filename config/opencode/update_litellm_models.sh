#!/usr/bin/env bash
#
# Sync the models list of a LiteLLM provider in opencode.json / opencode.jsonc
# with the models currently available on the LiteLLM proxy.
#
# Comments, trailing commas and formatting in the config are preserved:
# only the individual model entries that changed are edited.
#
# Usage:
#   ./update_litellm_models.sh [path/to/opencode.jsonc]
#
# Environment:
#   LITELLM_API_KEY     (required) API key for the LiteLLM proxy
#   LITELLM_BASE_URL    (optional) override the baseURL; it is also written into
#                       the config's provider.litellm.options.baseURL
#
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

: "${LITELLM_API_KEY:?LITELLM_API_KEY is not set}"
for cmd in curl node npm; do
  command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is required but not installed"
done

# Locate the config: argument, then the default locations.
CONFIG="${1:-}"
if [[ -z "$CONFIG" ]]; then
  for f in "$HOME/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.json"; do
    [[ -f "$f" ]] && CONFIG="$f" && break
  done
fi
[[ -n "$CONFIG" && -f "$CONFIG" ]] || die "config not found (pass a path to opencode.json/opencode.jsonc)"

# jsonc-parser (from VS Code) is installed once into a cache directory.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/opencode-model-sync"
if [[ ! -d "$CACHE/node_modules/jsonc-parser" ]]; then
  echo "Installing jsonc-parser into $CACHE ..."
  mkdir -p "$CACHE"
  npm install --silent --no-audit --no-fund --prefix "$CACHE" jsonc-parser@3 >/dev/null \
    || die "failed to install jsonc-parser"
fi
export NODE_PATH="$CACHE/node_modules"

export CONFIG

# Step 1: read the baseURL from the config.
base_url="${LITELLM_BASE_URL:-$(node -e '
  const fs = require("fs"), { parse, printParseErrorCode } = require("jsonc-parser");
  const text = fs.readFileSync(process.env.CONFIG, "utf8");
  const errors = [];
  const cfg = parse(text, errors, { allowTrailingComma: true, disallowComments: false });
  if (errors.length) {
    for (const e of errors) {
      const before = text.slice(0, e.offset).split("\n");
      const hint = e.offset >= text.trimEnd().length ? " (unexpected end of file: missing closing bracket?)" : "";
      console.error(`${process.env.CONFIG}:${before.length}:${before.at(-1).length + 1}: ${printParseErrorCode(e.error)}${hint}`);
    }
    process.exit(1);
  }
  process.stdout.write(cfg?.provider?.litellm?.options?.baseURL ?? "");
')}" || die "could not parse $CONFIG"
[[ -n "$base_url" ]] || die "no baseURL found at provider.litellm.options.baseURL"
base_url="${base_url%/}"

# Step 2: fetch the models from LiteLLM.
echo "Fetching models from $base_url/models ..."
MODELS_RESPONSE="$(curl -fsS --max-time 20 \
  -H "Authorization: Bearer $LITELLM_API_KEY" \
  "$base_url/models")" || die "request to $base_url/models failed"
export MODELS_RESPONSE BASE_URL_OVERRIDE="${LITELLM_BASE_URL:+$base_url}"

# Step 3: apply per-model edits, leaving the rest of the file untouched.
node <<'JS'
const fs = require("fs");
const { parse, modify, applyEdits } = require("jsonc-parser");
const { CONFIG, MODELS_RESPONSE, BASE_URL_OVERRIDE } = process.env;

let ids;
try {
  ids = [...new Set(JSON.parse(MODELS_RESPONSE).data.map(m => m.id))].sort();
} catch {
  console.error("error: unexpected response from LiteLLM: " + MODELS_RESPONSE);
  process.exit(1);
}
if (!ids.length) {
  console.error("error: LiteLLM returned no models; leaving config untouched");
  process.exit(1);
}

const original = fs.readFileSync(CONFIG, "utf8");
const opts = { allowTrailingComma: true, disallowComments: false };
const provider = parse(original, [], opts)?.provider?.litellm ?? {};
const existing = provider.models ?? {};
const oldBaseURL = provider.options?.baseURL;
const baseChanged = !!BASE_URL_OVERRIDE && BASE_URL_OVERRIDE !== oldBaseURL;

// Match the file's indentation for any new lines.
const indent = original.match(/^([ \t]+)"/m)?.[1] ?? "  ";
const fmt = { formattingOptions: { insertSpaces: !indent.includes("\t"), tabSize: indent.length } };

const added = ids.filter(id => !(id in existing));
const removed = Object.keys(existing).filter(id => !ids.includes(id));

if (!added.length && !removed.length && !baseChanged) {
  console.log(`Models already up to date (${ids.length} models).`);
  process.exit(0);
}

let text = original;
if (baseChanged) {
  text = applyEdits(text, modify(text, ["provider", "litellm", "options", "baseURL"], BASE_URL_OVERRIDE, fmt));
}
const path = ["provider", "litellm", "models"];
for (const id of removed) text = applyEdits(text, modify(text, [...path, id], undefined, fmt));
for (const id of added)   text = applyEdits(text, modify(text, [...path, id], { name: id }, fmt));

if (baseChanged)    console.log(`baseURL: ${oldBaseURL ?? "(unset)"} -> ${BASE_URL_OVERRIDE}`);
if (added.length)   console.log("Added:\n" + added.map(i => "  + " + i).join("\n"));
if (removed.length) console.log("Removed:\n" + removed.map(i => "  - " + i).join("\n"));

// Back up, then write atomically.
fs.copyFileSync(CONFIG, CONFIG + ".bak");
const tmp = CONFIG + ".tmp-" + process.pid;
fs.writeFileSync(tmp, text);
fs.renameSync(tmp, CONFIG);
console.log(`Updated ${CONFIG} (backup at ${CONFIG}.bak)`);
JS
