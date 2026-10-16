using System;
using Microsoft.Extensions.Configuration;

namespace MMSERP.Api.Common
{
    public static class CompanyConfigHelper
    {
        private const string DefaultCompanyName = "NEWTECHINFOSOL";

        /// <summary>
        /// Reads COMPANY_NAME from environment variable or configuration.
        /// Falls back to default 'NEWTECHINFOSOL' if not explicitly configured
        /// to ensure transactions and DAYBOOK audit logging never crash.
        /// </summary>
        public static string ResolveCompanyName(IConfiguration configuration)
        {
            var companyName = Environment.GetEnvironmentVariable("COMPANY_NAME")
                ?? configuration["COMPANY_NAME"]
                ?? configuration["CompanyName"];

            if (string.IsNullOrWhiteSpace(companyName))
            {
                return DefaultCompanyName;
            }

            return companyName.Trim();
        }

        private const string DefaultLocationCode = "LWHL26_SQL";

        /// <summary>
        /// Reads LOCATION_CODE from environment variable or configuration.
        /// Falls back to default 'LWHL26_SQL' if not explicitly configured.
        /// </summary>
        public static string ResolveLocationCode(IConfiguration configuration)
        {
            var locCode = Environment.GetEnvironmentVariable("LOCATION_CODE")
                ?? configuration["LOCATION_CODE"]
                ?? configuration["LocationCode"];

            if (string.IsNullOrWhiteSpace(locCode))
            {
                return DefaultLocationCode;
            }

            return locCode.Trim();
        }
    }
}
