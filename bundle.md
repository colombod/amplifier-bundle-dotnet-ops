---
bundle:
  name: dotnet-ops
  version: 1.3.0
  description: >-
    .NET CLI operations bundle. Provides a cross-platform specialist agent
    for .NET development — project creation, build, test, publish, NuGet
    package management, and solution management.

agents:
  include:
    - dotnet-ops:agents/dotnet-ops

includes:
  - bundle: dotnet-ops:behaviors/dotnet-ops
---

# .NET Operations Bundle

Provides `dotnet-ops` — a cross-platform specialist agent for .NET CLI operations.

## Usage

Delegate .NET operations:
```
delegate(agent="dotnet-ops:dotnet-ops", instruction="Create a new web API project")
delegate(agent="dotnet-ops:dotnet-ops", instruction="Add Newtonsoft.Json package")
delegate(agent="dotnet-ops:dotnet-ops", instruction="Run tests with coverage")
```

