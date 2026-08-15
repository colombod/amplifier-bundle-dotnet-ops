# DTU test harness for `dotnet-ops`

Reproducible, **isolated** validation of the `dotnet-ops` agent using
[Digital Twin Universe](https://github.com/microsoft/amplifier-bundle-digital-twin-universe)
(DTU) environments. Exercising this agent is destructive — it installs/upgrades
SDKs, edits shell profiles, and sets env vars — so it must run in a sandbox,
never on your host.

These are the exact environments + procedure that caught two real defects:
- **D-12** — the agent body never reached the model (a broken `agents.include`
  form), so every earlier "behavior" test was silently measuring nothing.
- **D-11** — self-discovery (`dotnet --cli-schema`) not firing first on generic
  prompts.

## What's here

| File | Purpose |
|------|---------|
| `profiles/dotnet-ops-net10.yaml` | Linux box with the **.NET 10 SDK** — the self-discovery (`dotnet --cli-schema`) path |
| `profiles/dotnet-ops-nosdk.yaml` | Clean box with **no .NET SDK** — the missing-SDK detection path |
| `dotnet-invocation-shim.sh` | Installs a `dotnet` invocation logger in the box (Stage 2 instrument) |

## Prerequisites
- `amplifier-digital-twin` CLI installed and working (Incus-based).
- **Adapt the `config.providers` block** in each profile to your own Amplifier
  provider setup — the committed blocks mirror one host's modules/models/env-var
  names and are a *reference*, not a portable default. Export the matching
  provider keys in your shell before launching.

## Launch

```bash
amplifier-digital-twin launch tests/dtu/profiles/dotnet-ops-net10.yaml --name dotnet-ops-net10
amplifier-digital-twin launch tests/dtu/profiles/dotnet-ops-nosdk.yaml  --name dotnet-ops-nosdk
```

Both profiles fail the launch loudly if their SDK state is wrong (net10 asserts
`10.x`; nosdk asserts `dotnet` is absent), and the net10 readiness gate asserts
`dotnet --cli-schema` returns valid JSON.

## The canary rule (do NOT skip)

A delegated agent that loads **no system prompt** still runs and answers — it
just behaves like a bare model. That is exactly the D-12 failure mode, and it
makes every behavior result meaningless. So **gate every behavior test on a
canary** proving the agent body actually reached the model.

### Stage 1 — canary: the agent body loads

Delegate to the agent, then inspect the delegated sub-session's `llm:request`
(in the box's `events.jsonl`) and assert **both**:
- `has_system == true`, and
- the system prompt contains a body-unique string, e.g.
  `## Operating Procedure — do this in order, every task`.

Use the **name** form of the address — `dotnet-ops:dotnet-ops` (the path form
`dotnet-ops:agents/dotnet-ops` is the D-12 bug and no longer resolves). A quick
behavioral canary that needs no log parsing:

```bash
amplifier-digital-twin exec dotnet-ops-net10 -- \
  amplifier tool invoke delegate agent=dotnet-ops:dotnet-ops \
  instruction="Does your system prompt contain a section titled 'Operating Procedure'? Reply exactly YES or NO_SUCH_SECTION."
# PASS = YES (body loaded).  NO_SUCH_SECTION = D-12 regression: STOP, do not trust Stage 2.
```

> Control: delegating to a base agent (e.g. `anchors:explorer`) should always show
> `has_system=true`. If the base agent loads but `dotnet-ops` doesn't, the defect
> is in this bundle (that's how D-12 was localized).

### Stage 2 — behavior: self-discovery fires first (.NET 10)

Only if Stage 1 passes. Install the invocation shim, then run the **verbatim
generic prompt** (no hints about `--cli-schema`/`--help`/the full surface):

```bash
amplifier-digital-twin exec dotnet-ops-net10 -- bash -s < tests/dtu/dotnet-invocation-shim.sh

# repeat 3x for consistency:
amplifier-digital-twin exec dotnet-ops-net10 -- bash -lc ': > /tmp/dotnet-invocations.log'
amplifier-digital-twin exec dotnet-ops-net10 -- \
  amplifier run 'delegate to dotnet-ops:dotnet-ops: list the subcommands this SDK supports'
amplifier-digital-twin exec dotnet-ops-net10 -- cat /tmp/dotnet-invocations.log
```

**PASS:** `dotnet --cli-schema` appears in the log (self-discovery fired first)
and the reported surface matches the full schema (~32 top-level subcommands on
SDK 10.0.x), not the leaner ~26 that `--help` yields.

### no-SDK box — missing-SDK detection

```bash
amplifier-digital-twin exec dotnet-ops-nosdk -- \
  amplifier run 'delegate to dotnet-ops:dotnet-ops: build the solution'
```

**PASS:** the agent reports that the .NET SDK isn't installed, with per-platform
install guidance — no confusing build error.

## Re-test after a bundle change

The profiles pin the bundle at `@main`. After merging a change:

```bash
amplifier-digital-twin update dotnet-ops-net10   # re-pulls @main, re-runs readiness
# then repeat Stage 1 (canary) and Stage 2 (behavior)
```

To test an unmerged branch, point the profile's
`amplifier bundle add git+…@main` at your branch ref and relaunch.

## Teardown

```bash
amplifier-digital-twin destroy dotnet-ops-net10
amplifier-digital-twin destroy dotnet-ops-nosdk
```
