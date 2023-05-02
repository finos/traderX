using CacheManager.Core;
using FluentValidation;
using FluentValidation.Results;
using JetBrains.Annotations;
using MediatR;
using PeopleService.Core.DirectoryService;
using System.Linq;

namespace PeopleService.Core.Queries
{
    public static class GetMatchingPeople
    {
        public class Request : IRequest<Response?>
        {
            /// <summary>
            /// Search text
            /// </summary>
            public string? SearchText { get; set; }

            /// <summary>
            /// Returns the specified number of element. (Default is 10)
            /// </summary>
            public int Take { get; set; } = 10;
        }

        public class Response
        {
            public List<Person>? People { get; set; }
        }

        [UsedImplicitly]
        public class RequestValidator : AbstractValidator<Request>
        {
            public override ValidationResult Validate(ValidationContext<Request> context)
            {
                if (string.IsNullOrWhiteSpace(context.InstanceToValidate.SearchText))
                {
                    return new ValidationResult(
                        new[]
                        {
                            new ValidationFailure(
                                "",
                                $"{nameof(Request.SearchText)} must be provided")
                        });
                }

                if (context.InstanceToValidate.SearchText.Length < 3)
                {
                    return new ValidationResult(
                        new[]
                        {
                            new ValidationFailure(
                                "",
                                $"{nameof(Request.SearchText)} must be at least 3 characters long")
                        });
                }

                return new ValidationResult();
            }
        }

        internal class RequestHandler : IRequestHandler<Request, Response?>
        {
            private readonly IDirectoryService _directoryService;
            private readonly ICacheManager<Response> _cacheManager;

            public RequestHandler(IDirectoryService directoryService, ICacheManager<Response> cacheManager)
            {
                _directoryService = directoryService;
                _cacheManager = cacheManager;
            }

            public async Task<Response?> Handle(Request request, CancellationToken cancellationToken)
            {
                var cacheKey = GetCacheKey(request);
                var result = _cacheManager.GetCacheItem(cacheKey);
                if (result != null)
                {
                    return result.Value?.People?.Count == 0 ? null : result.Value;
                }

                var people = (await _directoryService.GetMatchingPerson(request.SearchText!, request.Take))?.ToList();

                var response = new Response
                {
                    People = people
                };

                _cacheManager.Add(cacheKey, response);

                return people?.Count == 0 ? null : response;
            }

            private static string GetCacheKey(Request request) => (request.SearchText ?? "") + "," + request.Take;
        }
    }
}
