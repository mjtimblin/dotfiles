#!/usr/bin/env pwsh
#
# Sync the models list of a LiteLLM provider in opencode.json / opencode.jsonc
# with the models currently available on the LiteLLM proxy.
#
# Both config layouts are supported: the native V2 "providers" map (plural,
# with settings.baseURL) and the legacy V1 "provider" map (singular, with
# options.baseURL). Every litellm provider block found is kept in sync.
#
# Each model is written with its modelID, display name and the context/output
# limits reported by LiteLLM (max_input_tokens / max_output_tokens), e.g.:
#
#   "deepseek-v4.1-flash": {
#     "modelID": "deepseek-v4.1-flash",
#     "name": "deepseek-v4.1-flash",
#     "limit": { "context": 1000000, "output": 384000 }
#   }
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
#                       the config's provider baseURL (V2 providers.litellm.settings
#                       or V1 provider.litellm.options)
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
    if ($script:WORK -and (Test-Path -LiteralPath $script:WORK)) {
        Remove-Item -Recurse -Force $script:WORK -ErrorAction SilentlyContinue
    }
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

# Scratch space for the (potentially large) LiteLLM responses. They are passed
# to node as files: the /model/info payload can exceed the environment size cap.
$script:WORK = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $script:WORK | Out-Null
$ModelsFile = Join-Path $script:WORK "models.json"
$InfoFile = Join-Path $script:WORK "model_info.json"

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
  process.stdout.write(cfg?.providers?.litellm?.settings?.baseURL ?? cfg?.provider?.litellm?.options?.baseURL ?? "");
'@

if ($env:LITELLM_BASE_URL) {
    $base_url = $env:LITELLM_BASE_URL
} else {
    $base_url = (& node -e $readBaseUrl)
    if ($LASTEXITCODE -ne 0) { Die "could not parse $CONFIG" }
}
if (-not $base_url) { Die "no baseURL found at providers.litellm.settings.baseURL or provider.litellm.options.baseURL" }
$base_url = $base_url.TrimEnd("/")

# ---------------------------------------------------------------------------
# Step 2: fetch the models from LiteLLM.
# ---------------------------------------------------------------------------
Write-Host "Fetching models from $base_url/models ..."
try {
    Invoke-WebRequest `
        -Uri "$base_url/models" `
        -Headers @{ Authorization = "Bearer $env:LITELLM_API_KEY" } `
        -TimeoutSec 20 `
        -OutFile $ModelsFile
} catch {
    Die "request to $base_url/models failed"
}

# Step 2b: fetch per-model info for the context window / max output tokens.
Write-Host "Fetching model info from $base_url/model/info ..."
try {
    Invoke-WebRequest `
        -Uri "$base_url/model/info" `
        -Headers @{ Authorization = "Bearer $env:LITELLM_API_KEY" } `
        -TimeoutSec 20 `
        -OutFile $InfoFile
} catch {
    Write-Warning "could not fetch $base_url/model/info; limits will not be populated"
    Set-Content -LiteralPath $InfoFile -Value "{}" -NoNewline
}

$env:MODELS_FILE = $ModelsFile
$env:MODEL_INFO_FILE = $InfoFile
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
const { CONFIG, MODELS_FILE, MODEL_INFO_FILE, BASE_URL_OVERRIDE } = process.env;

let ids;
try {
  ids = [...new Set(JSON.parse(fs.readFileSync(MODELS_FILE, "utf8")).data.map(m => m.id))].sort();
} catch {
  console.error("error: unexpected response from LiteLLM: " + fs.readFileSync(MODELS_FILE, "utf8"));
  process.exit(1);
}
if (!ids.length) {
  console.error("error: LiteLLM returned no models; leaving config untouched");
  process.exit(1);
}

// Build a model name -> limit map from /model/info. LiteLLM reports the
// context window as max_input_tokens and the output cap as max_output_tokens.
const toInt = v => (typeof v === "number" && Number.isFinite(v) ? Math.round(v) : undefined);
const limits = new Map();
let rawInfo = "";
try { rawInfo = fs.readFileSync(MODEL_INFO_FILE, "utf8").trim(); } catch {}
if (rawInfo) {
  try {
    for (const m of JSON.parse(rawInfo).data ?? []) {
      const info = m?.model_info ?? {};
      const context = toInt(info.max_input_tokens);
      const output = toInt(info.max_output_tokens);
      if (context === undefined && output === undefined) continue;
      const limit = {};
      if (context !== undefined) limit.context = context;
      if (output !== undefined) limit.output = output;
      if (typeof m?.model_name === "string") limits.set(m.model_name, limit);
    }
  } catch {
    console.error("warning: could not parse /model/info response; limits will not be populated");
  }
}

const original = fs.readFileSync(CONFIG, "utf8");
const opts = { allowTrailingComma: true, disallowComments: false };
const cfg = parse(original, [], opts) ?? {};

// OpenCode V2 uses a native "providers" map (plural) with settings.baseURL;
// V1 uses "provider" (singular) with options.baseURL. When both are present
// the native V2 entry takes precedence, so keep every block that exists in sync.
const targets = [];
const v2 = cfg?.providers?.litellm;
if (v2 && typeof v2 === "object") {
  targets.push({
    label: "providers.litellm",
    modelsPath: ["providers", "litellm", "models"],
    basePath: ["providers", "litellm", "settings", "baseURL"],
    models: v2.models ?? {},
    oldBaseURL: v2.settings?.baseURL,
  });
}
const v1 = cfg?.provider?.litellm;
if (v1 && typeof v1 === "object") {
  targets.push({
    label: "provider.litellm",
    modelsPath: ["provider", "litellm", "models"],
    basePath: ["provider", "litellm", "options", "baseURL"],
    models: v1.models ?? {},
    oldBaseURL: v1.options?.baseURL,
  });
}
// Nothing to sync yet: fall back to creating a V1 provider block.
if (!targets.length) {
  targets.push({
    label: "provider.litellm",
    modelsPath: ["provider", "litellm", "models"],
    basePath: ["provider", "litellm", "options", "baseURL"],
    models: {},
    oldBaseURL: undefined,
  });
}

// Match the file's indentation for any new lines.
const indent = original.match(/^([ \t]+)"/m)?.[1] ?? "  ";
const fmt = { formattingOptions: { insertSpaces: !indent.includes("\t"), tabSize: indent.length } };

const sameLimit = (a, b) => !!a && !!b && a.context === b.context && a.output === b.output;

let text = original;
let changed = false;
const report = [];

for (const t of targets) {
  const existing = t.models;
  const baseChanged = !!BASE_URL_OVERRIDE && BASE_URL_OVERRIDE !== t.oldBaseURL;

  const added = ids.filter(id => !(id in existing));
  const removed = Object.keys(existing).filter(id => !ids.includes(id));

  // Existing entries that are missing modelID/name or whose limits changed.
  const changedExisting = [];
  for (const id of ids) {
    if (!(id in existing)) continue;
    const cur = existing[id] && typeof existing[id] === "object" ? existing[id] : {};
    const limit = limits.get(id);
    const patch = {
      id,
      modelID: cur.modelID !== id,
      name: cur.name !== id,
      limit: limit !== undefined && !sameLimit(cur.limit, limit) ? limit : undefined,
    };
    if (patch.modelID || patch.name || patch.limit) changedExisting.push(patch);
  }

  if (!added.length && !removed.length && !baseChanged && !changedExisting.length) continue;
  changed = true;

  if (targets.length > 1) report.push(`${t.label}:`);
  if (baseChanged) {
    text = applyEdits(text, modify(text, t.basePath, BASE_URL_OVERRIDE, fmt));
    report.push(`baseURL: ${t.oldBaseURL ?? "(unset)"} -> ${BASE_URL_OVERRIDE}`);
  }
  for (const id of removed) text = applyEdits(text, modify(text, [...t.modelsPath, id], undefined, fmt));
  for (const id of added) {
    const entry = { modelID: id, name: id };
    const limit = limits.get(id);
    if (limit) entry.limit = limit;
    text = applyEdits(text, modify(text, [...t.modelsPath, id], entry, fmt));
  }
  for (const u of changedExisting) {
    if (u.modelID) text = applyEdits(text, modify(text, [...t.modelsPath, u.id, "modelID"], u.id, fmt));
    if (u.name)    text = applyEdits(text, modify(text, [...t.modelsPath, u.id, "name"], u.id, fmt));
    if (u.limit)   text = applyEdits(text, modify(text, [...t.modelsPath, u.id, "limit"], u.limit, fmt));
  }

  if (added.length)    report.push("Added:\n" + added.map(i => "  + " + i).join("\n"));
  if (removed.length)  report.push("Removed:\n" + removed.map(i => "  - " + i).join("\n"));
  if (changedExisting.length) report.push("Updated:\n" + changedExisting.map(u => "  ~ " + u.id).join("\n"));
}

if (!changed) {
  console.log(`Models already up to date (${ids.length} models).`);
  process.exit(0);
}

console.log(report.join("\n"));

// Back up, then write atomically.
fs.copyFileSync(CONFIG, CONFIG + ".bak");
const tmp = CONFIG + ".tmp-" + process.pid;
fs.writeFileSync(tmp, text);
fs.renameSync(tmp, CONFIG);
console.log(`Updated ${CONFIG} (backup at ${CONFIG}.bak)`);
'@

try {
    & node -e $applyEdits
    $exitCode = $LASTEXITCODE
} finally {
    Remove-Item -Recurse -Force $script:WORK -ErrorAction SilentlyContinue
}
exit $exitCode
