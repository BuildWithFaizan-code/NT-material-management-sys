using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;
        private readonly ILogger<AuthController> _logger;
        private const string RefreshCookieName = "nt_refresh_token";

        public AuthController(IAuthService authService, ILogger<AuthController> logger)
        {
            _authService = authService;
            _logger = logger;
        }

        private string? GetClientIp()
        {
            return Request.Headers.TryGetValue("X-Forwarded-For", out var forwarded)
                ? forwarded.FirstOrDefault()?.Split(',')[0].Trim()
                : HttpContext.Connection.RemoteIpAddress?.ToString();
        }

        private int? GetCurrentUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(claim, out var id) ? id : null;
        }

        private bool IsWebClient()
        {
            return Request.Headers.TryGetValue("X-Client-Platform", out var platform)
                && string.Equals(platform.ToString(), "web", StringComparison.OrdinalIgnoreCase);
        }

        private void SetRefreshTokenCookie(string rawRefreshToken, DateTime expiresAt)
        {
            var cookieOptions = new CookieOptions
            {
                HttpOnly = true,
                Secure = true, // Force Secure for HttpOnly cookie
                SameSite = SameSiteMode.Strict,
                Expires = expiresAt,
                Path = "/api/auth"
            };
            Response.Cookies.Append(RefreshCookieName, rawRefreshToken, cookieOptions);
        }

        private void ClearRefreshTokenCookie()
        {
            var cookieOptions = new CookieOptions
            {
                HttpOnly = true,
                Secure = true,
                SameSite = SameSiteMode.Strict,
                Expires = DateTime.UtcNow.AddDays(-1),
                Path = "/api/auth"
            };
            Response.Cookies.Append(RefreshCookieName, string.Empty, cookieOptions);
        }

        /// <summary>
        /// POST /api/auth/login
        /// Authenticates user and issues access token + refresh token.
        /// Rate limited to 5 attempts per IP per minute.
        /// </summary>
        [HttpPost("login")]
        [AllowAnonymous]
        [EnableRateLimiting("LoginRateLimit")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            if (request == null)
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid login payload."));
            }

            var ip = GetClientIp();
            var result = await _authService.LoginAsync(request, ip);

            if (!result.Success || result.Data == null)
            {
                return Unauthorized(result);
            }

            // If web client, deliver refresh token via HttpOnly cookie and strip from response body
            if (IsWebClient() && !string.IsNullOrEmpty(result.Data.RefreshToken))
            {
                SetRefreshTokenCookie(result.Data.RefreshToken, DateTime.UtcNow.AddDays(7));
                var webResponseData = result.Data with { RefreshToken = null };
                return Ok(ApiResponse<LoginResponse>.Ok(webResponseData, result.Message));
            }

            return Ok(result);
        }

        /// <summary>
        /// POST /api/auth/refresh
        /// Native / desktop client token rotation path (Refresh Token passed in body).
        /// </summary>
        [HttpPost("refresh")]
        [AllowAnonymous]
        public async Task<IActionResult> Refresh([FromBody] RefreshTokenRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.RefreshToken))
            {
                return BadRequest(ApiResponse<string>.Fail("Refresh token is required."));
            }

            var ip = GetClientIp();
            var deviceInfo = Request.Headers.UserAgent.ToString();
            var result = await _authService.RefreshTokenAsync(request.RefreshToken, ip, deviceInfo);

            if (!result.Success)
            {
                return Unauthorized(result);
            }

            return Ok(result);
        }

        /// <summary>
        /// POST /api/auth/refresh-web
        /// Web client token rotation path (Refresh Token passed via HttpOnly cookie).
        /// </summary>
        [HttpPost("refresh-web")]
        [AllowAnonymous]
        public async Task<IActionResult> RefreshWeb()
        {
            if (!Request.Cookies.TryGetValue(RefreshCookieName, out var rawRefreshToken) || string.IsNullOrWhiteSpace(rawRefreshToken))
            {
                return Unauthorized(ApiResponse<string>.Fail("No refresh token cookie found. Please log in."));
            }

            var ip = GetClientIp();
            var deviceInfo = Request.Headers.UserAgent.ToString();
            var result = await _authService.RefreshTokenAsync(rawRefreshToken, ip, deviceInfo);

            if (!result.Success || result.Data == null)
            {
                ClearRefreshTokenCookie();
                return Unauthorized(result);
            }

            // Set rotated cookie
            if (!string.IsNullOrEmpty(result.Data.RefreshToken))
            {
                SetRefreshTokenCookie(result.Data.RefreshToken, DateTime.UtcNow.AddDays(7));
            }

            var webData = result.Data with { RefreshToken = null };
            return Ok(ApiResponse<LoginResponse>.Ok(webData, result.Message));
        }

        /// <summary>
        /// POST /api/auth/logout
        /// Logs out user, invalidating refresh token and clearing cookies.
        /// </summary>
        [HttpPost("logout")]
        [AllowAnonymous]
        public async Task<IActionResult> Logout([FromBody] RefreshTokenRequest? request)
        {
            var userId = GetCurrentUserId();
            string? rawToken = request?.RefreshToken;

            if (Request.Cookies.TryGetValue(RefreshCookieName, out var cookieToken))
            {
                rawToken ??= cookieToken;
                ClearRefreshTokenCookie();
            }

            if (userId.HasValue)
            {
                await _authService.LogoutAsync(userId.Value, rawToken);
            }

            return Ok(ApiResponse<bool>.Ok(true, "Logged out successfully."));
        }

        /// <summary>
        /// POST /api/auth/change-password
        /// Allows authenticated user to update their password.
        /// </summary>
        [HttpPost("change-password")]
        [Authorize]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
        {
            var userId = GetCurrentUserId();
            if (!userId.HasValue)
            {
                return Unauthorized(ApiResponse<string>.Fail("User is not authenticated."));
            }

            var result = await _authService.ChangePasswordAsync(userId.Value, request);
            if (!result.Success)
            {
                return BadRequest(result);
            }

            ClearRefreshTokenCookie();
            return Ok(result);
        }

        /// <summary>
        /// POST /api/auth/register
        /// Admin-only user provisioning endpoint.
        /// </summary>
        [HttpPost("register")]
        [Authorize]
        public async Task<IActionResult> Register([FromBody] RegisterUserRequest request)
        {
            var isAdminClaim = User.FindFirst("isAdmin")?.Value;
            if (!string.Equals(isAdminClaim, "true", StringComparison.OrdinalIgnoreCase))
            {
                return StatusCode(403, ApiResponse<string>.Fail("Forbidden: Admin privileges required to provision users."));
            }

            var adminUserId = GetCurrentUserId() ?? 0;
            var result = await _authService.RegisterUserAsync(request, adminUserId);

            if (!result.Success)
            {
                return BadRequest(result);
            }

            return Ok(result);
        }

        /// <summary>
        /// POST /api/auth/mfa/setup
        /// Enrolls authenticated user in TOTP MFA, returning secret and QR code URI.
        /// </summary>
        [HttpPost("mfa/setup")]
        [Authorize]
        public async Task<IActionResult> SetupMfa()
        {
            var userId = GetCurrentUserId();
            if (!userId.HasValue)
            {
                return Unauthorized(ApiResponse<string>.Fail("User is not authenticated."));
            }

            var result = await _authService.SetupMfaAsync(userId.Value);
            return Ok(result);
        }

        /// <summary>
        /// POST /api/auth/mfa/verify
        /// Confirms TOTP code and activates MFA for authenticated user.
        /// </summary>
        [HttpPost("mfa/verify")]
        [Authorize]
        public async Task<IActionResult> VerifyMfa([FromBody] MfaVerifyRequest request)
        {
            var userId = GetCurrentUserId();
            if (!userId.HasValue)
            {
                return Unauthorized(ApiResponse<string>.Fail("User is not authenticated."));
            }

            var result = await _authService.VerifyAndEnableMfaAsync(userId.Value, request);
            if (!result.Success)
            {
                return BadRequest(result);
            }

            return Ok(result);
        }

        /// <summary>
        /// POST /api/auth/mfa/login
        /// Second-step verification for MFA challenge during login.
        /// </summary>
        [HttpPost("mfa/login")]
        [AllowAnonymous]
        public async Task<IActionResult> MfaLogin([FromBody] MfaLoginRequest request)
        {
            var ip = GetClientIp();
            var result = await _authService.VerifyMfaLoginAsync(request, ip);

            if (!result.Success || result.Data == null)
            {
                return Unauthorized(result);
            }

            if (IsWebClient() && !string.IsNullOrEmpty(result.Data.RefreshToken))
            {
                SetRefreshTokenCookie(result.Data.RefreshToken, DateTime.UtcNow.AddDays(7));
                var webResponseData = result.Data with { RefreshToken = null };
                return Ok(ApiResponse<LoginResponse>.Ok(webResponseData, result.Message));
            }

            return Ok(result);
        }

        /// <summary>
        /// GET /api/auth/sessions
        /// Returns active sessions for authenticated user.
        /// </summary>
        [HttpGet("sessions")]
        [Authorize]
        public async Task<IActionResult> GetSessions()
        {
            var userId = GetCurrentUserId();
            if (!userId.HasValue)
            {
                return Unauthorized(ApiResponse<string>.Fail("User is not authenticated."));
            }

            Request.Cookies.TryGetValue(RefreshCookieName, out var currentToken);
            var result = await _authService.GetActiveSessionsAsync(userId.Value, currentToken);
            return Ok(result);
        }

        /// <summary>
        /// DELETE /api/auth/sessions/{tokenId}
        /// Revokes specific active session.
        /// </summary>
        [HttpDelete("sessions/{tokenId:int}")]
        [Authorize]
        public async Task<IActionResult> RevokeSession(int tokenId)
        {
            var userId = GetCurrentUserId();
            if (!userId.HasValue)
            {
                return Unauthorized(ApiResponse<string>.Fail("User is not authenticated."));
            }

            var result = await _authService.RevokeSessionAsync(userId.Value, tokenId);
            if (!result.Success)
            {
                return NotFound(result);
            }

            return Ok(result);
        }

        /// <summary>
        /// DELETE /api/auth/sessions
        /// Revokes all active sessions for authenticated user ("log out everywhere").
        /// </summary>
        [HttpDelete("sessions")]
        [Authorize]
        public async Task<IActionResult> RevokeAllSessions()
        {
            var userId = GetCurrentUserId();
            if (!userId.HasValue)
            {
                return Unauthorized(ApiResponse<string>.Fail("User is not authenticated."));
            }

            var result = await _authService.RevokeAllSessionsAsync(userId.Value);
            ClearRefreshTokenCookie();
            return Ok(result);
        }
    }
}
