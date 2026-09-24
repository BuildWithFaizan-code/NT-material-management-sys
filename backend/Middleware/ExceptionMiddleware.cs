using System.Net;
using System.Security.Authentication;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;
using MMSERP.Api.Models;

namespace MMSERP.Api.Middleware
{
    public class ExceptionMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<ExceptionMiddleware> _logger;

        public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);

                // Handle status code responses that didn't throw exceptions (e.g. from framework auth/authorization)
                if (context.Response.StatusCode == StatusCodes.Status401Unauthorized && !context.Response.HasStarted)
                {
                    await WriteJsonResponseAsync(context, HttpStatusCode.Unauthorized, "Unauthorized: Authentication is required to access this resource.");
                }
                else if (context.Response.StatusCode == StatusCodes.Status403Forbidden && !context.Response.HasStarted)
                {
                    await WriteJsonResponseAsync(context, HttpStatusCode.Forbidden, "Forbidden: You do not have permission to access this resource.");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled exception occurred during request {Method} {Path}: {Message}",
                    context.Request.Method, context.Request.Path, ex.Message);
                await HandleExceptionAsync(context, ex);
            }
        }

        private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
        {
            if (context.Response.HasStarted)
            {
                return;
            }

            var (statusCode, clientMessage) = exception switch
            {
                AuthenticationException or SecurityTokenException or UnauthorizedAccessException =>
                    (HttpStatusCode.Unauthorized, "Unauthorized: Authentication required or invalid token."),
                KeyNotFoundException =>
                    (HttpStatusCode.NotFound, "The requested resource was not found."),
                ArgumentException =>
                    (HttpStatusCode.BadRequest, "Invalid request parameters."),
                InvalidOperationException =>
                    (HttpStatusCode.BadRequest, "The requested operation could not be completed."),
                _ =>
                    (HttpStatusCode.InternalServerError, $"An unexpected server error occurred: {exception.Message}")
            };

            await WriteJsonResponseAsync(context, statusCode, clientMessage);
        }

        private static async Task WriteJsonResponseAsync(HttpContext context, HttpStatusCode statusCode, string clientMessage)
        {
            context.Response.ContentType = "application/json";
            context.Response.StatusCode = (int)statusCode;

            var response = ApiResponse<object>.Fail(clientMessage);
            var json = JsonSerializer.Serialize(response, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });

            await context.Response.WriteAsync(json);
        }
    }
}
