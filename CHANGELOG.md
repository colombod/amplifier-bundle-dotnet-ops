# Changelog

All notable changes to `amplifier-bundle-dotnet-ops` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-08-14

Ergonomics and cross-platform correctness pass (macOS / Windows / Linux).

### Fixed
- **Behavior install was broken.** `behaviors/dotnet-ops.yaml` now includes the
  `dotnet-ops` agent (`agents.include`); previously it advertised the agent but
  never installed it, so composing the behavior left the delegation instructions
  pointing at an absent agent.
- **No Windows shell on the behavior path.** `behaviors/dotnet-ops.yaml` now
  declares `tool-pwsh` (it was missing), so the behavior actually delivers the
  cross-platform shell support it describes.
- **Fragile platform detection.** Replaced the "run bash, assume Windows if it
  fails" heuristic with a positive-signal probe (`pwsh` RuntimeInformation, with
  a `uname -s` fallback that maps `MINGW*`/`MSYS*`/`CYGWIN*` to Windows), plus an
  explicit Git Bash / WSL note. A successful bash run no longer implies Linux.
- **Incorrect command-chaining guidance.** `&&`/`||` are documented as valid in
  PowerShell 7+ (the required pwsh), with a legacy Windows PowerShell 5.1
  (`$LASTEXITCODE`-guard) alternative for the clean/restore/build chain.

### Changed
- **`tool-pwsh` re-homed and pinned.** Moved off the personal fork
  (`colombod/...@main`) to the canonical upstream
  `anokye-labs/amplifier-module-tool-pwsh`, pinned to an immutable commit.
- **All tool sources pinned.** `tool-bash` and `tool-filesystem` pinned to
  immutable commit SHAs; no tool source floats on `@main` anymore.
- **Agent `model_role`** changed from `fast` to a `[coding, general]` fallback
  chain to match the diagnostic, multi-step workload.

### Added
- Worked cross-platform example (bash POSIX path vs pwsh native `$env:USERPROFILE`
  path + `dotnet.exe`) in the agent's CLI reference.
- Two failure-path agent examples (SDK-not-installed; ambiguous multi-project
  target).
- `.github/workflows/validate.yml`: 3-OS structural-lint matrix + a full
  foundation `validate-bundle-repo` run on push / PR.

## [1.0.0]

- Initial release: cross-platform `dotnet-ops` specialist agent (project
  lifecycle, build/test/publish, NuGet, solutions, references, EF, tools,
  templates), root bundle, and composable behavior.
