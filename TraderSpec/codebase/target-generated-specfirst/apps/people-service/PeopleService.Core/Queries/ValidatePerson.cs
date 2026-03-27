using FluentValidation;
using FluentValidation.Results;
using JetBrains.Annotations;
using MediatR;
using PeopleService.Core.DirectoryService;

namespace PeopleService.Core.Queries
{
    public static class ValidatePerson
    {
        public class Request : IRequest<Response>
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

        public class Response
        {
            public bool IsValid { get; set; }
        }

        internal class RequestHandler : IRequestHandler<Request, Response>
        {
            private readonly IDirectoryService _directoryService;

            public RequestHandler(IDirectoryService directoryService)
            {
                _directoryService = directoryService;
            }

            public async Task<Response> Handle(Request request, CancellationToken cancellationToken)
            {
                bool result = await _directoryService.ValidatePerson(request.LogonId, request.EmployeeId);

                var response = new Response
                {
                    IsValid = result
                };

                return response;
            }
        }
    }
}
