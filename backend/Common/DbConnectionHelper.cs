using Microsoft.Extensions.Configuration;

namespace MMSERP.Api.Common;

public static class DbConnectionHelper
{
    /// <summary>
    /// Safely resolves the database connection string. Environment-variable-first ordering
    /// is deliberate: appsettings.json is committed to source control and must never be the
    /// effective source of a real secret, even as a fallback that could accidentally get populated.
    /// The CONNECTION_STRING environment variable is the authoritative source of truth in all
    /// deployed environments. Fallback to configuration.GetConnectionString("DefaultConnection")
    /// is retained strictly for local development via appsettings.Development.json (or appsettings.Local.json).
    /// </summary>
    public static string ResolveConnectionString(IConfiguration configuration)
    {
        var connStr = Environment.GetEnvironmentVariable("CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connStr))
        {
            connStr = configuration.GetConnectionString("DefaultConnection");
        }

        if (string.IsNullOrWhiteSpace(connStr))
        {
            throw new InvalidOperationException(
                "Database connection string is unconfigured or empty. " +
                "Please configure 'ConnectionStrings:DefaultConnection' in appsettings.Development.json (or appsettings.Local.json) " +
                "or set the 'CONNECTION_STRING' environment variable.");
        }

        return connStr.Trim();
    }
}
