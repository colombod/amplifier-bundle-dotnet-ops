---
name: dotnet-tools-and-templates
description: >-
  Manage .NET CLI tools and project templates correctly and reproducibly —
  local (manifest-pinned) tools over global, .NET 10 one-shot exec/dnx, and the
  modern `dotnet new` template subcommands with @version syntax. Load when
  installing/running a dotnet tool or installing/using a template. Tools and
  templates run FULL-TRUST arbitrary code — apply the trust guardrails below.
version: 1.0.0
license: MIT
---

# .NET tools & templates

> Both `dotnet tool` packages and `dotnet new` templates execute **full-trust
> arbitrary code**. Only install ones you trust, and never run tool commands from
> `~/Downloads` or a shared dir — the CLI walks the directory tree upward for a
> tool manifest and could pick up one you didn't intend.

## Tools — prefer LOCAL (manifest-pinned) over global

Local tools are version-pinned in a committed manifest → reproducible on every
machine and in CI, no PATH mutation, no user-global collisions.

```bash
dotnet new tool-manifest              # creates ./.config/dotnet-tools.json
dotnet tool install dotnet-ef         # records the exact version in the manifest
git add .config/dotnet-tools.json     # commit it
# any contributor / CI, one command:
dotnet tool restore
```

Manifest shape:
```json
{ "version": 1, "isRoot": true,
  "tools": { "dotnet-ef": { "version": "10.0.0", "commands": ["dotnet-ef"] } } }
```
Run a local tool: `dotnet tool run <cmd>` or the short `dotnet <cmd>`. Resolution
walks up from the cwd for `.config/dotnet-tools.json`; non-`isRoot` manifests
merge with ancestors.

### Install modes
| Mode | Command | Location | Scope |
|---|---|---|---|
| **Local** (preferred) | `dotnet tool install <pkg>` (no `-g`) | NuGet cache + manifest | per-directory-tree, version-pinned |
| Global | `dotnet tool install -g <pkg>` | `$HOME/.dotnet/tools` | per-user machine-wide (must be on PATH — see `dotnet-env-and-shell-setup`) |
| Tool-path | `dotnet tool install <pkg> --tool-path ~/bin` | wherever you say | not on PATH automatically |

### Lifecycle
```bash
dotnet tool list           # local (+ manifest path);  add --global or --tool-path <dir>
dotnet tool update  <pkg>  # = uninstall + reinstall latest stable; same scope flag as install
dotnet tool uninstall <pkg>
dotnet tool restore        # local only — restore everything in the manifest
dotnet tool search <term>  # NuGet.org
```
Version selection (.NET 8+): `--version M.N.P` = that EXACT version (incl.
unlisted); `--version M.N.*` = latest in that band. `--prerelease` for previews.

### .NET 10 additions
- **One-shot, no install:** `dotnet tool exec <pkg>` downloads + runs a tool
  (prompts before download). If a `.config/dotnet-tools.json` is nearby, the
  **manifest-pinned version is used** — one-shot still respects repo pinning.
- **`dnx <tool>`** — short alias forwarding to the CLI (`dnx dotnetsay "hi"`);
  populates only the global cache (no `~/.dotnet/tools` shim).
- `dotnet tool install` now **auto-creates a manifest** if none is found
  (nearest `.git`/`.sln` ancestor, else cwd). Opt out: `--create-manifest-if-needed=false`.

## Templates — `dotnet new`

Since the .NET 7 SDK these are **subcommands**, not `--flags`. Emit only the
modern forms for .NET 9/10:

```bash
dotnet new list                                  # installed templates
dotnet new search spa                            # search NuGet.org (quote "F#" — # is a shell comment)
dotnet new install Microsoft.DotNet.Web.Spa.ProjectTemplates
dotnet new install <pkg>@<version>               # @ syntax (:: was deprecated in the 9.0.200 SDK)
dotnet new install ./path/to/local/templates     # from a folder
dotnet new update --check-only                   # dry-run
dotnet new update
dotnet new uninstall                             # lists installed packages + how to remove each
dotnet new uninstall <pkg>                       # NOTE: no version number on uninstall
```

Behavioral facts to encode:
- Installed template packages **persist across newer SDKs** (a package installed
  under 10.0.100 is available in 10.0.101/10.0.200…) but **not** in SDKs older
  than the one that installed them.
- Re-running `install` with the same version is a no-op; without a version it
  updates to latest stable.
- **Built-in templates get no update check** — they ship with the SDK and update
  when you patch the SDK. `dotnet new update` only touches packages you installed.
- `--force` is required to generate into a dir where files would be overwritten;
  `--dry-run` previews. `--add-source` uses the NuGet config of the **current dir**.
- Per-template options are **dynamic** (synthesized from the template's
  `template.json`) — get them from `dotnet new <template> --help` (the live schema
  / `--cli-schema` does NOT enumerate them; see `dotnet-cli-self-discovery`).

## Discover, don't assume
On .NET 10+ confirm the exact tool/template subcommands and flags via
`dotnet <cmd> --cli-schema` (load `dotnet-cli-self-discovery`) rather than
trusting these examples, which can lag your installed SDK. Verify destructive
tool/template installs in a sandbox (`tests/dtu/`) when appropriate.
