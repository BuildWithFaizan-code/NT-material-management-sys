using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;
using OtpNet;

namespace MMSERP.Api.Services
{
    public class AuthService : IAuthService
    {
        private readonly IAuthRepository _authRepository;
        private readonly IRolePermissionRepository _roleRepository;
        private readonly IPermissionCacheService _cacheService;
        private readonly ILogger<AuthService> _logger;
        private readonly byte[] _jwtKeyBytes;
        private const int AccessTokenLifetimeMinutes = 15;
        private const int RefreshTokenLifetimeDays = 7;
        private const int MfaChallengeLifetimeMinutes = 5;

        public AuthService(
            IAuthRepository authRepository,
            IRolePermissionRepository roleRepository,
            IPermissionCacheService cacheService,
            IConfiguration configuration,
            ILogger<AuthService> logger)
        {
            _authRepository = authRepository;
            _roleRepository = roleRepository;
            _cacheService = cacheService;
            _logger = logger;

            var jwtKey = Environment.GetEnvironmentVariable("JWT_SIGNING_KEY")
                ?? configuration["JWT_SIGNING_KEY"];
            if (string.IsNullOrWhiteSpace(jwtKey))
            {
                throw new InvalidOperationException("FATAL: Environment variable 'JWT_SIGNING_KEY' is missing. A secure key of at least 256 bits is required.");
            }

            _jwtKeyBytes = Encoding.UTF8.GetBytes(jwtKey);
            if (_jwtKeyBytes.Length < 32)
            {
                throw new InvalidOperationException("FATAL: Environment variable 'JWT_SIGNING_KEY' must be at least 256 bits (32 characters).");
            }
        }

        public async Task<ApiResponse<LoginResponse>> LoginAsync(LoginRequest request, string? ipAddress)
        {
            if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
            {
                return ApiResponse<LoginResponse>.Fail("Username and password are required.");
            }

            var user = await _authRepository.GetUserByUsernameAsync(request.Username.Trim());
            if (user == null)
            {
                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    EventType = "LoginFailed",
                    IpAddress = ipAddress,
                    DeviceInfo = request.DeviceInfo,
                    Success = false,
                    Detail = "User not found"
                });
                return ApiResponse<LoginResponse>.Fail("Invalid credentials.");
            }

            // Check if account is locked
            if (user.LockedUntil.HasValue && user.LockedUntil.Value > DateTime.UtcNow)
            {
                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    UserId = user.UserId,
                    EventType = "LoginAttemptWhileLocked",
                    IpAddress = ipAddress,
                    DeviceInfo = request.DeviceInfo,
                    Success = false,
                    Detail = $"Account locked until {user.LockedUntil.Value:O}"
                });
                return ApiResponse<LoginResponse>.Fail("Account temporarily locked. Please try again later.");
            }

            // Verify password
            bool passwordValid = false;
            try
            {
                passwordValid = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Password verification error for user {UserId}", user.UserId);
            }

            if (!passwordValid)
            {
                var failedCount = user.FailedLoginCount + 1;
                DateTime? lockedUntil = null;

                if (failedCount >= 5)
                {
                    // Exponential backoff cooldown: 5 min, 15 min, 60 min
                    int cooldownMinutes = failedCount switch
                    {
                        5 or 6 or 7 => 5,
                        8 or 9 or 10 or 11 => 15,
                        _ => 60
                    };
                    lockedUntil = DateTime.UtcNow.AddMinutes(cooldownMinutes);
                    _logger.LogWarning("User {UserId} locked out until {LockedUntil} after {FailedCount} failed attempts.", user.UserId, lockedUntil, failedCount);
                }

                await _authRepository.RecordFailedLoginAsync(user.UserId, failedCount, lockedUntil);

                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    UserId = user.UserId,
                    EventType = lockedUntil.HasValue ? "AccountLocked" : "LoginFailed",
                    IpAddress = ipAddress,
                    DeviceInfo = request.DeviceInfo,
                    Success = false,
                    Detail = lockedUntil.HasValue ? $"Account locked after {failedCount} failures" : $"Failed attempt #{failedCount}"
                });

                return ApiResponse<LoginResponse>.Fail("Invalid credentials.");
            }

            // Password is valid
            if (!user.IsActive)
            {
                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    UserId = user.UserId,
                    EventType = "LoginFailedInactive",
                    IpAddress = ipAddress,
                    DeviceInfo = request.DeviceInfo,
                    Success = false,
                    Detail = "Account is inactive"
                });
                return ApiResponse<LoginResponse>.Fail("Account is inactive. Please contact your administrator.");
            }

            // Reset failed login count and update last login
            await _authRepository.UpdateLoginSuccessAsync(user.UserId);

            var userInfo = await BuildUserInfoDtoAsync(user);

            // MFA Check
            if (user.MfaEnabled && !string.IsNullOrWhiteSpace(user.MfaSecret))
            {
                var challengeToken = GenerateMfaChallengeToken(user);
                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    UserId = user.UserId,
                    EventType = "MfaChallengeIssued",
                    IpAddress = ipAddress,
                    DeviceInfo = request.DeviceInfo,
                    Success = true,
                    Detail = "MFA code required"
                });

                return ApiResponse<LoginResponse>.Ok(new LoginResponse(
                    AccessToken: null,
                    RefreshToken: null,
                    ExpiresInSeconds: MfaChallengeLifetimeMinutes * 60,
                    MustChangePassword: user.MustChangePassword,
                    RequiresMfa: true,
                    MfaChallengeToken: challengeToken,
                    User: userInfo
                ), "MFA authentication required.");
            }

            // Issue access token and refresh token
            var accessToken = GenerateJwtToken(user);
            var rawRefreshToken = GenerateSecureToken();
            var tokenHash = HashToken(rawRefreshToken);

            var refreshToken = new RefreshToken
            {
                UserId = user.UserId,
                TokenHash = tokenHash,
                DeviceInfo = request.DeviceInfo,
                IpAddress = ipAddress,
                IssuedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddDays(RefreshTokenLifetimeDays)
            };

            await _authRepository.CreateRefreshTokenAsync(refreshToken);

            await _authRepository.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = user.UserId,
                EventType = "Login",
                IpAddress = ipAddress,
                DeviceInfo = request.DeviceInfo,
                Success = true,
                Detail = "Successful login"
            });

            return ApiResponse<LoginResponse>.Ok(new LoginResponse(
                AccessToken: accessToken,
                RefreshToken: rawRefreshToken,
                ExpiresInSeconds: AccessTokenLifetimeMinutes * 60,
                MustChangePassword: user.MustChangePassword,
                RequiresMfa: false,
                MfaChallengeToken: null,
                User: userInfo
            ), "Login successful.");
        }

        public async Task<ApiResponse<LoginResponse>> RefreshTokenAsync(string rawRefreshToken, string? ipAddress, string? deviceInfo)
        {
            if (string.IsNullOrWhiteSpace(rawRefreshToken))
            {
                return ApiResponse<LoginResponse>.Fail("Refresh token is required.");
            }

            var tokenHash = HashToken(rawRefreshToken.Trim());
            var storedToken = await _authRepository.GetRefreshTokenByHashAsync(tokenHash);

            if (storedToken == null || storedToken.ExpiresAt <= DateTime.UtcNow)
            {
                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    EventType = "TokenRefreshFailed",
                    IpAddress = ipAddress,
                    DeviceInfo = deviceInfo,
                    Success = false,
                    Detail = "Refresh token not found or expired"
                });
                return ApiResponse<LoginResponse>.Fail("Invalid or expired refresh token.");
            }

            // Token Replay / Theft Detection:
            // If an already revoked token is presented again, someone has compromised or replayed it!
            if (storedToken.RevokedAt != null)
            {
                _logger.LogWarning("SECURITY ALERT: Replay detected on TokenId {TokenId} for UserId {UserId}. Revoking entire token family.",
                    storedToken.TokenId, storedToken.UserId);

                await _authRepository.RevokeTokenFamilyAsync(storedToken.UserId);

                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    UserId = storedToken.UserId,
                    EventType = "TokenReplayDetected",
                    IpAddress = ipAddress,
                    DeviceInfo = deviceInfo,
                    Success = false,
                    Detail = $"Replay detected for TokenId {storedToken.TokenId}. Token family revoked."
                });

                return ApiResponse<LoginResponse>.Fail("Session terminated due to security violation. Please log in again.");
            }

            var user = await _authRepository.GetUserByIdAsync(storedToken.UserId);
            if (user == null || !user.IsActive)
            {
                return ApiResponse<LoginResponse>.Fail("User account is invalid or inactive.");
            }

            // Issue new access token and new rotated refresh token
            var newAccessToken = GenerateJwtToken(user);
            var newRawRefreshToken = GenerateSecureToken();
            var newTokenHash = HashToken(newRawRefreshToken);

            var newRefreshToken = new RefreshToken
            {
                UserId = user.UserId,
                TokenHash = newTokenHash,
                DeviceInfo = deviceInfo ?? storedToken.DeviceInfo,
                IpAddress = ipAddress,
                IssuedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddDays(RefreshTokenLifetimeDays)
            };

            var newTokenId = await _authRepository.CreateRefreshTokenAsync(newRefreshToken);

            // Mark old token revoked and link to successor
            await _authRepository.RevokeRefreshTokenAsync(storedToken.TokenId, newTokenId);

            await _authRepository.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = user.UserId,
                EventType = "TokenRotated",
                IpAddress = ipAddress,
                DeviceInfo = deviceInfo,
                Success = true,
                Detail = $"TokenId {storedToken.TokenId} rotated to {newTokenId}"
            });

            var userInfo = await BuildUserInfoDtoAsync(user);

            return ApiResponse<LoginResponse>.Ok(new LoginResponse(
                AccessToken: newAccessToken,
                RefreshToken: newRawRefreshToken,
                ExpiresInSeconds: AccessTokenLifetimeMinutes * 60,
                MustChangePassword: user.MustChangePassword,
                RequiresMfa: false,
                MfaChallengeToken: null,
                User: userInfo
            ), "Token refreshed successfully.");
        }

        public async Task<ApiResponse<bool>> LogoutAsync(int? userId, string? rawRefreshToken = null)
        {
            int? effectiveUserId = userId;

            if (!string.IsNullOrWhiteSpace(rawRefreshToken))
            {
                var tokenHash = HashToken(rawRefreshToken.Trim());
                var token = await _authRepository.GetRefreshTokenByHashAsync(tokenHash);
                if (token != null)
                {
                    await _authRepository.RevokeRefreshTokenAsync(token.TokenId);
                    effectiveUserId ??= token.UserId;
                }
            }
            else if (userId.HasValue)
            {
                await _authRepository.RevokeAllSessionsAsync(userId.Value);
            }

            if (effectiveUserId.HasValue)
            {
                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    UserId = effectiveUserId.Value,
                    EventType = "Logout",
                    Success = true,
                    Detail = "User logged out"
                });
            }

            return ApiResponse<bool>.Ok(true, "Logged out successfully.");
        }

        public async Task<ApiResponse<bool>> RegisterUserAsync(RegisterUserRequest request, int adminUserId)
        {
            if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Email))
            {
                return ApiResponse<bool>.Fail("Username and email are required.");
            }

            var passwordValidation = ValidatePasswordComplexity(request.Password);
            if (!passwordValidation.IsValid)
            {
                return ApiResponse<bool>.Fail(passwordValidation.ErrorMessage);
            }

            var existing = await _authRepository.GetUserByUsernameAsync(request.Username.Trim());
            if (existing != null)
            {
                return ApiResponse<bool>.Fail("A user with this username or email already exists.");
            }

            var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password, workFactor: 11);

            var newUser = new User
            {
                Username = request.Username.Trim(),
                Email = request.Email.Trim(),
                PasswordHash = passwordHash,
                IsActive = true,
                IsAdmin = request.IsAdmin,
                MustChangePassword = true, // Admin-created users must change password on first login
                CreatedAt = DateTime.UtcNow,
                CreatedBy = adminUserId
            };

            await _authRepository.CreateUserAsync(newUser);

            await _authRepository.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = adminUserId,
                EventType = "UserCreated",
                Success = true,
                Detail = $"Created user {newUser.Username} (IsAdmin: {newUser.IsAdmin})"
            });

            return ApiResponse<bool>.Ok(true, "User created successfully.");
        }

        public async Task<ApiResponse<bool>> ChangePasswordAsync(int userId, ChangePasswordRequest request)
        {
            var user = await _authRepository.GetUserByIdAsync(userId);
            if (user == null)
            {
                return ApiResponse<bool>.Fail("User not found.");
            }

            if (!BCrypt.Net.BCrypt.Verify(request.CurrentPassword, user.PasswordHash))
            {
                return ApiResponse<bool>.Fail("Current password is incorrect.");
            }

            var passwordValidation = ValidatePasswordComplexity(request.NewPassword);
            if (!passwordValidation.IsValid)
            {
                return ApiResponse<bool>.Fail(passwordValidation.ErrorMessage);
            }

            var newHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword, workFactor: 11);
            await _authRepository.UpdatePasswordAsync(userId, newHash);

            // Invalidate other sessions upon password change
            await _authRepository.RevokeTokenFamilyAsync(userId);

            await _authRepository.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = userId,
                EventType = "PasswordChanged",
                Success = true,
                Detail = "Password changed and other sessions revoked"
            });

            return ApiResponse<bool>.Ok(true, "Password changed successfully. Please log in again with your new password.");
        }

        public async Task<ApiResponse<MfaSetupResponse>> SetupMfaAsync(int userId)
        {
            var user = await _authRepository.GetUserByIdAsync(userId);
            if (user == null)
            {
                return ApiResponse<MfaSetupResponse>.Fail("User not found.");
            }

            var secretKey = KeyGeneration.GenerateRandomKey(20);
            var base32Secret = Base32Encoding.ToString(secretKey);
            var otpAuthUri = $"otpauth://totp/NT-MMS:{user.Username}?secret={base32Secret}&issuer=NT-MMS";

            return ApiResponse<MfaSetupResponse>.Ok(new MfaSetupResponse(base32Secret, otpAuthUri), "MFA setup key generated.");
        }

        public async Task<ApiResponse<bool>> VerifyAndEnableMfaAsync(int userId, MfaVerifyRequest request)
        {
            var user = await _authRepository.GetUserByIdAsync(userId);
            if (user == null)
            {
                return ApiResponse<bool>.Fail("User not found.");
            }

            if (string.IsNullOrWhiteSpace(request.SecretKey) || string.IsNullOrWhiteSpace(request.Code))
            {
                return ApiResponse<bool>.Fail("Secret key and 6-digit code are required.");
            }

            byte[] secretBytes;
            try
            {
                secretBytes = Base32Encoding.ToBytes(request.SecretKey.Trim());
            }
            catch
            {
                return ApiResponse<bool>.Fail("Invalid secret key format.");
            }

            var totp = new Totp(secretBytes);
            if (!totp.VerifyTotp(request.Code.Trim(), out _, new VerificationWindow(previous: 1, future: 1)))
            {
                return ApiResponse<bool>.Fail("Invalid MFA verification code.");
            }

            await _authRepository.SetMfaSecretAsync(userId, request.SecretKey.Trim(), enabled: true);

            await _authRepository.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = userId,
                EventType = "MfaEnabled",
                Success = true,
                Detail = "MFA successfully enrolled and enabled"
            });

            return ApiResponse<bool>.Ok(true, "MFA successfully verified and enabled.");
        }

        public async Task<ApiResponse<LoginResponse>> VerifyMfaLoginAsync(MfaLoginRequest request, string? ipAddress)
        {
            if (string.IsNullOrWhiteSpace(request.ChallengeToken) || string.IsNullOrWhiteSpace(request.Code))
            {
                return ApiResponse<LoginResponse>.Fail("Challenge token and 6-digit code are required.");
            }

            // Validate challenge token
            var principal = ValidateMfaChallengeToken(request.ChallengeToken);
            if (principal == null)
            {
                return ApiResponse<LoginResponse>.Fail("MFA challenge token is invalid or expired. Please log in again.");
            }

            var userIdClaim = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdClaim, out var userId))
            {
                return ApiResponse<LoginResponse>.Fail("Invalid token payload.");
            }

            var user = await _authRepository.GetUserByIdAsync(userId);
            if (user == null || !user.IsActive || string.IsNullOrWhiteSpace(user.MfaSecret))
            {
                return ApiResponse<LoginResponse>.Fail("User not found or MFA not configured.");
            }

            byte[] secretBytes;
            try
            {
                secretBytes = Base32Encoding.ToBytes(user.MfaSecret);
            }
            catch
            {
                return ApiResponse<LoginResponse>.Fail("Server MFA configuration error.");
            }

            var totp = new Totp(secretBytes);
            if (!totp.VerifyTotp(request.Code.Trim(), out _, new VerificationWindow(previous: 1, future: 1)))
            {
                await _authRepository.WriteAuditLogAsync(new AuthAuditLog
                {
                    UserId = user.UserId,
                    EventType = "MfaLoginFailed",
                    IpAddress = ipAddress,
                    DeviceInfo = request.DeviceInfo,
                    Success = false,
                    Detail = "Incorrect MFA code"
                });
                return ApiResponse<LoginResponse>.Fail("Invalid MFA code.");
            }

            // MFA verification succeeded!
            var accessToken = GenerateJwtToken(user);
            var rawRefreshToken = GenerateSecureToken();
            var tokenHash = HashToken(rawRefreshToken);

            var refreshToken = new RefreshToken
            {
                UserId = user.UserId,
                TokenHash = tokenHash,
                DeviceInfo = request.DeviceInfo,
                IpAddress = ipAddress,
                IssuedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddDays(RefreshTokenLifetimeDays)
            };

            await _authRepository.CreateRefreshTokenAsync(refreshToken);

            await _authRepository.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = user.UserId,
                EventType = "MfaLoginSuccess",
                IpAddress = ipAddress,
                DeviceInfo = request.DeviceInfo,
                Success = true,
                Detail = "MFA authentication completed"
            });

            var userInfo = await BuildUserInfoDtoAsync(user);

            return ApiResponse<LoginResponse>.Ok(new LoginResponse(
                AccessToken: accessToken,
                RefreshToken: rawRefreshToken,
                ExpiresInSeconds: AccessTokenLifetimeMinutes * 60,
                MustChangePassword: user.MustChangePassword,
                RequiresMfa: false,
                MfaChallengeToken: null,
                User: userInfo
            ), "MFA login successful.");
        }

        public async Task<ApiResponse<IEnumerable<SessionDto>>> GetActiveSessionsAsync(int userId, string? currentToken)
        {
            var tokens = await _authRepository.GetActiveTokensByUserIdAsync(userId);
            string? currentHash = !string.IsNullOrWhiteSpace(currentToken) ? HashToken(currentToken) : null;

            var dtoList = tokens.Select(t => new SessionDto(
                TokenId: t.TokenId,
                DeviceInfo: t.DeviceInfo ?? "Unknown Device",
                IpAddress: t.IpAddress,
                IssuedAt: t.IssuedAt,
                ExpiresAt: t.ExpiresAt,
                IsCurrent: currentHash != null && t.TokenHash == currentHash
            ));

            return ApiResponse<IEnumerable<SessionDto>>.Ok(dtoList, "Active sessions fetched.");
        }

        public async Task<ApiResponse<bool>> RevokeSessionAsync(int userId, int tokenId)
        {
            var success = await _authRepository.RevokeSessionAsync(tokenId, userId);
            if (!success)
            {
                return ApiResponse<bool>.Fail("Session not found or already revoked.");
            }

            await _authRepository.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = userId,
                EventType = "SessionRevoked",
                Success = true,
                Detail = $"Revoked session TokenId #{tokenId}"
            });

            return ApiResponse<bool>.Ok(true, "Session revoked successfully.");
        }

        public async Task<ApiResponse<bool>> RevokeAllSessionsAsync(int userId)
        {
            var count = await _authRepository.RevokeAllSessionsAsync(userId);

            await _authRepository.WriteAuditLogAsync(new AuthAuditLog
            {
                UserId = userId,
                EventType = "AllSessionsRevoked",
                Success = true,
                Detail = $"Revoked {count} active sessions"
            });

            return ApiResponse<bool>.Ok(true, $"All active sessions ({count}) revoked successfully.");
        }

        #region Helper Methods

        private string GenerateJwtToken(User user)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = new SymmetricSecurityKey(_jwtKeyBytes);

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new(ClaimTypes.Name, user.Username),
                new("email", user.Email),
                new("isAdmin", user.IsAdmin.ToString().ToLowerInvariant()),
                new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddMinutes(AccessTokenLifetimeMinutes),
                SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256Signature)
            };

            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }

        private string GenerateMfaChallengeToken(User user)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = new SymmetricSecurityKey(_jwtKeyBytes);

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new("purpose", "mfa_challenge"),
                new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddMinutes(MfaChallengeLifetimeMinutes),
                SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256Signature)
            };

            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }

        private ClaimsPrincipal? ValidateMfaChallengeToken(string token)
        {
            var tokenHandler = new JwtSecurityTokenHandler();
            var key = new SymmetricSecurityKey(_jwtKeyBytes);

            try
            {
                var principal = tokenHandler.ValidateToken(token, new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = key,
                    ValidateIssuer = false,
                    ValidateAudience = false,
                    ClockSkew = TimeSpan.Zero
                }, out var validatedToken);

                if (principal.FindFirst("purpose")?.Value != "mfa_challenge")
                {
                    return null;
                }

                return principal;
            }
            catch
            {
                return null;
            }
        }

        private static string GenerateSecureToken()
        {
            var bytes = RandomNumberGenerator.GetBytes(64);
            return Convert.ToBase64String(bytes)
                .Replace("+", "-")
                .Replace("/", "_")
                .TrimEnd('=');
        }

        private static string HashToken(string token)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
            return Convert.ToHexString(bytes);
        }

        private static (bool IsValid, string ErrorMessage) ValidatePasswordComplexity(string password)
        {
            if (string.IsNullOrWhiteSpace(password) || password.Length < 10)
            {
                return (false, "Password must be at least 10 characters long.");
            }

            // Reject purely numeric passwords
            if (long.TryParse(password, out _) || decimal.TryParse(password, out _))
            {
                return (false, "Password cannot be purely numeric. Please include letters or special characters.");
            }

            return (true, string.Empty);
        }

        public async Task<ApiResponse<UserInfoDto>> GetCurrentUserAsync(int userId)
        {
            var user = await _authRepository.GetUserByIdAsync(userId);
            if (user == null || !user.IsActive)
            {
                return ApiResponse<UserInfoDto>.Fail("User not found or inactive.");
            }

            var userInfo = await BuildUserInfoDtoAsync(user);
            return ApiResponse<UserInfoDto>.Ok(userInfo, "User profile retrieved successfully.");
        }

        private async Task<UserInfoDto> BuildUserInfoDtoAsync(User user)
        {
            if (user.IsAdmin)
            {
                var allModules = await _roleRepository.GetAllModulesAsync();
                var masterModules = allModules
                    .Where(m => string.Equals(m.ModuleGroup, "Master", StringComparison.OrdinalIgnoreCase))
                    .Select(m => m.ModuleName)
                    .OrderBy(n => n)
                    .ToList();

                return new UserInfoDto(
                    UserId: user.UserId,
                    Username: user.Username,
                    Email: user.Email,
                    IsAdmin: true,
                    RoleId: user.RoleId,
                    RoleName: "System Administrator",
                    PermittedModules: masterModules
                );
            }

            string? roleName = null;
            List<string> permittedModules = new();

            if (user.RoleId.HasValue)
            {
                var role = await _roleRepository.GetRoleByIdAsync(user.RoleId.Value);
                roleName = role?.RoleName;
                permittedModules = await _cacheService.GetPermittedModulesByRoleAsync(user.RoleId.Value);
            }

            return new UserInfoDto(
                UserId: user.UserId,
                Username: user.Username,
                Email: user.Email,
                IsAdmin: false,
                RoleId: user.RoleId,
                RoleName: roleName ?? "Standard User",
                PermittedModules: permittedModules
            );
        }

        #endregion
    }
}
