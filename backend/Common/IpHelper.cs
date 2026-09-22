using Microsoft.AspNetCore.Http;

namespace MMSERP.Api.Common
{
    public static class IpHelper
    {
        /// <summary>
        /// Extracts the client IP address from the HTTP context in a reverse-proxy aware manner.
        ///
        /// SECURITY RATIONALE:
        /// Under reverse proxies (such as Render, AWS ALB, Cloudflare, or NGINX), incoming client
        /// requests pass through one or more hops. If an untrusted external client sends an
        /// 'X-Forwarded-For: 1.2.3.4' header to spoof their identity, the reverse proxy appends
        /// the client's actual TCP connection IP to the END of the list:
        ///   X-Forwarded-For: 1.2.3.4, <actual_client_ip>
        ///
        /// Taking the FIRST IP (index 0) allows attackers to bypass rate limiters and spoof audit logs
        /// by injecting arbitrary IPs. By taking the LAST non-empty entry (the one appended by our
        /// immediate trusted ingress proxy), we ensure the rate limiter and audit trail record the
        /// real calling address.
        /// </summary>
        public static string GetClientIp(HttpContext context)
        {
            if (context.Request.Headers.TryGetValue("X-Forwarded-For", out var forwarded) && !string.IsNullOrWhiteSpace(forwarded))
            {
                var ips = forwarded.ToString().Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                if (ips.Length > 0 && !string.IsNullOrWhiteSpace(ips[^1]))
                {
                    return ips[^1];
                }
            }

            return context.Connection.RemoteIpAddress?.ToString() ?? "unknown_client";
        }
    }
}
