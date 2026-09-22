using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IAuthRepository
    {
        Task<User?> GetUserByUsernameAsync(string username);
        Task<User?> GetUserByIdAsync(int userId);
        Task<int> CreateUserAsync(User user);
        Task<bool> UpdateUserAsync(User user);
        Task<bool> UpdateLoginSuccessAsync(int userId);
        Task<bool> RecordFailedLoginAsync(int userId, int failedCount, DateTime? lockedUntil);
        Task<bool> UpdatePasswordAsync(int userId, string passwordHash);
        Task<bool> SetMfaSecretAsync(int userId, string? secret, bool enabled);
        Task<int> CreateRefreshTokenAsync(RefreshToken token);
        Task<RefreshToken?> GetRefreshTokenByHashAsync(string tokenHash);
        Task<bool> RevokeRefreshTokenAsync(int tokenId, int? replacedByTokenId = null);
        Task<int> RevokeTokenFamilyAsync(int userId);
        Task<IEnumerable<RefreshToken>> GetActiveTokensByUserIdAsync(int userId);
        Task<bool> RevokeSessionAsync(int tokenId, int userId);
        Task<int> RevokeAllSessionsAsync(int userId);
        Task<int> WriteAuditLogAsync(AuthAuditLog log);
    }
}
