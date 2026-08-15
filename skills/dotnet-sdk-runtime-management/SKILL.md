---
name: dotnet-sdk-runtime-management
description: >-
  Install, upgrade, pin, and run side-by-side .NET SDKs/runtimes correctly on
  Linux, macOS, and Windows. Load when you need to set up or change which .NET
  is installed, pin a repo to an SDK with global.json, or diagnose a broken
  install (missing libhostfxr, Linux package-feed mix-ups, tools not on PATH).
  Destructive — exercise in a sandbox (see tests/dtu/), never blindly on a host.
version: 1.0.0
license: MIT
---

# .NET SDK / runtime management (cross-platform)

**Detect before you change.** Establish the current state first (and use the
`dotnet-cli-self-discovery` skill for version-accurate CLI facts):

```bash
command -v dotnet && dotnet --info        # SDK + runtimes + RID + base path
dotnet --list-sdks                        # "<version> [<path>]" per line
dotnet --list-runtimes
```
> On Linux, **more than one distinct bracketed root** across `--list-sdks`
> (e.g. both `/usr/lib/dotnet` and `/usr/share/dotnet`) is the signature of a
> package-feed mix-up — see Troubleshooting.

Pick the install method by intent:

| Situation | Use |
|---|---|
| CI / container / ephemeral, or an exact patch/band not in a feed | `dotnet-install.sh` (§ script) |
| N SDKs side-by-side under `$HOME`, no root | `dotnet-install.sh --install-dir` |
| Long-lived dev machine, one current SDK + security updates | Package manager / official installer |
| macOS dev machine | `.pkg` installer or Homebrew **cask** (§ macOS) |

## `dotnet-install.sh` (canonical: `https://dot.net/v1/dotnet-install.sh`)

Microsoft positions this as a **CI/automation** tool. It does **NOT** set
`DOTNET_ROOT` and does **NOT** persist `PATH` — you must wire those yourself
(see the `dotnet-env-and-shell-setup` skill).

```bash
curl -fsSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh && chmod +x dotnet-install.sh
./dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
```

Key options:

| Option | Meaning |
|---|---|
| `--channel` | `LTS` (default) \| `STS` \| `A.B` (e.g. `10.0`) \| feature band `A.B.Cxx` |
| `--version` | `latest` or an exact 3-part build (e.g. `9.0.306`); overrides `--channel` |
| `--quality` | `daily`\|`preview`\|`GA` — only with `--channel`, ignored for LTS/STS |
| `--runtime` | `dotnet`\|`aspnetcore`\|`windowsdesktop` (omit → full SDK) |
| `--install-dir` | default `$HOME/.dotnet`; use it for side-by-side under $HOME |
| `--jsonfile <global.json>` | read the SDK version from a repo's `global.json` (CI-friendly pinning) |
| `--dry-run` | print the resolved command + URL instead of installing (plan first) |
| `--skip-non-versioned-files` | **required** when layering an OLDER SDK into a dir that already has a newer one |

**Side-by-side (order matters — newest first):**
```bash
./dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
./dotnet-install.sh --channel 9.0  --install-dir "$HOME/.dotnet" --skip-non-versioned-files
"$HOME/.dotnet/dotnet" --list-sdks
```
Omitting `--skip-non-versioned-files` on the older install overwrites the newer
`dotnet` host — a classic self-inflicted break. There is **no uninstall script**
(remove manually). Optional GPG verify: fetch `dotnet-install.asc`/`.sig` and
`gpg --verify` before running in automation.

## Package managers

### Linux — the 2025/2026 change
Since .NET 9, Microsoft only ships packages for distros that don't ship their
own. On **Ubuntu 24.04+** use the distro feed, plus `ppa:dotnet/backports` for
versions the built-in feed lacks. The **Microsoft feed is x64-only** (use the
distro feed or manual install on Arm64).
```bash
sudo apt-get update && sudo apt-get install -y dotnet-sdk-10.0
# version not in the built-in feed (e.g. .NET 9 on 24.04):
sudo add-apt-repository ppa:dotnet/backports && sudo apt-get update
sudo apt-get install -y dotnet-sdk-9.0
sudo apt-get install -y aspnetcore-runtime-10.0   # runtime only (incl. .NET runtime)
```
Package names: `{dotnet|aspnetcore}-{sdk|runtime}-<ver>` (`sdk` valid only for
`dotnet`). **Snap-installed .NET breaks global tools** — avoid it for this agent.

### macOS
`.pkg` installer or `brew install --cask dotnet-sdk` match Microsoft's layout
(`/usr/local/share/dotnet`). The Homebrew **formula** (`brew install dotnet`) is
source-built and installs under `$HOMEBREW_PREFIX/opt/dotnet/libexec` — with it
you **must** `export DOTNET_ROOT="$HOMEBREW_PREFIX/opt/dotnet/libexec"`.
Installing both formula and cask is the macOS feed mix-up (they conflict). On
Apple Silicon the x64 SDK installs under `/usr/local/share/dotnet/x64/`; PATH
order + `DOTNET_ROOT` decide which wins.

### Windows
```powershell
winget install Microsoft.DotNet.SDK.10
winget install Microsoft.DotNet.AspNetCore.10
```
IDs: `Microsoft.DotNet.{SDK|Runtime|AspNetCore|DesktopRuntime}.{major}` (use
`Preview` for previews). Silent: `/install /quiet /norestart` (exit 3010 = reboot).

## Per-repo pinning with `global.json`
Selects the **SDK/CLI** version independent of the runtime a project targets.
```jsonc
{
  "sdk": {
    "version": "10.0.100",          // full 3-part; "10", "10.0", wildcards are INVALID
    "rollForward": "latestFeature", // default is "patch" when version is set
    "allowPrerelease": false        // default true OUTSIDE Visual Studio — set false to avoid previews
  }
}
```
`rollForward`: `patch`·`feature`·`minor`·`major`·`latestPatch`·`latestFeature`·`latestMinor`·`latestMajor`·`disable`. No `global.json`/no `version` → highest installed SDK. With package **lock files**, use `"rollForward": "disable"`.

**New in .NET 10:**
```jsonc
{ "sdk": { "version": "10.0.100",
           "paths": [".dotnet", "$host$"],     // extra SDK search locations (first match wins); SDK commands only
           "errorMessage": "Run ./install.sh to get the required .NET SDK." },
  "test": { "runner": "Microsoft.Testing.Platform" } }
```
Scaffold: `dotnet new globaljson --sdk-version 10.0.100 --roll-forward latestFeature`.
Gotcha: the CLI muxer resolves `global.json` from the **cwd** upward, while the
MSBuild project resolver starts from the **solution** dir — running `dotnet` from
a subdirectory can pick a different SDK than you expect.

## Troubleshooting
**Feed mix-up (Linux)** — symptoms: `libhostfxr.so could not be found`,
`.../FrameworkList.xml` missing, or `/usr/lib*/dotnet` **and** `/usr/share/dotnet`
both present. Fix: pick ONE repo. Debian/Ubuntu, keep MS repo for other packages:
```bash
sudo apt remove 'dotnet*' 'aspnet*' 'netstandard*'
# /etc/apt/preferences:  Package: dotnet* aspnet* netstandard*
#                        Pin: origin "packages.microsoft.com"
#                        Pin-Priority: -10
```
RPM: `sudo dnf remove 'dotnet*' 'aspnet*'` then `excludepkgs=dotnet*,aspnet*` in `microsoft-prod.repo` (or `dnf remove packages-microsoft-prod`).

**Host trace for a fatal runtime error:**
```bash
DOTNET_HOST_TRACE=1 DOTNET_HOST_TRACEFILE=host_trace.txt dotnet --info
```

**Manual-install deps (Ubuntu 24.04):** `ca-certificates libc6 libgcc-s1
libgssapi-krb5-2 libicu74 libssl3t64 libstdc++6 tzdata zlib1g` (the `libicu`
soname tracks the release: `libicu70` 22.04, `libicu74` 24.04, `libicu76` 25.x).

## Verify before use in a sandbox
The `tests/dtu/` net10 profile is a worked example of a correct install:
`dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet` + wired
`DOTNET_ROOT`/PATH + the `SHELL` export. Use it (or the nosdk profile) to test
install/upgrade/pin changes in isolation rather than on a real machine.
