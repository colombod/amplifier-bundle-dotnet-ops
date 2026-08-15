---
name: dotnet-cli-command-reference
description: >-
  A static catalog of common `dotnet` CLI commands — project creation, solution
  management, build/run, test, NuGet, project references, publish, tool
  management, EF, templates, runtime identifiers, and troubleshooting. Load this
  for ready examples when you need a starting point. On .NET 10+ PREFER live
  self-discovery (dotnet --cli-schema; see the dotnet-cli-self-discovery skill) —
  this catalog is a fallback and may lag the installed SDK.
version: 1.0.0
license: MIT
---

# .NET CLI command reference (static fallback)

> **Discovery beats this catalog.** These are hand-maintained examples and can
> lag your installed SDK. On **.NET 10+** confirm the real surface with
> `dotnet --cli-schema` (load `dotnet-cli-self-discovery`); on .NET 8/9 confirm
> with `dotnet complete "dotnet <partial>"`. Use this catalog for a quick start
> or when discovery is unavailable — then verify flags against the live schema.

## Project creation
```
dotnet new list                                  # installed templates
dotnet new webapi   -n MyApi                      # ASP.NET Web API
dotnet new console  -n MyApp                      # Console app
dotnet new classlib -n MyLib                      # Class library
dotnet new blazorwasm -n MyBlazorApp              # Blazor WebAssembly
dotnet new worker   -n MyService                  # Background service
dotnet new xunit    -n MyTests                     # xUnit test project
dotnet new nunit    -n MyTests                     # NUnit test project
dotnet new mstest   -n MyTests                     # MSTest project
dotnet new razor    -n MyWebApp                    # Razor Pages
dotnet new mvc      -n MyMvcApp                     # MVC
dotnet new grpc     -n MyGrpcService               # gRPC
dotnet new webapi   -n MyApi --framework net9.0    # specific framework
dotnet new console  -n MyApp -o ./src/MyApp        # specific directory
```

## Solution management
```
dotnet new sln -n MySolution
dotnet sln add src/MyApp/MyApp.csproj
dotnet sln add **/*.csproj                        # add all recursively
dotnet sln remove src/OldProject/OldProject.csproj
dotnet sln list
```

## Build and run
```
dotnet build
dotnet build --configuration Release
dotnet build --no-restore
dotnet build --verbosity detailed
dotnet run
dotnet run --project src/MyApi/MyApi.csproj
dotnet run -- --urls "http://localhost:5000"      # args after -- go to the app
dotnet watch run
dotnet watch test
dotnet clean
```

## Testing
```
dotnet test
dotnet test --filter "FullyQualifiedName~MyTest"
dotnet test --filter "Category=Unit"
dotnet test --logger "console;verbosity=detailed"
dotnet test --no-build
dotnet test --collect:"XPlat Code Coverage"        # requires coverlet
dotnet test tests/MyTests/MyTests.csproj
```

## NuGet package management
```
dotnet add package Newtonsoft.Json
dotnet add package Microsoft.EntityFrameworkCore --version 8.0.0
dotnet remove package Newtonsoft.Json
dotnet list package
dotnet list package --outdated
dotnet list package --vulnerable
dotnet restore
dotnet nuget locals all --clear
```
> On .NET 9+ prefer the verb-noun form and JSON output discovered via the schema:
> `dotnet package list --format json --output-version 1` (the `--deprecated` /
> `--outdated` / `--vulnerable` filters are mutually exclusive → 3 calls).

## Project references
```
dotnet add src/MyApp/MyApp.csproj reference src/MyLib/MyLib.csproj
dotnet remove reference src/MyLib/MyLib.csproj
dotnet list reference
```

## Publishing
```
dotnet publish --configuration Release                                   # framework-dependent
dotnet publish -c Release -r win-x64   --self-contained
dotnet publish -c Release -r linux-x64 --self-contained
dotnet publish -c Release -r osx-arm64 --self-contained
dotnet publish -c Release -r linux-x64 --self-contained -p:PublishSingleFile=true
dotnet publish -c Release -r linux-x64 --self-contained -p:PublishTrimmed=true
```

## dotnet tool management
```
dotnet tool install -g dotnet-ef                  # global (per user, ~/.dotnet/tools)
dotnet tool update  -g dotnet-ef
dotnet tool list    -g
dotnet tool uninstall -g dotnet-ef
dotnet tool restore                                # local tools from .config/dotnet-tools.json
```
> Prefer LOCAL manifest-pinned tools for reproducibility (`dotnet new tool-manifest`
> → `dotnet tool install <pkg>` → commit `.config/dotnet-tools.json` → `dotnet tool restore`).

## Entity Framework (requires the dotnet-ef tool)
```
dotnet ef migrations add InitialCreate
dotnet ef migrations add AddUserTable --project src/MyApp
dotnet ef migrations list
dotnet ef database update
dotnet ef database update InitialCreate
dotnet ef database update PreviousMigration        # revert
dotnet ef migrations remove
dotnet ef migrations script
dotnet ef dbcontext scaffold "ConnectionString" Microsoft.EntityFrameworkCore.SqlServer
```

## Template management
```
dotnet new install   Microsoft.DotNet.Web.ProjectTemplates.8.0
dotnet new install   <pkg>@<version>               # @ syntax (:: deprecated in 9.0.200)
dotnet new list
dotnet new uninstall Microsoft.DotNet.Web.ProjectTemplates.8.0
dotnet new update --check-only
dotnet new search "template-name"
```

## Common runtime identifiers (RIDs)
| Platform | RID |
|----------|-----|
| Windows x64 | `win-x64` |
| Windows ARM64 | `win-arm64` |
| Linux x64 | `linux-x64` |
| Linux ARM64 | `linux-arm64` |
| Linux musl x64 (Alpine) | `linux-musl-x64` |
| macOS x64 (Intel) | `osx-x64` |
| macOS ARM64 (Apple Silicon) | `osx-arm64` |

## Troubleshooting
```
# dotnet not found
which dotnet && dotnet --version                       # bash
Get-Command dotnet -ErrorAction SilentlyContinue; dotnet --version   # pwsh

# installed SDKs / runtimes / full diagnostics
dotnet --list-sdks
dotnet --list-runtimes
dotnet --info

# build errors — clean rebuild (&& works in bash AND pwsh 7+)
dotnet clean && dotnet restore && dotnet build
# legacy Windows PowerShell 5.1 (no &&):
dotnet clean; if ($LASTEXITCODE -eq 0) { dotnet restore }; if ($LASTEXITCODE -eq 0) { dotnet build }
dotnet list package --include-transitive               # package conflicts

# NuGet source issues
dotnet nuget list source
dotnet nuget add source "https://api.nuget.org/v3/index.json" --name "nuget.org"
```
