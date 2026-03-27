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
