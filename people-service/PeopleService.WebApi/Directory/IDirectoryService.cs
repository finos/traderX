namespace PeopleService.WebApi.Directory;

public interface IDirectoryService
{
    Task<Person?> GetPersonAsync(string? logonId, string? employeeId);
    Task<List<Person>> GetMatchingPeopleAsync(string searchText, int take);
    Task<bool> ValidatePersonAsync(string? logonId, string? employeeId);
}
