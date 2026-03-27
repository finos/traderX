using FluentValidation.Results;
using FluentValidation;
using MediatR;
using JetBrains.Annotations;
using PeopleService.Core.DirectoryService;

namespace PeopleService.Core.Queries
{
    public static class GetPerson
    {
        public class Request : IRequest<Person?>
        {
            /// <summary>
            /// Logon (user name)
            /// </summary>
            public string? LogonId { get; set; }

            /// <summary>
            /// MSID
            /// </summary>
            public string? EmployeeId { get; set; }
        }

        [UsedImplicitly]
        public class RequestValidator : AbstractValidator<Request>
        {
            public override ValidationResult Validate(ValidationContext<Request> context)
            {
                if (string.IsNullOrWhiteSpace(context.InstanceToValidate.LogonId)
                    && string.IsNullOrWhiteSpace(context.InstanceToValidate.EmployeeId))
                {
                    return new ValidationResult(
                        new[]
                        {
                            new ValidationFailure(
                                "",
                                $" Either {nameof(Request.LogonId)} or {nameof(Request.EmployeeId)} must be provided")
                        });
                }

                return new ValidationResult();
            }
        }

        internal class RequestHandler : IRequestHandler<Request, Person?>
        {
            private readonly IDirectoryService _directoryService;

            public RequestHandler(IDirectoryService directoryService)
            {
                _directoryService = directoryService;
            }

            public async Task<Person?> Handle(Request request, CancellationToken cancellationToken)
            {
                var person = await _directoryService.GetPerson(request.LogonId, request.EmployeeId);

                return person;
            }
        }
    }
}
