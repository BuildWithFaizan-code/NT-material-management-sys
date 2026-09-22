using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IAuthService
    {
        Task<ApiResponse<LoginResponse>> LoginAsync(LoginRequest request, string? ipAddress);
        Task<ApiResponse<LoginResponse>> RefreshTokenAsync(string rawRefreshToken, string? ipAddress, string? deviceInfo);
        Task<ApiResponse<bool>> LogoutAsync(int userId, string? rawRefreshToken);
        Task<ApiResponse<bool>> RegisterUserAsync(RegisterUserRequest request, int adminUserId);
        Task<ApiResponse<bool>> ChangePasswordAsync(int userId, ChangePasswordRequest request);
        Task<ApiResponse<MfaSetupResponse>> SetupMfaAsync(int userId);
        Task<ApiResponse<bool>> VerifyAndEnableMfaAsync(int userId, MfaVerifyRequest request);
        Task<ApiResponse<LoginResponse>> VerifyMfaLoginAsync(MfaLoginRequest request, string? ipAddress);
        Task<ApiResponse<IEnumerable<SessionDto>>> GetActiveSessionsAsync(int userId, string? currentToken);
        Task<ApiResponse<bool>> RevokeSessionAsync(int userId, int tokenId);
        Task<ApiResponse<bool>> RevokeAllSessionsAsync(int userId);
    }
}
