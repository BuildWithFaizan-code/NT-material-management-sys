using Microsoft.AspNetCore.Authorization;

namespace MMSERP.Api.Middleware
{
    /// <summary>
    /// Development Authorization Bypass Handler (Option A from NT-MMS Auth Plan).
    /// Auto-succeeds authorization requirements ONLY in Development environment.
    /// In Production, a startup guard strictly asserts this handler is never registered.
    /// </summary>
    public class AllowAnonymousInDevelopmentHandler : IAuthorizationHandler
    {
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<AllowAnonymousInDevelopmentHandler> _logger;

        public AllowAnonymousInDevelopmentHandler(
            IWebHostEnvironment environment,
            ILogger<AllowAnonymousInDevelopmentHandler> logger)
        {
            _environment = environment;
            _logger = logger;
        }

        public Task HandleAsync(AuthorizationHandlerContext context)
        {
            if (_environment.IsDevelopment())
            {
                foreach (var requirement in context.PendingRequirements.ToList())
                {
                    context.Succeed(requirement);
                }
            }

            return Task.CompletedTask;
        }
    }
}
