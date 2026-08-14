---
name: dotnet-cli-self-discovery
description: >-
  Interrogate the INSTALLED .NET SDK to learn its exact CLI surface instead of
  relying on hardcoded command knowledge. Use whenever you need to know which
  commands/options/JSON-output flags a given `dotnet` supports — especially on
  .NET 10+, where `dotnet --cli-schema` returns the whole CLI grammar as JSON.
  Load this for smart, version-accurate tool access and to learn what's new in
  the installed build.
version: 1.0.0
license: MIT
---

# .NET CLI self-discovery

**Doctrine: discover, don't assume.** The `dotnet` CLI changes every release. Do
not trust a memorized command list — ask the installed SDK what it can do, then
use exactly that. This keeps you correct on .NET 8, 9, 10, and whatever ships
next.

Set these once per session before parsing any output (they make output stable
and quiet, and stop `--cli-schema` from emitting telemetry):

```bash
export SHELL="${SHELL:-/bin/bash}" DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_CLI_UI_LANGUAGE=en
```

> ⚠️ **`SHELL` must be EXPORTED or `dotnet --cli-schema` throws** `Could not
> determine the shell from the environment - the SHELL environment variable was
> not set` (exit 1, no output). This bites by default in agent/tool contexts:
> **bash sets `SHELL` as a shell variable, not an exported one**, so a spawned
> subprocess (a `tool-bash` call, CI, `incus/docker exec`) sees no `SHELL`.
> Always export `SHELL="${SHELL:-/bin/bash}"` first — this single line is why the
> primitive works or fails in practice. (Verified on SDK 10.0.400.)

## Step 1 — establish the version (works on every SDK)

```bash
dotnet --version        # e.g. 10.0.400  → single clean line, trivial to parse
```

Parse `major.minor` from this. It decides which discovery tier is available.

## Step 2 — the capability-probe ladder (most → least capable)

### Tier 1 — `dotnet --cli-schema` (.NET 10+): the whole grammar as JSON
The single best primitive. Hidden, **recursive** root option that emits every
command/option/argument — names, types, arity, defaults, aliases, `required`,
`hidden`, and the full subcommand tree — as JSON.

```bash
dotnet --cli-schema                 # entire CLI
dotnet workload --cli-schema        # any subtree
dotnet package list --cli-schema    # scoped to one command
```

Facts you can rely on (they are guaranteed by the serializer):
- Output is `\n`-normalized on all platforms, indented, **null keys omitted**
  (absent key ⇒ null, not empty), options/subcommands **sorted case-insensitively
  by name**; arguments carry an explicit `order` field.
- Root object has a `version` field = the SDK version → the schema is
  self-identifying and safe to cache keyed on `dotnet --version`.
- `arity.maximum` is **omitted when unbounded** (don't expect a sentinel).

Detect Tier 1 by **probing**, never by reading `--help` (the option is
`Hidden=true`, so it never shows in help):

```bash
# SHELL export is REQUIRED (see gotcha above) — inline it so the probe is self-contained.
if SHELL="${SHELL:-/bin/bash}" dotnet --cli-schema >/tmp/cli.json 2>/dev/null \
     && head -c1 /tmp/cli.json | grep -q '{'; then
  echo "Tier 1: cli-schema available"
fi
```

Then read the schema to answer questions precisely, e.g. with `jq`:

```bash
# Top-level commands the installed SDK actually has:
jq -r '.subcommands | keys[]' /tmp/cli.json
# Does `dotnet package list` support --format, and what values?
dotnet package list --cli-schema | jq '.options["--format"]'
# Which commands expose a --format option (i.e. have machine-readable output)?
dotnet --cli-schema | jq -r '.. | objects | select(.options?["--format"]) | .name?' | sort -u
```

### Tier 2 — `dotnet complete` (.NET 8 / 9 fallback)
Flat, newline-delimited name enumeration — includes hidden symbols, but no
types/arity/descriptions. Present on 8, 9, and 10.

```bash
dotnet complete "dotnet "               # top-level commands + root options
dotnet complete "dotnet workload "      # subcommands of workload
dotnet complete "dotnet build --"       # options of build
```

Use this to confirm a command/option exists before emitting it on .NET 8/9.

### Tier 3 — parse `--help` (last resort)
Parseable but lossy: hidden options are omitted and section headers are
localized (pin `DOTNET_CLI_UI_LANGUAGE=en`). Prefer Tiers 1–2.

```bash
dotnet <command> --help
```

> **Never run `dotnet help <command>`** (no subcommand form): it shells out to a
> browser (`xdg-open`/`open`/`start`) and yields no useful stdout.

## Step 3 — prefer structured (JSON) output when acting

Discover which of these the installed SDK supports (via Tier 1/2), then prefer
them over scraping text. Verified availability:

| Command | Flag | Since | Notes |
|---|---|---|---|
| `dotnet package list` | `--format json --output-version 1` | .NET 8 | **Pin `--output-version 1`.** `--deprecated`/`--outdated`/`--vulnerable` are mutually exclusive → issue 3 calls. (On .NET 8 the verb form is `dotnet list package`.) |
| `dotnet tool list` | `--format json` | .NET 9 | default is `table` |
| `dotnet workload list` | `--machine-readable` | .NET 6 | hidden; single JSON line `{installed, updateAvailable}` |
| `dotnet workload search version` | `--format json [--take N]` | .NET 9 | array of `{workloadVersion}` |
| `dotnet run-api` | *(always JSON, stdin/stdout lines)* | .NET 10 | IDE-grade channel for file-based programs; errors returned **as JSON** |

**No JSON — must parse text** (pin UI language, key on the hardcoded English
inner labels like `Version:` / `RID:` / `Base Path:`): `dotnet --info`,
`--version`, `--list-sdks`, `--list-runtimes`, `dotnet new list`/`search`,
`dotnet solution list`, `dotnet sdk check`.

## Step 4 — learn what's NEW for the installed build

Authoritative, machine-readable, versioned — all in `dotnet/core`, keyed off
`dotnet --version`:

```bash
V=$(dotnet --version); CH=${V%.*.*}   # e.g. 10.0
curl -fsSL https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json \
  | jq --arg ch "$CH" '."releases-index"[] | select(."channel-version"==$ch)'
```

From that channel entry follow:
- `releases.json` — every patch, its SDK/runtime versions, CVE list, hashes.
- `release-notes/<major>/known-issues.md` — breakages affecting this build.
- `release-notes/<major>/api-diff/` — machine-comparable API deltas ("what changed").

The index validates against `https://json.schemastore.org/dotnet-releases-index.json`.
Use `dotnet/sdk` GitHub releases only to answer "newest SDK build", not for feature notes.

## Caching & guardrails
- **Cache the schema** keyed on `dotnet --version`; it is a pure function of the
  installed SDK. Invalidate on version change or `global.json` change.
- Always export `DOTNET_CLI_UI_LANGUAGE=en`, `DOTNET_CLI_TELEMETRY_OPTOUT=1`,
  `DOTNET_NOLOGO=1` before parsing.
- Prefer the **discovered** verb form: `dotnet list package` (.NET 8) migrated to
  `dotnet package list` (.NET 9+); let the schema/`complete` tell you which exists
  rather than assuming.
- `dotnet <template> --cli-schema` is best-effort only — template parameters are
  synthesized dynamically from `template.json`; use `dotnet new <template> --help`
  for those.

## One-shot bootstrap the agent can run
```bash
export SHELL="${SHELL:-/bin/bash}" DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_CLI_UI_LANGUAGE=en
V=$(dotnet --version 2>/dev/null) || { echo "dotnet not found"; exit 1; }
echo "SDK $V"
if dotnet --cli-schema >/tmp/dotnet-cli-schema.json 2>/dev/null \
     && head -c1 /tmp/dotnet-cli-schema.json | grep -q '{'; then
  echo "discovery=cli-schema (.NET 10+)"
  jq -r '.subcommands | keys | join(" ")' /tmp/dotnet-cli-schema.json
else
  echo "discovery=complete (.NET 8/9)"
  dotnet complete "dotnet "
fi
```
