using System;
using Microsoft.Extensions.Configuration;

namespace MMSERP.Api.Common
{
    public static class CompanyConfigHelper
    {
        /// <summary>
        /// Reads COMPANY_NAME from environment variable or configuration.
        /// Fails loudly with InvalidOperationException if not configured.
        /// </summary>
        public static string ResolveCompanyName(IConfiguration configuration)
        {
            var companyName = Environment.GetEnvironmentVariable("COMPANY_NAME")
                ?? configuration["COMPANY_NAME"];

            if (string.IsNullOrWhiteSpace(companyName))
            {
                throw new InvalidOperationException(
                    "Configuration error: 'COMPANY_NAME' is not configured. " +
                    "DAYBOOK audit logging requires a valid company name. " +
                    "Please set the 'COMPANY_NAME' environment variable or configuration setting.");
            }

            return companyName.Trim();
        }
    }
}
