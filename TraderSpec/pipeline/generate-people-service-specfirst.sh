#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/codebase/generated-components/people-service-specfirst"

rm -rf "${TARGET}"
mkdir -p \
  "${TARGET}/PeopleService.WebApi/Controllers" \
  "${TARGET}/PeopleService.WebApi/Directory" \
  "${TARGET}/PeopleService.WebApi/MockDirectory" \
  "${TARGET}/PeopleService.WebApi/Properties"

cat <<'EOF' > "${TARGET}/README.md"
# People-Service (Spec-First Generated)

This component is generated from TraderSpec requirements for the baseline, pre-containerized state.

## Run

```bash
cd PeopleService.WebApi
dotnet run
```

## Runtime Contract

- Default port: `18089` (override with `PEOPLE_SERVICE_PORT`)
- CORS origins: `CORS_ALLOWED_ORIGINS` (default `*`)
- Data source: `PeopleJsonFilePath` in `appsettings.json`
EOF

cat <<'EOF' > "${TARGET}/openapi.yaml"
openapi: 3.0.1
info:
  title: TraderSpec PeopleService.WebApi
  version: v1
paths:
  /People/GetPerson:
    get:
      summary: Get a person from directory by logon or employee ID
      parameters:
        - name: LogonId
          in: query
          schema:
            type: string
            nullable: true
        - name: EmployeeId
          in: query
          schema:
            type: string
            nullable: true
      responses:
        "200":
          description: Person found
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Person"
        "400":
          description: Invalid request
        "404":
          description: Person not found
  /People/GetMatchingPeople:
    get:
      summary: Get people where logonId or fullName contains search text
      parameters:
        - name: SearchText
          in: query
          schema:
            type: string
        - name: Take
          in: query
          schema:
            type: integer
            format: int32
            default: 10
      responses:
        "200":
          description: Matching people
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/GetMatchingPeopleResponse"
        "400":
          description: Invalid request
        "404":
          description: No matches
  /People/ValidatePerson:
    get:
      summary: Validate person identity by logon or employee ID
      parameters:
        - name: LogonId
          in: query
          schema:
            type: string
            nullable: true
        - name: EmployeeId
          in: query
          schema:
            type: string
            nullable: true
      responses:
        "200":
          description: Person is valid
        "400":
          description: Invalid request
        "404":
          description: Person not found
components:
  schemas:
    Person:
      type: object
      required:
        - logonId
        - fullName
        - email
        - employeeId
        - department
        - photoUrl
      properties:
        logonId:
          type: string
        fullName:
          type: string
        email:
          type: string
        employeeId:
          type: string
        department:
          type: string
        photoUrl:
          type: string
    GetMatchingPeopleResponse:
      type: object
      required:
        - people
      properties:
        people:
          type: array
          items:
            $ref: "#/components/schemas/Person"
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/PeopleService.WebApi.csproj"
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Swashbuckle.AspNetCore" Version="8.0.0" />
  </ItemGroup>
</Project>
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/Program.cs"
using Microsoft.OpenApi.Models;
using PeopleService.WebApi.Directory;

var builder = WebApplication.CreateBuilder(args);
var configuredPort = Environment.GetEnvironmentVariable("PEOPLE_SERVICE_PORT") ?? "18089";
builder.WebHost.UseUrls($"http://0.0.0.0:{configuredPort}");

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "PeopleService.WebApi", Version = "v1" });
});
builder.Services.AddSingleton<IDirectoryService, JsonDirectoryService>();

var corsAllowedOrigins = (Environment.GetEnvironmentVariable("CORS_ALLOWED_ORIGINS") ?? "*")
    .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);

builder.Services.AddCors(options =>
{
    options.AddPolicy("baseline-cors", policy =>
    {
        if (corsAllowedOrigins.Length == 0 || corsAllowedOrigins.Any(origin => origin == "*"))
        {
            policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
            return;
        }

        policy.WithOrigins(corsAllowedOrigins).AllowAnyMethod().AllowAnyHeader();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "PeopleService.WebApi v1"));
}

app.UseCors("baseline-cors");
app.UseAuthorization();
app.MapControllers();

app.Logger.LogInformation("[ready] people-service-specfirst listening on :{Port}", configuredPort);
app.Run();
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/Controllers/PeopleController.cs"
using Microsoft.AspNetCore.Mvc;
using PeopleService.WebApi.Directory;

namespace PeopleService.WebApi.Controllers;

[ApiController]
[Route("People")]
public class PeopleController : ControllerBase
{
    private readonly IDirectoryService _directoryService;
    private readonly ILogger<PeopleController> _logger;

    public PeopleController(IDirectoryService directoryService, ILogger<PeopleController> logger)
    {
        _directoryService = directoryService;
        _logger = logger;
    }

    [HttpGet("GetPerson")]
    [ProducesResponseType(typeof(Person), 200)]
    [ProducesResponseType(400)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetPerson([FromQuery] string? logonId, [FromQuery] string? employeeId)
    {
        if (string.IsNullOrWhiteSpace(logonId) && string.IsNullOrWhiteSpace(employeeId))
        {
            return BadRequest("Either LogonId or EmployeeId must be provided.");
        }

        var person = await _directoryService.GetPersonAsync(logonId, employeeId);
        if (person is null)
        {
            _logger.LogWarning("GetPerson not found for logonId={LogonId}, employeeId={EmployeeId}", logonId, employeeId);
            return NotFound();
        }

        return Ok(person);
    }

    [HttpGet("GetMatchingPeople")]
    [ProducesResponseType(typeof(GetMatchingPeopleResponse), 200)]
    [ProducesResponseType(400)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetMatchingPeople([FromQuery] string? searchText, [FromQuery] int take = 10)
    {
        if (string.IsNullOrWhiteSpace(searchText))
        {
            return BadRequest("SearchText must be provided.");
        }

        if (searchText.Length < 3)
        {
            return BadRequest("SearchText must be at least 3 characters long.");
        }

        if (take <= 0)
        {
            take = 10;
        }

        var people = await _directoryService.GetMatchingPeopleAsync(searchText, take);
        if (people.Count == 0)
        {
            _logger.LogWarning("GetMatchingPeople no matches for searchText={SearchText}", searchText);
            return NotFound();
        }

        return Ok(new GetMatchingPeopleResponse { People = people });
    }

    [HttpGet("ValidatePerson")]
    [ProducesResponseType(200)]
    [ProducesResponseType(400)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> ValidatePerson([FromQuery] string? logonId, [FromQuery] string? employeeId)
    {
        if (string.IsNullOrWhiteSpace(logonId) && string.IsNullOrWhiteSpace(employeeId))
        {
            return BadRequest("Either LogonId or EmployeeId must be provided.");
        }

        var isValid = await _directoryService.ValidatePersonAsync(logonId, employeeId);
        if (!isValid)
        {
            _logger.LogWarning("ValidatePerson failed for logonId={LogonId}, employeeId={EmployeeId}", logonId, employeeId);
            return NotFound();
        }

        return Ok();
    }
}

public sealed class GetMatchingPeopleResponse
{
    public List<Person> People { get; init; } = [];
}
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/Directory/IDirectoryService.cs"
namespace PeopleService.WebApi.Directory;

public interface IDirectoryService
{
    Task<Person?> GetPersonAsync(string? logonId, string? employeeId);
    Task<List<Person>> GetMatchingPeopleAsync(string searchText, int take);
    Task<bool> ValidatePersonAsync(string? logonId, string? employeeId);
}
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/Directory/JsonDirectoryService.cs"
using System.Text.Json;

namespace PeopleService.WebApi.Directory;

public sealed class JsonDirectoryService : IDirectoryService
{
    private readonly List<Person> _people;

    public JsonDirectoryService(IConfiguration configuration, IWebHostEnvironment environment)
    {
        var configuredPath = configuration["PeopleJsonFilePath"] ?? "MockDirectory/people.json";
        var fullPath = Path.IsPathRooted(configuredPath)
            ? configuredPath
            : Path.Combine(environment.ContentRootPath, configuredPath);

        if (!File.Exists(fullPath))
        {
            throw new FileNotFoundException($"People directory file not found: {fullPath}", fullPath);
        }

        var json = File.ReadAllText(fullPath);
        _people = JsonSerializer.Deserialize<List<Person>>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? [];
    }

    public Task<Person?> GetPersonAsync(string? logonId, string? employeeId)
    {
        if (!string.IsNullOrWhiteSpace(logonId))
        {
            return Task.FromResult(_people.FirstOrDefault(p => p.LogonId == logonId));
        }

        return Task.FromResult(_people.FirstOrDefault(p => p.EmployeeId == employeeId));
    }

    public Task<List<Person>> GetMatchingPeopleAsync(string searchText, int take)
    {
        var people = _people
            .Where(p =>
                p.FullName.Contains(searchText, StringComparison.Ordinal) ||
                p.LogonId.Contains(searchText, StringComparison.Ordinal))
            .Take(take)
            .ToList();

        return Task.FromResult(people);
    }

    public async Task<bool> ValidatePersonAsync(string? logonId, string? employeeId)
    {
        return await GetPersonAsync(logonId, employeeId) is not null;
    }
}
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/Directory/Person.cs"
namespace PeopleService.WebApi.Directory;

public sealed class Person
{
    public string LogonId { get; init; } = "";
    public string FullName { get; init; } = "";
    public string Email { get; init; } = "";
    public string EmployeeId { get; init; } = "";
    public string Department { get; init; } = "";
    public string PhotoUrl { get; init; } = "";
}
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/appsettings.json"
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "PeopleJsonFilePath": "MockDirectory/people.json",
  "AllowedHosts": "*"
}
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/appsettings.Development.json"
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/Properties/launchSettings.json"
{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "PeopleService.WebApi": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "swagger",
      "applicationUrl": "http://0.0.0.0:18089",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
EOF

cat <<'EOF' > "${TARGET}/PeopleService.WebApi/MockDirectory/people.json"
[
  {
    "LogonId": "user01",
    "FullName": "Alice Johnson",
    "Email": "alice.johnson@example.com",
    "EmployeeId": "E0001",
    "Department": "HR",
    "PhotoUrl": "https://example.com/photos/user01.jpg"
  },
  {
    "LogonId": "user02",
    "FullName": "Bob Smith",
    "Email": "bob.smith@example.com",
    "EmployeeId": "E0002",
    "Department": "Finance",
    "PhotoUrl": "https://example.com/photos/user02.jpg"
  },
  {
    "LogonId": "user03",
    "FullName": "Carol Brown",
    "Email": "carol.brown@example.com",
    "EmployeeId": "E0003",
    "Department": "IT",
    "PhotoUrl": "https://example.com/photos/user03.jpg"
  },
  {
    "LogonId": "user04",
    "FullName": "David Lee",
    "Email": "david.lee@example.com",
    "EmployeeId": "E0004",
    "Department": "Sales",
    "PhotoUrl": "https://example.com/photos/user04.jpg"
  },
  {
    "LogonId": "user05",
    "FullName": "Eva Garcia",
    "Email": "eva.garcia@example.com",
    "EmployeeId": "E0005",
    "Department": "Marketing",
    "PhotoUrl": "https://example.com/photos/user05.jpg"
  },
  {
    "LogonId": "user06",
    "FullName": "Frank Wilson",
    "Email": "frank.wilson@example.com",
    "EmployeeId": "E0006",
    "Department": "HR",
    "PhotoUrl": "https://example.com/photos/user06.jpg"
  },
  {
    "LogonId": "user07",
    "FullName": "Grace Harris",
    "Email": "grace.harris@example.com",
    "EmployeeId": "E0007",
    "Department": "Finance",
    "PhotoUrl": "https://example.com/photos/user07.jpg"
  },
  {
    "LogonId": "user08",
    "FullName": "Henry Martinez",
    "Email": "henry.martinez@example.com",
    "EmployeeId": "E0008",
    "Department": "IT",
    "PhotoUrl": "https://example.com/photos/user08.jpg"
  },
  {
    "LogonId": "user09",
    "FullName": "Ivy Clark",
    "Email": "ivy.clark@example.com",
    "EmployeeId": "E0009",
    "Department": "Sales",
    "PhotoUrl": "https://example.com/photos/user09.jpg"
  },
  {
    "LogonId": "user10",
    "FullName": "Jack Lewis",
    "Email": "jack.lewis@example.com",
    "EmployeeId": "E0010",
    "Department": "Marketing",
    "PhotoUrl": "https://example.com/photos/user10.jpg"
  }
]
EOF

echo "[done] regenerated ${TARGET}"
