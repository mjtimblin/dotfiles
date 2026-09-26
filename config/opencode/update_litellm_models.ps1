#!/usr/bin/env pwsh
#
# Sync the models list of a LiteLLM provider in opencode.json / opencode.jsonc
# with the models currently available on the LiteLLM proxy.
#
# Comments, trailing commas and formatting in the config are preserved:
# only the individual model entries that changed are edited.
#
# PowerShell 7+ equivalent of update_litellm_models.sh. The HTTP request is
# made with Invoke-WebRequest instead of curl; node/npm are still used for
# jsonc-parser (VS Code's JSON-with-comments parser).
#
# Usage:
#   ./update_litellm_models.ps1 [path/to/opencode.jsonc]
#
# Environment:
#   LITELLM_API_KEY     (required) API key for the LiteLLM proxy
#   LITELLM_BASE_URL    (optional) override the baseURL; it is also written into
#                       the config's provider.litellm.options.baseURL
#
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

function Die {
    param([string]$Message)
    [Console]::Error.WriteLine("error: $Message")
    exit 1
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
if (-not $env:LITELLM_API_KEY) {
    Die "LITELLM_API_KEY is not set"
}
foreach ($cmd in @("node", "npm")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Die "'$cmd' is required but not installed"
    }
}

# ---------------------------------------------------------------------------
# Locate the config: argument, then the default locations.
# ---------------------------------------------------------------------------
$CONFIG = $ConfigPath
if (-not $CONFIG) {
    foreach ($f in @(
        (Join-Path $HOME ".config/opencode/opencode.jsonc"),
        (Join-Path $HOME ".config/opencode/opencode.json")
    )) {
        if (Test-Path -LiteralPath $f -PathType Leaf) {
            $CONFIG = $f
            break
        }
    }
}
if (-not $CONFIG -or -not (Test-Path -LiteralPath $CONFIG -PathType Leaf)) {
    Die "config not found (pass a path to opencode.json/opencode.jsonc)"
}
$CONFIG = (Resolve-Path -LiteralPath $CONFIG).Path

# ---------------------------------------------------------------------------
# jsonc-parser (from VS Code) is installed once into a cache directory.
# ---------------------------------------------------------------------------
$CacheRoot = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME ".cache" }
$CACHE = Join-Path $CacheRoot "opencode-model-sync"
$JsoncParserDir = Join-Path $CACHE "node_modules/jsonc-parser"
if (-not (Test-Path -LiteralPath $JsoncParserDir -PathType Container)) {
    Write-Host "Installing jsonc-parser into $CACHE ..."
    New-Item -ItemType Directory -Force -Path $CACHE | Out-Null
    & npm install --silent --no-audit --no-fund --prefix $CACHE jsonc-parser@3 *> $null
    if ($LASTEXITCODE -ne 0) { Die "failed to install jsonc-parser" }
}
$env:NODE_PATH = Join-Path $CACHE "node_modules"

$env:CONFIG = $CONFIG

# ---------------------------------------------------------------------------
# Step 1: read the baseURL from the config.
# ---------------------------------------------------------------------------
$readBaseUrl = @'
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
'@

if ($env:LITELLM_BASE_URL) {
    $base_url = $env:LITELLM_BASE_URL
} else {
    $base_url = (& node -e $readBaseUrl)
    if ($LASTEXITCODE -ne 0) { Die "could not parse $CONFIG" }
}
if (-not $base_url) { Die "no baseURL found at provider.litellm.options.baseURL" }
$base_url = $base_url.TrimEnd("/")

# ---------------------------------------------------------------------------
# Step 2: fetch the models from LiteLLM.
# ---------------------------------------------------------------------------
Write-Host "Fetching models from $base_url/models ..."
try {
    $response = Invoke-WebRequest `
        -Uri "$base_url/models" `
        -Headers @{ Authorization = "Bearer $env:LITELLM_API_KEY" } `
        -TimeoutSec 20
    $modelsResponse = $response.Content
} catch {
    Die "request to $base_url/models failed"
}
$env:MODELS_RESPONSE = $modelsResponse
if ($env:LITELLM_BASE_URL) {
    $env:BASE_URL_OVERRIDE = $base_url
} else {
    $env:BASE_URL_OVERRIDE = ""
}

# ---------------------------------------------------------------------------
# Step 3: apply per-model edits, leaving the rest of the file untouched.
# ---------------------------------------------------------------------------
$applyEdits = @'
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
'@

& node -e $applyEdits
exit $LASTEXITCODE

