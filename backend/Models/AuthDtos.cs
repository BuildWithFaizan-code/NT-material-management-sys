namespace MMSERP.Api.Models
{
    public record LoginRequest(
        string Username,
        string Password,
        string? DeviceInfo = null
    );

    public record UserInfoDto(
        int UserId,
        string Username,
        string Email,
        bool IsAdmin,
        int? RoleId = null,
        string? RoleName = null,
        List<string>? PermittedModules = null
    );

    public record LoginResponse(
        string? AccessToken,
        string? RefreshToken,
        int ExpiresInSeconds,
        bool MustChangePassword,
        bool RequiresMfa,
        string? MfaChallengeToken,
        UserInfoDto? User
    );

    public record RegisterUserRequest(
        string Username,
        string Email,
        string Password,
        bool IsAdmin = false
    );

    public record ChangePasswordRequest(
        string CurrentPassword,
        string NewPassword
    );

    public record RefreshTokenRequest(
        string? RefreshToken
    );

    public record SessionDto(
        int TokenId,
        string? DeviceInfo,
        string? IpAddress,
        DateTime IssuedAt,
        DateTime ExpiresAt,
        bool IsCurrent
    );

    public record MfaSetupResponse(
        string SecretKey,
        string OtpAuthUri
    );

    public record MfaVerifyRequest(
        string Code,
        string? SecretKey = null
    );

    public record MfaLoginRequest(
        string ChallengeToken,
        string Code,
        string? DeviceInfo = null
    );
}
