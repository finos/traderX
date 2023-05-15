using MediatR;
using Microsoft.AspNetCore.Mvc;
using PeopleService.Core.DirectoryService;
using PeopleService.Core.Queries;

namespace PeopleService.WebApi.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class PeopleController : ControllerBase
    {
        private readonly IMediator _mediator;
        private readonly ILogger<PeopleController> _logger;

        public PeopleController(IMediator mediator, ILogger<PeopleController> logger)
        {
            _mediator = mediator;
            _logger = logger;
        }

        /// <summary>
        /// Get a person from directory by logon or employee ID
        /// </summary>
        /// <param name="request"></param>
        /// <returns></returns>
        /// <response code="200">The person with the specified identity was found</response>
        /// <response code="400">The request was invalid</response>
        /// <response code="404">The person with the specified identity was not found</response>
        [HttpGet(nameof(GetPerson))]
        [ProducesResponseType(typeof(Person), 200)]
        public async Task<IActionResult> GetPerson([FromQuery] GetPerson.Request request)
        {
            _logger.LogInformation($"PeopleService.GetPerson called with LogonId: {request.LogonId}, EmployeeId: {request.EmployeeId}");

            var response = await _mediator.Send(request);
            if (response == null)
            {
                _logger.LogWarning($"Person not found with LogonId: {request.LogonId}, EmployeeId: {request.EmployeeId}.");
                return NotFound();
            }

            _logger.LogInformation($"Person found with LogonId: {request.LogonId}, EmployeeId: {request.EmployeeId}.");
            return Ok(response);
        }

        /// <summary>
        /// Get all the people from the directory whose logonId or full name contain the search text
        /// </summary>
        /// <param name="request"></param>
        /// <returns></returns>
        /// <response code="200">List of People whose LogonId or FullName contain the search text</response>
        /// <response code="400">The request was invalid</response>
        /// <response code="404">People with the specified search text were not found</response>
        [HttpGet(nameof(GetMatchingPeople))]
        [ProducesResponseType(typeof(GetMatchingPeople.Response), 200)]
        public async Task<IActionResult> GetMatchingPeople([FromQuery] GetMatchingPeople.Request request)
        {
            _logger.LogInformation($"PeopleService.GetMatchingPeople called with searchtext: {request.SearchText}");

            var response = await _mediator.Send(request);
            if (response == null)
            {
                _logger.LogWarning($"People do not exist with searchtext: {request.SearchText}.");
                return NotFound();
            }

            _logger.LogInformation($"People found when using searchtext:  {request.SearchText}.");
            return Ok(response);
        }

        /// <summary>
        /// Validate a person against the directory without returning any attributes.
        /// </summary>
        /// <param name="request"></param>
        /// <returns></returns>
        /// <response code="200">The person with the specified identity was found</response>
        /// <response code="400">The request was invalid</response>
        /// <response code="404">The person with the specified identity was not found</response>
        [HttpGet(nameof(ValidatePerson))]
        public async Task<IActionResult> ValidatePerson([FromQuery] ValidatePerson.Request request)
        {
            _logger.LogInformation($"PeopleService.ValidatePerson called with LogonId: {request.LogonId}, EmployeeId: {request.EmployeeId}");

            var response = await _mediator.Send(request);
            if (!response.IsValid)
            {
                _logger.LogWarning($"Person does not exist with LogonId: {request.LogonId}, EmployeeId: {request.EmployeeId}.");
                return NotFound();
            }

            _logger.LogInformation($"Valid person with LogonId: {request.LogonId}, EmployeeId: {request.EmployeeId}.");
            return Ok();
        }
    }
}