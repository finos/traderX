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
