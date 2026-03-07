# .NET CLI Delegation

## When to Delegate to dotnet-ops

**ALWAYS delegate .NET CLI operations to `dotnet-ops:dotnet-ops`.**

| Trigger | Example |
|---------|---------|
| Project creation | "Create a new web API", "dotnet new..." |
| Building | "Build the project", "dotnet build" |
| Running | "Run the app", "dotnet run" |
| Testing | "Run tests", "dotnet test with coverage" |
| Publishing | "Publish for production", "Create a release build" |
| NuGet packages | "Add package X", "Update packages", "Remove package" |
| Project references | "Add reference to...", "Link projects" |
| Solution management | "Create a solution", "Add project to solution" |
| Tool management | "Install dotnet tool...", "Update EF tools" |
| EF migrations | "Add migration", "Update database" |
| Template management | "Install template", "List templates" |

**Do NOT attempt dotnet CLI commands directly.** The dotnet-ops agent has cross-platform awareness, safety protocols, and structured output formatting.
