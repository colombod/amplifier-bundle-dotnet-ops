---
name: dotnet-env-and-shell-setup
description: >-
  Wire the .NET developer environment on Linux/macOS — DOTNET_ROOT, PATH for
  global tools, and the useful DOTNET_* variables — into the correct shell
  profile (bash/zsh/fish), idempotently. Load when a global tool is "installed
  but not found", when DOTNET_ROOT is unset, or when setting sensible CLI
  defaults. Edits shell profiles — verify in a sandbox (tests/dtu/) first.
version: 1.0.0
license: MIT
---

# .NET environment & shell profiles (Linux / macOS focus)

## Read-only health probe FIRST
Never edit a profile before you know what's actually wrong:

```bash
command -v dotnet || echo "dotnet NOT on PATH"
echo "DOTNET_ROOT=${DOTNET_ROOT:-<unset>}"
case ":$PATH:" in *":$HOME/.dotnet/tools:"*) echo "tools ON PATH";; *) echo "tools NOT on PATH";; esac
ls "$HOME/.dotnet/tools" 2>/dev/null            # tools that exist but may be unreachable
dotnet --info 2>/dev/null | sed -n '1,12p'      # SDK + Base Path (its install dir)
```

Detect the user's actual shell (edit the RIGHT file, not the default):
```bash
basename "${SHELL:-/bin/bash}"    # bash | zsh | fish ...
```

## The variables that matter

| Variable | Set to | Why |
|---|---|---|
| `DOTNET_ROOT` | the SDK install dir (e.g. `$HOME/.dotnet`, `/usr/share/dotnet`, or Homebrew-formula `libexec`) | the host uses it to find the runtime; **`dotnet-install.sh` does not set it** |
| `PATH` += `$DOTNET_ROOT` | so `dotnet` itself is found (script installs) | |
| `PATH` += `$HOME/.dotnet/tools` | **the classic "tool installed but not found"** — global tools live here and are NOT on PATH by default | |
| `DOTNET_CLI_TELEMETRY_OPTOUT=1` | opt out of telemetry | quieter, and required for clean `--cli-schema` |
| `DOTNET_NOLOGO=1` | suppress the first-run banner | stops banner noise in parsed output |
| `DOTNET_CLI_UI_LANGUAGE=en` | force English | stable labels when you must parse text output |
| `SHELL="${SHELL:-/bin/bash}"` (exported) | ensure SHELL is EXPORTED | `dotnet --cli-schema` aborts without an exported SHELL (see the `dotnet-cli-self-discovery` skill) |
| `NUGET_PACKAGES` | a custom global package cache dir (optional) | share/relocate the cache |
| `DOTNET_ROLL_FORWARD` | `LatestMinor` etc. (optional) | runtime roll-forward policy |

> On the Homebrew **formula** (macOS), `DOTNET_ROOT` must be
> `$HOMEBREW_PREFIX/opt/dotnet/libexec`; the `.pkg`/cask use
> `/usr/local/share/dotnet`. Match `DOTNET_ROOT` to where `dotnet --info` reports
> its Base Path.

## Idempotent profile wiring — never clobber

Append a single guarded block; re-running must not duplicate it. Pick `DR`
(the install dir) from `dotnet --info` Base Path or the known install location.

### bash — `~/.bashrc` (interactive) and/or `~/.profile` (login)
```bash
DR="${DOTNET_ROOT:-$HOME/.dotnet}"
BLOCK_BEGIN="# >>> dotnet env (managed) >>>"
if ! grep -qF "$BLOCK_BEGIN" ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc <<EOF
$BLOCK_BEGIN
export DOTNET_ROOT="$DR"
case ":\$PATH:" in *":\$DOTNET_ROOT:"*) ;; *) export PATH="\$DOTNET_ROOT:\$PATH";; esac
case ":\$PATH:" in *":\$HOME/.dotnet/tools:"*) ;; *) export PATH="\$HOME/.dotnet/tools:\$PATH";; esac
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_CLI_UI_LANGUAGE=en
export SHELL="\${SHELL:-/bin/bash}"
# <<< dotnet env (managed) <<<
EOF
fi
```
(For login-only shells that don't read `.bashrc`, apply the same guarded block to
`~/.profile`.)

### zsh — `~/.zshrc`
Same block as bash, appended to `~/.zshrc` (guard on the same `BLOCK_BEGIN`).

### fish — `~/.config/fish/config.fish`
fish syntax differs; use `fish_add_path` (idempotent by design):
```fish
if not set -q __dotnet_env_managed
  set -gx __dotnet_env_managed 1
  set -gx DOTNET_ROOT "$HOME/.dotnet"          # or the real install dir
  fish_add_path $DOTNET_ROOT $HOME/.dotnet/tools
  set -gx DOTNET_CLI_TELEMETRY_OPTOUT 1
  set -gx DOTNET_NOLOGO 1
  set -gx DOTNET_CLI_UI_LANGUAGE en
  set -gx SHELL (status fish-path); or set -gx SHELL /usr/bin/fish
end
```

## After editing
The changes apply to NEW shells. To verify without a fresh login, source the
file (bash/zsh: `source ~/.bashrc`) or re-run the read-only probe in a new shell,
then confirm:
```bash
echo "$DOTNET_ROOT"; command -v dotnet; command -v <your-global-tool>
```

## "Installed but not found" — the canonical fix
Symptom: `dotnet tool install -g X` succeeds, but running `X` says command not
found. Cause: `$HOME/.dotnet/tools` isn't on PATH. Fix: add it via the guarded
block above for the user's actual shell (do NOT just export it in the current
process — that won't persist).

## Machine scope note
Machine-wide `/etc/profile.d/*.sh` (as the `tests/dtu/` net10 profile uses) wires
these for every login shell in a controlled box; for a user's own machine prefer
their per-user profile so you don't need root and don't affect other users.
Always verify profile edits in a sandbox (`tests/dtu/`) before doing them on a
real machine.
