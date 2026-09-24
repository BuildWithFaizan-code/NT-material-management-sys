using Microsoft.Extensions.Configuration;

namespace MMSERP.Api.Common;

public static class DbConnectionHelper
{
    /// <summary>
    /// Safely resolves the database connection string from environment variables,
    /// appsettings.Local.json, or appsettings.json, ensuring empty or whitespace
    /// strings are rejected early with an actionable message.
    /// </summary>
    public static string ResolveConnectionString(IConfiguration configuration)
    {
        var connStr = configuration.GetConnectionString("DefaultConnection");
        if (string.IsNullOrWhiteSpace(connStr))
        {
            connStr = Environment.GetEnvironmentVariable("CONNECTION_STRING");
        }

        if (string.IsNullOrWhiteSpace(connStr))
        {
            throw new InvalidOperationException(
                "Database connection string is unconfigured or empty. " +
                "Please configure 'ConnectionStrings:DefaultConnection' in appsettings.json " +
                "or set the 'CONNECTION_STRING' environment variable.");
        }

        return connStr.Trim();
    }
}
