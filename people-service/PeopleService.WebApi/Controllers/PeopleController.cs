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
