# amplifier-bundle-dotnet-ops

Cross-platform .NET CLI specialist agent for [Amplifier](https://github.com/microsoft/amplifier). Build, test, publish, manage NuGet packages, and run Entity Framework migrations through a dedicated agent that handles platform differences automatically.

## Installation

### As an app bundle (recommended)

```bash
amplifier bundle add git+https://github.com/colombod/amplifier-bundle-dotnet-ops@main --app
```

### As a composable behavior (add to existing bundle)

```bash
amplifier bundle add git+https://github.com/colombod/amplifier-bundle-dotnet-ops@main#subdirectory=behaviors/dotnet-ops.yaml --app
```

### In a custom bundle

```yaml
includes:
  - bundle: git+https://github.com/microsoft/amplifier-foundation@main
  - bundle: git+https://github.com/colombod/amplifier-bundle-dotnet-ops@main#subdirectory=behaviors/dotnet-ops.yaml
```

## Prerequisites

- **.NET SDK** (6.0, 7.0, 8.0, or 9.0) — [Install .NET](https://dotnet.microsoft.com/download)
- **Amplifier** — `uv tool install git+https://github.com/microsoft/amplifier`

Platform-specific shell requirements:
| Platform | Required |
|----------|----------|
| Windows | PowerShell 7+ (`winget install Microsoft.PowerShell`) |
| Linux/macOS | bash (pre-installed) |

## What It Does

The `dotnet-ops` agent handles all .NET CLI operations via delegation. It automatically detects your platform and uses the right shell — `pwsh` on Windows, `bash` on Linux/macOS.

### Capabilities

| Operation | Example prompt |
|-----------|---------------|
| Create projects | "Create a new ASP.NET Web API called OrderService" |
| Build | "Build the project in Release mode" |
| Run | "Run the app on port 5000" |
| Test | "Run tests with detailed output" |
| Publish | "Publish for Linux x64 as self-contained" |
| NuGet packages | "Add Entity Framework Core" |
| Check outdated | "Show outdated NuGet packages" |
| Solution management | "Create a solution and add all projects" |
| Project references | "Add a reference from MyApp to MyLib" |
| EF migrations | "Add a migration called AddUserTable" |
| Tool management | "Install dotnet-ef globally" |
| Templates | "List available project templates" |

### How It Works

```
User: "Create a new web API and add Swagger"
  |
  v
Orchestrator sees .NET trigger --> delegates to dotnet-ops agent
  |
  v
dotnet-ops agent (fast model, cross-platform):
  1. Detects platform (uname -s or $PSVersionTable.OS)
  2. Picks shell (bash on Linux/macOS, pwsh on Windows)
  3. Creates project: dotnet new webapi -n MyApi
  4. Adds package: dotnet add MyApi package Swashbuckle.AspNetCore
  5. Returns structured result with project path, framework, and packages
```

## Cross-Platform Awareness

The agent understands platform differences and adjusts automatically:

| Aspect | Windows | Linux/macOS |
|--------|---------|-------------|
| Shell used | `pwsh` | `bash` |
| Env vars | `$env:VARIABLE` | `$VARIABLE` |
| Default SDK path | `C:\Program Files\dotnet\` | `/usr/share/dotnet/` |
| NuGet cache | `%USERPROFILE%\.nuget\packages` | `~/.nuget/packages` |
| Runtime IDs | `win-x64`, `win-arm64` | `linux-x64`, `osx-arm64` |

## Safety

The agent enforces safety protocols:

- Checks `dotnet --version` before running operations
- Will NOT run `dotnet ef database update` on production without confirmation
- Will NOT push NuGet packages to nuget.org without explicit confirmation
- Will NOT modify `.csproj` files directly — uses `dotnet` CLI commands
- Will NOT change target frameworks of existing projects without asking
- Reports full build error output (no summarizing)

## Bundle Structure

```
amplifier-bundle-dotnet-ops/
├── bundle.md                        # Root bundle
├── agents/
│   └── dotnet-ops.md                # Cross-platform specialist agent (model_role: fast)
├── behaviors/
│   └── dotnet-ops.yaml              # Composable behavior
└── context/
    └── delegation-instructions.md   # Routing rules for orchestrators
```

## Common Runtime Identifiers

For `dotnet publish -r <rid>`:

| Platform | RID |
|----------|-----|
| Windows x64 | `win-x64` |
| Windows ARM64 | `win-arm64` |
| Linux x64 | `linux-x64` |
| Linux ARM64 | `linux-arm64` |
| Linux Alpine x64 | `linux-musl-x64` |
| macOS Intel | `osx-x64` |
| macOS Apple Silicon | `osx-arm64` |

## Related Bundles

| Bundle | Purpose | Install |
|--------|---------|---------|
| [tool-pwsh](https://github.com/colombod/amplifier-module-tool-pwsh) | PowerShell tool module (used on Windows) | Included automatically |
| [winget-ops](https://github.com/colombod/amplifier-bundle-winget-ops) | Windows Package Manager agent | `amplifier bundle add git+https://github.com/colombod/amplifier-bundle-winget-ops@main --app` |

## License

MIT
