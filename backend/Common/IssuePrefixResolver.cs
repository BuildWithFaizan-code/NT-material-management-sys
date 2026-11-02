using System;

namespace MMSERP.Api.Common
{
    public static class IssuePrefixResolver
    {
        /// <summary>
        /// Resolves the sequence prefix for an Issue Manager document.
        /// Accepts strictly verified combinations from legacy traces.
        /// Any unverified combination throws an InvalidOperationException naming missing trace C.2-1.
        /// </summary>
        public static string Resolve(string? issueMode, string? fromDeptName)
        {
            var mode = issueMode?.Trim();
            var dept = fromDeptName?.Trim();

            // Verified legacy case: From-department 'REGULAR' with Issue Mode 'To Department'
            if (string.Equals(mode, "To Department", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(dept, "REGULAR", StringComparison.OrdinalIgnoreCase))
            {
                return "REGU";
            }

            throw new InvalidOperationException(
                $"Prefix resolution for department '{dept}' and mode '{mode}' is not verified yet. Awaiting legacy trace (C.2-1).");
        }

        /// <summary>
        /// Safe check to determine if the prefix resolves without throwing.
        /// </summary>
        public static bool TryResolve(string? issueMode, string? fromDeptName, out string? prefix, out string? errorMessage)
        {
            try
            {
                prefix = Resolve(issueMode, fromDeptName);
                errorMessage = null;
                return true;
            }
            catch (Exception ex)
            {
                prefix = null;
                errorMessage = ex.Message;
                return false;
            }
        }
    }
}
