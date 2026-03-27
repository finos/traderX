# People-Service (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

```bash
cd PeopleService.WebApi
dotnet run
```

## Runtime Contract

- Default port: `18089` via `PEOPLE_SERVICE_PORT`
- CORS origins: `CORS_ALLOWED_ORIGINS` (default `*`)
- Data source: `PeopleJsonFilePath` in `appsettings.json`
